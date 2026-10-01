#!/usr/bin/env bash
#
# Usage: build.sh SOURCE_DIR STAGE_DIR [CONFIGURE_ARGS...]
#
# Installs into STAGE_DIR/usr. CHANGELOG_REV fills ChangeLog's $Revision$,
# which SVN would have expanded, so a trunk build is numbered like an SVN one.

set -euo pipefail

SRC=$(cd "$1" && pwd)
mkdir -p "$2"
STAGE=$(cd "$2" && pwd)
shift 2

cd "$SRC"
if [ -n "${CHANGELOG_REV:-}" ]; then
  sed -i.orig "s/^\\\$Revision\\\$\$/\$Revision: $CHANGELOG_REV \$/" ChangeLog
fi
# Microchip's non-free PIC headers are not redistributed, and the simulators
# are left to distribution packages.
./configure --prefix=/usr --disable-non-free --disable-ucsim --disable-sdcdb "$@"
make -j"$(getconf _NPROCESSORS_ONLN)"
make install DESTDIR="$STAGE"

# sdbinutils also installs parts of GNU binutils that clash with the system's.
cd "$STAGE/usr"
find . -mindepth 1 -maxdepth 1 ! -name bin ! -name libexec ! -name share -exec rm -rf {} +
rm -rf bin/c++filt bin/c++filt.exe share/info share/locale
