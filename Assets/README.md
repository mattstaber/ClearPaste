# ClearPaste icon

- **Editable source:** `ClearPaste.icon`, a native Icon Composer document.
- **Renderer:** Apple Icon Composer 27.0 (`ictool`, design generation 27).
- **Layers:** Clipboard body, clip, text lines, and sparkle, each an original SVG.
- **Material:** Blue/teal background gradient with separately lit glass foreground groups.
- **Previews:** `ClearPaste-{Default,Dark,ClearLight,ClearDark,TintedLight,TintedDark}.png`, rendered by Icon Composer.

Run `scripts/render-icon.sh` to regenerate the previews, or open the `.icon` document in Icon Composer. The document structure follows Apple's [Landmarks sample](https://developer.apple.com/documentation/swiftui/landmarks-building-an-app-with-liquid-glass); no sample artwork is used.

`build-app.sh` compiles the source with Xcode's asset compiler when available. Command-line-tools-only builds package the rendered ICNS fallback. The prior AI-generated icon has been replaced completely.
