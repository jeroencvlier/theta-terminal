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
export BASE_URL

# Generate nginx config from template
echo "Generating nginx configuration..."
echo "  Nginx listening on: $NGINX_PORT"
echo "  Forwarding to terminal on: $THETA_TERMINAL_PORT"
echo "  Base URL for rewrites: $BASE_URL"
envsubst '${THETA_TERMINAL_PORT} ${NGINX_PORT} ${THETATERMINALID} ${BASE_URL}' < /etc/nginx/templates/nginx.conf.template > /etc/nginx/nginx.conf

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

# Start the Java Theta Terminal on its default port with optimized memory settings
echo "Starting Theta Terminal (Java) with ID $THETATERMINALID on port $THETA_TERMINAL_PORT..."
java \
    -XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=60.0 \
    -XX:InitialRAMPercentage=30.0 \
    -Xmx400m \
    -XX:+UseG1GC \
    -XX:G1HeapRegionSize=16m \
    -XX:+DisableExplicitGC \
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
echo "Base URL: $BASE_URL"
echo ""
echo "Port mapping:"
echo "  External → Internal"
echo "  $NGINX_PORT    → $THETA_TERMINAL_PORT"
echo ""
echo "URL rewriting:"
echo "  Next-Page headers: localhost:$THETA_TERMINAL_PORT → $BASE_URL"
echo ""
echo "Endpoints:"
echo "  Theta API: $BASE_URL"
echo "  Health: http://localhost:8080/health"
echo "  Terminal Health: http://localhost:8080/terminal-health"
echo "  Terminal Info: http://localhost:8080/terminal-info"
echo ""
echo "IMPORTANT: Update your services to use: BASE_URL=$BASE_URL"
echo "==================================="

# Monitor both processes with better logging
echo "Monitoring Java PID: $JAVA_PID, Nginx PID: $NGINX_PID"
while kill -0 $JAVA_PID 2>/dev/null && kill -0 $NGINX_PID 2>/dev/null; do
    # Log memory usage every 5 minutes
    if [ $(($(date +%s) % 300)) -eq 0 ]; then
        echo "Memory usage: $(free -h | head -2)"
        echo "Java process status: $(ps -p $JAVA_PID -o pid,ppid,cmd,%mem,%cpu --no-headers 2>/dev/null || echo 'Java process not found')"
        echo "Nginx process status: $(ps aux | grep '[n]ginx' | head -1 || echo 'Nginx process not found')"
        echo "All Java processes: $(ps aux | grep '[j]ava' | wc -l)"
        echo "All Nginx processes: $(ps aux | grep '[n]ginx' | wc -l)"
    fi
    sleep 10
done

# Check which process stopped
if ! kill -0 $JAVA_PID 2>/dev/null; then
    echo "ERROR: Java Theta Terminal process (PID $JAVA_PID) has stopped!"
    wait $JAVA_PID 2>/dev/null
    java_exit_code=$?
    echo "Java process exit code: $java_exit_code"
fi

if ! kill -0 $NGINX_PID 2>/dev/null; then
    echo "ERROR: Nginx process (PID $NGINX_PID) has stopped!"
    wait $NGINX_PID 2>/dev/null
    nginx_exit_code=$?
    echo "Nginx process exit code: $nginx_exit_code"
fi

echo "One of the services has stopped. Shutting down..."
cleanup