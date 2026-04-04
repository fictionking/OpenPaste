# OpenPaste

<div align="center">
  <img src="openpaste_app.png" alt="OpenPaste Application Screenshot" width="600">
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

Download the latest `OpenPaste.dmg` from the repository and open it to install.

1. Download [OpenPaste.dmg](./OpenPaste.dmg)
2. Open the downloaded DMG file
3. Drag OpenPaste to Applications folder

### From Source

```bash
git clone https://github.com/fictionking/openpaste.git
cd openpaste
xcodebuild -project OpenPaste.xcodeproj -scheme OpenPaste
open build/Release/OpenPaste.app
```

### Homebrew (Coming Soon)

```bash
brew install --cask openpaste
```

## Features

- **Clipboard History**: Automatically captures all copy/paste operations
- **Quick Access**: Global hotkey (⌘⇧V) to show floating panel
- **Smart Organization**: Auto-categorization by source app
- **Pinning**: Pin important items to prevent expiry
- **Search**: Multi-dimensional search by content, type, date, and source
- **Privacy**: All data stored locally, no cloud sync

### Text Explosion (New in v1.1)

- **Intelligent Tokenization**: Automatically detects and extracts entities from clipboard text using Apple's Natural Language framework
- **Multilingual Support**: Works with Chinese, English, Japanese, Korean, Russian, Arabic, and more
- **Entity Types**: Personal names, organizations, places, phone numbers, URLs, currency, dates, addresses, flight numbers, tracking numbers
- **Quick Insert**: Click any token to instantly insert it into the active application
- **Visual Filtering**: Filter by entity type with colorful icon-based chips
- **Customizable Hotkey**: Set your preferred hotkey for text explosion in Settings

## Keyboard Shortcuts

- ⌘⇧V - Show/hide clipboard history
- ⌘⇧B - Show text explosion panel (default, customizable in Settings)

## License

This project is licensed under the MIT License - see the [MIT-LICENSE](MIT-LICENSE) file for details.
