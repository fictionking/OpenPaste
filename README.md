# OpenPaste

<div align="center">
  <img src="openpaste_app.png" alt="OpenPaste Application Screenshot" width="600">
</div>
<div align="center">
  <img src="openpaste_app_2.png" alt="OpenPaste Application Screenshot" width="600">
</div>

A modern macOS clipboard management application built with SwiftUI.

## Overview

OpenPaste is a clipboard companion for macOS that helps you manage your copy/paste history with ease. It features intelligent text explosion for multilingual content, making it easy to extract and insert specific entities like names, dates, phone numbers, and more.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9+

## Building

1. Open `OpenPaste.xcodeproj` in Xcode
2. Select the OpenPaste scheme
3. Press Cmd+R to build and run

Or build from command line:

```bash
xcodebuild -project OpenPaste.xcodeproj -scheme OpenPaste -configuration Debug
```

## Installation

### Direct Download (Recommended)

Download the latest `OpenPaste.dmg` from [GitHub Releases](https://github.com/fictionking/OpenPaste/releases/latest) and open it to install.

1. Download [OpenPaste.dmg](https://github.com/fictionking/OpenPaste/releases/latest)
2. Open the downloaded DMG file
3. Drag OpenPaste to Applications folder

### From Source

```bash
git clone https://github.com/fictionking/openpaste.git
cd openpaste
xcodebuild -project OpenPaste.xcodeproj -scheme OpenPaste
open build/Release/OpenPaste.app
```

## Features

- **Clipboard History**: Automatically captures all copy/paste operations
- **Quick Access**: Global hotkey (⌘⇧V) to show floating panel
- **Smart Organization**: Auto-categorization by source app
- **Pinning**: Pin important items to prevent expiry
- **Search**: Multi-dimensional search by content, type, date, and source
- **Privacy**: All data stored locally, no cloud sync
- **Text Explosion**: Extract and insert entities (names, dates, phone numbers, URLs, etc.) from clipboard text with multilingual support
- **OCR Recognition**: Extract text from images using Apple's Vision framework with 20+ language support
- **Internationalization**: Complete localization for 14 languages (English, Chinese, Japanese, Korean, and more)

## Keyboard Shortcuts

- ⌘⇧V - Show/hide clipboard history
- ⌘⇧B - Show text explosion panel 
(default, customizable in Settings)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

## License

This project is licensed under the MIT License - see the [MIT-LICENSE](MIT-LICENSE) file for details.
