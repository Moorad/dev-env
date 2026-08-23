#!/bin/bash

FILE_PATH=$1

if [ -z "$FILE_PATH" ]; then
  echo "No file path provided\nUsage: upload-artifact.sh <file-path>"
  exit 1
fi

FILENAME=$(basename "$FILE_PATH")

AUTH=$(op item get "dufs" --vault "Home" --fields username,password --reveal | tr "," ":")

if [ -z "$AUTH" ]; then
  echo "Could not read credentials from 1Password. Unlock it and try again." >&2
  exit 1
fi

if ! curl --fail --silent --show-error --user "$AUTH" -T "$FILE_PATH" "https://files.moorad.dev/artifacts/$FILENAME"; then
  echo "Upload failed" >&2
  exit 1
fi

echo "File uploaded successfully"
echo "https://files.moorad.dev/artifacts/$FILENAME"
