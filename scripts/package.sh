#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
zsh scripts/build.sh
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Config/Info.plist)
ARCH="${ONESHOW_ARCH:-$(uname -m)}"
mkdir -p dist/release
STAGE="$(mktemp -d "$PWD/.build/release.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
cp -R "dist/一休·OneShow.app" "$STAGE/一休·OneShow.app"
cp README.md "$STAGE/使用说明.md"
cp -R docs "$STAGE/docs"
ditto -c -k --sequesterRsrc "$STAGE" "dist/release/OneShow-$VERSION-$ARCH.zip"
echo "Release: dist/release/OneShow-$VERSION-$ARCH.zip"
