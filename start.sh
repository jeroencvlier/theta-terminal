#!/bin/sh

echo "Starting Theta Terminal v3 with nginx proxy..."

# Validate required environment variables
if [ -z "$THETADATA_API_KEY" ]; then
    echo "ERROR: THETADATA_API_KEY environment variable is required"
    exit 1
fi

# Environment: PROD (production) or STAGE (staging)
THETA_ENV=${THETA_ENV:-PROD}
case "$THETA_ENV" in
    PROD)
        FPSS_REGION="fpss_nj_hosts"
        ;;
    STAGE)
        FPSS_REGION="fpss_stage_hosts"
        ;;
    *)
        echo "ERROR: THETA_ENV must be PROD or STAGE (got '$THETA_ENV')"
        exit 1
        ;;
esac
echo "Environment: $THETA_ENV (fpss_region=$FPSS_REGION)"

# Optional: Terminal ID
THETATERMINALID=${THETATERMINALID:-""}

# Determine port
if [ -n "$THETATERMINALID" ]; then
    TERMINAL_PORT=$((25503 + THETATERMINALID))
    WS_PORT=$((25520 + THETATERMINALID))
    echo "Terminal ID: $THETATERMINALID"
    echo "Terminal port: $TERMINAL_PORT"
    echo "WebSocket port: $WS_PORT"
else
    TERMINAL_PORT=25503
    WS_PORT=25520
    echo "Single terminal mode"
    echo "Terminal port: $TERMINAL_PORT"
fi

# API key auth: terminal reads THETADATA_API_KEY from environment (no creds.txt needed)
echo "✓ API key auth (THETADATA_API_KEY)"

# Create config.toml with FULL proper structure (matching default)
cat > /app/config.toml << EOF
host = "0.0.0.0"
port = ${TERMINAL_PORT}
log_directory = "/tmp"
request_queue_length = 128

[env]
mdds_type = "${THETA_ENV}"

[mdds_server]
host = "mdds-01.thetadata.us"
port = 443
tls = true

[fpss]
enable = true
reconnect_wait = 1000
fpss_queue_depth = 1000000
ws_port = ${WS_PORT}
fpss_region = "${FPSS_REGION}"
fpss_nj_hosts = "nj-a.thetadata.us:20000,nj-a.thetadata.us:20001,nj-b.thetadata.us:20000,nj-b.thetadata.us:20001"
fpss_stage_hosts = "nj-a.thetadata.us:20100,test-server.thetadata.us:20100,test-server.thetadata.us:20101"
fpss_dev_hosts = "nj-a.thetadata.us:20200,test-server.thetadata.us:20200,test-server.thetadata.us:20201"
EOF

echo "✓ config.toml created with port=$TERMINAL_PORT"

# Create nginx config
cat > /etc/nginx/nginx.conf << NGINX_EOF
events {
    worker_connections 1024;
}
http {
    log_format timed '\$remote_addr [\$time_local] "\$request" \$status \${body_bytes_sent}B \${request_time}s';
    access_log /dev/stdout timed;
    error_log /dev/stderr;
    server {
        listen 25500;
        location /mcp {
            return 403;
        }
        location / {
            proxy_pass http://127.0.0.1:${TERMINAL_PORT};
            proxy_set_header X-Real-IP 127.0.0.1;
            proxy_set_header X-Forwarded-For 127.0.0.1;
            proxy_set_header Host \$host;
            proxy_connect_timeout 3600s;
            proxy_send_timeout 3600s;
            proxy_read_timeout 3600s;
            proxy_buffering off;
        }
    }
}
NGINX_EOF
echo "✓ nginx: :25500 -> :${TERMINAL_PORT}"

# Start terminal and log output
echo "Starting terminal (auto-update may take 5+ minutes on first run)..."
java -Xmx2g -jar /app/ThetaTerminalv3.jar > /tmp/terminal.log 2>&1 &
JAVA_PID=$!

# Wait for terminal to actually start (no timeout)
echo "Waiting for terminal startup..."
SECONDS=0
while true; do
    # Check if process died
    if ! kill -0 $JAVA_PID 2>/dev/null; then
        echo "✗ Terminal died after ${SECONDS}s:"
        cat /tmp/terminal.log
        exit 1
    fi
    
    # Check if started
    if grep -q "Starting server" /tmp/terminal.log 2>/dev/null; then
        echo "✓ Terminal started after ${SECONDS}s!"
        break
    fi
    
    # Progress update every 30 seconds
    if [ $((SECONDS % 30)) -eq 0 ] && [ $SECONDS -gt 0 ]; then
        echo "Still waiting... (${SECONDS}s) - terminal is updating/starting"
        tail -2 /tmp/terminal.log 2>/dev/null || echo "(downloading update...)"
    fi
    
    sleep 1
    SECONDS=$((SECONDS + 1))
done

echo "Terminal startup complete!"
cat /tmp/terminal.log

# Start nginx
nginx -g "daemon off;" &
NGINX_PID=$!

echo ""
echo "============================================"
echo "Running!"
echo "============================================"
echo "Terminal PID: $JAVA_PID"
echo "nginx PID: $NGINX_PID"
if [ -n "$THETATERMINALID" ]; then
    echo "Terminal ID: $THETATERMINALID"
fi
echo "Terminal port: $TERMINAL_PORT"
echo "nginx proxy: :25500 -> :${TERMINAL_PORT}"
echo "Test: curl http://localhost:25500/v3/terminal/mdds/status"
echo ""

# Keep showing logs
tail -f /tmp/terminal.log &
wait