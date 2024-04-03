#!/usr/bin/env bash

set -e

# Rotate the latest.log files
cd /home/container || exit 1

if [ -f latest.log.0 ]; then
  cp latest.log.0 latest.log.1
fi
if [ -f latest.log ]; then
  cp latest.log latest.log.0
fi

# If GITHUB_URL and GITHUB_PRIVATE_KEY are set, we'll use them to clone the repository to /tmp/repo (current user is container)
if [ -n "$GITHUB_URL" ] && [ -n "$GITHUB_PRIVATE_KEY" ]; then
  mkdir -p /tmp/repo
  ssh-keyscan github.com >> /home/container/.ssh/known_hosts
  echo "$GITHUB_PRIVATE_KEY" > /home/container/.ssh/id_rsa
  chmod 600 /home/container/.ssh/id_rsa
  # Clone the repository to /tmp/repo using GITHUB_BRANCH if it's set
  if [ -n "$GITHUB_BRANCH" ]; then
    git clone --single-branch --branch "$GITHUB_BRANCH" "$GITHUB_URL" /tmp/repo
  else
    git clone "$GITHUB_URL" /tmp/repo
  fi
  cd /tmp/repo || exit 1

  # If GITHUB_FILE_POSTFIX is set, look for any files with that postfix and remove that postfix using find
  if [ -n "$GITHUB_FILE_POSTFIX" ]; then
    find . -type f -name "*$GITHUB_FILE_POSTFIX" -exec bash -c 'mv "$1" "${1%$2}"' _ {} "$GITHUB_FILE_POSTFIX" \;
  fi

  # Now rsync the files from /tmp/repo to /home/container
  rsync -a --exclude=".git" /tmp/repo/ /home/container/
fi

exec /entrypoint.sh "$@"
