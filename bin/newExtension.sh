#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/jenkinsGet.sh"
set -e

PROFILE=${VSCODE_PROFILE:-Ivy}
JOB="vscode-designer"
BRANCH=${1:-release%252F14.0}
SUCCESS_URL=$(jenkinsSuccessUrl "$JOB" "$BRANCH")
ARTIFACT_URL="$SUCCESS_URL/artifact/extension/*.vsix/*zip*/extension.zip"

if ! command -v code >/dev/null 2>&1; then
  echo 'Error: VS Code CLI command "code" was not found in PATH.' >&2
  exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo 'Error: this script requires unzip.' >&2
  exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading VS Code Designer extension ${BRANCH}..."
jenkinsDownload "$ARTIFACT_URL" "$TMP_DIR/extension.zip"

unzip -q "$TMP_DIR/extension.zip" -d "$TMP_DIR/unpacked"
VSIX=$(find "$TMP_DIR/unpacked" -type f -name '*.vsix' -print -quit)
if [ -z "$VSIX" ]; then
  echo 'Error: no .vsix package was found in the downloaded archive.' >&2
  exit 1
fi

echo "Installing $(basename "$VSIX")..."
code --install-extension "$VSIX" --force --profile "$PROFILE"
echo "VS Code Designer extension installed in profile \"$PROFILE\"."
