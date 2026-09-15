#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
ICONSET="$PWD/.build/ClearPaste.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Assets/ClearPaste-Default.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" Assets/ClearPaste-Default.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil --convert icns "$ICONSET" --output .build/ClearPaste.icns
