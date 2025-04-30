#!/bin/bash

# Wait for the container to fully initialize
sleep 1

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Switch to the container's working directory
cd /home/container || exit 1

## if auto_update is not set or to 1 update
if [ -z "${AUTO_UPDATE}" ] || [ "${AUTO_UPDATE}" == "1" ]; then
  # Allow for the staging branch to also update itself
  ./steamcmd/steamcmd.sh +force_install_dir /home/container +login anonymous +app_update 258550 $(printf %s "-beta ${SRCDS_BETAID:-public}") $( [[ -z ${SRCDS_BETAPASS} ]] || printf %s "-betapassword ${SRCDS_BETAPASS}" ) +quit
else
    echo -e "Not updating game server as auto update was set to 0. Starting Server"
fi

declare -A carbon_configs=(
    ["carbon"]="production_build Carbon.Linux.Release.tar.gz Updating Carbon..."
    ["carbon-minimal"]="production_build Carbon.Linux.Minimal.tar.gz Updating Carbon Minimal..."
    ["carbon-edge"]="edge_build Carbon.Linux.Debug.tar.gz Updating Carbon Edge..."
    ["carbon-edge-minimal"]="edge_build Carbon.Linux.Minimal.tar.gz Updating Carbon Edge Minimal..."
    ["carbon-staging"]="rustbeta_staging_build Carbon.Linux.Debug.tar.gz Updating Carbon Staging..."
    ["carbon-staging-minimal"]="rustbeta_staging_build Carbon.Linux.Minimal.tar.gz Updating Carbon Staging Minimal..."
    ["carbon-aux1"]="rustbeta_aux01_build Carbon.Linux.Debug.tar.gz Updating Carbon Aux1..."
    ["carbon-aux1-minimal"]="rustbeta_aux01_build Carbon.Linux.Minimal.tar.gz Updating Carbon Aux1 Minimal..."
    ["carbon-aux2"]="rustbeta_aux02_build Carbon.Linux.Debug.tar.gz Updating Carbon Aux2..."
    ["carbon-aux2-minimal"]="rustbeta_aux02_build Carbon.Linux.Minimal.tar.gz Updating Carbon Aux2 Minimal..."
)

# Replace Startup Variables
MODIFIED_STARTUP=$(eval echo -e ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')
echo ":/home/container$ ${MODIFIED_STARTUP}"

if [[ -n "${carbon_configs[$FRAMEWORK]}" ]]; then
    IFS=' ' read -r build_type tarball message <<< "${configs[$FRAMEWORK]}"
        
    # Display update message
    echo "$message"

    curl -sSL "https://github.com/CarbonCommunity/Carbon/releases/download/${build_type}/${tarball}" | tar zx
    echo "Done updating Carbon!"

    export DOORSTOP_ENABLED=1
    export DOORSTOP_TARGET_ASSEMBLY="$(pwd)/carbon/managed/Carbon.Preloader.dll"
    MODIFIED_STARTUP="LD_PRELOAD=$(pwd)/libdoorstop.so ${MODIFIED_STARTUP}"
elif [[ "${FRAMEWORK}" == "oxide-staging" ]]; then
    echo "updating oxide-staging"
    curl -sSL -o oxide-staging.zip "https://downloads.oxidemod.com/artifacts/Oxide.Rust/staging/Oxide.Rust-linux.zip"
    unzip -o -q oxide-staging.zip
    rm oxide-staging.zip
    echo "Done updating oxide Staging"
elif [[ "$OXIDE" == "1" ]] || [[ "${FRAMEWORK}" == "oxide" ]]; then
    # Oxide: https://github.com/OxideMod/Oxide.Rust
    echo "Updating uMod..."
    curl -sSL "https://github.com/OxideMod/Oxide.Rust/releases/latest/download/Oxide.Rust-linux.zip" > umod.zip
    unzip -o -q umod.zip
    rm umod.zip
    echo "Done updating uMod!"
# else Vanilla, do nothing
fi

# Fix for Rust not starting
export LD_LIBRARY_PATH=$(pwd)/RustDedicated_Data/Plugins/x86_64:$(pwd)

# Run the Server
/wrapper/wrapper.js "${MODIFIED_STARTUP}"