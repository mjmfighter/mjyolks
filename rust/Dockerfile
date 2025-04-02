FROM ghcr.io/parkervcp/games:rust

USER root
RUN apt-get update && apt-get install -y git findutils rsync
USER container

COPY --chown=container:container entrypoint2.sh /entrypoint2.sh
COPY --chown=continer:container sync_functions.sh /sync_functions.sh
COPY --chown=container:container ./wrapper.js /wrapper/wrapper.js
RUN chmod +x /entrypoint2.sh
CMD ["/entrypoint2.sh"]