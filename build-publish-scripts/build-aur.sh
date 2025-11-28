#!/bin/bash
set -euo pipefail
export LC_ALL=C

cd "$(dirname "$0")"

TAURI_CONF="../textmerger/src-tauri/tauri.conf.json"

get_version_from_pkgbuild() {
    if [ -f "PKGBUILD" ]; then
        grep -Po '^pkgver=\K.*' PKGBUILD
    else
        echo ""
    fi
}

echo "Building textmerger (Rust/Tauri) for Arch Linux..."

VERSION=$(get_version_from_pkgbuild)
if [ -z "$VERSION" ]; then
    echo "Error: Could not extract version from PKGBUILD"
    exit 1
fi
echo "Detected version from PKGBUILD: $VERSION"

if [ -f "$TAURI_CONF" ]; then
    echo "Updating tauri.conf.json version to $VERSION..."
    sed -i 's/"version": *"[^"]*"/"version": "'"$VERSION"'"/' "$TAURI_CONF"
else
    echo "Warning: tauri.conf.json not found at $TAURI_CONF"
fi

echo "Cleaning old build files..."
rm -f *.pkg.tar.zst *.src.tar.gz
rm -rf src/ pkg/

echo "Creating source tarball..."
cd ..
tar --exclude='.git' \
    --exclude='dist' \
    --exclude='build' \
    --exclude='pkg' \
    --exclude='textmerger/node_modules' \
    --exclude='textmerger/src-tauri/target' \
    --exclude='build-publish-scripts/src' \
    --exclude='build-publish-scripts/pkg' \
    --exclude='*.pkg.tar.*' \
    --exclude='.idea' \
    --exclude='.vscode' \
    --exclude='.DS_Store' \
    -czf "build-publish-scripts/textmerger-$VERSION.tar.gz" \
    --transform="s,^,textmerger-$VERSION/," \
    .

cd build-publish-scripts

echo "Updating checksums..."
updpkgsums

echo "Building Arch package..."
makepkg -sfc

echo ""
PKG_FILE=$(ls textmerger-*.pkg.tar.zst 2>/dev/null | head -n 1)

if [ ! -f "$PKG_FILE" ]; then
    echo "Error: Package file not found. Build failed?"
    exit 1
fi

echo "Build completed successfully!"
echo "Package created: $PKG_FILE"

if pacman -Qi textmerger &> /dev/null; then
    echo "Removing existing textmerger package..."
    sudo pacman -Rns textmerger --noconfirm
fi

echo "Installing new package..."
sudo pacman -U "$PKG_FILE" --noconfirm