# theta-terminal

Theta Terminal v3, containerized, behind an nginx proxy.

The terminal locks to the IP of whoever contacts it first. nginx sits in front and always presents
`127.0.0.1` to it, so the terminal keeps working no matter what client connects.

## Quick start

```bash
echo "THETADATA_API_KEY=your_key_here" > .env.prod
make build
make up
curl http://localhost:25500/v3/terminal/mdds/status
```

## Environments

`docker-compose.yml` defines two services sharing the same image, split by env file and host port:

| service | env file | `THETA_ENV` | host port | `fpss_region` | `/mcp` default |
|---|---|---|---|---|---|
| `theta-terminal-v3-prod` | `.env.prod` | `PROD` | 25500 | `fpss_nj_hosts` | blocked (403) |
| `theta-terminal-v3-stage` | `.env.stage` | `STAGE` | 25501 | `fpss_stage_hosts` | enabled |

`MCP_ENABLED=true|false` overrides the per-env default either way. Stage runs behind the `stage`
compose profile, so it only starts when asked for explicitly.

## Env vars

| var | required | default | notes |
|---|---|---|---|
| `THETADATA_API_KEY` | yes | - | terminal auth; startup fails without it |
| `THETA_ENV` | no | `PROD` | `PROD` or `STAGE`, see table above |
| `MCP_ENABLED` | no | per-env | `true`/`false`, overrides the `/mcp` default |
| `THETATERMINALID` | no | unset | shifts the internal terminal port to `25503+ID` and websocket port to `25520+ID`; used only when running more than one terminal on the same host |

## Make targets

```
build         Build the Docker image
up            Start the prod container
down          Stop and remove the prod container
logs          Follow container logs
restart       Restart the prod container
up-all        Start prod + stage (stage on :25501)
up-stage      Start stage only
down-stage    Stop stage only
down-all      Stop prod + stage
restart-all   Restart prod + stage
clean         Remove containers, images, and volumes
start         Build, start, and follow logs
all           Build and start
test          Start prod and check the connection
version       Print the running terminal's version
```

## How it runs

`start.sh` generates `/app/config.toml` and `/etc/nginx/nginx.conf` at container boot from the env
vars above; nothing environment-specific is baked into the image. nginx listens on `25500` and proxies
to the terminal's internal port. First boot can take 5+ minutes while the terminal self-updates.

## Troubleshooting

- **Terminal exits on startup** - check `docker compose logs`; `start.sh` prints the terminal's own log
  on failure.
- **Port 25501 already in use** - something else is bound to it, or stage is already running
  (`make down-stage`).
- **`ERROR: THETADATA_API_KEY environment variable is required`** - the relevant env file
  (`.env.prod` / `.env.stage`) is missing or empty.

## Deploy

`render.yaml` is currently commented out. It expects the `main` branch, a `theta-terminal-envs` env
group providing `THETADATA_API_KEY`, and health-checks `/v3/terminal/mdds/status`.
