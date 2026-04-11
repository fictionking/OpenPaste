# Changelog

## [1.4] - 2026-04-11

### Improved
- **Memory Optimization**: Further reduced memory usage through complete pagination implementation
- **Startup Performance**: App now loads instantly without fetching clipboard history on startup
- **Scroll Performance**: Data is loaded progressively as you scroll (50 items per batch)
- **Memory Efficiency**: Only visible items are kept in memory, releasing resources when panel is hidden

### Changed
- **Data Loading**: Implemented lazy loading with initial batch of 50 items, loading more on scroll
- **Startup Behavior**: Clipboard data is now loaded only when the floating panel is shown
- **Memory Architecture**: Complete migration to `ClipboardItemSummary` throughout the UI layer

---

## [1.3] - 2026-04-11

### Improved
- **Memory Optimization**: Reduced memory footprint by ~80% through lightweight summary data structure and lazy loading
- **Panel Lifecycle**: Clear clipboard data from memory when panel is hidden, reload on display
- **Performance**: Load only necessary data for list display, defer heavy pasteboard data until paste operation

### Changed
- **Data Architecture**: Introduced `ClipboardItemSummary` for efficient in-memory storage
- **Paste Loading**: Changed to UUID-based lazy loading for full clipboard data
- **Background Management**: Automatic memory cleanup when floating panel closes

---

## [1.2] - 2026-04-09

### Improved
- **Visual Enhancements**: Updated settings panel with dark glassmorphism background and white text with shadows for better readability
- **Search Panel**: Enhanced text visibility with white text and shadows
- **App Icon Colors**: Dynamic color extraction directly from app icons, removing hardcoded color values

### Fixed
- **Cloud/iCloud Sources**: Fixed transparent background issue by extracting real colors from iCloud app icon
- **Text Explosion Overlay**: Fixed permission UI overflow in floating panel with proper full-panel overlay
- **Button Click Areas**: Fixed button click responsiveness by adding proper content shape
- **Internationalization**: Added missing empty state localizations for all supported languages

### Changed
- **Glass Effect**: Added support for macOS 26.0+ glassEffect API in floating panel
- **Code Cleanup**: Removed legacy code from AppIconColorExtractor (predefinedColors, AppIconColorView)

---

## [1.1] - 2026-04-08

### Added
- **Text Explosion**: Extract and insert entities (names, dates, phone numbers, URLs, etc.) from clipboard text with multilingual support
- **OCR Recognition**: Extract text from images using Apple's Vision framework with 20+ language support
- **Internationalization**: Complete localization for 14 languages (English, Chinese, Japanese, Korean, and more)

---

## [1.0] - Initial Release

### Added
- Clipboard history management with global hotkey (⌘⇧V)
- Auto-categorization by source app, pinning, and multi-dimensional search
- Local-only data storage for privacy
