# CompressX by DhivaLabs

[![ARM64 builds](https://github.com/Dhiva-Labs/Smart-Compress/actions/workflows/desktop.yml/badge.svg?branch=main)](https://github.com/Dhiva-Labs/Smart-Compress/actions/workflows/desktop.yml)
![Linux x64 | arm64](https://img.shields.io/badge/Linux-x64%20%7C%20arm64-informational?logo=linux&logoColor=white)
![Windows x64 | arm64](https://img.shields.io/badge/Windows-x64%20%7C%20arm64-informational?logo=windows&logoColor=white)

Offline-first file compressor and converter built with Flutter. Everything
runs on-device — no uploads, no ads, no tracking.

Targets: **Linux** (x64, arm64), **Windows** (x64, arm64), **Android** (single codebase).

## Modules

| Module | What works today | Backend |
|---|---|---|
| Image Compressor | Quality slider, resize, target file size (100 KB–1 MB), EXIF removal, presets (Email/WhatsApp/Instagram/Website/Max/Best), batch, before/after comparison with zoom | pure Dart (`image`), runs in an isolate |
| Image Converter | JPG/PNG/WEBP/GIF/BMP/TIFF/ICO/TGA in → JPG/PNG/GIF/BMP/TIFF/ICO out | pure Dart |
| PDF Tools | Images → PDF everywhere; compress (4 levels) and merge on desktop | `pdf` package; Ghostscript/qpdf when installed |
| Video Compressor | Resolution, CRF quality, frame rate, target size, remove audio, format conversion (MP4/MKV/MOV/AVI/WEBM) | system FFmpeg (desktop) |
| Audio Compressor | Bitrate, target size, format conversion (MP3/AAC/OGG/FLAC/WAV/M4A) | system FFmpeg (desktop) |
| Archive | Create ZIP (optional AES-256 password) / TAR / TAR.GZ from files or folders, extract with password support | pure Dart (`archive`), runs in an isolate |
| History | Per-file log plus totals: files processed, storage saved, most-used type | `shared_preferences` |
| Settings | Light/Dark/System theme, default quality, output folder, keep/delete originals | |

Batch processing is built into every module — add multiple files and each
row shows its own status, sizes, and savings.

## Desktop extras

- Drag-and-drop files onto any picker area.
- Video/audio and PDF compress/merge shell out to system tools and degrade
  gracefully with install hints when missing:
  `sudo apt install ffmpeg ghostscript qpdf`

## Known limitations

- WEBP and HEIC can be read but not written (the pure-Dart `image` package
  has no encoders for them).
- Target file size mode always outputs JPEG.
- Video/audio and PDF compression are desktop-only for now; Android support
  needs an FFmpeg/MuPDF integration.
- 7Z is not supported (no pure-Dart implementation).

## Development

```bash
flutter pub get
flutter test          # engine unit tests + phone/desktop layout tests
flutter analyze
flutter build linux   # or: windows, apk
```

## Packaging & CI

Every push to `main` and every pull request runs the **Desktop builds**
workflow (`.github/workflows/desktop.yml`): tests, a release build, packaging
and a start-up check on Linux x64, Linux arm64, Windows x64 and Windows arm64.
Flutter cannot cross-compile desktop apps, so each leg runs on a native
runner. Every leg keeps its packages as a workflow artifact:

| Platform      | Files                                                                    |
|---------------|--------------------------------------------------------------------------|
| Linux x64     | `smart-compress_<version>_amd64.deb`, `smart-compress-linux-x64.tar.gz`   |
| Linux arm64   | `smart-compress_<version>_arm64.deb`, `smart-compress-linux-arm64.tar.gz` |
| Windows x64   | `smart-compress-windows-x64.zip`                                          |
| Windows arm64 | `smart-compress-windows-arm64.zip`                                        |

When a GitHub Release is published, the same workflow attaches all of them to
it; a file the release already has is left alone. The Android APK is not built
in CI (see below).

**Ubuntu .deb locally** — after `flutter build linux --release`:

```bash
bash tool/build_deb.sh    # → dist/smart-compress_<version>_<amd64|arm64>.deb
sudo apt install ./dist/smart-compress_1.0.0_amd64.deb   # _arm64.deb on an arm64 machine
```

The architecture is the one of the machine you build on: `build_deb.sh` and
`tool/build_tarball.sh` read `build/linux/x64/` or `build/linux/arm64/`
accordingly.

**Windows locally** — on a Windows machine with Flutter:
`flutter build windows --release` → `build\windows\x64\runner\Release\`
(`build\windows\arm64\runner\Release\` on an arm64 machine);
`tool/package_windows.ps1` zips it.

**Android APK** — `flutter build apk --release`, output at
`build/app/outputs/flutter-apk/app-release.apk` (signed with the debug key;
set up a keystore in `android/key.properties` before a Play Store release).

Layout: `lib/engines/` holds pure processing logic (no Flutter imports,
isolate-friendly), `lib/core/` app services (settings, history, external
tools), `lib/features/<module>/` one screen per module, `lib/widgets/`
shared UI.

## Sponsors

Dhiva Labs is an independent, self-funded lab. [Sponsorships](https://github.com/sponsors/Dhiva-Labs) help bring this project and the rest of Dhiva Labs to every platform, iPhone and Mac included.

[![Sponsor Dhiva Labs](https://img.shields.io/badge/Sponsor-Dhiva%20Labs-ea4aaa?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/Dhiva-Labs)

Monthly sponsors at $10 and up are listed here:

<!-- sponsors -->
*Be the first: [sponsor Dhiva Labs](https://github.com/sponsors/Dhiva-Labs).*
<!-- sponsors -->
