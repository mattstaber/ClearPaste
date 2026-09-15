# EasyPaste

**Plain text, on command.** A small native macOS menu bar utility.

| Shortcut | Behavior |
| --- | --- |
| **⌘C** | Copy normally, including formatting. |
| **⌘V** | Paste normally. |
| **⌥⌘V** | Paste the copied text without formatting. |

EasyPaste never automatically strips copied text. It temporarily supplies plain text for Option-Command-V, sends a normal paste keystroke to the frontmost app, then restores the original clipboard if you haven't copied something else.

## Build and run

Requires macOS 13 or later and Apple's Swift command line tools or Xcode. No third-party packages.

```sh
./scripts/build-app.sh
open dist/EasyPaste.app
```

Look for the clipboard icon in the menu bar. Open **Settings → Enable Accessibility…**, then allow EasyPaste in **System Settings → Privacy & Security → Accessibility**. This permission lets EasyPaste send the paste keystroke. Copy and normal paste work without that permission; the plain-text shortcut needs it.

For regular use, copy `dist/EasyPaste.app` to Applications before granting permission and enabling **Launch at login**. Rebuilding an ad hoc signed app can require reauthorizing Accessibility. Builds are locally signed, not notarized for public distribution.

## Features

- Global Option-Command-V shortcut, with registration errors shown in the menu.
- Temporary plain-text clipboard with restoration after paste.
- Common URL tracking removal (`utm_*` and common click identifiers).
- Optional invisible-space removal, straight quotes, footnote removal, and newline cleanup.
- Launch at login and native light/dark settings.
- No automatic copy transformation, clipboard history, analytics, or network requests.

## Behavior and limits

- The shortcut fires on key release and waits for modifiers to lift. It cancels if focus changes before pasting. A second plain-text paste is ignored while one is in progress.
- Clipboard restoration happens **800 ms after sending paste**. macOS provides no universal paste-completion callback. Apps that read the clipboard unusually late may see the restored formatting, and an ordinary paste within that short window sees the temporary plain text. A newer copy is never overwritten by restoration.
- Files, images, multiple-item copies, and known sensitive/transient clipboard markers are skipped by Option-Command-V; use normal paste for those. Unmarked secrets cannot be distinguished from ordinary text.
- Rich text must include a plain-text representation. Embedded hyperlink targets are removed while their visible text remains.
- Optional text transformations can change prose or code (such as `[a]`); all except tracking removal are off by default.
- Another app claiming Option-Command-V can prevent registration. Secure-input fields or apps that reject synthetic paste may not support the shortcut.
- Clipboard data stays in memory. Only preferences are stored on disk.

This is an independent implementation inspired by [Pure Paste](https://sindresorhus.com/pure-paste), with a shortcut-driven workflow. It is not affiliated with Pure Paste and does not reproduce every feature.

## Validation

```sh
./scripts/test.sh
```

The standalone runner works with command-line tools alone. The same cases are also available through `swift test --disable-sandbox` when XCTest is installed with Xcode.

The 12 checks cover text and URL transformations, keeping copied rich text intact, plain-text eligibility, clipboard restoration, protecting sensitive/image/file and multiple-item copies, and avoiding restoration over a newer copy. Tests use isolated named pasteboards, not your general clipboard.

The automated suite does not prove paste delivery into every macOS app. After granting Accessibility, copy bold text in a rich-text editor: check that ⌘V retains bold, ⌥⌘V uses plain text, and a subsequent ⌘V (after one second) retains bold again.
