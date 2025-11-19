#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' 

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🚀 textmerger Release Creator${NC}"
echo "=================================="

# Read version from PKGBUILD
if [[ -f "$SCRIPT_DIR/PKGBUILD" ]]; then
    NEW_VERSION=$(grep "^pkgver=" "$SCRIPT_DIR/PKGBUILD" | cut -d'=' -f2)
    if [ -z "$NEW_VERSION" ]; then
        echo -e "${RED}❌ Errore: Impossibile leggere pkgver da PKGBUILD${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Versione rilevata da PKGBUILD: $NEW_VERSION${NC}"
else
    echo -e "${RED}❌ PKGBUILD non trovato in $SCRIPT_DIR${NC}"
    exit 1
fi

TAG_VERSION="v$NEW_VERSION"

echo -e "${YELLOW}📋 Preparazione release $NEW_VERSION...${NC}"

# Update pyproject.toml
if [[ -f "$PROJECT_ROOT/pyproject.toml" ]]; then
    sed -i "s/version = \".*\"/version = \"$NEW_VERSION\"/" "$PROJECT_ROOT/pyproject.toml"
    echo -e "${GREEN}✅ pyproject.toml allineato alla versione $NEW_VERSION${NC}"
else
    echo -e "${RED}❌ pyproject.toml non trovato${NC}"
    exit 1
fi

# Update .SRCINFO
echo -e "${YELLOW}🔄 Aggiornamento .SRCINFO...${NC}"
cd "$SCRIPT_DIR"
makepkg --printsrcinfo > .SRCINFO
echo -e "${GREEN}✅ .SRCINFO aggiornato${NC}"

RELEASE_NOTES_FILE="$PROJECT_ROOT/docs/release-notes.md"
if [[ ! -f "$RELEASE_NOTES_FILE" ]]; then
    echo -e "${RED}❌ Errore: $RELEASE_NOTES_FILE non trovato${NC}"
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ Errore: GitHub CLI (gh) non è installato${NC}"
    echo "Installa con: sudo pacman -S github-cli"
    exit 1
fi

echo -e "${YELLOW}🔐 Verifica autenticazione GitHub...${NC}"
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ Non sei autenticato con GitHub CLI${NC}"
    echo "Esegui: gh auth login"
    exit 1
fi

# Git operations
echo -e "${YELLOW}📦 Commit e Tag...${NC}"
cd "$PROJECT_ROOT"
git add pyproject.toml build-publish-scripts/PKGBUILD build-publish-scripts/.SRCINFO
git commit -m "chore: bump version to $NEW_VERSION"
git tag "$TAG_VERSION"
git push origin main
git push origin "$TAG_VERSION"

echo -e "${GREEN}✅ Git push completato${NC}"

# Create GitHub Release
echo -e "${YELLOW}🚀 Creazione release GitHub...${NC}"
gh release create "$TAG_VERSION" --title "Release $TAG_VERSION" --notes-file "$RELEASE_NOTES_FILE"

echo -e "${GREEN}✅ Release GitHub creata con successo!${NC}"
echo -e "${BLUE}Ora puoi eseguire ./push-aur.sh per aggiornare AUR.${NC}"
