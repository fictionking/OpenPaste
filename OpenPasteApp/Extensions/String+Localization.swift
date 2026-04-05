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
    NSLocalizedString(self, bundle: .main, comment: "")
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
    static let search = "common.search".localized
    static let settings = "common.settings".localized
    static let recent = "common.recent".localized
    static let text = "common.text".localized
    static let image = "common.image".localized
    static let file = "common.file".localized
    static let link = "common.link".localized
    static let email = "common.email".localized
    static let phone = "common.phone".localized
    static let color = "common.color".localized
    static let code = "common.code".localized
    static let all = "common.all".localized
    static let folder = "common.folder".localized
    static let clipboardContent = "common.clipboard_content".localized
  }

  // MARK: - Text Explosion
  enum TextExplosion {
    static let analyzing = "text_explosion.analyzing".localized
    static let processing = "text_explosion.processing".localized
    static let emptyHint = "text_explosion.empty_hint".localized
    static let noText = "text_explosion.no_text".localized
    static let needPermission = "text_explosion.need_permission".localized
    static let openSettings = "text_explosion.open_settings".localized
    static let restartAfterAuth = "text_explosion.restart_after_auth".localized
  }

  // MARK: - Search
  enum Search {
    static let placeholder = "search.placeholder".localized
    static let emptyTitle = "search.empty_title".localized
    static let emptyMessage = "search.empty_message".localized
    static let noResults = "search.no_results".localized
    static let tryDifferent = "search.try_different".localized
  }

  // MARK: - Category
  enum Category {
    static let recent = "category.recent".localized
    static let text = "category.text".localized
    static let code = "category.code".localized
    static let image = "category.image".localized
    static let file = "category.file".localized
    static let link = "category.link".localized
    static let email = "category.email".localized
    static let phone = "category.phone".localized
    static let color = "category.color".localized
    static let custom = "category.custom".localized
    static let addTo = "category.add_to".localized
    static let removeFrom = "category.remove_from".localized
    static let none = "category.none".localized
    static let favorite1 = "category.favorite_1".localized
    static let favorite2 = "category.favorite_2".localized
    static let favorite3 = "category.favorite_3".localized
    static let favorite4 = "category.favorite_4".localized
  }

  // MARK: - Content Type
  enum ContentType {
    static let text = "content_type.text".localized
    static let image = "content_type.image".localized
    static let folder = "content_type.folder".localized
    static let file = "content_type.file".localized
    static let link = "content_type.link".localized
    static let email = "content_type.email".localized
    static let phone = "content_type.phone".localized
    static let color = "content_type.color".localized
    static let richText = "content_type.rich_text".localized
    static let content = "content_type.content".localized
  }

  // MARK: - OCR
  enum OCR {
    static let processing = "ocr.processing".localized
    static let failed = "ocr.failed".localized
    static let noTextFound = "ocr.no_text_found".localized
    static let unsupportedFormat = "ocr.unsupported_format".localized
    static let initFailed = "ocr.init_failed".localized
  }

  // MARK: - Status Bar
  enum StatusBar {
    static let openHistory = "status_bar.open_history".localized
    static let quit = "status_bar.quit".localized
  }

  // MARK: - Error
  enum Error {
    static let needAccessibilityPermission = "error.need_accessibility_permission".localized
    static let insertFailed = "error.insert_failed".localized
    static let noClipboardContent = "error.no_clipboard_content".localized
  }

  // MARK: - Help
  enum Help {
    static let clickToCopy = "help.click_to_copy".localized
  }
}
