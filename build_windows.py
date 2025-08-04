"""
Build script for Windows executable using PyInstaller
"""
import PyInstaller.__main__
import os
import sys

def build_windows():
    """Build Windows executable"""

    # PyInstaller arguments
    args = [
        '__main__.py',
        '--name=TextMerger',
        '--windowed',  # No console window
        '--onefile',   # Single executable
        '--icon=assets/logo/logo.ico',
        '--add-data=assets;assets',
        '--add-data=translations;translations',
        '--add-data=ui;ui',
        '--add-data=core;core',
        '--add-data=utils;utils',
        '--hidden-import=PyQt5.QtCore',
        '--hidden-import=PyQt5.QtGui',
        '--hidden-import=PyQt5.QtWidgets',
        '--hidden-import=flask',
        '--hidden-import=werkzeug',
        '--hidden-import=nbformat',
        '--clean',
        '--noconfirm'
    ]

    print("Building Windows executable...")
    PyInstaller.__main__.run(args)
    print("Build completed! Check the 'dist' folder for TextMerger.exe")

if __name__ == "__main__":
    build_windows()
