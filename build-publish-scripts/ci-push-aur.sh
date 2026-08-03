#!/usr/bin/env bash
# ci-push-aur.sh — publisher AUR usato da .github/workflows/aur-publish.yml.
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

MAX_ATTEMPTS=5
RETRY_DELAY=15

echo "Clonazione repo AUR (fresca)..."
CLONED=0
for i in $(seq 1 $MAX_ATTEMPTS); do
    if git clone --depth 1 "$AUR_REMOTE_URL" "$AUR_REPO_DIR"; then
        CLONED=1
        break
    fi
    echo "Tentativo $i/$MAX_ATTEMPTS di clonazione AUR fallito (AUR potrebbe essere temporaneamente in manutenzione). Riprovo tra ${RETRY_DELAY}s..."
    sleep "$RETRY_DELAY"
done

if [ "$CLONED" -ne 1 ]; then
    echo "Errore: Impossibile clonare il repository AUR dopo $MAX_ATTEMPTS tentativi." >&2
    exit 1
fi

echo "Aggiornamento checksum con updpkgsums..."
# updpkgsums riscrive PKGBUILD in-place: serve una directory scrivibile.
# /workspace è di proprietà di root (montato dal runner), non di builder.
WORK_DIR="$HOME/pkgbuild-work"
mkdir -p "$WORK_DIR"
cp "$PKGBUILD" "$WORK_DIR/PKGBUILD"
cd "$WORK_DIR"
updpkgsums

echo "Generazione .SRCINFO..."
makepkg --printsrcinfo > .SRCINFO

echo "Copia file nel repository AUR..."
cp PKGBUILD .SRCINFO "$AUR_REPO_DIR/"

cd "$AUR_REPO_DIR"
git config user.email "aur-bot@textmerger-ci"
git config user.name "Textmerger CI"
git add -A

if git diff --staged --quiet; then
    echo "Nessuna modifica da pushare su AUR, esco senza errori."
    exit 0
fi

VERSION=$(awk -F'=' '/^pkgver[[:space:]]*=/{print $2; exit}' PKGBUILD | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

echo "Commit e push su AUR (v${VERSION})..."
git commit -m "Update to v${VERSION}"

PUSHED=0
for i in $(seq 1 $MAX_ATTEMPTS); do
    if git push; then
        PUSHED=1
        break
    fi
    echo "Tentativo $i/$MAX_ATTEMPTS di push su AUR fallito. Riprovo tra ${RETRY_DELAY}s..."
    sleep "$RETRY_DELAY"
done

if [ "$PUSHED" -ne 1 ]; then
    echo "Errore: Impossibile effettuare il push su AUR dopo $MAX_ATTEMPTS tentativi." >&2
    exit 1
fi

echo "Push completato su AUR."
