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

    # Step 1: Generate a list of files that have corresponding .ignore files in the source
    local IGNORE_FILES
    IGNORE_FILES=$(find "$SOURCE" -type f -name '*.ignore' -printf '%P\n' | sed 's/\.ignore$//')

    # Step 2: Create a temporary directory to store the list of files to keep
    local TEMP_DIR
    TEMP_DIR=$(mktemp -d)
    local KEEP_LIST="$TEMP_DIR/keep_list"
    
    # Generate list of all files in source, excluding those with .ignore
    find "$SOURCE" -type f -printf '%P\n' | grep -v '\.ignore$' > "$TEMP_DIR/all_files"
    
    # Remove ignored files from the list
    grep -v -f <(echo "$IGNORE_FILES") "$TEMP_DIR/all_files" > "$KEEP_LIST"

    # Step 3: Clean destination directory of files not in source
    while IFS= read -r -d '' FILE; do
        local REL_PATH="${FILE#$DESTINATION/}"
        if ! grep -q "^$REL_PATH\$" "$KEEP_LIST"; then
            rm "$FILE"
            echo "Removed '$FILE' from destination"
        fi
    done < <(find "$DESTINATION" -type f -print0)

    # Step 4: Copy files from source to destination
    while IFS= read -r FILE; do
        local SOURCE_FILE="$SOURCE/$FILE"
        local DEST_FILE="$DESTINATION/$FILE"
        
        # Create the destination directory if it doesn't exist
        mkdir -p "$(dirname "$DEST_FILE")"
        
        # Copy the file, preserving attributes
        cp -p "$SOURCE_FILE" "$DEST_FILE"
    done < "$KEEP_LIST"

    # Step 3: Copy over the files with corresponding .ignore files only if they don't exist in the destination
    local FILE
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
    done <<< "$IGNORE_FILES"

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

    # Clean up temporary exclude file
    # rm "$EXCLUDE_FILE"
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

    # Create a temporary exclude file for rsync
    local EXCLUDE_FILE
    EXCLUDE_FILE=$(mktemp)
    echo "$IGNORE_FILES" > "$EXCLUDE_FILE"

    # Step 2: Sync all files except those with corresponding .ignore files
    rsync -av -q --exclude-from="$EXCLUDE_FILE" "$SOURCE"/ "$DESTINATION"/

    # Step 3: Copy over the files with corresponding .ignore files only if they don't exist in the destination
    local FILE
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
    done <<< "$IGNORE_FILES"

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

    # Clean up temporary exclude file
    rm "$EXCLUDE_FILE"
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

    # Step 1: Copy missing files from source to destination
    rsync -av --ignore-existing "$SOURCE"/ "$DESTINATION"/

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
