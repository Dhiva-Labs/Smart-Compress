#!/usr/bin/env bash
# Runs inside the Flatpak sandbox (test-bundle.sh, SANDBOX_TEST). The bundled
# tools must be found the way the app looks for them (`which`) and do the
# jobs the app gives them, with the encoders and settings it asks for
# (lib/engines/media_engine.dart, lib/engines/pdf_engine.dart).
set -euo pipefail
cd "$(mktemp -d)"
for t in ffmpeg gs qpdf; do which "$t"; done

# Video: H.264 + AAC in MP4, VP9 + Opus in WebM. Audio: MP3, and AAC in M4A.
ffmpeg -y -hide_banner -loglevel error \
  -f lavfi -i testsrc=duration=2:size=320x240:rate=15 -f lavfi -i sine=frequency=440:duration=2 \
  -c:v libx264 -preset medium -crf 23 -c:a aac -b:a 128k in.mp4
ffmpeg -y -hide_banner -loglevel error -i in.mp4 -vf scale=-2:120 \
  -c:v libvpx-vp9 -crf 32 -b:v 0 -c:a libopus -b:a 128k out.webm
ffmpeg -y -hide_banner -loglevel error -i in.mp4 -vn -c:a libmp3lame -b:a 128k out.mp3
ffmpeg -y -hide_banner -loglevel error -i in.mp4 -vn -c:a aac -b:a 128k out.m4a
ffmpeg -hide_banner -i out.webm -f null - 2>&1 | grep -E 'Duration|Stream'

# PDF: write one with text in a base font, compress it as the app does, and
# merge two with qpdf.
gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=in.pdf \
  -c '/Helvetica findfont 24 scalefont setfont 72 700 moveto (CompressX) show showpage'
gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.5 -dPDFSETTINGS=/ebook \
  -dNOPAUSE -dQUIET -dBATCH -sOutputFile=small.pdf in.pdf
qpdf --empty --pages in.pdf small.pdf -- merged.pdf
qpdf --check merged.pdf
ls -l
echo "ffmpeg, gs and qpdf work inside the sandbox"
