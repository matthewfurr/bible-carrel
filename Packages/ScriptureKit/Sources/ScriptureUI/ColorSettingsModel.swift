import Foundation
import Observation
import OSLog
import ScriptureModel

/// A highlight color as the settings list shows it.
public struct ColorRow: Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var lightHex: String
    public var darkHex: String
    public let isDefault: Bool
    public let highlightCount: Int

    public init(id: UUID, name: String, lightHex: String, darkHex: String, isDefault: Bool, highlightCount: Int) {
        self.id = id
        self.name = name
        self.lightHex = lightHex
        self.darkHex = darkHex
        self.isDefault = isDefault
        self.highlightCount = highlightCount
    }
}

/// The Settings pane's view of the highlight colors. Every mutation reloads the rows and tells
/// the reader (`onChange`) so open chapters recolor.
@MainActor @Observable
public final class ColorSettingsModel {
    public static let newColorName = "New Color"
    /// A new color starts as the band's gray, already at the marks' shared lightness.
    public static let newColorLightHex = MarkLightness.conformed(hex: "#D0D0D0", dark: false)
    public static let newColorDarkHex = MarkLightness.conformed(hex: "#505050", dark: true)

    public private(set) var rows: [ColorRow] = []
    /// A plain sentence for the reader when a change could not be saved; stays until `clearError()`.
    public private(set) var lastError: String?

    private let store: MarkupStore
    private let onChange: () -> Void
    private let logger = Logger(subsystem: "com.matthewfurr.ReadingThroughScripture", category: "settings")

    public init(store: MarkupStore, onChange: @escaping () -> Void) {
        self.store = store
        self.onChange = onChange
        reload()
    }

    public func reload() {
        attempt {
            rows = try store.colors().map { color in
                ColorRow(
                    id: color.uuid,
                    name: color.name,
                    lightHex: color.lightHex,
                    darkHex: color.darkHex,
                    isDefault: color.isDefault,
                    highlightCount: try store.highlightCount(usingColor: color.uuid))
            }
        }
    }

    public func add() {
        attempt { try store.addColor(name: Self.newColorName, lightHex: Self.newColorLightHex, darkHex: Self.newColorDarkHex) }
        changed()
    }

    public func rename(id: UUID, to name: String) {
        attempt {
            guard let color = try store.color(id: id) else { return }
            try store.renameColor(color, to: name)
        }
        changed()
    }

    public func setHex(id: UUID, lightHex: String, darkHex: String) {
        attempt {
            guard let color = try store.color(id: id) else { return }
            try store.setColorHex(color, lightHex: lightHex, darkHex: darkHex)
        }
        changed()
    }

    public func move(fromOffsets: IndexSet, toOffset: Int) {
        attempt { try store.moveColors(fromOffsets: fromOffsets, toOffset: toOffset) }
        changed()
    }

    /// Persists a complete order (after a drag that shifted rows live).
    public func reorder(to ids: [UUID]) {
        attempt { try store.setColorOrder(ids) }
        changed()
    }

    public func delete(id: UUID) {
        attempt {
            guard let color = try store.color(id: id) else { return }
            try store.deleteColor(color)
        }
        changed()
    }

    private func changed() {
        reload()
        onChange()
    }

    public func clearError() {
        lastError = nil
    }

    static let saveFailure = "The highlight colors could not be saved. Try it again. If it keeps failing, quit and reopen the app."

    private func attempt(_ work: () throws -> Void) {
        do {
            try work()
        } catch {
            lastError = Self.saveFailure
            logger.error("Color settings operation failed: \(error)")
        }
    }
}
