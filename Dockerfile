FROM eclipse-temurin:21-jre-alpine

# Set working directory
WORKDIR /app

# Install curl using apk
RUN apk add --no-cache curl && \
    mkdir -p /root/ThetaData/ThetaTerminal && \
    rm -rf /var/cache/apk/* && \
    rm -rf /tmp/*

# Copy configuration files and the JAR file
COPY configs/ /root/ThetaData/ThetaTerminal/
COPY ThetaTerminal.jar .

# Expose the required ports
EXPOSE 25510 25520 11000 10000 25511 25521 11001 10001
    

# Set the entry point for the application
ENTRYPOINT java \
    -XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=75.0 \
    -XX:InitialRAMPercentage=50.0 \
    -Xmx512m \
    -XX:TieredStopAtLevel=1 \
    -jar /app/ThetaTerminal.jar $THETADATAUSERNAME $THETADATAPASSWORD $THETATERMINALID
