import sys
import os

if 'linux' in sys.platform:
    os.environ["QT_QPA_PLATFORM"] = "xcb"

from PyQt5.QtWidgets import QApplication
from PyQt5.QtGui import QIcon
from ui.mainwindow import MainWindow
from utils.helpers import get_asset_path

def main():
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec_())

if __name__ == '__main__':
    main()
