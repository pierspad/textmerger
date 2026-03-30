#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=C

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_DIR="$PROJECT_ROOT/textmerger"

PKGBUILD="$SCRIPT_DIR/PKGBUILD"
UPDATE_SCRIPT="$SCRIPT_DIR/update_project_info.sh"
CHECK_SCRIPT="$SCRIPT_DIR/check_version_consistency.sh"

if [ ! -f "$PKGBUILD" ]; then
    echo -e "${RED}Error: PKGBUILD non trovato${NC}"
    exit 1
fi

VERSION="$(awk -F'=' '/^pkgver[[:space:]]*=/{print $2; exit}' "$PKGBUILD" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: impossibile leggere pkgver da PKGBUILD${NC}"
    exit 1
fi

echo -e "${BLUE}textmerger - Build AppImage v${VERSION}${NC}"
echo "=================================="

echo -e "${YELLOW}Allineo metadati progetto...${NC}"
bash "$UPDATE_SCRIPT"

echo -e "${YELLOW}Verifico coerenza versioni...${NC}"
bash "$CHECK_SCRIPT"

cd "$APP_DIR"

if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Installazione dipendenze frontend...${NC}"
    npm install
fi

echo -e "${YELLOW}Build AppImage...${NC}"
NO_STRIP=true npm run tauri build -- --bundles appimage

echo -e "${GREEN}Build completato${NC}"
echo -e "${GREEN}AppImage path: $APP_DIR/src-tauri/target/release/bundle/appimage/${NC}"
