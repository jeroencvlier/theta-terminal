FROM eclipse-temurin:21-jre-alpine

# Install nginx and curl
# nginx is needed to proxy requests and mask client IPs
# (terminal locks IP on first request, nginx presents all as 127.0.0.1)
RUN apk add --no-cache nginx curl && \
    mkdir -p /root/ThetaData/ThetaTerminal

# Distrust eMudhra (emSign) root: intermediates compromised Oct 2026.
# ThetaData uses Let's Encrypt (mdds) and its own cert (fpss), so nothing here needs it.
RUN keytool -delete -cacerts -storepass changeit \
    -alias "cn_emsign_root_ca__g1,o_emudhra_technologies_limited,ou_emsign_pki,c_in [jdk]" \
    || echo "emSign root not present"

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

ENTRYPOINT ["./start.sh"]