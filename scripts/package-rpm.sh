#!/usr/bin/env bash
#
# Usage: package-rpm.sh STAGE_DIR VERSION RELEASE OUT_DIR

set -euo pipefail

STAGE=$(cd "$1" && pwd)
VERSION=$2
RELEASE=$3
mkdir -p "$4"
OUT=$(cd "$4" && pwd)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# The package owns the sdcc directories and every file outside them, but not
# shared directories such as /usr/bin.
(cd "$STAGE" && find usr \( -type d -name 'sdcc*' -prune -print \) -o \( ! -type d -print \)) |
  sed 's|^|/|' > "$WORK/files.list"

cat > "$WORK/sdcc.spec" <<EOF
Name: sdcc
Version: $VERSION
Release: $RELEASE
Summary: Small Device C Compiler
License: GPL-2.0-or-later AND GPL-3.0-or-later
URL: https://sdcc.sourceforge.net/

# The tree is installed already, so rpmbuild only packages it.
%define debug_package %{nil}
%define __os_install_post %{nil}
%define _build_id_links none

%description
SDCC built from unmodified upstream source.

%install
cp -a $STAGE/usr %{buildroot}/

%files -f $WORK/files.list
EOF

rpmbuild -bb --define "_topdir $WORK/rpm" "$WORK/sdcc.spec"
cp "$WORK"/rpm/RPMS/*/*.rpm "$OUT/"
