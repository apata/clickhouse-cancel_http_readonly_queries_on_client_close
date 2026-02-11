FROM alpine/openssl as cert-generator
USER 101:101
WORKDIR /certs
RUN openssl req -newkey rsa:2048 -x509 -days 365 -nodes -keyout ./server.key -out ./server.crt -subj '/C=US/ST=State/L=City/O=Organization/CN=localhost'

FROM clickhouse/clickhouse-server:latest
COPY --from=cert-generator /certs/server.crt /etc/clickhouse-server/
COPY --from=cert-generator /certs/server.key /etc/clickhouse-server/
