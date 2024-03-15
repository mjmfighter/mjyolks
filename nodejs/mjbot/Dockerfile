FROM node:18

LABEL author="Matthew Mjelde" maintainer="webmaster@mjmfighter.com"

RUN apt-get update -y

RUN apt-get install -y ffmpeg wget gnupg ca-certificates

USER container
ENV USER=container  HOME=/home/container
WORKDIR /home/container

COPY        ./mjbot/entrypoint.sh /entrypoint.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]
