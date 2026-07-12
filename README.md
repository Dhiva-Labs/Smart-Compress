# CompressX by DhivaLabs

Offline-first file compressor and converter built with Flutter. Everything
runs on-device — no uploads, no ads, no tracking.

Targets: **Linux**, **Windows**, **Android** (single codebase).

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

Every push to `main` runs the **Build** workflow (`.github/workflows/build.yml`):
analyze + tests, then three artifacts in parallel —
`smart-compress-windows-x64.zip` (built on a Windows runner), the Ubuntu
`.deb`, and the Android APK. Download them from the workflow run's
Artifacts section, or push a tag (`git tag v0.1.0 && git push --tags`) to
attach all three to a GitHub Release.

**Ubuntu .deb locally** — after `flutter build linux --release`:

```bash
bash tool/build_deb.sh    # → dist/smart-compress_<version>_amd64.deb
sudo apt install ./dist/smart-compress_0.1.0_amd64.deb
```

**Windows locally** — on a Windows machine with Flutter:
`flutter build windows --release` → `build\windows\x64\runner\Release\`.

**Android APK** — `flutter build apk --release`, output at
`build/app/outputs/flutter-apk/app-release.apk` (signed with the debug key;
set up a keystore in `android/key.properties` before a Play Store release).

Layout: `lib/engines/` holds pure processing logic (no Flutter imports,
isolate-friendly), `lib/core/` app services (settings, history, external
tools), `lib/features/<module>/` one screen per module, `lib/widgets/`
shared UI.
