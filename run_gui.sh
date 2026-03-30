#!/usr/bin/env bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$SCRIPT_DIR/textmerger"

if [ ! -d "$APP_DIR" ]; then
    echo -e "${RED}Error: cartella textmerger non trovata in $SCRIPT_DIR${NC}"
    exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
    echo -e "${RED}Error: npm non trovato. Installa Node.js e npm.${NC}"
    exit 1
fi

echo -e "${BLUE}Avvio TextMerger in modalita sviluppo...${NC}"
cd "$APP_DIR"

if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Installazione dipendenze frontend...${NC}"
    npm install
fi

if [ ! -f "node_modules/.bin/tauri" ]; then
    echo -e "${YELLOW}Installazione Tauri CLI locale...${NC}"
    npm install @tauri-apps/cli
fi

echo -e "${GREEN}Dipendenze OK${NC}"
echo -e "${BLUE}Eseguo: npm run tauri dev${NC}"
echo -e "${YELLOW}Premi Ctrl+C per fermare${NC}"

npm run tauri dev
