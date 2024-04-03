FROM ghcr.io/pterodactyl/games:rust

RUN apt-get update && apt-get install -y git findutils rsync

COPY --chown=container:container entrypoint2.sh /entrypoint2.sh
RUN chmod +x /entrypoint2.sh
CMD ["/entrypoint2.sh"]