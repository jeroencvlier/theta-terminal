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
user root;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Map to rewrite Next-Page headers - simple hostname/port replacement only
    map \$upstream_http_next_page \$next_page_rewritten {
        default \$upstream_http_next_page;
        
        # Replace internal URLs with external BASE_URL, preserving the exact path
        "~^http://127\.0\.0\.1:${TERMINAL_PORT}(?<path>.*)$" "http://theta-terminal-ktbl:25500\$path";
        "~^http://localhost:${TERMINAL_PORT}(?<path>.*)$" "http://theta-terminal-ktbl:25500\$path";
        
        # Handle case where terminal returns just the domain without path
        "~^http://127\.0\.0\.1:${TERMINAL_PORT}$" "http://theta-terminal-ktbl:25500";
        "~^http://localhost:${TERMINAL_PORT}$" "http://theta-terminal-ktbl:25500";
    }

    # Logging format
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100m;
    
    # Proxy settings for better performance
    proxy_buffering on;
    proxy_buffer_size 4k;
    proxy_buffers 8 4k;
    proxy_busy_buffers_size 8k;
    proxy_temp_file_write_size 8k;

    # Upstream for Theta Terminal 
    upstream theta_terminal {
        server 127.0.0.1:${TERMINAL_PORT};
        keepalive 32;
    }

    # Main proxy server - listens on the proxy port
    server {
        listen 25500;
        server_name _;

        # Handle health checks and root requests - return simple response instead of forwarding
        location = / {
            access_log off;
            return 200 "Theta Terminal Proxy Active\\n";
            add_header Content-Type text/plain;
        }

        # Handle favicon requests
        location = /favicon.ico {
            return 204;
            access_log off;
        }

        # Proxy ALL API requests to Theta Terminal (preserves complete path including /v2)
        location /v2/ {
            # Preserve the COMPLETE original request URI including /v2 path
            proxy_pass http://theta_terminal;
            
            # CRITICAL: Set headers to ensure single IP perspective for terminal
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP 127.0.0.1;
            proxy_set_header X-Forwarded-For 127.0.0.1;
            proxy_set_header X-Forwarded-Proto \$scheme;
            
            # Connection settings
            proxy_connect_timeout 30s;
            proxy_send_timeout 120s;
            proxy_read_timeout 120s;
            
            # Handle HTTP/1.1 properly
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            
            # Don't buffer responses for streaming/pagination
            proxy_buffering off;
            proxy_cache off;
            
            # Handle redirects properly
            proxy_redirect off;
            
            # IMPORTANT: Handle Next-Page header rewriting
            proxy_hide_header Next-Page;
            add_header Next-Page \$next_page_rewritten always;
            
            # Pass through other Theta API specific headers
            proxy_pass_header Content-Type;
            proxy_pass_header Content-Length;
            proxy_pass_header Access-Control-Allow-Origin;
            proxy_pass_header Access-Control-Allow-Methods;
            proxy_pass_header Access-Control-Allow-Headers;
        }

        # Proxy other API requests (non-v2)
        location /system/ {
            proxy_pass http://theta_terminal;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP 127.0.0.1;
            proxy_set_header X-Forwarded-For 127.0.0.1;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_connect_timeout 10s;
            proxy_send_timeout 10s;
            proxy_read_timeout 10s;
        }
    }

    # Health check server for container orchestration
    server {
        listen 8080;
        server_name _;
        access_log off;

        location /health {
            return 200 "container healthy - proxy on 25500, terminal on port ${TERMINAL_PORT}\\n";
            add_header Content-Type text/plain;
        }

        # Proxy health check to terminal
        location /terminal-health {
            proxy_pass http://theta_terminal/system/mdds/status;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP 127.0.0.1;
            proxy_set_header X-Forwarded-For 127.0.0.1;
            proxy_connect_timeout 10s;
            proxy_send_timeout 10s;
            proxy_read_timeout 10s;
        }

        # Get terminal info
        location /terminal-info {
            return 200 "Terminal ID: ${THETATERMINALID}, Terminal Port: ${TERMINAL_PORT}, Proxy Port: 25500\\n";
            add_header Content-Type text/plain;
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