FROM ghcr.io/parkervcp/steamcmd:debian

COPY --chown=container:container entrypoint2.sh /entrypoint2.sh
RUN chmod +x /entrypoint2.sh
CMD ["/entrypoint2.sh"]
