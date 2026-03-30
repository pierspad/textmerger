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
UPDATE_SCRIPT="$SCRIPT_DIR/update_project_info.sh"
CHECK_SCRIPT="$SCRIPT_DIR/check_version_consistency.sh"
RELEASE_NOTES_FILE="$PROJECT_ROOT/docs/release-notes.md"

read_pkgver() {
    awk -F'=' '/^pkgver[[:space:]]*=/{print $2; exit}' "$PKGBUILD" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//'
}

open_file_blocking() {
    local file="$1"
    local title="$2"

    if [ ! -f "$file" ]; then
        echo -e "${RED}Error: file non trovato: $file${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Apro ${title}... salva e chiudi per continuare${NC}"
    code --wait "$file"
}

if [ ! -f "$PKGBUILD" ]; then
    echo -e "${RED}Error: PKGBUILD non trovato in $SCRIPT_DIR${NC}"
    exit 1
fi

if [ ! -f "$UPDATE_SCRIPT" ] || [ ! -f "$CHECK_SCRIPT" ]; then
    echo -e "${RED}Error: script di supporto mancanti (update/check)${NC}"
    exit 1
fi

if [ ! -f "$RELEASE_NOTES_FILE" ]; then
    echo -e "${RED}Error: release notes non trovate in $RELEASE_NOTES_FILE${NC}"
    exit 1
fi

if ! command -v code >/dev/null 2>&1; then
    echo -e "${RED}Error: comando 'code' non disponibile. Installa/abilita VS Code CLI.${NC}"
    exit 1
fi

echo -e "${BLUE}textmerger Release Creator${NC}"
echo "=================================="

open_file_blocking "$PKGBUILD" "PKGBUILD"

VERSION="$(read_pkgver)"
if [ -z "$VERSION" ]; then
    echo -e "${RED}Error: impossibile leggere pkgver dal PKGBUILD${NC}"
    exit 1
fi

TAG_VERSION="v$VERSION"
echo -e "${GREEN}Versione rilevata: ${VERSION}${NC}"

echo -e "${YELLOW}Allineo i file progetto dal PKGBUILD...${NC}"
bash "$UPDATE_SCRIPT"

echo -e "${YELLOW}Verifico coerenza versioni...${NC}"
bash "$CHECK_SCRIPT"

for file in \
    "$PROJECT_ROOT/textmerger/src-tauri/tauri.conf.json" \
    "$PROJECT_ROOT/textmerger/src-tauri/Cargo.toml" \
    "$PROJECT_ROOT/textmerger/package.json" \
    "$PROJECT_ROOT/packaging/textmerger.desktop" \
    "$RELEASE_NOTES_FILE"; do
    open_file_blocking "$file" "$(basename "$file")"
done

if ! grep -q "$VERSION" "$RELEASE_NOTES_FILE"; then
    echo -e "${YELLOW}Attenzione: la versione ${VERSION} non compare nelle release notes.${NC}"
fi

read -rp "Procedere con la release ${TAG_VERSION}? [s/N] " confirm_release
if [[ ! "$confirm_release" =~ ^[sS]$ ]]; then
    echo -e "${YELLOW}Release annullata.${NC}"
    exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
    echo -e "${RED}Error: GitHub CLI (gh) non installato${NC}"
    echo "Installa con: sudo pacman -S github-cli"
    exit 1
fi

echo -e "${YELLOW}Verifica autenticazione GitHub...${NC}"
if ! gh auth status >/dev/null 2>&1; then
    echo -e "${RED}Error: non autenticato con GitHub CLI${NC}"
    echo "Esegui: gh auth login"
    exit 1
fi

echo -e "${GREEN}Autenticazione OK${NC}"

if command -v makepkg >/dev/null 2>&1; then
    echo -e "${YELLOW}Genero .SRCINFO...${NC}"
    (
        cd "$SCRIPT_DIR"
        makepkg --printsrcinfo > .SRCINFO
    )
    echo -e "${GREEN}.SRCINFO aggiornato${NC}"
else
    echo -e "${YELLOW}makepkg non disponibile, skip .SRCINFO${NC}"
fi

echo -e "${YELLOW}Commit, tag e push...${NC}"
cd "$PROJECT_ROOT"

git add -A

if git diff --cached --quiet; then
    echo -e "${YELLOW}Nessuna modifica da committare, continuo con il tag${NC}"
else
    git commit -m "chore: release ${TAG_VERSION}"
    echo -e "${GREEN}Commit creato${NC}"
fi

if git rev-parse "$TAG_VERSION" >/dev/null 2>&1; then
    echo -e "${YELLOW}Tag ${TAG_VERSION} gia esistente, lo ricreo${NC}"
    git tag -d "$TAG_VERSION"
    git push origin ":refs/tags/$TAG_VERSION" 2>/dev/null || true
fi

git tag "$TAG_VERSION"

BRANCH="$(git branch --show-current)"
if [ -z "$BRANCH" ]; then
    echo -e "${RED}Error: impossibile rilevare il branch corrente (HEAD detached?)${NC}"
    exit 1
fi

git push origin "$BRANCH"
git push origin "$TAG_VERSION"

echo -e "${YELLOW}Creo GitHub release...${NC}"
gh release create "$TAG_VERSION" \
    --title "textmerger ${TAG_VERSION}" \
    --notes-file "$RELEASE_NOTES_FILE"

echo -e "${GREEN}Release ${TAG_VERSION} creata con successo${NC}"
echo -e "${BLUE}Dopo il build GitHub, esegui ./push-aur.sh per aggiornare AUR.${NC}"
