# Maintainer: PierpaoloSpadafora
pkgname=textmerger
pkgver=1.0.0
pkgrel=1
pkgdesc="A Python GUI application for merging text files"
arch=('any')
url="https://github.com/PierpaoloSpadafora/TextMerger"
license=('MIT')
depends=('python' 'python-pyqt5' 'python-flask' 'python-werkzeug')
makedepends=('python-build' 'python-installer' 'python-wheel' 'python-setuptools')
optdepends=('python-pip: for installing optional dependencies like nbformat for Jupyter notebook support')
source=()
sha256sums=()

prepare() {
  # Source is already prepared by build-arch.sh
  cd "$srcdir/TextMerger-$pkgver"
}

build() {
  cd "$srcdir/TextMerger-$pkgver"
  python -m build --wheel --no-isolation
}

check() {
  cd "$srcdir/TextMerger-$pkgver"
  # Add any tests here if available
}

package() {
  cd "$srcdir/TextMerger-$pkgver"
  python -m installer --destdir="$pkgdir" dist/*.whl

  # Install license
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"

  # Install desktop file
  install -Dm644 textmerger.desktop "$pkgdir/usr/share/applications/textmerger.desktop"
}
