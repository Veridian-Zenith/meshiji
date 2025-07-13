# Maintainer: Dae <daedaevibin@naver.com>
pkgname=voix
pkgver=0.1.0 # Placeholder, will need to be updated
pkgrel=1
pkgdesc="A PAM authentication helper"
arch=('x86_64')
url="https://github.com/Veridian-Zenith/Voix"
license=('AGPL3' 'VCL1.0') # Based on LICENSE-AGPLv3 and LICENSE-VCL1.0
depends=('libpam')
makedepends=('cmake' 'gcc' 'make' 'pkgconf')
source=("${pkgname}-${pkgver}.tar.gz::https://github.com/Veridian-Zenith/Voix/archive/refs/tags/v${pkgver}.tar.gz") # Placeholder
sha256sums=('SKIP') # Will update with actual checksum later

build() {
  ./build.fish
}

package() {
  install -Dm755 build/voix "${pkgdir}/usr/bin/voix"
  install -Dm644 "${srcdir}/${pkgname}-${pkgver}/LICENSE-AGPLv3" "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE-AGPLv3"
  install -Dm644 "${srcdir}/${pkgname}-${pkgver}/LICENSE-VCL1.0" "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE-VCL1.0"
}
