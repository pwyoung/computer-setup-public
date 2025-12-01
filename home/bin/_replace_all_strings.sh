#!/bin/bash

# Check if correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 'string_to_find' 'string_to_replace'"
    echo "Example: $0 'old_text' 'new_text'"
    exit 1
fi

# Store arguments
FIND_STR="$1"
REPLACE_STR="$2"

# Escape special characters for sed
FIND_STR_ESCAPED=$(printf '%s\n' "$FIND_STR" | sed 's/[[\.*^$/]/\\&/g')
REPLACE_STR_ESCAPED=$(printf '%s\n' "$REPLACE_STR" | sed 's/[[\.*^$/]/\\&/g')

# Count number of files that will be processed
FILE_COUNT=$(find . -type f -not -path "*/\.*" | wc -l)

echo "This will search through $FILE_COUNT files in the current directory and subdirectories."
echo "Finding: '$FIND_STR'"
echo "Replacing with: '$REPLACE_STR'"
echo -n "Do you want to continue? (y/N): "
read -r CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Create a backup directory with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backup_$TIMESTAMP"
mkdir "$BACKUP_DIR"

# Create a temporary file to store modified files count
TEMP_COUNT_FILE=$(mktemp)
echo "0" > "$TEMP_COUNT_FILE"

# Process each file
find . -type f -not -path "*/\.*" -not -path "./$BACKUP_DIR/*" -print0 | while IFS= read -r -d '' file; do
    # Skip binary files
    if file "$file" | grep -q "binary"; then
        continue
    fi

    # Check if the file contains the string
    if grep -q "$FIND_STR" "$file"; then
        # Create directory structure in backup
        BACKUP_PATH="$BACKUP_DIR/$(dirname "$file")"
        mkdir -p "$BACKUP_PATH"

        # Create backup
        cp "$file" "$BACKUP_DIR/$file"

        # Perform replacement using perl
        perl -i -pe "s/$FIND_STR_ESCAPED/$REPLACE_STR_ESCAPED/g" "$file"

        echo "Modified: $file"
        # Increment the counter in the temporary file
        curr_count=$(<"$TEMP_COUNT_FILE")
        echo $((curr_count + 1)) > "$TEMP_COUNT_FILE"
    fi
done

# Read the final count
MODIFIED_COUNT=$(<"$TEMP_COUNT_FILE")
rm "$TEMP_COUNT_FILE"

echo "Operation completed."
echo "Files modified: $MODIFIED_COUNT"
echo "Backups created in: $BACKUP_DIR"

if [ $MODIFIED_COUNT -eq 0 ]; then
    echo "No files were modified. The search string was not found."
    rm -r "$BACKUP_DIR"
fi
