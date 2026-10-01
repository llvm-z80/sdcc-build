#!/usr/bin/env bash
#
# Usage: make-repo.sh PACKAGE_DIR SITE_DIR BASE_URL
#
# Builds signed apt and dnf repositories from the .deb and .rpm files in
# PACKAGE_DIR. GPG_KEY_ID names the signing key, which must already be in the
# GPG keyring.

set -euo pipefail

PKGS=$(cd "$1" && pwd)
mkdir -p "$2"
SITE=$(cd "$2" && pwd)
BASE_URL=$3
: "${GPG_KEY_ID:?set GPG_KEY_ID}"

gpg --batch --yes --armor --export "$GPG_KEY_ID" > "$SITE/sdcc.asc"

# apt
mkdir -p "$SITE/apt/pool/main"
cp "$PKGS"/*.deb "$SITE/apt/pool/main/"
cd "$SITE/apt"
archs=()
for deb in pool/main/*.deb; do
  archs+=("$(dpkg-deb --field "$deb" Architecture)")
done
mapfile -t archs < <(printf '%s\n' "${archs[@]}" | sort -u)
for arch in "${archs[@]}"; do
  dir=dists/stable/main/binary-$arch
  mkdir -p "$dir"
  apt-ftparchive --arch "$arch" packages pool > "$dir/Packages"
  gzip -9kn "$dir/Packages"
done
apt-ftparchive \
  -o APT::FTPArchive::Release::Origin=llvm-z80 \
  -o APT::FTPArchive::Release::Label=SDCC \
  -o APT::FTPArchive::Release::Suite=stable \
  -o APT::FTPArchive::Release::Codename=stable \
  -o APT::FTPArchive::Release::Components=main \
  -o "APT::FTPArchive::Release::Architectures=${archs[*]}" \
  release dists/stable > "$SITE/Release.tmp"
mv "$SITE/Release.tmp" dists/stable/Release
gpg --batch --yes --local-user "$GPG_KEY_ID" --clearsign -o dists/stable/InRelease dists/stable/Release
gpg --batch --yes --local-user "$GPG_KEY_ID" -abs -o dists/stable/Release.gpg dists/stable/Release
# The key goes inside the .sources file, so one download sets apt up.
{
  printf 'Types: deb\nURIs: %s/apt\nSuites: stable\nComponents: main\nSigned-By:\n' "$BASE_URL"
  sed 's/^$/./; s/^/ /' "$SITE/sdcc.asc"
} > "$SITE/sdcc.sources"

# dnf
for rpm in "$PKGS"/*.rpm; do
  arch=$(rpm -qp --queryformat '%{ARCH}' "$rpm")
  mkdir -p "$SITE/rpm/$arch"
  cp "$rpm" "$SITE/rpm/$arch/"
done
for dir in "$SITE"/rpm/*/; do
  rpmsign --define "_gpg_name $GPG_KEY_ID" --addsign "$dir"*.rpm
  createrepo_c -q "$dir"
done
cat > "$SITE/sdcc.repo" <<EOF
[llvm-z80-sdcc]
name=SDCC (llvm-z80)
baseurl=$BASE_URL/rpm/\$basearch
enabled=1
gpgcheck=1
gpgkey=$BASE_URL/sdcc.asc
EOF
