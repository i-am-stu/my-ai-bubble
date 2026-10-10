# My AI Bubble

A small floating launcher for the AI apps on your Mac. Add your apps, move the bubble wherever it suits you, and click an app bubble to bring its window forward.

[**Download for Mac**](https://github.com/stu-collett/my-ai-bubble/releases/latest/download/My-AI-Bubble.zip) · [All releases](https://github.com/stu-collett/my-ai-bubble/releases) · [Report an issue](https://github.com/stu-collett/my-ai-bubble/issues)

![My AI Bubble preview](docs/preview.png)

## Install

Requires **macOS 13 Ventura or later**. The download includes both **Apple silicon and Intel** builds. No developer tools are needed to use it.

1. Download **My-AI-Bubble.zip** and double-click it to unzip.
2. Drag **My AI Bubble** into **Applications**.
3. Open it, then right-click the centre bubble to add your apps.

**First-open warning:** this early release is locally signed, but is **not Developer ID signed or notarised by Apple**. macOS may block it. If you trust the download, try opening it, then use **System Settings → Privacy & Security → Open Anyway** and confirm. Some managed Macs do not permit this. [Apple’s guidance](https://support.apple.com/102445). There is no need to disable Gatekeeper or run a security-bypass command.

## Use

- **Drag the centre bubble** to move the group.
- **Click the centre bubble** to fold or unfold the app bubbles.
- **Click an app bubble** to launch the app or bring it forward.
- **Right-click the centre bubble** to add or remove apps, bring the bubble into view, or quit.

The menu-bar icon provides the same controls. App choices and position are remembered. You can add up to ten installed apps. Common AI apps are picked up automatically from Applications on first launch; any other installed app can be added through the menu.

To launch at login, add My AI Bubble in **System Settings → General → Login Items**.

## What it does

A native Mac launcher with an animated glass bubble, circular app icons and sequential open/close animations. It floats above normal windows and follows you between desktops. Animations respect the macOS Reduce Motion setting.

It does not read chats, monitor notifications, send data, or require Accessibility permission. There are no accounts, analytics or background network services. Your existing AI apps run independently and keep their own subscriptions and settings.

## Build from source

Install Apple’s Xcode Command Line Tools, then run:

```sh
./scripts/build.sh
```

The universal app is created at `build/My AI Bubble.app`. No third-party packages are required. To run the focused behaviour checks and create release downloads:

```sh
./scripts/test.sh
./scripts/package.sh
```

The app uses Swift, AppKit and Core Image. This version was tested on an Apple silicon Mac; the Intel slice is cross-compiled and has not been tested on Intel hardware. First-open approval on a fresh Mac has not been independently tested.

## Distribution

Release downloads use local ad-hoc signing. For a smoother public install, a maintainer with an Apple Developer account should Developer ID sign the app, notarise it and staple Apple’s ticket before packaging. [Apple’s distribution guide](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

App logos are read from apps installed on the user’s Mac. The product names and logos in the preview belong to their respective owners. My AI Bubble is an independent launcher and is not affiliated with those services.

## Licence

No open-source licence has been selected yet. The source is published for inspection; release downloads are provided for use on your own Mac.
