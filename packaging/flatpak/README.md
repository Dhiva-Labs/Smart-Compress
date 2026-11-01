# Flatpak

The `flatpak` job in `.github/workflows/desktop.yml` builds
`smart-compress-<version>-<x86_64|aarch64>.flatpak` on the GNOME 51 runtime,
then installs that bundle in the Flatpak builder container and runs it
(`test-bundle.sh`): every ELF file must find its libraries inside the sandbox,
`check-tools.sh` must compress a video (H.264/AAC and VP9/Opus), audio (MP3,
AAC) and a PDF and merge two PDFs with the bundled tools, and the "CompressX"
window must come up under Xvfb.

The manifest does not compile anything. It takes the installed tree of the
`.deb` CI built for that architecture, after `bundle-tools.sh` added ffmpeg,
Ghostscript and qpdf from Ubuntu 24.04 under `usr/lib/smart-compress/tools/`
(with every library they need beyond the runtime, Ghostscript's resources and
fonts, and each package's copyright file and exact version in
`tools/licenses/`). The app runs these tools for video, audio and PDF work and
looks for them on `PATH`; inside the sandbox it cannot reach the host's
copies, so the Flatpak carries its own and puts them in `/app/bin`.

Install a bundle from a release (the GNOME runtime comes from Flathub):

```sh
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user ./smart-compress-1.0.0-x86_64.flatpak
flatpak run com.dhivalabs.smartcompress
```

Permissions: Wayland/X11, the GPU and the home folder (`--filesystem=home`):
the compressed copy is written next to the original by default, and dragged-in
files arrive as paths. Files outside the home folder can be opened through the
file chooser, but then set an output folder in Settings.

## A Flathub submission would differ

- Flathub does not build from CI artifacts or take binaries copied from
  another distribution. The `tree` source becomes the release `.deb`, and
  ffmpeg, Ghostscript and qpdf are built from source as modules (with
  x264/LAME for the encoders the app asks for).
- Flathub asks for a free-software or redistributable licence in the
  metainfo; the repository has none.
- `flatpak-builder-lint` must pass on the manifest and the metainfo
  (screenshots, release notes, a brand colour).
