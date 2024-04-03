FROM 		--platform=$TARGETOS/$TARGETARCH debian:bookworm-slim

LABEL       author="Isaac A." maintainer="isaac@isaacs.site"

LABEL       org.opencontainers.image.source="https://github.com/pterodactyl/yolks"
LABEL       org.opencontainers.image.licenses=MIT

ENV         DEBIAN_FRONTEND=noninteractive

RUN			dpkg --add-architecture i386 \
			&& apt update \
			&& apt upgrade -y \
			&& apt install -y lib32gcc-s1 lib32stdc++6 unzip curl iproute2 tzdata libgdiplus libsdl2-2.0-0:i386 git rsync findutils

RUN		curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
      && apt-get install -y nodejs \
			&& npm install --global ws \
			&& useradd -d /home/container -m container

USER 		container
ENV  		USER=container HOME=/home/container

WORKDIR 	/home/container

COPY 		./entrypoint.sh /entrypoint.sh
COPY    ./entrypoint2.sh /entrypoint2.sh
COPY 		./wrapper.js /wrapper.js

CMD			[ "/bin/bash", "/entrypoint2.sh" ]