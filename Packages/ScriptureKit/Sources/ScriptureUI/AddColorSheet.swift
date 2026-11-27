import ScriptureModel
import SwiftUI

/// Name plus light and dark variants for a new highlight color. The dark picker follows the
/// light one until it is touched.
public struct AddColorSheet: View {
    /// A new color starts from the first default, so it begins at the marks' shared lightness.
    private static let start = MarkupContainer.defaultColors[0]

    @Environment(\.self) private var environment
    @State private var name = ""
    @State private var light = Self.color(start.lightHex)
    @State private var dark = Self.color(start.darkHex)
    /// SwiftUI delivers our own `dark = light` assignment as a later `onChange`, so the
    /// "touched" decision lives in a tested helper that compares values instead of using a flag.
    @State private var sync = ColorPairSync(light: start.lightHex, dark: start.darkHex)

    let onAdd: (_ name: String, _ lightHex: String, _ darkHex: String) -> Void
    let onCancel: () -> Void

    public init(onAdd: @escaping (_ name: String, _ lightHex: String, _ darkHex: String) -> Void, onCancel: @escaping () -> Void) {
        self.onAdd = onAdd
        self.onCancel = onCancel
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var conformedLight: String { MarkLightness.conformed(hex: hex(light), dark: false) }
    private var conformedDark: String { MarkLightness.conformed(hex: hex(dark), dark: true) }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("New Highlight Color")
                .font(.headline)
            Form {
                TextField("Name", text: $name)
                ColorPicker("Light", selection: $light, supportsOpacity: false)
                ColorPicker("Dark", selection: $dark, supportsOpacity: false)
                // What will be stored: each pick held to the marks' lightness band.
                HStack(spacing: AppSpacing.xs) {
                    HStack(spacing: AppSpacing.xxs) {
                        MarkerGlyph(color: MarkupColor(lightHex: conformedLight, darkHex: conformedLight))
                        MarkerGlyph(color: MarkupColor(lightHex: conformedDark, darkHex: conformedDark))
                    }
                    .help("Light and dark, as they will be saved")
                    .accessibilityHidden(true)
                    Text("Kept light enough for the text to stay readable.")
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    onAdd(trimmedName, conformedLight, conformedDark)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedName.isEmpty)
            }
        }
        .padding(AppSpacing.lg)
        .frame(width: 340)
        .onChange(of: light) { _, newValue in
            sync.setLight(hex(newValue))
            if !sync.darkTouched { dark = newValue }
        }
        .onChange(of: dark) { _, newValue in
            sync.setDark(hex(newValue))
        }
    }

    private static func color(_ hex: String) -> Color {
        let c = ColorHex.components(hex) ?? (red: 1, green: 1, blue: 1)
        return Color(.sRGB, red: c.red, green: c.green, blue: c.blue)
    }

    private func hex(_ color: Color) -> String {
        let resolved = color.resolve(in: environment)
        return ColorHex.string(red: Double(resolved.red), green: Double(resolved.green), blue: Double(resolved.blue))
    }
}
