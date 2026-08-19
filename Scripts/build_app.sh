#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Building release binary..."
swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)/Klack"

APP="Klack.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN_PATH" "$APP/Contents/MacOS/Klack"
cp Support/Info.plist "$APP/Contents/Info.plist"

if [ -d Resources/Sounds ]; then
    cp -R Resources/Sounds "$APP/Contents/Resources/Sounds"
fi
if [ -f SoundPack/LICENSE.txt ]; then
    cp SoundPack/LICENSE.txt "$APP/Contents/Resources/LICENSE.txt"
fi
if [ -f SoundPack/README-source.txt ]; then
    cp SoundPack/README-source.txt "$APP/Contents/Resources/README-source.txt"
fi

echo "Ad-hoc codesigning..."
codesign --force --sign - "$APP"
codesign --verify --verbose "$APP"

echo "Done: $APP"
echo "Move it to /Applications, then launch via Finder (not Terminal) for the first run."
