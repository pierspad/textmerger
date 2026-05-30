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
EXTRACT_NOTES_SCRIPT="$SCRIPT_DIR/extract-release-notes.sh"
RELEASE_NOTES_FILE="$PROJECT_ROOT/docs/release-notes.md"
CHANGES_FILE="$PROJECT_ROOT/docs/list_of_things_changed.md"

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

    if command -v code >/dev/null 2>&1; then
        echo -e "${YELLOW}Apro ${title}... salva e chiudi per continuare${NC}"
        code --wait "$file"
    else
        echo -e "${YELLOW}Puoi modificare il file con il tuo editor preferito: $file${NC}"
        echo -e "${YELLOW}👉 Modifica il file, SALVALO e poi premi [INVIO] in questo terminale per continuare...${NC}"
        read -r
    fi
}

if [ ! -f "$PKGBUILD" ]; then
    echo -e "${RED}Error: PKGBUILD non trovato in $SCRIPT_DIR${NC}"
    exit 1
fi

if [ ! -f "$UPDATE_SCRIPT" ] || [ ! -f "$CHECK_SCRIPT" ] || [ ! -f "$EXTRACT_NOTES_SCRIPT" ]; then
    echo -e "${RED}Error: script di supporto mancanti (update/check/extract release notes)${NC}"
    exit 1
fi

if [ ! -f "$RELEASE_NOTES_FILE" ]; then
    echo -e "${RED}Error: release notes non trovate in $RELEASE_NOTES_FILE${NC}"
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

if [ -f "$CHANGES_FILE" ]; then
    echo -e "${BLUE}Apro il changelog operativo LLM prima delle release notes: $(basename "$CHANGES_FILE")${NC}"
    open_file_blocking "$CHANGES_FILE" "$(basename "$CHANGES_FILE")"
else
    echo -e "${YELLOW}Nota: $CHANGES_FILE non esiste ancora. Lo useranno gli LLM per annotare le modifiche.${NC}"
fi

open_file_blocking "$RELEASE_NOTES_FILE" "$(basename "$RELEASE_NOTES_FILE")"

if ! grep -q '[^[:space:]]' "$RELEASE_NOTES_FILE"; then
    echo -e "${RED}Error: release notes vuote. Compilale prima di pubblicare.${NC}"
    exit 1
fi

RELEASE_BODY_PREVIEW="$(mktemp)"
trap 'rm -f "$RELEASE_BODY_PREVIEW"' EXIT

echo -e "${YELLOW}Verifico la sezione release notes per ${TAG_VERSION}...${NC}"
bash "$EXTRACT_NOTES_SCRIPT" "$TAG_VERSION" "$RELEASE_NOTES_FILE" "$RELEASE_BODY_PREVIEW"
echo -e "${GREEN}Release notes valide; verra pubblicata la sezione del tag o il blocco 'Release Notes'.${NC}"

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

echo -e "${YELLOW}Modifiche che finiranno nel commit/tag:${NC}"
git -C "$PROJECT_ROOT" status --short
echo ""

read -rp "Procedere con commit, tag e push di ${TAG_VERSION}? [s/N] " confirm_release
if [[ ! "$confirm_release" =~ ^[sS]$ ]]; then
    echo -e "${YELLOW}Release annullata.${NC}"
    exit 0
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

git push --atomic origin "$BRANCH" "$TAG_VERSION"

echo -e "${GREEN}Tag ${TAG_VERSION} pubblicato con successo${NC}"
echo -e "${BLUE}La GitHub Action creera la release usando solo la sezione ${TAG_VERSION} di docs/release-notes.md.${NC}"
echo -e "${BLUE}Dopo il build GitHub, esegui ./push-aur.sh per aggiornare AUR.${NC}"
