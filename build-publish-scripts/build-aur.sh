#!/bin/bash
set -euo pipefail
export LC_ALL=C

cd "$(dirname "$0")"

if [ ! -f "PKGBUILD" ]; then
    echo "Error: PKGBUILD not found"
    exit 1
fi
VERSION=$(grep -Po '^pkgver=\K.*' PKGBUILD)
echo "Building TextMerger v$VERSION locally..."

PROJECT_ROOT="../textmerger"
echo "Building Tauri project..."
cd "$PROJECT_ROOT"
if [ ! -d "node_modules" ]; then
    npm install
fi
npm run tauri build -- --bundles deb

cd - > /dev/null
DEB_PATH="$PROJECT_ROOT/src-tauri/target/release/bundle/deb/textmerger_${VERSION}_amd64.deb"

if [ ! -f "$DEB_PATH" ]; then
    echo "Error: .deb package not found at $DEB_PATH"
    exit 1
fi

echo "Copying .deb package..."
cp "$DEB_PATH" "textmerger_${VERSION}_amd64.deb"

echo "Packaging for Arch with PKGBUILD.local..."
rm -f *.pkg.tar.zst
makepkg -p PKGBUILD.local -sfc --noconfirm

PKG_FILE=$(ls textmerger-*.pkg.tar.zst 2>/dev/null | head -n 1)
if [ ! -f "$PKG_FILE" ]; then
    echo "Error: Arch package creation failed."
    exit 1
fi

echo "------------------------------------------------"
echo "Build success!"
echo "Arch Package: $PWD/$PKG_FILE"
echo "------------------------------------------------"

read -p "Do you want to install this package now? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if pacman -Qi textmerger &> /dev/null; then
        echo "Removing previous version..."
        sudo pacman -Rns textmerger --noconfirm
    fi
    echo "Installing..."
    sudo pacman -U "$PKG_FILE" --noconfirm
else
    echo "Skipping installation."
fi