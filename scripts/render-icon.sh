#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
ICON_TOOL=${ICON_COMPOSER_TOOL:-"/Applications/Icon Composer.app/Contents/Executables/ictool"}
if [[ ! -x "$ICON_TOOL" ]]; then
    echo "Icon Composer 27 is required to regenerate previews. Set ICON_COMPOSER_TOOL to its ictool executable." >&2
    exit 1
fi
for rendition in Default Dark ClearLight ClearDark TintedLight TintedDark; do
    output="Assets/ClearPaste-${rendition}.png"
    "$ICON_TOOL" Assets/ClearPaste.icon --export-image --output-file "$output" --platform macOS --rendition "$rendition" --width 1024 --height 1024 --scale 1 --design-generation 27
done
