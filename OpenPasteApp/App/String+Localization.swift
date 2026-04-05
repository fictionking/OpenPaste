//
//  String+Localization.swift
//  OpenPaste
//
//  Created by OpenPaste
//

import SwiftUI

extension String {
  /// Returns the localized version of this string
  var localized: String {
    // Use default localization - macOS will automatically pick the correct language
    NSLocalizedString(self, comment: "")
  }

  /// Returns the localized string with formatted arguments
  func localized(with arguments: CVarArg...) -> String {
    String(format: self.localized, arguments: arguments)
  }
}

// MARK: - Type-safe Localization Keys
/// Strongly typed localization keys to avoid runtime string errors
enum L10n {

  // MARK: - Common
  enum Common {
    static var search: String { "common.search".localized }
    static var settings: String { "common.settings".localized }
    static var recent: String { "common.recent".localized }
    static var text: String { "common.text".localized }
    static var image: String { "common.image".localized }
    static var file: String { "common.file".localized }
    static var link: String { "common.link".localized }
    static var email: String { "common.email".localized }
    static var phone: String { "common.phone".localized }
    static var color: String { "common.color".localized }
    static var code: String { "common.code".localized }
    static var all: String { "common.all".localized }
    static var folder: String { "common.folder".localized }
    static var clipboardContent: String { "common.clipboard_content".localized }
  }

  // MARK: - Text Explosion
  enum TextExplosion {
    static var analyzing: String { "text_explosion.analyzing".localized }
    static var processing: String { "text_explosion.processing".localized }
    static var emptyHint: String { "text_explosion.empty_hint".localized }
    static var noText: String { "text_explosion.no_text".localized }
    static var needPermission: String { "text_explosion.need_permission".localized }
    static var openSettings: String { "text_explosion.open_settings".localized }
    static var restartAfterAuth: String { "text_explosion.restart_after_auth".localized }
  }

  // MARK: - Search
  enum Search {
    static var placeholder: String { "search.placeholder".localized }
    static var emptyTitle: String { "search.empty_title".localized }
    static var emptyMessage: String { "search.empty_message".localized }
    static var noResults: String { "search.no_results".localized }
    static var tryDifferent: String { "search.try_different".localized }
    static var resultsCount: String { "search.results_count".localized }
  }

  // MARK: - Category
  enum Category {
    static var recent: String { "category.recent".localized }
    static var text: String { "category.text".localized }
    static var code: String { "category.code".localized }
    static var image: String { "category.image".localized }
    static var file: String { "category.file".localized }
    static var link: String { "category.link".localized }
    static var email: String { "category.email".localized }
    static var phone: String { "category.phone".localized }
    static var color: String { "category.color".localized }
    static var custom: String { "category.custom".localized }
    static var addTo: String { "category.add_to".localized }
    static var removeFrom: String { "category.remove_from".localized }
    static var none: String { "category.none".localized }
    static var favorite1: String { "category.favorite_1".localized }
    static var favorite2: String { "category.favorite_2".localized }
    static var favorite3: String { "category.favorite_3".localized }
    static var favorite4: String { "category.favorite_4".localized }
  }

  // MARK: - Content Type
  enum ContentType {
    static var text: String { "content_type.text".localized }
    static var image: String { "content_type.image".localized }
    static var folder: String { "content_type.folder".localized }
    static var file: String { "content_type.file".localized }
    static var link: String { "content_type.link".localized }
    static var email: String { "content_type.email".localized }
    static var phone: String { "content_type.phone".localized }
    static var color: String { "content_type.color".localized }
    static var richText: String { "content_type.rich_text".localized }
    static var content: String { "content_type.content".localized }
  }

  // MARK: - OCR
  enum OCR {
    static var processing: String { "ocr.processing".localized }
    static var failed: String { "ocr.failed".localized }
    static var noTextFound: String { "ocr.no_text_found".localized }
    static var unsupportedFormat: String { "ocr.unsupported_format".localized }
    static var initFailed: String { "ocr.init_failed".localized }
  }

  // MARK: - Status Bar
  enum StatusBar {
    static var openHistory: String { "status_bar.open_history".localized }
    static var quit: String { "status_bar.quit".localized }
  }

  // MARK: - Error
  enum Error {
    static var needAccessibilityPermission: String { "error.need_accessibility_permission".localized }
    static var insertFailed: String { "error.insert_failed".localized }
    static var noClipboardContent: String { "error.no_clipboard_content".localized }
  }

  // MARK: - Help
  enum Help {
    static var clickToCopy: String { "help.click_to_copy".localized }
  }

  // MARK: - Settings
  enum Settings {
    static var keyboard: String { "settings.keyboard".localized }
    static var clipboardHistory: String { "settings.clipboard_history".localized }
    static var textExplosion: String { "settings.text_explosion".localized }
    static var dataManagement: String { "settings.data_management".localized }
    static var retentionPeriod: String { "settings.retention_period".localized }
    static var retentionDays: String { "settings.retention_days".localized }
    static var retentionHint: String { "settings.retention_hint".localized }
    static var history: String { "settings.history".localized }
    static var maximumHistory: String { "settings.maximum_history".localized }
    static var maximumHistoryItems: String { "settings.maximum_history_items".localized }
    static var historyHint: String { "settings.history_hint".localized }
    static var about: String { "settings.about".localized }
    static var version: String { "settings.version".localized }
    static var viewLicense: String { "settings.view_license".localized }
    static var quitApp: String { "settings.quit_app".localized }
    static var settings: String { "settings.settings".localized }
    static var recordExplosionHotkey: String { "settings.record_explosion_hotkey".localized }
    static var recordClipboardHotkey: String { "settings.record_clipboard_hotkey".localized }
    static var pressKeyCombo: String { "settings.press_key_combo".localized }
    static var recording: String { "settings.recording".localized }
    static var cancel: String { "settings.cancel".localized }
    static var save: String { "settings.save".localized }
  }

  // MARK: - Slide Action
  enum SlideAction {
    static var slideToClearAll: String { "slide_action.slide_to_clear_all".localized }
    static var slideToClear: String { "slide_action.slide_to_clear".localized }
    static var slideToDelete: String { "slide_action.slide_to_delete".localized }
    static var slideToConfirm: String { "slide_action.slide_to_confirm".localized }
  }
}
