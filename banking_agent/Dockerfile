FROM ballerina/ballerina:2201.12.11

USER root
WORKDIR /app

COPY . /app

RUN rm -rf /app/target /app/Dependencies.toml || true
RUN bal build

EXPOSE 8293

CMD ["bal", "run"]