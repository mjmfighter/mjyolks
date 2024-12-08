FROM    debian:bookworm-slim

LABEL   author="Matthew M." maintainer="mjmfighter@steampunkvalley.com"
LABEL   org.opencontainers.image.source="https://github.com/mjmfighter/mjyolks"
LABEL   org.opencontainers.image.licenses=MIT

ENV     DEBIAN_FRONTEND=noninteractive

WORKDIR /home/container

RUN	dpkg --add-architecture i386 \
        && apt update \
        && apt upgrade -y \
        && apt install -y lib32gcc-s1 lib32stdc++6 unzip curl iproute2 tzdata libgdiplus libsdl2-2.0-0:i386 git findutils rsync \
        && curl -sL https://deb.nodesource.com/setup_21.x | bash - \
        && apt install -y nodejs \
        && useradd -d /home/container -m container \
        && npm install -g ws

ENV     USER=container HOME=/home/container
USER    container

COPY    entrypoint.sh /entrypoint.sh
COPY    sync_functions.sh /sync_functions.sh
COPY    wrapper.js /wrapper.js

CMD     ["/bin/bash", "/entrypoint.sh"]
