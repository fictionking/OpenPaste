//
//  OpenPasteApp+CoreDataProperties.swift
//  OpenPaste
//
//  Created by fictionking on 2026-03-28.
//
//

import Foundation
import CoreData

extension ClipboardItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ClipboardItem> {
        return NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
    }

    @NSManaged public var allPasteboardData: Data?
    @NSManaged public var allPasteboardTypes: String?
    @NSManaged public var capturedAt: Date
    @NSManaged public var content: Data
    @NSManaged public var contentHash: String?
    @NSManaged public var contentType: String
    @NSManaged public var expiresAt: Date
    @NSManaged public var id: UUID
    @NSManaged public var isPinned: Bool
    @NSManaged public var sourceApp: String?
    @NSManaged public var title: String?
    @NSManaged public var ocrText: String?
    @NSManaged public var ocrLanguage: String?
    @NSManaged public var ocrRecognizedAt: Date?
    @NSManaged public var category: Category?
}

extension Category {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Category> {
        return NSFetchRequest<Category>(entityName: "Category")
    }

    @NSManaged public var icon: String?
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var sortOrder: Int32
    @NSManaged public var type: String
    @NSManaged public var items: NSSet?
}

// MARK: Generated accessors for Category
extension Category {

    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: ClipboardItem)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: ClipboardItem)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)
}
