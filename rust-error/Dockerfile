FROM    --platform=$TARGETOS/$TARGETARCH ghcr.io/parkervcp/games:rust

LABEL   author="Matthew M." maintainer="mjmfighter@steampunkvalley.com"
LABEL   org.opencontainers.image.source="https://github.com/mjmfighter/mjyolks"
LABEL   org.opencontainers.image.licenses=MIT

ENV     DEBIAN_FRONTEND=noninteractive

RUN	dpkg --add-architecture i386 \
        && apt update \
        && apt upgrade -y \
        && apt install -y lib32gcc-s1 lib32stdc++6 unzip curl iproute2 tzdata libgdiplus libsdl2-2.0-0:i386 git findutils rsync tar jq


RUN     curl -s https://api.github.com/repos/GitoxideLabs/gitoxide/releases/latest \
        | jq -r '.assets[] | select(.name | test("x86_64-unknown-linux-musl.tar.gz")) | .browser_download_url' \
        | xargs curl -L \
        | tar xzf - -C /usr/local/bin --strip-components=1 --wildcards "*/ein" "*/gix"
    

COPY    rust_monitor /bin/rust_monitor
RUN     chmod +x /bin/rust_monitor

USER 	container
ENV  	USER=container HOME=/home/container

WORKDIR /home/container

COPY    entrypoint.sh /entrypoint.sh
# COPY    sync_functions.sh /sync_functions.sh

# COPY    wrapper.js /wrapper.js

ENTRYPOINT [ "/bin/bash", "/entrypoint.sh" ]
# CMD     ["/bin/bash", "/entrypoint.sh"]
