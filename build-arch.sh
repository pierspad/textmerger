#!/bin/bash

# Build script for Arch Linux package
set -e

echo "Building TextMerger for Arch Linux..."

# Check if we're on Arch Linux
if ! command -v pacman &> /dev/null; then
    echo "Warning: This script is designed for Arch Linux"
fi

# Install build dependencies if needed
echo "Installing build dependencies..."
sudo pacman -S --needed python python-build python-installer python-wheel python-setuptools

# Create a proper source structure for PKGBUILD
echo "Preparing source package..."
rm -rf src pkg
mkdir -p src

# Create a clean copy of the project excluding build artifacts
echo "Creating clean source copy..."
rsync -av \
    --exclude='.git/' \
    --exclude='dist/' \
    --exclude='build/' \
    --exclude='src/' \
    --exclude='pkg/' \
    --exclude='*.egg-info/' \
    --exclude='__pycache__/' \
    --exclude='*.pyc' \
    --exclude='.venv*/' \
    --exclude='*.pkg.tar.*' \
    . src/TextMerger-1.0.0/

# Build the package
echo "Building Arch package..."
makepkg -sf

echo ""
echo "Build completed! Install with:"
echo "sudo pacman -U textmerger-1.0.0-1-any.pkg.tar.zst"
