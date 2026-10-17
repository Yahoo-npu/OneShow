#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
APP="dist/一休·OneShow.app"
SDK="${ONESHOW_SDK_PATH:-$(xcrun --sdk macosx --show-sdk-path)}"
ARCH="${ONESHOW_ARCH:-$(uname -m)}"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" .build/module-cache
cp Config/Info.plist "$APP/Contents/Info.plist"
cp Resources/*.js Resources/*LICENSE.md Resources/*.icns "$APP/Contents/Resources/"
sources=(Sources/**/*.swift)
xcrun swiftc -sdk "$SDK" -module-cache-path "$PWD/.build/module-cache" "${sources[@]}" -parse-as-library -swift-version 5 -target "$ARCH-apple-macosx14.0" -O -framework SwiftUI -framework WebKit -framework JavaScriptCore -o "$APP/Contents/MacOS/OneShow"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "Built: $APP ($ARCH)"
