#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=C

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

PKGBUILD="$SCRIPT_DIR/PKGBUILD"
TAURI_CONF="$PROJECT_ROOT/textmerger/src-tauri/tauri.conf.json"
TAURI_CARGO="$PROJECT_ROOT/textmerger/src-tauri/Cargo.toml"
FRONTEND_PKG="$PROJECT_ROOT/textmerger/package.json"
DESKTOP_FILE="$PROJECT_ROOT/packaging/textmerger.desktop"

if [ ! -f "$PKGBUILD" ]; then
    echo -e "${RED}Error: PKGBUILD non trovato${NC}"
    exit 1
fi

PKGVER="$(awk -F'=' '/^pkgver[[:space:]]*=/{print $2; exit}' "$PKGBUILD" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')"
if [ -z "$PKGVER" ]; then
    echo -e "${RED}Error: impossibile leggere pkgver${NC}"
    exit 1
fi

ERRORS=0

check_equals() {
    local label="$1"
    local file="$2"
    local current="$3"

    if [ -z "$current" ]; then
        echo -e "  ${RED}ERR${NC} $label - valore non trovato"
        ERRORS=$((ERRORS + 1))
        return
    fi

    if [ "$current" != "$PKGVER" ]; then
        echo -e "  ${RED}ERR${NC} $label - trovato ${current}, atteso ${PKGVER}"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "  ${GREEN}OK${NC} $label - ${current}"
    fi
}

echo -e "${YELLOW}Controllo coerenza versioni (atteso: ${PKGVER})...${NC}"

if [ -f "$TAURI_CONF" ]; then
    TAURI_VERSION="$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' "$TAURI_CONF" | head -n 1 | tr -d '\r')"
    check_equals "textmerger/src-tauri/tauri.conf.json" "$TAURI_CONF" "$TAURI_VERSION"
else
    echo -e "  ${RED}ERR${NC} textmerger/src-tauri/tauri.conf.json non trovato"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "$TAURI_CARGO" ]; then
    CARGO_VERSION="$(awk '
        /^\[package\]$/ { in_pkg=1; next }
        in_pkg && /^\[/ { in_pkg=0 }
        in_pkg && /^version = / {
            value=$3
            gsub(/"/, "", value)
            print value
            exit
        }
    ' "$TAURI_CARGO" | tr -d '\r')"
    check_equals "textmerger/src-tauri/Cargo.toml" "$TAURI_CARGO" "$CARGO_VERSION"
else
    echo -e "  ${RED}ERR${NC} textmerger/src-tauri/Cargo.toml non trovato"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "$FRONTEND_PKG" ]; then
    FRONTEND_VERSION="$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' "$FRONTEND_PKG" | head -n 1 | tr -d '\r')"
    check_equals "textmerger/package.json" "$FRONTEND_PKG" "$FRONTEND_VERSION"
else
    echo -e "  ${RED}ERR${NC} textmerger/package.json non trovato"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "$DESKTOP_FILE" ]; then
    DESKTOP_VERSION="$(awk -F'=' '/^Version=/{print $2; exit}' "$DESKTOP_FILE" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    check_equals "packaging/textmerger.desktop" "$DESKTOP_FILE" "$DESKTOP_VERSION"
else
    echo -e "  ${YELLOW}WARN${NC} packaging/textmerger.desktop non trovato, skip"
fi

if grep -q '^Version=${pkgver}$' "$PKGBUILD"; then
    echo -e "  ${GREEN}OK${NC} build-publish-scripts/PKGBUILD desktop version dinamica"
else
    echo -e "  ${RED}ERR${NC} build-publish-scripts/PKGBUILD desktop version non dinamica (atteso: Version=\${pkgver})"
    ERRORS=$((ERRORS + 1))
fi

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo -e "${RED}Coerenza versioni fallita (${ERRORS} errori)${NC}"
    exit 1
fi

echo -e "${GREEN}Coerenza versioni verificata (${PKGVER})${NC}"