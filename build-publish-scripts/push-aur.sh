#!/usr/bin/env bash

set -euo pipefail

PROJECT_NAME="${PROJECT_NAME:-$(grep -Po '^pkgname=\K.*' PKGBUILD)}"
AUR_REPO_DIR="${AUR_REPO_DIR:-./$PROJECT_NAME}"
ICON_DIR="${ICON_DIR:-${PROJECT_NAME}/assets/logo}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [[ -z "$PROJECT_NAME" ]]; then
    echo -e "${RED}❌ Errore: Impossibile estrarre pkgname dal PKGBUILD${NC}"
    exit 1
fi

if [[ ! -d "$AUR_REPO_DIR" ]]; then
    echo -e "${YELLOW}⚠️  Directory $AUR_REPO_DIR non trovata. Clonazione repository AUR...${NC}"
    if ! git clone "ssh://aur@aur.archlinux.org/${PROJECT_NAME}.git" "$AUR_REPO_DIR"; then
        echo -e "${RED}❌ Errore nella clonazione SSH. Assicurati di avere una chiave SSH configurata per AUR.${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}🔄 Aggiornamento repository AUR per ${PROJECT_NAME}${NC}"

rm -rf pkg/ src/ ./*.pkg.*

echo -e "${YELLOW}🔍 Verifica e aggiornamento checksum SHA256 con updpkgsums...${NC}"

if ! updpkgsums; then
    echo -e "${RED}❌ Errore durante l'aggiornamento dei checksum${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Checksum aggiornati${NC}"

echo -e "${YELLOW}📄 Generazione .SRCINFO...${NC}"
makepkg --printsrcinfo > .SRCINFO
echo -e "${YELLOW}📁 Copia file nel repository AUR...${NC}"
cp PKGBUILD .SRCINFO "$AUR_REPO_DIR/"
for f in "$PROJECT_NAME".{install,desktop}; do
  [[ -f $f ]] && cp "$f" "$AUR_REPO_DIR/"
done
[[ -d $ICON_DIR ]] && cp "$ICON_DIR"/*.png "$AUR_REPO_DIR/" || true

echo -e "${YELLOW}🚀 Commit e push su AUR...${NC}"
cd "$AUR_REPO_DIR"
git add -A

if ! git diff --staged --quiet; then
    git commit -m "update $(date --iso-8601=seconds)"
fi

git push
echo -e "${GREEN}✅ Push completato su AUR${NC}"
