FROM    --platform=$TARGETOS/$TARGETARCH node:24-slim

LABEL   author="Matthew M." maintainer="mjmfighter@steampunkvalley.com"
LABEL   org.opencontainers.image.source="https://github.com/mjmfighter/mjyolks"
LABEL   org.opencontainers.image.licenses=MIT

ENV     DEBIAN_FRONTEND=noninteractive

RUN     dpkg --add-architecture i386 \
        && apt-get update && apt-get -y upgrade \
        && apt-get install -y --no-install-recommends \
              lib32gcc-s1 lib32stdc++6 libsdl2-2.0-0:i386 \
              libgdiplus locales tzdata ca-certificates \
              curl unzip iproute2 git findutils rsync \
        && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen \
        && rm -rf /var/lib/apt/lists/*

ENV     LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

RUN     mkdir /wrapper \
        && npm install --prefix /wrapper ws@^8 \
        && useradd -m -d /home/container -s /bin/bash container

USER    container
ENV     USER=container HOME=/home/container NODE_PATH=/wrapper/node_modules
WORKDIR /home/container

COPY    --chown=container:container entrypoint.sh /entrypoint.sh
COPY    --chown=container:container wrapper.js /wrapper/wrapper.js
RUN     chmod +x /wrapper/wrapper.js

CMD     ["/bin/bash", "/entrypoint.sh"]
