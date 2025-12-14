#!/bin/bash

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")/textmerger"

echo "Structure check:"
echo "Script dir: $SCRIPT_DIR"
echo "Project root: $PROJECT_ROOT"

if [ ! -d "$PROJECT_ROOT" ]; then
    echo "Error: Could not find project root at $PROJECT_ROOT"
    exit 1
fi

cd "$PROJECT_ROOT"

echo "Installing frontend dependencies..."
npm install

echo "Building AppImage..."
NO_STRIP=true npm run tauri build -- --bundles appimage

echo "Build complete."
echo "AppImage should be in: $PROJECT_ROOT/src-tauri/target/release/bundle/appimage/"
