#!/usr/bin/env bash
# ci-push-aur.sh — variante non interattiva di push-aur.sh per GitHub Actions.
# Eseguito come utente non privilegiato dentro un container archlinux:base-devel.

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="/workspace/build-publish-scripts"
cd "$SCRIPT_DIR"

PKGBUILD="$SCRIPT_DIR/PKGBUILD"
CHECK_SCRIPT="$SCRIPT_DIR/check_version_consistency.sh"

# update_project_info.sh NON viene chiamato in CI: stessa motivazione di vesta —
# usa sed -i su file del workspace a cui il container non ha write permission.
# Al commit del tag tutto è già allineato; updpkgsums pensa al checksum runtime.

PROJECT_NAME="$(awk -F'=' '/^pkgname[[:space:]]*=/{print $2; exit}' "$PKGBUILD" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
if [ -z "$PROJECT_NAME" ]; then
    echo "Errore: impossibile leggere pkgname dal PKGBUILD" >&2
    exit 1
fi

AUR_REMOTE_URL="ssh://aur@aur.archlinux.org/${PROJECT_NAME}.git"
AUR_REPO_DIR="$HOME/aur-repo"

echo "Verifica coerenza versioni..."
bash "$CHECK_SCRIPT"

echo "Clonazione repo AUR (fresca)..."
git clone --depth 1 "$AUR_REMOTE_URL" "$AUR_REPO_DIR"

echo "Aggiornamento checksum con updpkgsums..."
updpkgsums

echo "Generazione .SRCINFO..."
makepkg --printsrcinfo > .SRCINFO

echo "Copia file nel repository AUR..."
cp PKGBUILD .SRCINFO "$AUR_REPO_DIR/"

cd "$AUR_REPO_DIR"
git add -A

if git diff --staged --quiet; then
    echo "Nessuna modifica da pushare su AUR, esco senza errori."
    exit 0
fi

VERSION=$(awk -F'=' '/^pkgver[[:space:]]*=/{print $2; exit}' PKGBUILD | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

echo "Commit e push su AUR (v${VERSION})..."
git commit -m "Update to v${VERSION}"
git push
echo "Push completato su AUR."
