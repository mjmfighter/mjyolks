#!/bin/bash

set -e

# Set NODE_PATH for node to use global installs
# export NODE_PATH=$(npm root -g)

. /sync_functions.sh

cd /home/container

HOME_DIR="/home/container"
TMP_GIT_DIR="$HOME_DIR/tmp-clone"
export TMPDIR="$HOME_DIR/.tmp"

# Make internal Docker IP address available to processes.
export INTERNAL_IP=`ip route get 1 | awk '{print $(NF-2);exit}'`

# Remove TMPDIR and TMP_GIT_DIR if they exist
rm -rf $TMP_GIT_DIR
rm -rf $TMPDIR

# Create TMPDIR
mkdir -p $TMPDIR

# Rotate the latest.log files
if [ -f latest.log.0 ]; then
  cp latest.log.0 latest.log.1
fi
if [ -f latest.log ]; then
  cp latest.log latest.log.0
fi

# Rotate the console.log files
if [ -f console.log.0 ]; then
  cp console.log.0 console.log.1
fi
if [ -f console.log ]; then
  cp console.log console.log.0
fi

## if auto_update is not set or to 1 update
if [ -z ${AUTO_UPDATE} ] || [ "${AUTO_UPDATE}" == "1" ]; then
	./steamcmd/steamcmd.sh +force_install_dir /home/container +login anonymous +app_update 258550 +quit
else
    echo -e "Not updating game server as auto update was set to 0. Starting Server"
fi

# Replace Startup Variables
MODIFIED_STARTUP=`eval echo $(echo ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')`
echo ":/home/container$ ${MODIFIED_STARTUP}"

if [[ "${FRAMEWORK}" == "carbon" ]]; then
    # Carbon: https://github.com/CarbonCommunity/Carbon.Core
    echo "Updating Carbon..."
    curl -sSL "https://github.com/CarbonCommunity/Carbon.Core/releases/download/production_build/Carbon.Linux.Release.tar.gz" | tar zx
    echo "Done updating Carbon!"

    export DOORSTOP_ENABLED=1
    export DOORSTOP_TARGET_ASSEMBLY="$(pwd)/carbon/managed/Carbon.Preloader.dll"
    export LD_PRELOAD="$(pwd)/libdoorstop.so"
    # MODIFIED_STARTUP="LD_PRELOAD=$(pwd)/libdoorstop.so ${MODIFIED_STARTUP}"

elif [[ "$OXIDE" == "1" ]] || [[ "${FRAMEWORK}" == "oxide" ]]; then
    # Oxide: https://github.com/OxideMod/Oxide.Rust
    echo "Updating uMod..."
    curl -sSL "https://github.com/OxideMod/Oxide.Rust/releases/latest/download/Oxide.Rust-linux.zip" > umod.zip
    unzip -o -q umod.zip
    rm umod.zip
    echo "Done updating uMod!"
# else Vanilla, do nothing
fi

# If GITHUB_URL and GITHUB_ACCESS_TOKEN are set, we'll use them to clone the repository to /tmp/repo (current user is container)
if [ -n "$GITHUB_URL" ]; then
  echo "Cloning repository from $GITHUB_URL"
  # mkdir -p $TMP_GIT_DIR

  # Clone the repository. Use the GITHUB_ACCESS_TOEKN to authenticate
  if [ -n "$GITHUB_USERNAME" ] && [ -n "$GITHUB_ACCESS_TOKEN" ]; then
    GITHUB_PHRASED_ADDRESS="https://${GITHUB_USERNAME}:${GITHUB_ACCESS_TOKEN}@${GITHUB_URL#https://}"
  else
    GITHUB_PHRASED_ADDRESS="$GITHUB_URL"
  fi

  # Clone a specific branch if GITHUB_BRANCH is set, else the default branch
  if [ -n "$GITHUB_BRANCH" ]; then
    echo "Cloning branch $GITHUB_BRANCH"
    echo git clone --single-branch --branch "$GITHUB_BRANCH" "$GITHUB_PHRASED_ADDRESS" $TMP_GIT_DIR
    git clone --single-branch --branch "$GITHUB_BRANCH" "$GITHUB_PHRASED_ADDRESS" $TMP_GIT_DIR || echo "Failed to clone branch $GITHUB_BRANCH" 
  else
    echo git clone "$GITHUB_PHRASED_ADDRESS" $TMP_GIT_DIR
    git clone "$GITHUB_PHRASED_ADDRESS" $TMP_GIT_DIR || echo "Failed to clone repository"
  fi

  cd $TMP_GIT_DIR || exit 1

  # If GITHUB_FILE_POSTFIX is set, look for any files with that postfix and remove that postfix using find
  if [ -n "$GITHUB_FILE_POSTFIX" ]; then
    echo "Removing postfix $GITHUB_FILE_POSTFIX from files"
    find . -type f -name "*$GITHUB_FILE_POSTFIX" -exec bash -c 'mv "$1" "${1%$2}"' _ {} "$GITHUB_FILE_POSTFIX" \;
  fi
  SYNC_NEWER_DIRS=("carbon/extensions")
  SYNC_DELETE_DIRS=("carbon/plugins" "carbon/configs")
  SYNC_DIRS=("carbon/data" "carbon/modules" "carbon/managed/modules" "HarmonyMods_Data" "server")

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

# Make sure we are in the container directory
cd $HOME_DIR || exit 1

# Fix for Rust not starting
export LD_LIBRARY_PATH=$(pwd)/RustDedicated_Data/Plugins/x86_64:$(pwd)

# Run the Server
rust_monitor ${MODIFIED_STARTUP}
