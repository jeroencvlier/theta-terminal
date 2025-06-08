#!/bin/sh

# Start script for Theta Terminal with dynamic Nginx reverse proxy
# Handles both terminal ID 0 (port 25510) and ID 1 (port 25511)

echo "Starting Theta Terminal with Nginx Reverse Proxy..."

# Set default values if not provided
THETADATAUSERNAME=${THETADATAUSERNAME:-""}
THETADATAPASSWORD=${THETADATAPASSWORD:-""}
THETATERMINALID=${THETATERMINALID:-"0"}

# Determine the actual terminal port based on ID
if [ "$THETATERMINALID" = "0" ]; then
    THETA_TERMINAL_PORT=25510
    THETA_WS_PORT=25520
    echo "Using Terminal ID 0 (Production) - HTTP: $THETA_TERMINAL_PORT, WS: $THETA_WS_PORT"
elif [ "$THETATERMINALID" = "1" ]; then
    THETA_TERMINAL_PORT=25511
    THETA_WS_PORT=25521
    echo "Using Terminal ID 1 (Staging) - HTTP: $THETA_TERMINAL_PORT, WS: $THETA_WS_PORT"
else
    echo "ERROR: Invalid THETATERMINALID: $THETATERMINALID. Must be 0 or 1."
    exit 1
fi

# Export for nginx template
export THETA_TERMINAL_PORT

# Generate nginx config from template
echo "Generating nginx configuration for terminal port $THETA_TERMINAL_PORT..."
envsubst '${THETA_TERMINAL_PORT} ${THETATERMINALID}' < /etc/nginx/templates/nginx.conf.template > /etc/nginx/nginx.conf

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

# Start the Java Theta Terminal
echo "Starting Theta Terminal (Java) with ID $THETATERMINALID..."
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

# Test Theta Terminal connection on actual port
echo "Testing Theta Terminal connection on port $THETA_TERMINAL_PORT..."
for i in $(seq 1 30); do
    if curl -s --connect-timeout 5 http://127.0.0.1:$THETA_TERMINAL_PORT/system/mdds/status >/dev/null 2>&1; then
        echo "Theta Terminal is responding on port $THETA_TERMINAL_PORT"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "ERROR: Theta Terminal not responding after 30 attempts"
        echo "Check if terminal ID $THETATERMINALID is correct and port $THETA_TERMINAL_PORT is available"
        kill $JAVA_PID 2>/dev/null
        exit 1
    fi
    echo "Attempt $i/30: Waiting for Theta Terminal..."
    sleep 2
done

# Start Nginx reverse proxy
echo "Starting Nginx reverse proxy (listening on 25510, forwarding to $THETA_TERMINAL_PORT)..."
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
echo "Testing Nginx proxy on port 25510..."
for i in $(seq 1 10); do
    if curl -s --connect-timeout 5 http://127.0.0.1:25510/system/mdds/status >/dev/null 2>&1; then
        echo "Nginx proxy is working on port 25510"
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
echo "Terminal Port: $THETA_TERMINAL_PORT"
echo "Proxy Port: 25510 (external interface)"
echo ""
echo "Endpoints:"
echo "  Theta API: http://localhost:25510"
echo "  Health: http://localhost:8080/health"
echo "  Terminal Health: http://localhost:8080/terminal-health"
echo "  Terminal Info: http://localhost:8080/terminal-info"
echo ""
echo "All external services should connect to port 25510"
echo "Nginx ensures all requests appear as 127.0.0.1 to terminal"
echo "==================================="

# Monitor both processes
while kill -0 $JAVA_PID 2>/dev/null && kill -0 $NGINX_PID 2>/dev/null; do
    sleep 10
done

echo "One of the services has stopped. Shutting down..."
cleanup