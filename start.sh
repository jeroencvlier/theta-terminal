#!/bin/sh

echo "Starting Theta Terminal v3 with nginx proxy..."

# Validate required environment variables
if [ -z "$THETADATAUSERNAME" ]; then
    echo "ERROR: THETADATAUSERNAME environment variable is required"
    exit 1
fi

if [ -z "$THETADATAPASSWORD" ]; then
    echo "ERROR: THETADATAPASSWORD environment variable is required"
    exit 1
fi

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

# Create credentials
cat > /app/creds.txt << EOF
$THETADATAUSERNAME
$THETADATAPASSWORD
EOF
echo "✓ Credentials created"

# Create config.toml with FULL proper structure (matching default)
cat > /app/config.toml << EOF
host = "0.0.0.0"
port = ${TERMINAL_PORT}
log_directory = "/tmp"

[mdds_server]
host = "mdds-01.thetadata.us"
port = 443
tls = true

[fpss]
enable = true
reconnect_wait = 1000
fpss_queue_depth = 1000000
ws_port = ${WS_PORT}
fpss_region = "fpss_nj_hosts"
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
    access_log /dev/stdout;
    error_log /dev/stderr;
    server {
        listen 25500;
        location / {
            proxy_pass http://127.0.0.1:${TERMINAL_PORT};
            proxy_set_header X-Real-IP 127.0.0.1;
            proxy_set_header X-Forwarded-For 127.0.0.1;
            proxy_set_header Host \$host;
            proxy_connect_timeout 300s;
            proxy_send_timeout 300s;
            proxy_read_timeout 300s;
            proxy_buffering off;
        }
    }
}
NGINX_EOF
echo "✓ nginx: :25500 -> :${TERMINAL_PORT}"

# Start terminal
echo "Starting terminal..."
java -Xmx2g -jar /app/ThetaTerminal.jar &
JAVA_PID=$!

# Wait for terminal
sleep 25

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

wait