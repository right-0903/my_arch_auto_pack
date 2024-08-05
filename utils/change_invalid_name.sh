#!/bin/bash

# Specify the directory to process
TARGET_DIR="$1"

# Check if the directory parameter is provided
if [ -z "$TARGET_DIR" ]; then
  echo "$0: Please provide a directory path"
  exit 1
fi

# Ensure the target directory exists
if [ ! -d "$TARGET_DIR" ]; then
  echo "$0: The specified directory does not exist"
  exit 1
fi

# Define invalid characters to be removed, in case failed to upload artifacts
# Invalid characters include:  Double quote ", Colon :, Less than <, Greater than >,
# Vertical bar |, Asterisk *, Question mark ?, Carriage return \r, Line feed \n
INVALID_CHARS='["<>|*?:\r\n]'

# Iterate over all files in the specified directory
for FILE in "$TARGET_DIR"/*; do
  # Extract the filename and directory name
  DIRNAME=$(dirname "$FILE")
  BASENAME=$(basename "$FILE")

  # Remove invalid characters
  CLEAN_NAME=$(echo "$BASENAME" | tr $INVALID_CHARS '.')

  # If the cleaned filename differs from the original, rename the file
  if [ "$BASENAME" != "$CLEAN_NAME" ]; then
    mv "$DIRNAME/$BASENAME" "$DIRNAME/$CLEAN_NAME"
    echo "$0: Renamed: $BASENAME -> $CLEAN_NAME"
  fi
done

echo "$0: All files processed"
