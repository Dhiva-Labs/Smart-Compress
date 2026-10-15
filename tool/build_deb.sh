#!/usr/bin/env bash
# Packages the Linux release bundle into dist/smart-compress_<version>_<arch>.deb
# Run from the project root after: flutter build linux --release
#
# <arch> is the Debian architecture of the build machine (amd64 or arm64),
# which is also the only one `flutter build linux` can target, so the bundle
# is read from build/linux/x64/... on amd64 and build/linux/arm64/... on arm64.
set -euo pipefail

VERSION=$(grep '^version:' pubspec.yaml | cut -d' ' -f2 | cut -d'+' -f1)
DEB_ARCH="$(dpkg --print-architecture)"
case "$DEB_ARCH" in
  amd64) FLUTTER_ARCH=x64 ;;
  arm64) FLUTTER_ARCH=arm64 ;;
  *)
    echo "error: unsupported architecture '$DEB_ARCH' (amd64 or arm64)" >&2
    exit 1
    ;;
esac
PKG="smart-compress_${VERSION}_${DEB_ARCH}"
ROOT="dist/deb/$PKG"

rm -rf "$ROOT"
mkdir -p "$ROOT"/{DEBIAN,usr/lib/smart-compress,usr/bin,usr/share/applications,usr/share/icons/hicolor/256x256/apps,usr/share/icons/hicolor/512x512/apps}

cp -r "build/linux/$FLUTTER_ARCH/release/bundle/"* "$ROOT/usr/lib/smart-compress/"
cp assets/icon/smart_compress_256.png "$ROOT/usr/share/icons/hicolor/256x256/apps/smart-compress.png"
cp assets/icon/smart_compress.png "$ROOT/usr/share/icons/hicolor/512x512/apps/smart-compress.png"
ln -s ../lib/smart-compress/smart_compress "$ROOT/usr/bin/smart-compress"

cat > "$ROOT/DEBIAN/control" <<EOF
Package: smart-compress
Version: $VERSION
Section: utils
Priority: optional
Architecture: $DEB_ARCH
Maintainer: DhivaLabs <dhivakar1010@gmail.com>
Depends: libgtk-3-0, libglib2.0-0, libstdc++6
Recommends: ffmpeg, ghostscript, qpdf
Description: CompressX by DhivaLabs
 Offline-first file compressor and converter.
 Compress images, PDFs, video, audio and archives entirely on-device.
 No uploads, no ads, no tracking.
EOF

cat > "$ROOT/usr/share/applications/smart-compress.desktop" <<'EOF'
[Desktop Entry]
Name=CompressX
Comment=Compress and convert files offline
Exec=/usr/lib/smart-compress/smart_compress
Icon=smart-compress
Terminal=false
Type=Application
Categories=Utility;Compression;
Keywords=compress;convert;image;pdf;video;audio;zip;
EOF

dpkg-deb --build --root-owner-group "$ROOT" "dist/$PKG.deb"
echo "Built dist/$PKG.deb"
