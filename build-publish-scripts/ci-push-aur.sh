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

DELAYS=(15 30 60 300 300 300 300 300)
TOTAL_ATTEMPTS=${#DELAYS[@]}
CLONE_LOG="$HOME/aur-clone.log"

echo "Clonazione repo AUR (fresca)..."
CLONED=0
for i in "${!DELAYS[@]}"; do
    attempt=$((i + 1))
    rm -rf "$AUR_REPO_DIR"
    if git clone --depth 1 "$AUR_REMOTE_URL" "$AUR_REPO_DIR" 2>&1 | tee "$CLONE_LOG"; then
        CLONED=1
        break
    fi

    # "Permission denied (publickey)" NON è un problema transitorio: ritentare
    # per 25 minuti maschera l'errore vero facendolo sembrare manutenzione AUR
    # (è successo davvero: il segreto AUR_SSH_PRIVATE_KEY conteneva una chiave
    # non più registrata sull'account AUR e i log dicevano "manutenzione").
    if grep -q 'Permission denied (publickey)' "$CLONE_LOG"; then
        echo "Errore: l'AUR ha rifiutato la chiave SSH (Permission denied (publickey))." >&2
        echo "Non è un problema transitorio: nessun retry." >&2
        echo "Il segreto AUR_SSH_PRIVATE_KEY non corrisponde a nessuna chiave registrata" >&2
        echo "su https://aur.archlinux.org/account/ (fingerprint della chiave in uso qui sopra)." >&2
        exit 1
    fi

    delay=${DELAYS[$i]}
    if [ "$delay" -ge 60 ]; then
        delay_fmt="$((delay / 60)) min"
    else
        delay_fmt="${delay}s"
    fi
    echo "Tentativo $attempt/$TOTAL_ATTEMPTS di clonazione AUR fallito (AUR in manutenzione o irraggiungibile). Riprovo tra ${delay_fmt}..."
    sleep "$delay"
done

if [ "$CLONED" -ne 1 ]; then
    echo "Errore: Impossibile clonare il repository AUR dopo $TOTAL_ATTEMPTS tentativi (~25 min)." >&2
    echo "Suggerimento: L'AUR potrebbe essere in manutenzione prolungata. Rieseguire il workflow da GitHub Actions ('Re-run jobs') più tardi." >&2
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

PUSH_DELAYS=(15 30 60 180 300)
TOTAL_PUSH_ATTEMPTS=${#PUSH_DELAYS[@]}

echo "Commit e push su AUR (v${VERSION})...."
git commit -m "Update to v${VERSION}"

PUSH_LOG="$HOME/aur-push.log"
PUSHED=0
for i in "${!PUSH_DELAYS[@]}"; do
    attempt=$((i + 1))
    if git push 2>&1 | tee "$PUSH_LOG"; then
        PUSHED=1
        break
    fi
    if grep -q 'Permission denied (publickey)' "$PUSH_LOG"; then
        echo "Errore: l'AUR ha rifiutato la chiave SSH in push. Nessun retry." >&2
        exit 1
    fi
    delay=${PUSH_DELAYS[$i]}
    if [ "$delay" -ge 60 ]; then
        delay_fmt="$((delay / 60)) min"
    else
        delay_fmt="${delay}s"
    fi
    echo "Tentativo $attempt/$TOTAL_PUSH_ATTEMPTS di push su AUR fallito. Riprovo tra ${delay_fmt}..."
    sleep "$delay"
done

if [ "$PUSHED" -ne 1 ]; then
    echo "Errore: Impossibile effettuare il push su AUR dopo $TOTAL_PUSH_ATTEMPTS tentativi." >&2
    exit 1
fi

echo "Push completato su AUR."
