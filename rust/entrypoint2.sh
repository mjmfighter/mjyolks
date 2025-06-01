#!/usr/bin/env bash

set -e

. /sync_functions.sh

HOME_DIR="/home/container"
TMP_GIT_DIR="$HOME_DIR/tmp"
export TMPDIR="$HOME_DIR/.tmp"

# Remove TMPDIR and TMP_GIT_DIR if they exist
rm -rf $TMP_GIT_DIR
rm -rf $TMPDIR

# Create TMPDIR
mkdir -p $TMPDIR

# Rotate the latest.log files
cd $HOME_DIR || exit 1

if [ -f latest.log.0 ]; then
  cp latest.log.0 latest.log.1
fi
if [ -f latest.log ]; then
  cp latest.log latest.log.0
fi

# If GITHUB_URL and GITHUB_ACCESS_TOKEN are set, we'll use them to clone the repository to /tmp/repo (current user is container)
if [ -n "$GITHUB_URL" ] && [ "$GITHUB_SYNC" -eq 1 ]; then
  echo "Cloning repository from $GITHUB_URL"
  mkdir -p $TMP_GIT_DIR

  # Clone the repository. Use the GITHUB_ACCESS_TOKEN to authenticate
  if [ -n "$GITHUB_USERNAME" ] && [ -n "$GITHUB_ACCESS_TOKEN" ]; then
    GITHUB_PHRASED_ADDRESS="https://${GITHUB_USERNAME}:${GITHUB_ACCESS_TOKEN}@${GITHUB_URL#https://}"
  else
    GITHUB_PHRASED_ADDRESS="$GITHUB_URL"
  fi

  # Clone a specific branch if GITHUB_BRANCH is set, else the default branch
  if [ -n "$GITHUB_BRANCH" ]; then
    git clone --single-branch --branch "$GITHUB_BRANCH" "$GITHUB_PHRASED_ADDRESS" $TMP_GIT_DIR
  else
    git clone "$GITHUB_PHRASED_ADDRESS" $TMP_GIT_DIR
  fi

  cd $TMP_GIT_DIR || exit 1

  # If GITHUB_FILE_POSTFIX is set, look for any files with that postfix and remove that postfix using find
  if [ -n "$GITHUB_FILE_POSTFIX" ]; then
    echo "Removing postfix $GITHUB_FILE_POSTFIX from files"
    find . -type f -name "*$GITHUB_FILE_POSTFIX" -exec bash -c 'mv "$1" "${1%$2}"' _ {} "$GITHUB_FILE_POSTFIX" \;
  fi
  SYNC_NEWER_DIRS=("carbon/extensions" "carbon/data")
  SYNC_DELETE_DIRS=("carbon/plugins" "carbon/configs")
  SYNC_DIRS=("carbon/modules" "carbon/managed/modules" "HarmonyMods_Data" "server")

  for DIR in "${SYNC_NEWER_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
      if [ ! -d "$HOME_DIR/$DIR" ]; then
        echo "Creating directory $HOME_DIR/$DIR"
        mkdir -p "$HOME_DIR/$DIR"
      fi
      echo "Copying newer files from $TMP_GIT_DIR/$DIR/ to $HOME_DIR/$DIR/"
      # rsync -q -av --update --delete $TMP_GIT_DIR/$DIR/ $HOME_DIR/$DIR/
      sync_delete_with_ignore "$TMP_GIT_DIR/$DIR" "$HOME_DIR/$DIR"
    fi
  done

  for DIR in "${SYNC_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
      if [ ! -d "$HOME_DIR/$DIR" ]; then
        echo "Creating directory $HOME_DIR/$DIR"
        mkdir -p "$HOME_DIR/$DIR"
      fi
      echo "Copying files from $TMP_GIT_DIR/$DIR/ to $HOME_DIR/$DIR/"
      rsync -q -av $TMP_GIT_DIR/$DIR/ $HOME_DIR/$DIR/
    fi
  done

  for DIR in "${SYNC_DELETE_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
      if [ ! -d "$HOME_DIR/$DIR" ]; then
        echo "Creating directory $HOME_DIR/$DIR"
        mkdir -p "$HOME_DIR/$DIR"
      fi
      echo "Copying (delete) files from $TMP_GIT_DIR/$DIR/ to $HOME_DIR/$DIR/"
      # rsync -q -av --delete --exclude="*.ignore" --filter='dir-merge,- .ignore' $TMP_GIT_DIR/$DIR/ $HOME_DIR/$DIR/
      sync_delete_with_ignore "$TMP_GIT_DIR/$DIR" "$HOME_DIR/$DIR" 
    fi
  done

  # Clean up the repository and ssh keys
  echo "Cleaning up temporary files"
  rm -rf $TMP_GIT_DIR
  rm -rf $HOME_DIR/.ssh

  echo "Finished syncing files"
fi

cd $HOME_DIR || exit 1

exec bash /entrypoint.sh "$@"
