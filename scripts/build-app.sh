#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
swift build -c release --disable-sandbox
BIN_DIR=$(swift build -c release --show-bin-path)
APP="$PWD/dist/ClearPaste.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
rm -f "$APP/Contents/Resources/Assets.car"
./scripts/build-icon.sh
cp .build/ClearPaste.icns "$APP/Contents/Resources/ClearPaste.icns"
cp "$BIN_DIR/ClearPaste" "$APP/Contents/MacOS/ClearPaste"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ClearPaste</string>
<key>CFBundleIdentifier</key><string>local.easypaste.app</string>
<key>CFBundleName</key><string>ClearPaste</string>
<key>CFBundleDisplayName</key><string>ClearPaste</string>
<key>CFBundleIconFile</key><string>ClearPaste</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>2.0.1</string>
<key>CFBundleVersion</key><string>6</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Xcode compiles the layered Icon Composer source into the adaptive Assets.car.
# Command-line-tools-only builds keep the Icon Composer-rendered ICNS fallback.
if xcrun --find actool >/dev/null 2>&1; then
    xcrun actool Assets/ClearPaste.icon --compile "$APP/Contents/Resources" \
        --platform macosx --minimum-deployment-target 26.0 --target-device mac \
        --app-icon ClearPaste --output-partial-info-plist "$PWD/.build/icon-info.plist"
    python3 - "$APP/Contents/Info.plist" "$PWD/.build/icon-info.plist" <<'PYTHON'
import plistlib, sys
with open(sys.argv[1], 'rb') as f: info = plistlib.load(f)
with open(sys.argv[2], 'rb') as f: info.update(plistlib.load(f))
with open(sys.argv[1], 'wb') as f: plistlib.dump(info, f)
PYTHON
else
    echo "Xcode actool unavailable: using Icon Composer-rendered ICNS fallback."
fi
codesign --force --deep --sign - "$APP"
echo "Built $APP"
