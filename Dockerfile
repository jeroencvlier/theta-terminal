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
EXPOSE 25510 25511


ENTRYPOINT sh -c "apk add --no-cache net-tools && \
    java \
    -XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=75.0 \
    -XX:InitialRAMPercentage=50.0 \
    -Xmx512m \
    -XX:TieredStopAtLevel=1 \
    -jar /app/ThetaTerminal.jar $THETADATAUSERNAME $THETADATAPASSWORD $THETATERMINALID & \
    sleep 5 && \
    echo '==== Network Bindings After Starting App ====' && \
    netstat -tuln && \
    wait"
