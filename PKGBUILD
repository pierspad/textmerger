pkgname=myapp            # niente 'python-' se è applicazione CLI
pkgver=1.0.0
pkgrel=1
pkgdesc="Python CLI to do X"
arch=('any')
url="https://github.com/<tuo-user>/myapp"
license=('MIT')
depends=('python' 'python-requests')
source=("$pkgname-$pkgver.tar.gz::$url/archive/v$pkgver.tar.gz")
sha256sums=('SKIP')

build() {
  cd "$pkgname-$pkgver"
  python -m build --wheel       # richiede python-build
}

package() {
  cd "$pkgname-$pkgver"
  python -m installer --destdir="$pkgdir" dist/*.whl
}
