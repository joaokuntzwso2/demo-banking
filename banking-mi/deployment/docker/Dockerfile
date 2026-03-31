FROM amazoncorretto:17-alpine

RUN addgroup -S wso2 && adduser -S wso2carbon -G wso2

WORKDIR /home/wso2carbon

RUN apk add --no-cache unzip bash curl

RUN curl -L https://github.com/wso2/product-micro-integrator/releases/download/v4.5.0/wso2mi-4.5.0.zip -o /tmp/wso2mi.zip \
    && unzip /tmp/wso2mi.zip -d /home/wso2carbon \
    && rm /tmp/wso2mi.zip \
    && chown -R wso2carbon:wso2 /home/wso2carbon

EXPOSE 8290

USER wso2carbon

CMD ["/bin/sh", "-c", "export JAVA_OPTS=\"$JAVA_OPTS -Dhttpclient.hostnameVerifier=Strict -Djdk.tls.rejectClientInitiatedRenegotiation=true\" && /home/wso2carbon/wso2mi-4.5.0/bin/micro-integrator.sh"]