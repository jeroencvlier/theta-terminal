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

RUN apk add --no-cache nginx curl && \
    mkdir -p /root/ThetaData/ThetaTerminal

WORKDIR /app

COPY configs/ /root/ThetaData/ThetaTerminal/
COPY ThetaTerminal.jar .
COPY start.sh .
RUN chmod +x start.sh

EXPOSE 25500 8080

ENTRYPOINT ["./start.sh"]