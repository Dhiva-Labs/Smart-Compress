#!/usr/bin/env bash
# Builds smart-compress-linux-<arch>.tar.gz from the Linux release bundle.
#
# Run from anywhere after `flutter build linux --release` in the repo root:
#
#     tool/build_tarball.sh [output-dir]    # default: dist/
#
# <arch> is Flutter's name for the build machine (x64 or arm64), which is also
# the only architecture `flutter build linux` can target. The archive holds the
# bundle in a single smart-compress-linux-<arch>/ directory; run
# ./smart_compress from inside it.
set -euo pipefail

cd "$(dirname "$0")/.."
OUT_DIR="${1:-dist}"
case "$(uname -m)" in
  x86_64) ARCH=x64 ;;
  aarch64 | arm64) ARCH=arm64 ;;
  *)
    echo "error: unsupported machine '$(uname -m)' (x86_64 or aarch64)" >&2
    exit 1
    ;;
esac
RELEASE_DIR="build/linux/$ARCH/release"

[ -x "$RELEASE_DIR/bundle/smart_compress" ] || {
  echo "error: $RELEASE_DIR/bundle/smart_compress not found - run 'flutter build linux --release' first" >&2
  exit 1
}

NAME="smart-compress-linux-${ARCH}"
mkdir -p "$OUT_DIR"
TARBALL="$OUT_DIR/$NAME.tar.gz"
tar -czf "$TARBALL" --owner=0 --group=0 --sort=name \
  --transform "s,^bundle,$NAME," -C "$RELEASE_DIR" bundle
echo "built $TARBALL"
