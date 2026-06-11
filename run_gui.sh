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
    echo -e "${RED}❌ Error: cartella textmerger non trovata in $SCRIPT_DIR${NC}"
    exit 1
fi

cd "$APP_DIR"

echo -e "${BLUE}🚀 Starting TextMerger...${NC}"
echo ""

# 1. Prerequisite Checks
if ! command -v npm &> /dev/null; then
    echo -e "${RED}❌ Error: npm non trovato. Installa Node.js per continuare.${NC}"
    exit 1
fi

if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}📦 Installazione dipendenze frontend...${NC}"
    npm install
    echo ""
fi

if [ ! -f "node_modules/.bin/tauri" ]; then
    echo -e "${YELLOW}📦 Installazione Tauri CLI locale...${NC}"
    npm install @tauri-apps/cli
    echo ""
fi

echo -e "${GREEN}✅ Dependencies OK${NC}"

# 2. Dynamic Port Selection
BASE_PORT=5174
PORT=$BASE_PORT

find_free_port() {
    local port=$1
    while true; do
        if python3 -c "import socket; s = socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.bind(('127.0.0.1', $port))" >/dev/null 2>&1; then
            echo "$port"
            return 0
        fi
        port=$((port + 1))
    done
}

PORT=$(find_free_port "$BASE_PORT")
export PORT
echo -e "${GREEN}🔌 Using available port $PORT${NC}"

export WEBKIT_DISABLE_COMPOSITING_MODE=1
export WHISPER_DONT_GENERATE_BINDINGS=1

echo -e "${BLUE}🖥️  Starting Tauri in dev mode on port $PORT...${NC}"
echo -e "${YELLOW}   (Premi Ctrl+C per fermare)${NC}"
echo ""

npx tauri dev --config "{\"build\": {\"devUrl\": \"http://localhost:$PORT\"}}"
