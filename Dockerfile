# FROM eclipse-temurin:21-jre-alpine

# # Set working directory
# WORKDIR /app

# # Install curl using apk
# RUN apk add --no-cache curl && \
#     mkdir -p /root/ThetaData/ThetaTerminal && \
#     rm -rf /var/cache/apk/* && \
#     rm -rf /tmp/*

# # Copy configuration files and the JAR file
# COPY configs/ /root/ThetaData/ThetaTerminal/
# COPY ThetaTerminal.jar .

# # Expose the required ports
# EXPOSE 25510 25511


# # Set the entry point for the application
# ENTRYPOINT java \
#     -XX:+UseContainerSupport \
#     -XX:MaxRAMPercentage=75.0 \
#     -XX:InitialRAMPercentage=50.0 \
#     -Xmx512m \
#     -XX:TieredStopAtLevel=1 \
#     -jar /app/ThetaTerminal.jar $THETADATAUSERNAME $THETADATAPASSWORD $THETATERMINALID


FROM eclipse-temurin:21-jre-alpine

# Install nginx and sed for config modification
RUN apk add --no-cache nginx curl gettext sed && \
    mkdir -p /root/ThetaData/ThetaTerminal && \
    mkdir -p /var/log/nginx && \
    mkdir -p /var/lib/nginx/tmp && \
    mkdir -p /etc/nginx/templates && \
    rm -rf /var/cache/apk/* && \
    rm -rf /tmp/*

# Set working directory
WORKDIR /app

# Copy configuration files and the JAR file
COPY configs/ /root/ThetaData/ThetaTerminal/
COPY ThetaTerminal.jar .

# Copy nginx configuration template
COPY nginx.conf.template /etc/nginx/templates/nginx.conf.template

# Copy startup script
COPY start.sh .
RUN chmod +x start.sh

# Expose the proxy port (25500) and health check port (8080)
# Note: If your BASE_URL uses :25500, make sure this matches
EXPOSE 25500 8080

# Use the start script as entry point
ENTRYPOINT ["./start.sh"]