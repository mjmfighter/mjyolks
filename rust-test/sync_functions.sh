sync_delete_with_ignore() {
    # Usage: sync_delete_with_ignore <source_directory> <destination_directory> [extensions...]

    # Check if at least two arguments are provided
    if [ "$#" -lt 2 ]; then
        echo "Usage: sync_delete_with_ignore <source_directory> <destination_directory> [extensions...]"
        return 1
    fi

    # Assign arguments to variables
    local SOURCE="$1"
    local DESTINATION="$2"
    shift 2  # Shift the arguments to process extensions

    # Collect extensions into an array
    local EXTENSIONS=("$@")  # Remaining arguments are extensions

    # Ensure the source directory exists
    if [ ! -d "$SOURCE" ]; then
        echo "Source directory '$SOURCE' does not exist."
        return 1
    fi

    # Create the destination directory if it doesn't exist
    if [ ! -d "$DESTINATION" ]; then
        echo "Destination directory '$DESTINATION' does not exist. Creating it."
        mkdir -p "$DESTINATION"
    fi

    # Step 1: Generate a list of files that have corresponding .ignore files in the source
    local IGNORE_FILES
    IGNORE_FILES=$(find "$SOURCE" -type f -name '*.ignore' -printf '%P\n' | sed 's/\.ignore$//')

    # Create a temporary directory to store file list
    local TEMP_DIR
    TEMP_DIR=$(mktemp -d)
    local SOURCE_FILES="$TEMP_DIR/source_files"
    local IGNORE_LIST="$TEMP_DIR/ignore_list"

    # Save ignore files list
    echo "$IGNORE_FILES" > "$IGNORE_LIST"

    # Generate list of all files in source
    find "$SOURCE" -type f -not -name "*.ignore" -printf '%P\n' > "$SOURCE_FILES"

    # Remove files in destination that don't exist in source (simulating rsync --delete)
    find "$DESTINATION" -type f -printf '%P\n' | while IFS= read -r FILE; do
        if ! grep -Fxq "$FILE" "$SOURCE_FILES" && ! grep -Fxq "$FILE" "$IGNORE_LIST"; then
            rm -f "$DESTINATION/$FILE"
            echo "Deleted '$DESTINATION/$FILE'"
        fi
    done

    # Copy all files except those with corresponding .ignore files
    while IFS= read -r FILE; do
        if ! grep -Fxq "$FILE" "$IGNORE_LIST"; then
            local DIR=$(dirname "$DESTINATION/$FILE")
            mkdir -p "$DIR"
            cp -p "$SOURCE/$FILE" "$DESTINATION/$FILE"
        fi
    done < "$SOURCE_FILES"

    # Step 3: Copy over the files with corresponding .ignore files only if they don't exist in the destination
    while IFS= read -r FILE; do
        local SOURCE_FILE="$SOURCE/$FILE"
        local DEST_FILE="$DESTINATION/$FILE"

        if [ ! -e "$DEST_FILE" ]; then
            # Create the destination directory if it doesn't exist
            mkdir -p "$(dirname "$DEST_FILE")"
            # Copy the file, preserving attributes
            cp -p "$SOURCE_FILE" "$DEST_FILE"
            echo "Copied '$SOURCE_FILE' to '$DEST_FILE'"
        else
            echo "Skipped '$FILE' as it already exists in the destination."
        fi
    done < "$IGNORE_LIST"

    # Step 4: Process specified extensions
    if [ "${#EXTENSIONS[@]}" -gt 0 ]; then
        echo "Processing extensions: ${EXTENSIONS[*]}"
        # Loop over each specified extension
        for EXT in "${EXTENSIONS[@]}"; do
            # Find files in the destination ending with the extension
            find "$DESTINATION" -type f -name "*$EXT" -print0 | while IFS= read -r -d '' FILE; do
                local NEW_FILE="${FILE%$EXT}"
                if [ -e "$NEW_FILE" ]; then
                    echo "Cannot rename '$FILE' to '$NEW_FILE' because '$NEW_FILE' already exists."
                else
                    mv "$FILE" "$NEW_FILE"
                    echo "Renamed '$FILE' to '$NEW_FILE'"
                fi
            done
        done
    fi

    # Clean up temporary directory
    rm -rf "$TEMP_DIR"
}

sync_with_ignore() {
    # Usage: sync_with_ignore <source_directory> <destination_directory> [extensions...]

    # Check if at least two arguments are provided
    if [ "$#" -lt 2 ]; then
        echo "Usage: sync_with_ignore <source_directory> <destination_directory> [extensions...]"
        return 1
    fi

    # Assign arguments to variables
    local SOURCE="$1"
    local DESTINATION="$2"
    shift 2  # Shift the arguments to process extensions

    # Collect extensions into an array
    local EXTENSIONS=("$@")  # Remaining arguments are extensions

    # Ensure the source directory exists
    if [ ! -d "$SOURCE" ]; then
        echo "Source directory '$SOURCE' does not exist."
        return 1
    fi

    # Create the destination directory if it doesn't exist
    if [ ! -d "$DESTINATION" ]; then
        echo "Destination directory '$DESTINATION' does not exist. Creating it."
        mkdir -p "$DESTINATION"
    fi

    # Step 1: Generate a list of files that have corresponding .ignore files in the source
    local IGNORE_FILES
    IGNORE_FILES=$(find "$SOURCE" -type f -name '*.ignore' -printf '%P\n' | sed 's/\.ignore$//')

    # Create a temporary file to store ignore list
    local TEMP_DIR
    TEMP_DIR=$(mktemp -d)
    local IGNORE_LIST="$TEMP_DIR/ignore_list"
    echo "$IGNORE_FILES" > "$IGNORE_LIST"

    # Step 2: Copy all files except those with corresponding .ignore files
    find "$SOURCE" -type f -not -name "*.ignore" -printf '%P\n' | while IFS= read -r FILE; do
        if ! grep -Fxq "$FILE" "$IGNORE_LIST"; then
            local DIR=$(dirname "$DESTINATION/$FILE")
            mkdir -p "$DIR"
            cp -p "$SOURCE/$FILE" "$DESTINATION/$FILE"
        fi
    done

    # Step 3: Copy over the files with corresponding .ignore files only if they don't exist in the destination
    while IFS= read -r FILE; do
        local SOURCE_FILE="$SOURCE/$FILE"
        local DEST_FILE="$DESTINATION/$FILE"

        if [ ! -e "$DEST_FILE" ]; then
            # Create the destination directory if it doesn't exist
            mkdir -p "$(dirname "$DEST_FILE")"
            # Copy the file, preserving attributes
            cp -p "$SOURCE_FILE" "$DEST_FILE"
            echo "Copied '$SOURCE_FILE' to '$DEST_FILE'"
        else
            echo "Skipped '$FILE' as it already exists in the destination."
        fi
    done < "$IGNORE_LIST"

    # Step 4: Process specified extensions
    if [ "${#EXTENSIONS[@]}" -gt 0 ]; then
        echo "Processing extensions: ${EXTENSIONS[*]}"
        # Loop over each specified extension
        for EXT in "${EXTENSIONS[@]}"; do
            # Find files in the destination ending with the extension
            find "$DESTINATION" -type f -name "*$EXT" -print0 | while IFS= read -r -d '' FILE; do
                local NEW_FILE="${FILE%$EXT}"
                if [ -e "$NEW_FILE" ]; then
                    echo "Cannot rename '$FILE' to '$NEW_FILE' because '$NEW_FILE' already exists."
                else
                    mv "$FILE" "$NEW_FILE"
                    echo "Renamed '$FILE' to '$NEW_FILE'"
                fi
            done
        done
    fi

    # Clean up temporary directory
    rm -rf "$TEMP_DIR"
}

copy_missing_files() {
    # Usage: copy_missing_files <source_directory> <destination_directory> [extensions...]

    # Check if at least two arguments are provided
    if [ "$#" -lt 2 ]; then
        echo "Usage: copy_missing_files <source_directory> <destination_directory> [extensions...]"
        return 1
    fi

    # Assign arguments to variables
    local SOURCE="$1"
    local DESTINATION="$2"
    shift 2  # Shift the arguments to process extensions

    # Collect extensions into an array
    local EXTENSIONS=("$@")  # Remaining arguments are extensions

    # Ensure the source directory exists
    if [ ! -d "$SOURCE" ]; then
        echo "Source directory '$SOURCE' does not exist."
        return 1
    fi

    # Create the destination directory if it doesn't exist
    if [ ! -d "$DESTINATION" ]; then
        echo "Destination directory '$DESTINATION' does not exist. Creating it."
        mkdir -p "$DESTINATION"
    fi

    # Step 1: Copy only missing files from source to destination
    find "$SOURCE" -type f -printf '%P\n' | while IFS= read -r FILE; do
        if [ ! -e "$DESTINATION/$FILE" ]; then
            local DIR=$(dirname "$DESTINATION/$FILE")
            mkdir -p "$DIR"
            cp -p "$SOURCE/$FILE" "$DESTINATION/$FILE"
            echo "Copied '$SOURCE/$FILE' to '$DESTINATION/$FILE'"
        fi
    done

    # Step 2: Process specified extensions
    if [ "${#EXTENSIONS[@]}" -gt 0 ]; then
        echo "Processing extensions: ${EXTENSIONS[*]}"
        # Loop over each specified extension
        for EXT in "${EXTENSIONS[@]}"; do
            # Find files in the destination ending with the extension
            find "$DESTINATION" -type f -name "*$EXT" -print0 | while IFS= read -r -d '' FILE; do
                local NEW_FILE="${FILE%$EXT}"
                if [ -e "$NEW_FILE" ]; then
                    echo "Cannot rename '$FILE' to '$NEW_FILE' because '$NEW_FILE' already exists."
                else
                    mv "$FILE" "$NEW_FILE"
                    echo "Renamed '$FILE' to '$NEW_FILE'"
                fi
            done
        done
    fi
}