# QRule

Read any QR code visible on your Mac's screen — in a browser, a PDF, a paused video, a remote desktop, anywhere.

**Press a shortcut. Draw a box around the QR code. Open, copy, or share the result.**

## How it works

1. Press **⇧⌘7** (configurable in Settings).
2. The screen freezes and dims, just like the native macOS screenshot tool.
3. Drag a rectangle around the QR code.
4. A small panel appears with the decoded contents and four actions: **Open, Copy, Share, Close**.

Everything runs locally: decoding uses Apple's Vision framework, the app is sandboxed, has no network access, and never saves or transmits the screenshot. QRule lives in the menu bar, uses zero CPU while idle, and has no history, no accounts, and no settings sprawl.

## Requirements

- macOS 14 (Sonoma) or later
- To build: Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Install

```sh
git clone <this repo>
cd QRule
./build.sh --install
```

This generates the Xcode project, builds the Release configuration, packages `QRule.app`, installs it to `/Applications`, and launches it. (Run plain `./build.sh` to just produce `dist/QRule.app`.)

On first scan, macOS will ask for **Screen Recording** permission — enable QRule in System Settings, then quit and reopen the app once. The app must be signed with a stable identity (see `CODE_SIGN_IDENTITY` in `project.yml`) for the permission to persist across rebuilds.

## Usage

- **⇧⌘7** — start a scan (change it via the menu bar icon → Settings…)
- **Esc** or click outside — cancel
- **Return** — open the decoded link, **⌘C** — copy it

## Project layout

- `project.yml` — XcodeGen spec (the `.xcodeproj` is generated, not committed)
- `QRule/` — Swift sources: capture (ScreenCaptureKit), selection overlay (AppKit), decoding (Vision), result panel (SwiftUI)
- `Localization/` — Ukrainian strings injected into the KeyboardShortcuts dependency at packaging time
- `build.sh` — build, package, and optionally install
