FROM    --platform=$TARGETOS/$TARGETARCH debian:bullseye-slim

LABEL   author="Matthew M." maintainer="mjmfighter@steampunkvalley.com"
LABEL   org.opencontainers.image.source="https://github.com/mjmfighter/mjyolks"
LABEL   org.opencontainers.image.licenses=MIT

ENV     DEBIAN_FRONTEND=noninteractive

RUN	dpkg --add-architecture i386 \
        && apt update \
        && apt upgrade -y \
        && apt install -y lib32gcc-s1 lib32stdc++6 unzip curl iproute2 tzdata libgdiplus libsdl2-2.0-0:i386 git findutils rsync tar jq \
        && useradd -d /home/container -m container


RUN set -e; \
        ASSET_PATTERN="x86_64-unknown-linux-musl.tar.gz"; \
        release_data=$(curl -s "https://api.github.com/repos/GitoxideLabs/gitoxide/releases/latest"); \
        download_url=$(echo "$release_data" \
          | jq -r '.assets[] | select(.name | test("'$ASSET_PATTERN'")) | .browser_download_url'); \
        if [ -z "$download_url" ]; then \
            echo "Error: Could not find an asset matching '$ASSET_PATTERN' in the latest release."; \
            exit 1; \
        fi; \
        curl -L "$download_url" \
          | tar xzf - -C /bin --strip-components=1 --wildcards "*/ein" "*/gix"
    

COPY    rust_monitor /bin/rust_monitor
RUN     chmod +x /bin/rust_monitor

ENV     USER=container HOME=/home/container
USER    container

WORKDIR /home/container

COPY    entrypoint.sh /entrypoint.sh
COPY    sync_functions.sh /sync_functions.sh

# COPY    wrapper.js /wrapper.js

CMD     ["/bin/bash", "/entrypoint.sh"]
