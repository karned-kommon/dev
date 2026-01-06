FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y \
    syslog-ng \
    syslog-ng-core \
    syslog-ng-mod-json \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/log /etc/syslog-ng

EXPOSE 514/tcp 514/udp 601/tcp

# Copie le script d'entrée personnalisé
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
