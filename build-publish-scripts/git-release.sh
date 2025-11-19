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

    exit 1
fi

echo -e "${YELLOW}🏷️  Verifica esistenza tag...${NC}"
if git tag -l | grep -q "^$VERSION$"; then
    echo -e "${RED}❌ Il tag $VERSION esiste già${NC}"
    read -p "Vuoi eliminare il tag esistente e continuare? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}🗑️  Eliminazione tag locale e remoto...${NC}"
        git tag -d "$VERSION" || true
        git push origin --delete "$VERSION" || true
    else
        echo -e "${YELLOW}⏹️  Operazione annullata${NC}"
        exit 0
    fi
fi

echo -e "${YELLOW}🌿 Verifica stato repository...${NC}"
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "main" ]]; then
    echo -e "${RED}❌ Non sei sul branch main (attuale: $CURRENT_BRANCH)${NC}"
    exit 1
fi

if [[ -n $(git status --porcelain) ]]; then
    echo -e "${RED}❌ Ci sono modifiche non committate${NC}"
    git status --short
    exit 1
fi

echo -e "${YELLOW}⬇️  Pull delle ultime modifiche...${NC}"
git pull origin main

echo -e "${YELLOW}🔄 Aggiornamento versione in pyproject.toml...${NC}"
PYPROJECT_FILE="$PROJECT_ROOT/pyproject.toml"
if [[ -f "$PYPROJECT_FILE" ]]; then
    # Update version in pyproject.toml
    sed -i "s/^version = \".*\"/version = \"$PKGVER\"/" "$PYPROJECT_FILE"
    
    # Check if file changed
    if ! git diff --quiet "$PYPROJECT_FILE"; then
        echo -e "${GREEN}✅ pyproject.toml aggiornato a $PKGVER${NC}"
        git add "$PYPROJECT_FILE"
        git commit -m "chore: bump version to $PKGVER"
        git push origin main
    else
        echo -e "${BLUE}ℹ️  pyproject.toml è già aggiornato${NC}"
    fi
else
    echo -e "${RED}⚠️  pyproject.toml non trovato${NC}"
fi

echo -e "${YELLOW}🏷️  Creazione tag $VERSION...${NC}"
git tag -a "$VERSION" -m "Release $VERSION"

echo -e "${YELLOW}⬆️  Push del tag...${NC}"
git push origin "$VERSION"

echo -e "${YELLOW}🎉 Creazione release GitHub...${NC}"
gh release create "$VERSION" \
    --target main \
    --title "textmerger $VERSION" \
    --notes-file "$RELEASE_NOTES_FILE" \
    --generate-notes

echo -e "${GREEN}✅ Release $VERSION creato con successo!${NC}"
echo -e "${BLUE}🔗 Visualizza il release: https://github.com/pierspad/textmerger/releases/tag/$VERSION${NC}"

read -p "Vuoi aprire il release nel browser? (Y/n): " -n 1 -r
echo
REPLY=${REPLY:-Y}
if [[ $REPLY =~ ^[Yy]$ ]]; then
    gh release view "$VERSION" --web
fi