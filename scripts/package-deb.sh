#!/usr/bin/env bash
#
# Usage: package-deb.sh STAGE_DIR DEB_VERSION OUT_DIR
#
# DEB_MAINTAINER fills the Maintainer field.

set -euo pipefail

STAGE=$(cd "$1" && pwd)
VERSION=$2
mkdir -p "$3"
OUT=$(cd "$3" && pwd)
: "${DEB_MAINTAINER:?set DEB_MAINTAINER}"
ARCH=$(dpkg --print-architecture)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
mkdir -p deb/DEBIAN
cp -a "$STAGE/usr" deb/usr

# dpkg-shlibdeps insists on a debian/control.
mkdir debian
printf 'Source: sdcc\n\nPackage: sdcc\nArchitecture: any\n' > debian/control
elfs=()
while IFS= read -r -d '' f; do
  if file -b "$f" | grep -q '^ELF'; then
    elfs+=("$f")
  fi
done < <(find deb/usr -type f -print0)
depends=$(dpkg-shlibdeps -O "${elfs[@]}" | sed -n 's/^shlibs:Depends=//p')

cat > deb/DEBIAN/control <<EOF
Package: sdcc
Version: $VERSION
Architecture: $ARCH
Maintainer: $DEB_MAINTAINER
Installed-Size: $(du -sk deb/usr | cut -f1)
Depends: $depends
Conflicts: sdcc-libraries
Replaces: sdcc-libraries
Section: devel
Priority: optional
Homepage: https://sdcc.sourceforge.net/
Description: Small Device C Compiler
 SDCC built from unmodified upstream source.
EOF
dpkg-deb --root-owner-group --build deb "$OUT/sdcc_${VERSION}_$ARCH.deb"
