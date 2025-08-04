import sys
import os
import traceback

if 'linux' in sys.platform:
    os.environ["QT_QPA_PLATFORM"] = "xcb"

def main():
    try:
        from PyQt5.QtWidgets import QApplication
        from PyQt5.QtGui import QIcon
        from textmerger.ui.mainwindow import MainWindow
        from textmerger.utils.helpers import get_asset_path

        app = QApplication(sys.argv)
        app.setApplicationName("TextMerger")
        app.setApplicationDisplayName("TextMerger")
        app.setApplicationVersion("1.0.0")

        # Set application icon
        try:
            icon_path = get_asset_path("logo/logo.png")
            if os.path.exists(icon_path):
                app.setWindowIcon(QIcon(icon_path))
        except Exception as e:
            print(f"Warning: Could not set application icon: {e}")

        window = MainWindow()
        window.show()

        sys.exit(app.exec_())

    except ImportError as e:
        print(f"Import error: {e}")
        print("Make sure PyQt5 is installed: pip install PyQt5")
        sys.exit(1)
    except Exception as e:
        print(f"Error starting TextMerger: {e}")
        print("Traceback:")
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()
