# TextMerger [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

TextMerger is a Python application built with PyQt5 that lets you easily merge content from multiple files into one.


## Features
- **Drag & Drop** support for files and folders
- **One-click Copy** of merged text
- **Save** merged content to a new file
- **Light/Dark Mode**
- **Multilanguage** support
- **Customizable Shortcuts**

## Supported Formats
TextMerger works with a wide range of file types, including source code, web scripts, markup/configuration files, project files, and special formats (e.g., Jupyter Notebooks, PDFs, CSVs).

## Installation

### From Source
1. Ensure you have Python 3.9+ and pip installed.
2. Clone the repository:
   ```bash
   git clone https://github.com/tuouser/TextMerger.git
   cd TextMerger
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Launch the application:
   ```bash
   python __main__.py
   ```

### Build Executable
1. Install PyInstaller:
   ```bash
   pip install pyinstaller
   ```
2. Create the executable:
   ```bash
      py -m PyInstaller `
      --onefile `
      --noconsole `
      --name TextMerger `
      --icon=assets/logo/logo.png `
      --add-data "assets;assets" `
      --add-data "translations;translations" `
      __main__.py
   ```
3. The executable will be located in the `dist` folder.

## Contributing
Pull requests are welcome! For major changes, please open an issue first to discuss your ideas.

## License
This project is licensed under the MIT License – see the [LICENSE](LICENSE) file for details.