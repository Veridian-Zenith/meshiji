# Maintainer: Dae <daedaevibin@naver.com>
pkgname=voix
pkgver=0.0.15b
pkgrel=1
pkgdesc="A privilege escalation tool that replaces sudo/doas/sudo-rs, using PAM for authentication"
arch=('x86_64')
url="https://github.com/Veridian-Zenith/Voix"
license=('AGPL-3.0-or-later' 'VCL-1.0')
depends=('pam')
makedepends=('cmake' 'gcc' 'make' 'pkgconf')
source=("https://github.com/Veridian-Zenith/Voix/archive/refs/tags/v${pkgver}.tar.gz")
sha256sums=('SKIP') # Or real sha256sum from the release tarball

build() {
  cmake -B build -DCMAKE_BUILD_TYPE=Release
  cmake --build build
}

package() {
  # Binaries (add all 3)
  install -Dm755 build/voix       "${pkgdir}/usr/bin/voix"

  # Config defaults
  install -Dm644 lua/config.lua   "${pkgdir}/etc/voix/config.lua"

  # Licenses in proper dirs
  install -Dm644 LICENSE-AGPLv3   "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE-AGPLv3"
  install -Dm644 LICENSE-VCL1.0   "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE-VCL1.0"
}
