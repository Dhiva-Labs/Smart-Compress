#!/usr/bin/env bash
# Adds ffmpeg, Ghostscript and qpdf to the installed tree for the Flatpak.
#
# usage: bundle-tools.sh <tree>
#
# The app runs these three for video and audio, PDF compression and PDF
# merging, and finds them with `which`. The .rpm recommends them and the
# Arch package lists them as optional dependencies, so they come from the
# distribution; inside the Flatpak sandbox there is no system to install
# them into, so the Flatpak carries this Ubuntu runner's builds:
#
#   usr/lib/smart-compress/tools/bin/    ffmpeg, qpdf, gs (a wrapper, below)
#   usr/lib/smart-compress/tools/lib/    every library they need beyond what
#                                        the GNOME runtime has; RUNPATH
#                                        ($ORIGIN) ties them together
#   usr/lib/smart-compress/tools/share/ghostscript/
#                                        Ghostscript's resources, ICC
#                                        profiles and base fonts, which
#                                        Ubuntu's gs reads from /usr/share
#   usr/lib/smart-compress/tools/licenses/
#                                        each copied package's copyright file
#                                        and exact version
#
# Left to the runtime: glibc and the compiler runtime, GTK 3 and the
# libraries it is built on, X11/Wayland, the GL/GPU stack and ALSA.
#
# Needs ffmpeg, ghostscript and qpdf installed on the runner, patchelf and dpkg.
set -euo pipefail
[ $# -eq 1 ] || { echo "usage: $0 <tree>" >&2; exit 2; }
dest="$(cd "$1" && pwd)/usr/lib/smart-compress/tools"
install -d "$dest/bin" "$dest/lib" "$dest/licenses" "$dest/share/ghostscript"

host_lib() {
  case "$1" in
    # glibc and the compiler runtime
    ld-linux*|libc.so.*|libm.so.*|libdl.so.*|libpthread.so.*|librt.so.*|libresolv.so.*|\
    libutil.so.*|libmvec.so.*|libanl.so.*|libnss_*|libthread_db.so.*|libstdc++.so.*|libgcc_s.so.*) ;;
    # GTK 3 and what it is built on
    libgtk-3.so.*|libgdk-3.so.*|libgdk_pixbuf-2.0.so.*|libglib-2.0.so.*|libgobject-2.0.so.*|\
    libgio-2.0.so.*|libgmodule-2.0.so.*|libgthread-2.0.so.*|libpango-1.0.so.*|libpangocairo-1.0.so.*|\
    libpangoft2-1.0.so.*|libcairo.so.*|libcairo-gobject.so.*|libharfbuzz.so.*|libfreetype.so.*|\
    libfontconfig.so.*|libfribidi.so.*|libatk-1.0.so.*|libatk-bridge-2.0.so.*|libatspi.so.*|\
    libepoxy.so.*|libpixman-1.so.*|libpng16.so.*|libz.so.*|libexpat.so.*|libdbus-1.so.*|libffi.so.*|\
    libmount.so.*|libblkid.so.*|libselinux.so.*|libpcre2-8.so.*) ;;
    # X11 and Wayland client libraries
    libX11.so.*|libX11-xcb.so.*|libxcb.so.*|libxcb-render.so.*|libxcb-shm.so.*|libXau.so.*|\
    libXext.so.*|libXrender.so.*|libXfixes.so.*|libXi.so.*|libXrandr.so.*|libXcursor.so.*|\
    libXdamage.so.*|libXcomposite.so.*|libXinerama.so.*|libwayland-client.so.*|\
    libwayland-cursor.so.*|libwayland-egl.so.*|libwayland-server.so.*|libxkbcommon.so.*) ;;
    # GL and the GPU, sound
    libGL.so.*|libGLX.so.*|libGLdispatch.so.*|libOpenGL.so.*|libEGL.so.*|libgbm.so.*|\
    libdrm.so.*|libglapi.so.*|libasound.so.*) ;;
    *) return 1 ;;
  esac
}

# The package that owns a file. Not every Ubuntu package has moved its files
# to /usr yet, so try the /lib spelling too.
pkg_of() {
  local out
  out="$(dpkg -S "$1" 2> /dev/null || dpkg -S "${1#/usr}" 2> /dev/null)" ||
    { echo "no package owns $1" >&2; return 1; }
  printf '%s\n' "$out" | head -n 1 | cut -d: -f1
}

declare -A path=() seen=()
queue=() packages=()
for tool in ffmpeg qpdf gs; do
  real="$(readlink -f "$(command -v "$tool")")"
  # gs gets a wrapper; the binary sits next to it as gs.bin.
  name="$tool"; [ "$tool" = gs ] && name=gs.bin
  install -m755 "$real" "$dest/bin/$name"
  patchelf --set-rpath '$ORIGIN/../lib' "$dest/bin/$name"
  packages+=("$(pkg_of "$real")")
  queue+=("$dest/bin/$name")
  # Where each soname resolves on this runner: ldd follows the whole chain.
  while read -r soname arrow target _; do
    [ "$arrow" = '=>' ] || continue
    if [ "$target" = not ]; then echo "ldd $tool: $soname not found on this runner" >&2; exit 1; fi
    path["$soname"]="$target"
  done < <(ldd "$real")
done

# Walk the NEEDED graph from the three tools, stopping at runtime libraries.
copied=0
while [ "${#queue[@]}" -gt 0 ]; do
  f="${queue[0]}"
  queue=("${queue[@]:1}")
  while read -r soname; do
    [ -n "${seen[$soname]:-}" ] && continue
    seen["$soname"]=1
    host_lib "$soname" && continue
    src="${path[$soname]:-}"
    [ -n "$src" ] || { echo "$soname (needed by $(basename "$f")) did not resolve" >&2; exit 1; }
    real="$(readlink -f "$src")"
    install -m644 "$real" "$dest/lib/$soname"
    patchelf --set-rpath '$ORIGIN' "$dest/lib/$soname"
    packages+=("$(pkg_of "$real")")
    queue+=("$dest/lib/$soname")
    copied=$((copied + 1))
  done < <(objdump -p "$f" | awk '$1 == "NEEDED" { print $2 }')
done

# Ghostscript's run-time files. Ubuntu builds gs without them compiled in,
# so it reads Resource/Init, lib, the ICC profiles and the base fonts from
# /usr/share/ghostscript/<version>; -L copies the files the font and ICC
# symlinks point to.
gs_version="$(gs --version)"
cp -rL "/usr/share/ghostscript/$gs_version" "$dest/share/ghostscript/"
packages+=("$(pkg_of "/usr/share/ghostscript/$gs_version/Resource/Init/gs_init.ps")")
for f in "$dest/share/ghostscript/$gs_version/iccprofiles/default_rgb.icc" \
         "$dest/share/ghostscript/$gs_version/Resource/Init/gs_init.ps"; do
  [ -f "$f" ] || { echo "Ghostscript file missing after the copy: $f" >&2; exit 1; }
done
cat > "$dest/bin/gs" <<EOF
#!/bin/sh
# Ghostscript from Ubuntu, pointed at its run-time files next to it (it would
# look for them under /usr/share, which the Flatpak runtime does not have).
here="\$(dirname "\$(readlink -f "\$0")")"
share="\$here/../share/ghostscript/$gs_version"
GS_LIB="\$share/Resource/Init:\$share/lib:\$share/Resource/Font\${GS_LIB:+:\$GS_LIB}"
export GS_LIB
exec "\$here/gs.bin" -sGenericResourceDir="\$share/Resource/" -sICCProfilesDir="\$share/iccprofiles/" "\$@"
EOF
chmod 755 "$dest/bin/gs"

mapfile -t packages < <(printf '%s\n' "${packages[@]}" | sort -u)
for pkg in "${packages[@]}"; do
  cp "/usr/share/doc/$pkg/copyright" "$dest/licenses/$pkg.copyright"
done
dpkg-query -W -f '${Package} ${Version}\n' "${packages[@]}" > "$dest/licenses/PACKAGES.txt"

echo "bundled ffmpeg, qpdf and gs $gs_version with $copied libraries from ${#packages[@]} Ubuntu packages:"
du -sh "$dest"/*
cat "$dest/licenses/PACKAGES.txt"
