# TextMerger - Build Instructions

## Building for Arch Linux

### Quick Start
```bash
make arch
```

### Manual Build
```bash
./build-arch.sh
```

### Installation
After the build completes, install with:
```bash
sudo pacman -U textmerger-1.0.0-1-any.pkg.tar.zst
```

### Optional Features
For full functionality, install optional dependencies:

**Jupyter Notebook Support:**
```bash
pip install nbformat
```

**PDF Support:**
```bash
pip install PyPDF2
```

**All Optional Features:**
```bash
pip install nbformat PyPDF2
```

## Building for Windows

### Quick Start
```batch
build-windows.bat
```

### Manual Build
```batch
pip install -r requirements-windows.txt
python build_windows.py
```

The executable will be created in the `dist/` folder.

## Development

### Install for Development
```bash
make install-deps
make install
```

### Test the Application
```bash
make test
```

### Create Wheel Package
```bash
make wheel
```

## Troubleshooting

If you encounter issues with missing dependencies on Arch Linux, make sure all required packages are installed:

```bash
sudo pacman -S python python-pyqt5 python-flask python-werkzeug python-build python-installer python-wheel python-setuptools
```
