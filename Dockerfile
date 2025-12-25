FROM eclipse-temurin:21-jre-alpine

# Install nginx and curl
# nginx is needed to proxy requests and mask client IPs
# (terminal locks IP on first request, nginx presents all as 127.0.0.1)
RUN apk add --no-cache nginx curl && \
    mkdir -p /root/ThetaData/ThetaTerminal

WORKDIR /app

# Copy the v3 terminal JAR
COPY ThetaTerminalv3.jar ./ThetaTerminalv3.jar

# Copy startup script
COPY start.sh .
RUN chmod +x start.sh

# Expose ports:
# 25500 - nginx proxy (external access)
# 25503 - terminal default port (internal only, not exposed)
EXPOSE 25500

# Health check using v3 endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:25500/v3/terminal/mdds/status || exit 1

ENTRYPOINT ["./start.sh"]