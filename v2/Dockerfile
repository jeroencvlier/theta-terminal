FROM eclipse-temurin:21-jre-alpine

# Alpine uses 'apk' not 'apt' - but Java 21 is already included above
RUN apk add --no-cache nginx curl && \
    mkdir -p /root/ThetaData/ThetaTerminal

WORKDIR /app

COPY configs/ /root/ThetaData/ThetaTerminal/
COPY ThetaTerminal.jar .
COPY start.sh .
RUN chmod +x start.sh

EXPOSE 25500 8080

ENTRYPOINT ["./start.sh"]


# http://theta-terminal-ktbl:25510/v2