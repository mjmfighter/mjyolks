FROM steamcmd/steamcmd:latest

USER root
RUN apt-get update && apt-get install -y git findutils rsync jq curl tar

RUN     curl -s https://api.github.com/repos/GitoxideLabs/gitoxide/releases/latest \
        | jq -r '.assets[] | select(.name | test("x86_64-unknown-linux-musl.tar.gz")) | .browser_download_url' \
        | xargs curl -L \
        | tar xzf - -C /usr/local/bin --strip-components=1 --wildcards "*/ein" "*/gix"
    

COPY    rust_monitor /bin/rust_monitor
RUN     chmod +x /bin/rust_monitor

COPY entrypoint.sh /entrypoint.sh
COPY sync_functions.sh /sync_functions.sh

USER container

ENTRYPOINT ["/entrypoint.sh"]