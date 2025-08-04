.PHONY: help arch windows clean test install-deps

help:
	@echo "TextMerger Build System"
	@echo "======================"
	@echo "Available targets:"
	@echo "  arch        - Build package for Arch Linux"
	@echo "  windows     - Build executable for Windows (requires Windows/Wine)"
	@echo "  clean       - Clean build artifacts"
	@echo "  test        - Run application in development mode"
	@echo "  install-deps- Install development dependencies"

arch:
	@echo "Building for Arch Linux..."
	./build-arch.sh

windows:
	@echo "Building for Windows..."
	python build_windows.py

clean:
	@echo "Cleaning build artifacts..."
	rm -rf build/ dist/ *.egg-info/
	rm -f *.pkg.tar.zst
	rm -f *.spec

test:
	@echo "Running TextMerger in development mode..."
	python __main__.py

install-deps:
	@echo "Installing development dependencies..."
	pip install -r requirements.txt

# For development - create wheel package
wheel:
	@echo "Building wheel package..."
	python -m build --wheel

# Install from source (for development)
install:
	@echo "Installing TextMerger from source..."
	pip install -e .
