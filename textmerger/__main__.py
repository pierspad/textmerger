import os
import sys
import traceback

current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

if 'linux' in sys.platform:
    # Usa xcb solo se non è già impostato (permette override per Wayland)
    if "QT_QPA_PLATFORM" not in os.environ:
        os.environ["QT_QPA_PLATFORM"] = "xcb"
    # Abilita drag and drop su Wayland
    os.environ.setdefault("QT_WAYLAND_DISABLE_WINDOWDECORATION", "0")

def main():
    try:
        import ui.mainwindow
        import utils.helpers
        from PyQt5.QtCore import Qt
        from PyQt5.QtGui import QIcon
        from PyQt5.QtWidgets import QApplication

        app = QApplication(sys.argv)
        # Abilita drag and drop esplicitamente
        app.setAttribute(Qt.AA_DontUseNativeMenuBar, False)
        app.setApplicationName("TextMerger")
        app.setApplicationDisplayName("TextMerger")
        app.setApplicationVersion("1.0.0")

        try:
            icon_path = utils.helpers.get_asset_path("logo/logo.png")
            if os.path.exists(icon_path):
                app.setWindowIcon(QIcon(icon_path))
        except Exception as e:
            print(f"Warning: Could not set application icon: {e}")

        window = ui.mainwindow.MainWindow()
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
