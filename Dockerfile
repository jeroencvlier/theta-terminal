FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

RUN mkdir -p /root/ThetaData/ThetaTerminal && \
    rm -rf /var/cache/apk/* && \
    rm -rf /tmp/*

COPY configs/ /root/ThetaData/ThetaTerminal/
COPY ThetaTerminal.jar .

# Using shell form for environment variable expansion
ENTRYPOINT java \
    -XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=75.0 \
    -XX:InitialRAMPercentage=50.0 \
    -Xmx512m \
    -XX:TieredStopAtLevel=1 \
    -jar /app/ThetaTerminal.jar $THETADATAUSERNAME $THETADATAPASSWORD $THETATERMINALID