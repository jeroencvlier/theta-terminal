# Theta Terminal v3 - Docker Setup

Professional Docker setup for running Theta Data's Terminal v3 with nginx reverse proxy for multi-client support.

## 🎯 What This Is

A production-ready Docker container that runs Theta Terminal v3 with:
- **nginx reverse proxy** - Masks client IPs to prevent terminal locking
- **Automatic configuration** - Creates config files from environment variables
- **Multi-terminal support** - Optional terminal ID for running multiple instances
- **Health checks** - Built-in monitoring for Render/production deployments

## ⚡ Quick Start

### Prerequisites
- Docker & Docker Compose
- Theta Data account ([sign up here](https://thetadata.us))
- Java 21+ (included in Docker image)

### 5-Minute Setup

```bash
# 1. Clone/download this repository
cd theta-terminal

# 2. Get the v3 terminal JAR
curl -o terminal_versions/ThetaTerminalv3.jar \
     https://thetadata.us/ThetaTerminalv3.jar

# 3. Create credentials file
cp .env.example .env
# Edit .env with your Theta Data email and password

# 4. Build and start
make build
make up

# 5. Test connection
make test
```

**That's it!** Terminal is now running at `http://localhost:25500`

## 📊 Architecture

```
┌─────────────────────────────────────────────────────┐
│  Docker Container                                   │
│                                                     │
│  ┌──────────┐           ┌────────────────────────┐ │
│  │  nginx   │  Proxy    │  Theta Terminal v3     │ │
│  │  :25500  │──────────►│  :25503 (or 25504+)    │ │
│  └──────────┘           └────────────────────────┘ │
│       │                          │                  │
│  Masks all IPs              Reads config.toml      │
│  as 127.0.0.1               and creds.txt          │
│                                                     │
└─────────────────────────────────────────────────────┘
         │
         ▼
   Multiple Clients
   (any IP address)
```

### Why nginx?

Theta Terminal locks connections by IP address. Without nginx:
- First client connects ✓
- Second client (different IP) gets blocked ✗

With nginx as proxy:
- All requests appear as `127.0.0.1` to terminal
- Multiple clients can connect simultaneously ✓
- No IP locking issues ✓

### Ports

- **25500** - nginx proxy (external, what you connect to)
- **25503+** - Terminal (internal only, increments with Terminal ID)
- **25520+** - WebSocket/FPSS (internal, increments with Terminal ID)

## 📁 Project Structure

```
theta-terminal/
├── 🔧 Core Files
│   ├── Dockerfile                    # Docker image definition
│   ├── docker-compose.yml            # Container configuration
│   ├── start.sh                      # Startup script (creates configs)
│   ├── Makefile                      # Build commands
│   └── render.yaml                   # Render.com deployment
│
├── 🔒 Configuration
│   ├── .env                          # Your credentials (create this!)
│   ├── .env.example                  # Template
│   ├── .gitignore                    # Protects secrets
│   └── configs/
│       └── config.toml.example       # Terminal config template
│
├── 📦 Terminal
│   └── terminal_versions/
│       └── ThetaTerminalv3.jar       # v3 terminal (download this!)
│
├── 💻 Examples & Tools
│   ├── examples.py                   # Python API examples
│   ├── discover_v3_endpoints.py      # Endpoint discovery helper
│   ├── requirements.txt              # Python dependencies
│   └── setup.sh                      # Interactive setup script
│
└── 📚 Documentation
    ├── README.md                     # This file
    ├── QUICKSTART.md                 # 5-minute setup
    ├── SIMPLE_REFERENCE.md           # Quick reference
    ├── CURRENT_STATUS.md             # Setup status & testing
    ├── V2_V3_CONFIG_COMPARISON.md    # Config differences
    ├── NGINX_EXPLAINED.md            # Why nginx is needed
    └── ... (more detailed docs)
```

## ⚙️ Configuration

### Required Environment Variables

Create a `.env` file:

```bash
# Your Theta Data credentials
THETADATAUSERNAME=your-email@example.com
THETADATAPASSWORD=your-password
```

### Optional Environment Variables

```bash
# For multiple terminal instances
THETATERMINALID=0     # Terminal 0: port 25503
THETATERMINALID=1     # Terminal 1: port 25504
# etc.
```

### Auto-Generated Files

The `start.sh` script automatically creates:

1. **`/app/creds.txt`** - Credentials file
   ```
   your-email@example.com
   your-password
   ```

2. **`/app/config.toml`** - Terminal configuration
   ```toml
   host = "0.0.0.0"
   port = 25503
   log_directory = "/tmp"
   # ... full config structure
   ```

## 🚀 Usage

### Basic Commands

```bash
make build      # Build Docker image
make up         # Start container
make down       # Stop container
make logs       # View logs
make restart    # Restart (gets terminal updates)
make test       # Test connection
make clean      # Remove everything
```

### Python Examples

```bash
# Install dependencies
pip install -r requirements.txt

# Run examples (note: v3 data endpoints need verification)
python examples.py

# Discover v3 endpoints
python discover_v3_endpoints.py
```

### API Usage

```python
import requests

# Check status (v3 endpoints - confirmed working)
response = requests.get("http://localhost:25500/v3/terminal/mdds/status")
print(response.text)  # CONNECTED

# Data queries - check docs for correct v3 paths
# ⚠️ v2 endpoints return 410 Gone
# https://docs.thetadata.us/
```

## 📖 Documentation

### Getting Started
- **[QUICKSTART.md](QUICKSTART.md)** - 5-minute setup guide
- **[SIMPLE_REFERENCE.md](SIMPLE_REFERENCE.md)** - Quick command reference
- **[CURRENT_STATUS.md](CURRENT_STATUS.md)** - Current setup status

### Configuration & Setup
- **[V2_V3_CONFIG_COMPARISON.md](V2_V3_CONFIG_COMPARISON.md)** - v2 vs v3 config differences
- **[TERMINAL_ID_EXPLAINED.md](TERMINAL_ID_EXPLAINED.md)** - Multi-terminal setup
- **[NGINX_EXPLAINED.md](NGINX_EXPLAINED.md)** - Why nginx is needed

### Troubleshooting & Advanced
- **[PORT_TROUBLESHOOTING.md](PORT_TROUBLESHOOTING.md)** - Port configuration issues
- **[FIXED_TERMINAL_ID.md](FIXED_TERMINAL_ID.md)** - Terminal ID implementation details
- **[410_ERRORS_EXPLAINED.md](410_ERRORS_EXPLAINED.md)** - v2 endpoint deprecation

### Reference
- **[FILES.md](FILES.md)** - Complete file manifest
- **[VISUAL.md](VISUAL.md)** - Architecture diagrams
- **[INDEX.md](INDEX.md)** - Documentation index

## 🌐 Deploying to Render

### Setup

1. Push this repository to GitHub/GitLab
2. Connect repository to Render
3. Create environment group: `theta-terminal-envs`
4. Add environment variables:
   - `THETADATAUSERNAME`
   - `THETADATAPASSWORD`
   - `THETATERMINALID` (optional)

### Deploy

Render will automatically:
- Build from `Dockerfile`
- Use `render.yaml` configuration
- Run health checks at `/v3/terminal/mdds/status`
- Auto-deploy on pushes to `main` branch

## 🔍 API Endpoints

### Terminal Control (v3 - Confirmed Working) ✅

```bash
# Check MDDS connection
curl http://localhost:25500/v3/terminal/mdds/status
# Returns: CONNECTED

# Check FPSS connection
curl http://localhost:25500/v3/terminal/fpss/status
# Returns: CONNECTED

# Shutdown terminal (use with caution!)
curl http://localhost:25500/v3/terminal/shutdown
```

### Data API (v3 - Paths Changed from v2) ⚠️

**Important**: v2 data endpoints (`/v2/*`) return **410 Gone** in v3.

The data API paths have changed. Check the official documentation:
**https://docs.thetadata.us/**

To discover endpoints:
```bash
python discover_v3_endpoints.py
```

## 🐛 Troubleshooting

### Container Won't Start

```bash
# Check logs
make logs

# Verify credentials
docker compose exec theta-terminal cat /app/creds.txt

# Check Docker
docker compose ps
```

### Connection Fails

```bash
# Test terminal directly
curl http://localhost:25500/v3/terminal/mdds/status

# Should return: CONNECTED

# Check nginx is running
docker compose exec theta-terminal ps aux | grep nginx
```

### 410 Gone Errors

If you get 410 errors, you're using old v2 endpoints. The v3 terminal has completely removed them.

**Solution**: Check https://docs.thetadata.us/ for correct v3 API paths.

### Port Already in Use

Edit `docker-compose.override.yml`:
```yaml
services:
  theta-terminal:
    ports:
      - "25501:25500"  # Use different host port
```

## 📊 v2 to v3 Migration

### Key Changes

| Feature | v2 | v3 |
|---------|----|----|
| **Pagination** | Required (Next-Page headers) | None - single response |
| **Config Format** | `.properties` | `.toml` |
| **Credentials** | Command-line args | `creds.txt` file |
| **API Endpoints** | `/v2/*` | `/v3/*` (changed paths) |
| **Terminal ID** | Command-line arg | Config file (optional) |
| **Performance** | Baseline | 2-10x faster |
| **Output Formats** | JSON | JSON, NDJSON, CSV |

### Migration Steps

1. **Update Docker files** - Use this repository's files
2. **Create `.env`** - With your credentials
3. **Download v3 JAR** - Get ThetaTerminalv3.jar
4. **Update API calls** - Remove pagination handling
5. **Update endpoints** - Change from `/v2/*` to correct v3 paths
6. **Test** - Run `make test`

See **[MIGRATION.md](MIGRATION.md)** for detailed migration guide.

## 🎯 v3 Benefits

✅ **No pagination** - All data in single response  
✅ **2-10x faster** - Especially for large datasets  
✅ **Simpler code** - No pagination loops needed  
✅ **New formats** - NDJSON and CSV support  
✅ **Auto-updates** - Terminal updates on restart  
✅ **More capacity** - 2x concurrent requests vs v2  

## 📝 Common Workflows

### Single Terminal (Most Common)

```bash
# .env
THETADATAUSERNAME=email@example.com
THETADATAPASSWORD=password

# Start
make build && make up
```

### Multiple Terminals

```yaml
# docker-compose.yml
services:
  theta-0:
    environment:
      - THETATERMINALID=0
    ports:
      - "25500:25500"
      
  theta-1:
    environment:
      - THETATERMINALID=1
    ports:
      - "25501:25500"
```

### Development & Testing

```bash
# Start with logs
make start

# Restart (gets updates during beta)
make restart

# Test connection
make test

# Clean slate
make clean && make all
```

## 🔐 Security Notes

- Never commit `.env` file (protected by `.gitignore`)
- Never commit `creds.txt` (created at runtime only)
- nginx binds to `0.0.0.0` - use firewall if needed
- Keep `ThetaTerminalv3.jar` updated

## 🆘 Support

### Official Resources
- **Documentation**: https://docs.thetadata.us/
- **Discord**: https://discord.gg/thetadata
- **Email**: support@thetadata.net
- **Terminal Download**: https://thetadata.us/ThetaTerminalv3.jar

### Project Documentation
- Read `INDEX.md` for complete documentation navigation
- Check `SIMPLE_REFERENCE.md` for quick commands
- See troubleshooting docs for common issues

## 📜 License

This Docker setup is for use with Theta Data's Theta Terminal. Refer to Theta Data's terms of service for usage rights.

## 🙏 Acknowledgments

- Theta Data for providing the terminal and market data
- This setup was created to simplify v3 deployment with IP masking support

---

**Questions?** Check the documentation files or join the Theta Data Discord.

**Contributing?** PRs welcome for documentation improvements and bug fixes.

**Need v3 API help?** Visit https://docs.thetadata.us/ for official v3 REST API documentation.