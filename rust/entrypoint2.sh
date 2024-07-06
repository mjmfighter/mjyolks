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

# If GITHUB_URL and GITHUB_ACCESS_TOKEN are set, we'll use them to clone the repository to /tmp/repo (current user is container)
if [ -n "$GITHUB_URL" ]; then
  echo "Cloning repository from $GITHUB_URL"
  mkdir -p /tmp/repo

  # Clone the repository. Use the GITHUB_ACCESS_TOEKN to authenticate
  if [ -n "$GITHUB_USERNAME" ] && [ -n "$GITHUB_ACCESS_TOKEN" ]; then
    GITHUB_PHRASED_ADDRESS="https://${GITHUB_USERNAME}:${GITHUB_ACCESS_TOKEN}@${GITHUB_URL#https://}"
  else
    GITHUB_PHRASED_ADDRESS="$GITHUB_URL"
  fi

  # Clone a specific branch if GITHUB_BRANCH is set, else the default branch
  if [ -n "$GITHUB_BRANCH" ]; then
    git clone --single-branch --branch "$GITHUB_BRANCH" "$GITHUB_PHRASED_ADDRESS" /tmp/repo
  else
    git clone "$GITHUB_PHRASED_ADDRESS" /tmp/repo
  fi

  cd /tmp/repo || exit 1

  # If GITHUB_FILE_POSTFIX is set, look for any files with that postfix and remove that postfix using find
  if [ -n "$GITHUB_FILE_POSTFIX" ]; then
    echo "Removing postfix $GITHUB_FILE_POSTFIX from files"
    find . -type f -name "*$GITHUB_FILE_POSTFIX" -exec bash -c 'mv "$1" "${1%$2}"' _ {} "$GITHUB_FILE_POSTFIX" \;
  fi

  EXCLUDE_DIRS=("carbon/data")

  RSYNC_OPTS="-a --exclude=.git"

  for DIR in "${EXCLUDE_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
      RSYNC_OPTS+=" --exclude=$DIR"
    fi
  done

  # Rsync the files from /tmp/repo to /home/container
  echo "Copying files from /tmp/repo to /home/container"
  rsync $RSYNC_OPTS /tmp/repo/ /home/container/

  # Rsync the exclude directories from /tmp/repo to /home/container with --delete
  for DIR in "${EXCLUDE_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
      echo "Copying files from $DIR to /home/container"
      rsync -av --delete /tmp/repo/$DIR/ /home/container/$DIR/
    fi
  done

  # Clean up the repository and ssh keys
  echo "Cleaning up temporary files"
  rm -rf /tmp/repo
  rm -rf /home/container/.ssh

  echo "Finished syncing files"
fi

cd /home/container || exit 1

exec bash /entrypoint.sh "$@"
