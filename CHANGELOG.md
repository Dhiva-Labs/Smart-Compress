# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-16

First release. The version moves from the development number 0.1.0 to 1.0.0 in
`pubspec.yaml`, the About dialog and the README.

### Added
- CompressX: an offline-first file compressor and converter with image
  compression and conversion, PDF tools, video and audio compression, ZIP/TAR
  archives with optional AES-256 passwords, a processing history and settings.
  Everything runs on the device.
- Linux x64, Linux arm64, Windows x64 and Windows arm64 builds. Every package
  is built, tested and started on a runner of its own architecture. Releases
  carry `smart-compress_<version>_amd64.deb`, `smart-compress_<version>_arm64.deb`,
  `smart-compress-linux-x64.tar.gz`, `smart-compress-linux-arm64.tar.gz`,
  `smart-compress-windows-x64.zip` and `smart-compress-windows-arm64.zip`.
- Releases are completed by CI: publishing a release attaches the desktop
  packages, leaving alone any file name already on the release.

### Changed
- `jni` is updated to 1.0.3, which compiles on Linux arm64.

### Removed
- A local browser-profile folder is no longer tracked and is ignored.

### Notes
- The Android APK is not built by CI and is not part of this release.
