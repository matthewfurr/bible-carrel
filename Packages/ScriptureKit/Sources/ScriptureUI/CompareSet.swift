import Foundation
import ScriptureData
import SwiftUI

/// Which translations Compare Translations shows beside the one being read: one synced preference,
/// the ids joined by commas, so `@AppStorage` and the key-value store take it as a string. An ID this
/// build does not bundle stays in the string, so another device's choice survives a round trip.
public enum CompareSet {
    public static let key = "compareTranslationIDs"
    public static let defaultValue = "ESV,NASB,KJV,WEB"

    /// Trimmed, no blanks or repeats, in order. An empty string is an empty set.
    public static func ids(_ raw: String) -> [String] {
        var seen = Set<String>()
        return raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// `defaultValue` when the key is absent; a stored empty string is an empty set.
    public static func ids(from defaults: UserDefaults) -> [String] {
        ids(defaults.string(forKey: key) ?? defaultValue)
    }

    /// The set's ids that `translations` holds, in `translations`' order: the order of the panel's rows.
    public static func ordered(_ ids: [String], in translations: [ScriptureData.Translation]) -> [String] {
        translations.map(\.id).filter { ids.contains($0) }
    }

    /// What the Compare translations prompt run from the assistant's list sends: the set as the panel's
    /// rows order it, so the two ways in send the same translations, and the on-device three are the same
    /// three. With none of it bundled (every box off), the default four: a comparison with nothing in it
    /// says nothing to the reader.
    public static func promptIDs(_ ids: [String], in translations: [ScriptureData.Translation]) -> [String] {
        let chosen = ordered(ids, in: translations)
        return chosen.isEmpty ? ordered(self.ids(defaultValue), in: translations) : chosen
    }

    /// Removed if there, else added last; the rest stays as it was.
    public static func toggling(_ id: String, in raw: String) -> String {
        var current = ids(raw)
        if let index = current.firstIndex(of: id) {
            current.remove(at: index)
        } else {
            current.append(id)
        }
        return current.joined(separator: ",")
    }
}

/// One `Toggle` per translation, titled with its title, on `CompareSet.key` through `@AppStorage`.
/// A `Menu` draws each as a checkmark, a `Form` as a switch.
public struct CompareSetToggles: View {
    let translations: [ScriptureData.Translation]
    @AppStorage(CompareSet.key) private var raw = CompareSet.defaultValue

    public init(translations: [ScriptureData.Translation]) {
        self.translations = translations
    }

    public var body: some View {
        ForEach(translations) { translation in
            Toggle(translation.title, isOn: Binding(
                get: { CompareSet.ids(raw).contains(translation.id) },
                set: { isOn in
                    if isOn != CompareSet.ids(raw).contains(translation.id) {
                        raw = CompareSet.toggling(translation.id, in: raw)
                    }
                }))
        }
    }
}
