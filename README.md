# sdcc-build

[![Mirror](https://img.shields.io/github/actions/workflow/status/llvm-z80/sdcc-build/mirror.yml?branch=main&label=Mirror&style=flat-square)](https://github.com/llvm-z80/sdcc-build/actions/workflows/mirror.yml)
[![Build](https://img.shields.io/github/actions/workflow/status/llvm-z80/sdcc-build/build.yml?branch=main&label=Build&style=flat-square)](https://github.com/llvm-z80/sdcc-build/actions/workflows/build.yml)
[![Repository](https://img.shields.io/github/actions/workflow/status/llvm-z80/sdcc-build/repo.yml?branch=main&label=Repository&style=flat-square)](https://github.com/llvm-z80/sdcc-build/actions/workflows/repo.yml)
[![Release](https://img.shields.io/github/v/release/llvm-z80/sdcc?display_name=release&style=flat-square)](https://github.com/llvm-z80/sdcc/releases/latest)
[![License](https://img.shields.io/github/license/llvm-z80/sdcc-build?style=flat-square)](LICENSE)

Mirrors [SDCC](https://sdcc.sourceforge.net/) into
[llvm-z80/sdcc](https://github.com/llvm-z80/sdcc) and builds packages from it.
This repository deploys the latest SDCC packages for use in LLVM-Z80 build CI.

## Packages

The [releases of llvm-z80/sdcc](https://github.com/llvm-z80/sdcc/releases) hold:

- `sdcc-<version>-<platform>.tar.xz` or `.zip` for Linux (x86_64, aarch64),
  macOS (arm64) and Windows (x86_64). Unpack anywhere and put `bin/` on `PATH`.
- `.deb` for Debian and Ubuntu.
- `.rpm` for Fedora, RHEL 9 and later, and openSUSE.
- `sha256sums.txt`

## Package repositories

The latest release is also published as signed apt and dnf repositories.

Debian and Ubuntu:

```sh
cd /etc/apt/sources.list.d
sudo curl -fsSLo llvm-z80-sdcc.sources https://llvm-z80.github.io/sdcc-build/sdcc.sources
sudo apt update
sudo apt install sdcc
```

Fedora and RHEL:

```sh
cd /etc/yum.repos.d
sudo curl -fsSLo llvm-z80-sdcc.repo https://llvm-z80.github.io/sdcc-build/sdcc.repo
sudo dnf install sdcc
```

## License

SDCC is free software under the GPL. The build scripts in this repository are
released under [MIT-0](LICENSE).
