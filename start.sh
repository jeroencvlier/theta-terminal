#!/bin/sh

# Simplified start script - no config file modification needed
# Terminal runs on its default ports, nginx proxies from a different port

echo "Starting Theta Terminal with Nginx Reverse Proxy..."

# Set default values if not provided
THETADATAUSERNAME=${THETADATAUSERNAME:-""}
THETADATAPASSWORD=${THETADATAPASSWORD:-""}
THETATERMINALID=${THETATERMINALID:-"0"}

# Determine the terminal port based on ID (from original config)
if [ "$THETATERMINALID" = "0" ]; then
    THETA_TERMINAL_PORT=25510  # Production default
    THETA_WS_PORT=25520
    NGINX_PORT=25500  # Nginx listens on different port
    echo "Using Terminal ID 0 (Production) - Terminal: $THETA_TERMINAL_PORT, Proxy: $NGINX_PORT"
elif [ "$THETATERMINALID" = "1" ]; then
    THETA_TERMINAL_PORT=25511  # Staging default
    THETA_WS_PORT=25521
    NGINX_PORT=25500  # Nginx listens on same port for both
    echo "Using Terminal ID 1 (Staging) - Terminal: $THETA_TERMINAL_PORT, Proxy: $NGINX_PORT"
else
    echo "ERROR: Invalid THETATERMINALID: $THETATERMINALID. Must be 0 or 1."
    exit 1
fi

# Export for nginx template
export THETA_TERMINAL_PORT
export NGINX_PORT

# Generate nginx config from template
echo "Generating nginx configuration..."
echo "  Nginx listening on: $NGINX_PORT"
echo "  Forwarding to terminal on: $THETA_TERMINAL_PORT"
envsubst '${THETA_TERMINAL_PORT} ${NGINX_PORT} ${THETATERMINALID}' < /etc/nginx/templates/nginx.conf.template > /etc/nginx/nginx.conf

# Function to cleanup processes
cleanup() {
    echo "Shutting down services..."
    nginx -s quit 2>/dev/null
    kill $JAVA_PID 2>/dev/null
    wait $JAVA_PID 2>/dev/null
    echo "Services stopped"
    exit 0
}

# Set up signal handlers
trap cleanup TERM INT

# Start the Java Theta Terminal on its default port
echo "Starting Theta Terminal (Java) with ID $THETATERMINALID on port $THETA_TERMINAL_PORT..."
java \
    -XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=75.0 \
    -XX:InitialRAMPercentage=50.0 \
    -Xmx512m \
    -XX:TieredStopAtLevel=1 \
    -jar /app/ThetaTerminal.jar $THETADATAUSERNAME $THETADATAPASSWORD $THETATERMINALID &

JAVA_PID=$!
echo "Theta Terminal started with PID: $JAVA_PID"

# Wait for Theta Terminal to start up
echo "Waiting for Theta Terminal to initialize on port $THETA_TERMINAL_PORT..."
sleep 15

# Check if Theta Terminal is running
if ! kill -0 $JAVA_PID 2>/dev/null; then
    echo "ERROR: Theta Terminal failed to start"
    exit 1
fi

# Test Theta Terminal connection on its default port
echo "Testing Theta Terminal connection on port $THETA_TERMINAL_PORT..."
for i in $(seq 1 30); do
    if curl -s --connect-timeout 5 http://127.0.0.1:$THETA_TERMINAL_PORT/system/mdds/status >/dev/null 2>&1; then
        echo "Theta Terminal is responding on port $THETA_TERMINAL_PORT"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERROR: Theta Terminal not responding after 30 attempts"
        kill $JAVA_PID 2>/dev/null
        exit 1
    fi
    echo "Attempt $i/30: Waiting for Theta Terminal..."
    sleep 2
done

# Start Nginx reverse proxy on the proxy port
echo "Starting Nginx reverse proxy on port $NGINX_PORT..."
nginx -g "daemon off;" &
NGINX_PID=$!

# Wait for Nginx to start
sleep 3

# Check if Nginx is running
if ! kill -0 $NGINX_PID 2>/dev/null; then
    echo "ERROR: Nginx failed to start"
    cat /var/log/nginx/error.log
    kill $JAVA_PID 2>/dev/null
    exit 1
fi

# Test Nginx proxy
echo "Testing Nginx proxy on port $NGINX_PORT..."
for i in $(seq 1 10); do
    if curl -s --connect-timeout 5 http://127.0.0.1:$NGINX_PORT/system/mdds/status >/dev/null 2>&1; then
        echo "Nginx proxy is working on port $NGINX_PORT"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "WARNING: Nginx proxy not responding after 10 attempts"
        cat /var/log/nginx/error.log
    fi
    sleep 1
done

echo "==================================="
echo "Container startup complete!"
echo "Terminal ID: $THETATERMINALID"
echo "Terminal Port: $THETA_TERMINAL_PORT (internal)"
echo "Proxy Port: $NGINX_PORT (external interface)"
echo ""
echo "Port mapping:"
echo "  External → Internal"
echo "  $NGINX_PORT    → $THETA_TERMINAL_PORT"
echo ""
echo "Endpoints:"
echo "  Theta API: http://localhost:$NGINX_PORT"
echo "  Health: http://localhost:8080/health"
echo "  Terminal Health: http://localhost:8080/terminal-health"
echo "  Terminal Info: http://localhost:8080/terminal-info"
echo ""
echo "IMPORTANT: Update your services to use port $NGINX_PORT"
echo "BASE_URL=http://theta-terminal:$NGINX_PORT"
echo "==================================="

# Monitor both processes
while kill -0 $JAVA_PID 2>/dev/null && kill -0 $NGINX_PID 2>/dev/null; do
    sleep 10
done

echo "One of the services has stopped. Shutting down..."
cleanup