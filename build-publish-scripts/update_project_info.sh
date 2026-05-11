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

PKGBUILD="$SCRIPT_DIR/PKGBUILD"
TAURI_CONF="$PROJECT_ROOT/textmerger/src-tauri/tauri.conf.json"
TAURI_CARGO="$PROJECT_ROOT/textmerger/src-tauri/Cargo.toml"
TAURI_LOCK="$PROJECT_ROOT/textmerger/src-tauri/Cargo.lock"
FRONTEND_PKG="$PROJECT_ROOT/textmerger/package.json"
DESKTOP_FILE="$PROJECT_ROOT/packaging/textmerger.desktop"

read_pkgbuild_var() {
    local key="$1"
    awk -F'=' -v key="$key" '
        $1 ~ "^" key "[[:space:]]*$" {
            value=$2
            sub(/^[[:space:]]*/, "", value)
            sub(/[[:space:]]*$/, "", value)
            print value
            exit
        }
    ' "$PKGBUILD" | tr -d '\r'
}

trim_quotes() {
    local value="$1"
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"
    printf '%s' "$value"
}

normalize_license() {
    local value="$1"
    case "$value" in
        GPL3|GPL-3|GPL-3.0|GPLv3|GPLv3+)
            printf '%s' "GPL-3.0-only"
            ;;
        *)
            printf '%s' "$value"
            ;;
    esac
}

if [ ! -f "$PKGBUILD" ]; then
    echo -e "${RED}Error: PKGBUILD non trovato in $SCRIPT_DIR${NC}"
    exit 1
fi

VERSION_RAW="$(read_pkgbuild_var "pkgver")"
PKGDESC_RAW="$(read_pkgbuild_var "pkgdesc")"
URL_RAW="$(read_pkgbuild_var "url")"
LICENSE_RAW="$(read_pkgbuild_var "license")"

VERSION="$(trim_quotes "$VERSION_RAW")"
PKGDESC="$(trim_quotes "$PKGDESC_RAW")"
URL="$(trim_quotes "$URL_RAW")"
LICENSE_CLEAN="$(trim_quotes "${LICENSE_RAW//[()]/}")"
LICENSE_CLEAN="${LICENSE_CLEAN//\'/}"
LICENSE_CLEAN="${LICENSE_CLEAN//\"/}"
LICENSE_CLEAN="$(printf '%s' "$LICENSE_CLEAN" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
CARGO_LICENSE="$(normalize_license "$LICENSE_CLEAN")"

if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: impossibile leggere pkgver dal PKGBUILD${NC}"
    exit 1
fi

SAFE_PKGDESC="${PKGDESC//&/\\&}"
SAFE_PKGDESC="${SAFE_PKGDESC//\//\\/}"
SAFE_URL="${URL//&/\\&}"
SAFE_URL="${SAFE_URL//\//\\/}"
SAFE_LICENSE="${CARGO_LICENSE//&/\\&}"
SAFE_LICENSE="${SAFE_LICENSE//\//\\/}"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  textmerger - Update Project Info${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "  Versione:    ${GREEN}${VERSION}${NC}"
echo -e "  Descrizione: ${GREEN}${PKGDESC}${NC}"
echo -e "  URL:         ${GREEN}${URL}${NC}"
echo -e "  Licenza:     ${GREEN}${CARGO_LICENSE}${NC}"
echo -e "${BLUE}============================================${NC}"

ERRORS=0

if [ -f "$TAURI_CONF" ]; then
    sed -i "s/\"version\": \".*\"/\"version\": \"${VERSION}\"/" "$TAURI_CONF"
    echo -e "  ${GREEN}OK${NC} textmerger/src-tauri/tauri.conf.json - version"
else
    echo -e "  ${RED}ERR${NC} textmerger/src-tauri/tauri.conf.json non trovato"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "$TAURI_CARGO" ]; then
    sed -i "0,/^version = \".*\"/s//version = \"${VERSION}\"/" "$TAURI_CARGO"
    sed -i "0,/^description = \".*\"/s//description = \"${SAFE_PKGDESC}\"/" "$TAURI_CARGO"
    sed -i "0,/^license = \".*\"/s//license = \"${SAFE_LICENSE}\"/" "$TAURI_CARGO"
    sed -i "0,/^repository = \".*\"/s//repository = \"${SAFE_URL}\"/" "$TAURI_CARGO"
    echo -e "  ${GREEN}OK${NC} textmerger/src-tauri/Cargo.toml - version, description, license, repository"
else
    echo -e "  ${RED}ERR${NC} textmerger/src-tauri/Cargo.toml non trovato"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "$FRONTEND_PKG" ]; then
    sed -i "s/\"version\": \".*\"/\"version\": \"${VERSION}\"/" "$FRONTEND_PKG"
    echo -e "  ${GREEN}OK${NC} textmerger/package.json - version"
else
    echo -e "  ${RED}ERR${NC} textmerger/package.json non trovato"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "$TAURI_LOCK" ]; then
    if command -v cargo >/dev/null 2>&1; then
        (
            cd "$PROJECT_ROOT/textmerger/src-tauri"
            cargo update -p textmerger
        )
        echo -e "  ${GREEN}OK${NC} textmerger/src-tauri/Cargo.lock - package version sincronizzata"
    else
        echo -e "  ${YELLOW}WARN${NC} cargo non disponibile, skip Cargo.lock"
    fi
else
    echo -e "  ${YELLOW}WARN${NC} textmerger/src-tauri/Cargo.lock non trovato, skip"
fi

if [ -f "$DESKTOP_FILE" ]; then
    cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=${VERSION}
Type=Application
Name=TextMerger
Comment=${PKGDESC}
Exec=textmerger
Icon=textmerger
Terminal=false
Categories=Office;Utility;TextEditor;
Keywords=text;merge;files;editor;
StartupNotify=true
EOF
    echo -e "  ${GREEN}OK${NC} packaging/textmerger.desktop - metadata aggiornati"
else
    echo -e "  ${YELLOW}WARN${NC} packaging/textmerger.desktop non trovato, skip"
fi

if command -v makepkg >/dev/null 2>&1; then
    (
        cd "$SCRIPT_DIR"
        makepkg --printsrcinfo > .SRCINFO
    )
    echo -e "  ${GREEN}OK${NC} build-publish-scripts/.SRCINFO aggiornato"
else
    echo -e "  ${YELLOW}WARN${NC} makepkg non disponibile, skip .SRCINFO"
fi

if [ "$ERRORS" -gt 0 ]; then
    echo -e "${RED}Completato con ${ERRORS} errori${NC}"
    exit 1
fi

echo -e "${GREEN}Aggiornamento completato${NC}"
