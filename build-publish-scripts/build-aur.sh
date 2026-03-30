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
PKGNAME="$(awk -F'=' '/^pkgname[[:space:]]*=/{print $2; exit}' "$PKGBUILD" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [ -z "$VERSION" ] || [ -z "$PKGNAME" ]; then
    echo -e "${RED}Error: impossibile leggere pkgver/pkgname da PKGBUILD${NC}"
    exit 1
fi

echo -e "${BLUE}textmerger - Build Arch Package v${VERSION}${NC}"
echo "=================================="

echo -e "${YELLOW}Allineo metadati progetto...${NC}"
bash "$UPDATE_SCRIPT"

echo -e "${YELLOW}Verifico coerenza versioni...${NC}"
bash "$CHECK_SCRIPT"

echo -e "${YELLOW}Build Tauri (.deb)...${NC}"
cd "$APP_DIR"

if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Installazione dipendenze frontend...${NC}"
    npm install
fi

npm run tauri build -- --bundles deb

DEB_PATH="$APP_DIR/src-tauri/target/release/bundle/deb/textmerger_${VERSION}_amd64.deb"
if [ ! -f "$DEB_PATH" ]; then
    DEB_PATH="$(find "$APP_DIR/src-tauri/target/release/bundle/deb" -name "*.deb" | head -n 1 || true)"
fi

if [ -z "$DEB_PATH" ] || [ ! -f "$DEB_PATH" ]; then
    echo -e "${RED}Error: .deb non trovato dopo la build${NC}"
    exit 1
fi

echo -e "${GREEN}Deb trovato: $(basename "$DEB_PATH")${NC}"

cd "$SCRIPT_DIR"
cp "$DEB_PATH" "textmerger_${VERSION}_amd64.deb"

echo -e "${YELLOW}Packaging Arch con PKGBUILD.local...${NC}"
rm -f ./*.pkg.tar.zst
makepkg -p PKGBUILD.local -sfc --noconfirm

PKG_FILE="$(ls "${PKGNAME}"-*.pkg.tar.zst 2>/dev/null | head -n 1 || true)"
if [ -z "$PKG_FILE" ] || [ ! -f "$PKG_FILE" ]; then
    echo -e "${RED}Error: creazione pacchetto Arch fallita${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Build completato${NC}"
echo -e "${GREEN}Pacchetto: $SCRIPT_DIR/$PKG_FILE${NC}"

read -rp "Vuoi installare il pacchetto ora? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if pacman -Qi "$PKGNAME" >/dev/null 2>&1; then
        echo -e "${YELLOW}Rimozione versione precedente...${NC}"
        sudo pacman -Rns "$PKGNAME" --noconfirm
    fi
    echo -e "${YELLOW}Installazione...${NC}"
    sudo pacman -U "$PKG_FILE" --noconfirm
    echo -e "${GREEN}Installato${NC}"
else
    echo -e "${YELLOW}Installazione saltata${NC}"
fi