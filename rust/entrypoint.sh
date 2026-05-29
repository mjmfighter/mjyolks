#!/usr/bin/env bash
set -e

HOME_DIR="/home/container"
TMP_GIT_DIR="$HOME_DIR/tmp-git"
export TMPDIR="$HOME_DIR/.tmp"

declare -A CARBON_BUILDS=(
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
    ["carbon-aux3"]="rustbeta_aux03_build Carbon.Linux.Debug.tar.gz Updating Carbon Aux3..."
    ["carbon-aux3-minimal"]="rustbeta_aux03_build Carbon.Linux.Minimal.tar.gz Updating Carbon Aux3 Minimal..."
    ["carbon-aux4"]="rustbeta_aux04_build Carbon.Linux.Debug.tar.gz Updating Carbon Aux4..."
    ["carbon-aux4-minimal"]="rustbeta_aux04_build Carbon.Linux.Minimal.tar.gz Updating Carbon Aux4 Minimal..."
)

# --------------------------------------------------------------------
# rsync helpers (previously sync_functions.sh)
# --------------------------------------------------------------------

# Sync source into destination with --delete, but skip any file that has
# a sibling "<file>.ignore" in source. Those files are copied only if they
# don't already exist in destination (used for first-run seeding of configs).
sync_delete_with_ignore() {
    local SOURCE="$1"
    local DESTINATION="$2"

    if [ ! -d "$SOURCE" ]; then
        echo "Source directory '$SOURCE' does not exist."
        return 1
    fi
    mkdir -p "$DESTINATION"

    local IGNORE_FILES
    IGNORE_FILES=$(find "$SOURCE" -type f -name '*.ignore' -printf '%P\n' | sed 's/\.ignore$//')

    local EXCLUDE_FILE
    EXCLUDE_FILE=$(mktemp)
    {
        echo "$IGNORE_FILES"
        # Also exclude the .ignore sidecars themselves from the synced tree
        echo "*.ignore"
    } > "$EXCLUDE_FILE"

    rsync -a -q --delete --exclude-from="$EXCLUDE_FILE" "$SOURCE"/ "$DESTINATION"/

    local FILE
    while IFS= read -r FILE; do
        [ -z "$FILE" ] && continue
        local SOURCE_FILE="$SOURCE/$FILE"
        local DEST_FILE="$DESTINATION/$FILE"
        if [ ! -e "$DEST_FILE" ]; then
            mkdir -p "$(dirname "$DEST_FILE")"
            cp -p "$SOURCE_FILE" "$DEST_FILE"
            echo "Seeded missing file '$DEST_FILE'"
        fi
    done <<< "$IGNORE_FILES"

    rm -f "$EXCLUDE_FILE"
}

# Same as sync_delete_with_ignore but without --delete (additive sync).
sync_with_ignore() {
    local SOURCE="$1"
    local DESTINATION="$2"

    if [ ! -d "$SOURCE" ]; then
        echo "Source directory '$SOURCE' does not exist."
        return 1
    fi
    mkdir -p "$DESTINATION"

    local IGNORE_FILES
    IGNORE_FILES=$(find "$SOURCE" -type f -name '*.ignore' -printf '%P\n' | sed 's/\.ignore$//')

    local EXCLUDE_FILE
    EXCLUDE_FILE=$(mktemp)
    {
        echo "$IGNORE_FILES"
        echo "*.ignore"
    } > "$EXCLUDE_FILE"

    rsync -a -q --exclude-from="$EXCLUDE_FILE" "$SOURCE"/ "$DESTINATION"/

    local FILE
    while IFS= read -r FILE; do
        [ -z "$FILE" ] && continue
        local SOURCE_FILE="$SOURCE/$FILE"
        local DEST_FILE="$DESTINATION/$FILE"
        if [ ! -e "$DEST_FILE" ]; then
            mkdir -p "$(dirname "$DEST_FILE")"
            cp -p "$SOURCE_FILE" "$DEST_FILE"
            echo "Seeded missing file '$DEST_FILE'"
        fi
    done <<< "$IGNORE_FILES"

    rm -f "$EXCLUDE_FILE"
}

# --------------------------------------------------------------------
# Pipeline stages
# --------------------------------------------------------------------

setup_env() {
    export TZ=${TZ:-UTC}
    export INTERNAL_IP=$(ip route get 1 2>/dev/null | awk '{print $(NF-2);exit}')

    # Required for RustDedicated to find its bundled .so files
    export LD_LIBRARY_PATH="$HOME_DIR/RustDedicated_Data/Plugins/x86_64:$HOME_DIR"

    # Recreate scratch dirs
    rm -rf "$TMP_GIT_DIR" "$TMPDIR"
    mkdir -p "$TMPDIR"

    # Rotate log files (wrapper.js writes both)
    cd "$HOME_DIR"
    for base in latest.log console.log; do
        [ -f "${base}.0" ] && cp "${base}.0" "${base}.1"
        [ -f "${base}" ] && cp "${base}" "${base}.0"
    done
}

derive_steam_branch() {
    # Explicit user override wins
    if [ -n "$SRCDS_BETAID" ]; then
        echo "Using user-supplied Rust game branch: $SRCDS_BETAID"
        return 0
    fi

    case "$FRAMEWORK" in
        carbon-staging|carbon-staging-minimal)   export SRCDS_BETAID="staging" ;;
        carbon-aux1|carbon-aux1-minimal)         export SRCDS_BETAID="aux01"   ;;
        carbon-aux2|carbon-aux2-minimal)         export SRCDS_BETAID="aux02"   ;;
        carbon-aux3|carbon-aux3-minimal)         export SRCDS_BETAID="aux03"   ;;
        carbon-aux4|carbon-aux4-minimal)         export SRCDS_BETAID="aux04"   ;;
    esac

    [ -n "$SRCDS_BETAID" ] && \
        echo "FRAMEWORK=$FRAMEWORK -> using Rust game beta branch '$SRCDS_BETAID'"
}

update_steamcmd() {
    echo "Updating Rust dedicated server (app 258550)..."
    local beta_args=""
    [ -n "${SRCDS_BETAID}" ]   && beta_args+=" -beta ${SRCDS_BETAID:-public}"
    [ -n "${SRCDS_BETAPASS}" ] && beta_args+=" -betapassword ${SRCDS_BETAPASS}"

    # shellcheck disable=SC2086
    ./steamcmd/steamcmd.sh +force_install_dir "$HOME_DIR" +login anonymous +app_update 258550 $beta_args +quit
}

install_framework() {
    if [[ -n "${CARBON_BUILDS[$FRAMEWORK]}" ]]; then
        local build_type tarball message
        IFS=' ' read -r build_type tarball message <<< "${CARBON_BUILDS[$FRAMEWORK]}"
        local url="https://github.com/CarbonCommunity/Carbon/releases/download/${build_type}/${tarball}"

        echo "$message"
        echo "Downloading $url"
        curl -sSL "$url" | tar zx
        echo "Done updating Carbon!"

        export DOORSTOP_ENABLED=1
        export DOORSTOP_TARGET_ASSEMBLY="$HOME_DIR/carbon/managed/Carbon.Preloader.dll"
        CARBON_LD_PRELOAD="$HOME_DIR/libdoorstop.so"

    elif [[ "${FRAMEWORK}" == "oxide-staging" ]]; then
        echo "Updating Oxide (staging)..."
        local primary="https://downloads.oxidemod.com/artifacts/Oxide.Rust/staging/Oxide.Rust-linux.zip"
        local fallback="https://ci.appveyor.com/api/projects/oxidemod/oxide-rust/artifacts/Oxide.Rust-linux.zip?branch=staging"
        if ! curl -fsSL -o oxide-staging.zip "$primary"; then
            echo "Primary Oxide staging URL failed, trying AppVeyor fallback..."
            curl -fsSL -o oxide-staging.zip "$fallback"
        fi
        unzip -o -q oxide-staging.zip
        rm -f oxide-staging.zip
        echo "Done updating Oxide Staging"

    elif [[ "$OXIDE" == "1" ]] || [[ "${FRAMEWORK}" == "oxide" ]]; then
        echo "Updating Oxide (uMod)..."
        curl -sSL -o umod.zip "https://github.com/OxideMod/Oxide.Rust/releases/latest/download/Oxide.Rust-linux.zip"
        unzip -o -q umod.zip
        rm -f umod.zip
        echo "Done updating uMod!"
    else
        echo "FRAMEWORK='${FRAMEWORK:-vanilla}' — no framework install needed."
    fi
}

sync_github_repo() {
    [ -z "$GITHUB_URL" ] && return 0
    # GITHUB_SYNC is optional; if unset we still sync when GITHUB_URL is set.
    if [ -n "${GITHUB_SYNC+x}" ] && [ "$GITHUB_SYNC" != "1" ]; then
        echo "GITHUB_SYNC=${GITHUB_SYNC}, skipping repo sync."
        return 0
    fi

    echo "Cloning repository from $GITHUB_URL"
    mkdir -p "$TMP_GIT_DIR"

    local GITHUB_PHRASED_ADDRESS="$GITHUB_URL"
    if [ -n "$GITHUB_USERNAME" ] && [ -n "$GITHUB_ACCESS_TOKEN" ]; then
        GITHUB_PHRASED_ADDRESS="https://${GITHUB_USERNAME}:${GITHUB_ACCESS_TOKEN}@${GITHUB_URL#https://}"
    fi

    if [ -n "$GITHUB_BRANCH" ]; then
        git clone --depth 1 --single-branch --branch "$GITHUB_BRANCH" "$GITHUB_PHRASED_ADDRESS" "$TMP_GIT_DIR"
    else
        git clone --depth 1 "$GITHUB_PHRASED_ADDRESS" "$TMP_GIT_DIR"
    fi

    cd "$TMP_GIT_DIR"

    if [ -n "$GITHUB_FILE_POSTFIX" ]; then
        echo "Removing postfix '$GITHUB_FILE_POSTFIX' from files"
        find . -type f -name "*$GITHUB_FILE_POSTFIX" -exec bash -c 'mv "$1" "${1%$2}"' _ {} "$GITHUB_FILE_POSTFIX" \;
    fi

    local SYNC_NEWER_DIRS=("carbon/extensions")
    local SYNC_DELETE_DIRS=("carbon/plugins" "carbon/configs")
    local SYNC_DIRS=("carbon/data" "carbon/modules" "carbon/managed/modules" "HarmonyMods_Data" "server")

    local DIR
    for DIR in "${SYNC_NEWER_DIRS[@]}"; do
        if [ -d "$DIR" ]; then
            echo "Syncing newer files: $DIR"
            sync_delete_with_ignore "$TMP_GIT_DIR/$DIR" "$HOME_DIR/$DIR"
        fi
    done

    for DIR in "${SYNC_DIRS[@]}"; do
        if [ -d "$DIR" ]; then
            echo "Syncing (additive): $DIR"
            mkdir -p "$HOME_DIR/$DIR"
            rsync -a -q "$TMP_GIT_DIR/$DIR/" "$HOME_DIR/$DIR/"
        fi
    done

    for DIR in "${SYNC_DELETE_DIRS[@]}"; do
        if [ -d "$DIR" ]; then
            echo "Syncing (with delete): $DIR"
            sync_delete_with_ignore "$TMP_GIT_DIR/$DIR" "$HOME_DIR/$DIR"
        fi
    done

    cd "$HOME_DIR"
    rm -rf "$TMP_GIT_DIR" "$HOME_DIR/.ssh"
    echo "Finished syncing files"
}

launch_server() {
    cd "$HOME_DIR"

    # Expand {{VAR}} startup template
    local MODIFIED_STARTUP
    MODIFIED_STARTUP=$(eval echo -e "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')

    if [ -n "$CARBON_LD_PRELOAD" ]; then
        MODIFIED_STARTUP="LD_PRELOAD=${CARBON_LD_PRELOAD} ${MODIFIED_STARTUP}"
    fi

    echo ":/home/container$ ${MODIFIED_STARTUP}"
    exec /wrapper/wrapper.js "${MODIFIED_STARTUP}"
}

# --------------------------------------------------------------------
# Main
# --------------------------------------------------------------------

cd "$HOME_DIR"
setup_env
derive_steam_branch

if [ -z "${AUTO_UPDATE}" ] || [ "${AUTO_UPDATE}" = "1" ]; then
    update_steamcmd
else
    echo "AUTO_UPDATE=${AUTO_UPDATE}, skipping steamcmd update."
fi

install_framework
sync_github_repo
launch_server
