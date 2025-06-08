#!/bin/sh

echo "Starting Theta Terminal proxy..."

THETADATAUSERNAME=${THETADATAUSERNAME:-""}
THETADATAPASSWORD=${THETADATAPASSWORD:-""}
THETATERMINALID=${THETATERMINALID:-"0"}
BASE_URL=${BASE_URL:-"http://theta-terminal-ktbl:25500"}

# Set terminal port based on ID
if [ "$THETATERMINALID" = "0" ]; then
    TERMINAL_PORT=25510
elif [ "$THETATERMINALID" = "1" ]; then
    TERMINAL_PORT=25511
else
    echo "ERROR: THETATERMINALID must be 0 or 1"
    exit 1
fi

# Create nginx config with URL rewriting
cat > /etc/nginx/nginx.conf << EOF
events {
    worker_connections 1024;
}
http {
    # URL rewriting for Next-Page headers
    map \$upstream_http_next_page \$rewritten_next_page {
        default \$upstream_http_next_page;
        "~^http://127\.0\.0\.1:${TERMINAL_PORT}(?<path>.*)$" "${BASE_URL}\$path";
        "~^http://localhost:${TERMINAL_PORT}(?<path>.*)$" "${BASE_URL}\$path";
    }

    server {
        listen 25500;
        location / {
            proxy_pass http://127.0.0.1:${TERMINAL_PORT};
            proxy_set_header X-Real-IP 127.0.0.1;
            proxy_set_header X-Forwarded-For 127.0.0.1;
            proxy_set_header Host \$host;
            
            # Rewrite Next-Page headers
            proxy_hide_header Next-Page;
            add_header Next-Page \$rewritten_next_page always;
        }
    }
    server {
        listen 8080;
        location /health {
            return 200 "OK - Terminal ID: ${THETATERMINALID}, Port: ${TERMINAL_PORT}";
        }
    }
}
EOF

# Start terminal
java -Xmx2g -jar /app/ThetaTerminal.jar $THETADATAUSERNAME $THETADATAPASSWORD $THETATERMINALID &
JAVA_PID=$!

# Wait for terminal
sleep 15

# Start nginx
nginx -g "daemon off;" &

echo "Proxy running on port 25500, terminal on port $TERMINAL_PORT"
echo "Next-Page URLs rewritten to: $BASE_URL"

# Wait
wait