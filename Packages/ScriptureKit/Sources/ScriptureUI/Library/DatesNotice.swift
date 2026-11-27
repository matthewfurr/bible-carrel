import SwiftUI

/// The least height a text button in the notice or the footnote answers to: a finger's 44 pt on
/// the phone, the Mac's 24 pt (DESIGN.md's symbol buttons), scaled with the text (and the Library's type).
private struct DatesHitArea: ViewModifier {
    #if os(iOS)
    @ScaledMetric(relativeTo: .callout) private var height: CGFloat = 44
    #else
    @ScaledMetric(relativeTo: .callout) private var height: CGFloat = 24
    #endif
    @Environment(\.libraryType) private var type

    func body(content: Content) -> some View {
        content
            .frame(minHeight: type.metric(height))
            .contentShape(Rectangle())
    }
}

/// The notice at the head of a view that shows a date for the first time: a row on the overlay
/// paper, not an alert. Settings and OK both answer it, so it does not come back.
public struct DatesNotice: View {
    let onOpenSettings: () -> Void
    @Environment(\.libraryType) private var type

    public init(onOpenSettings: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(LibraryDates.notice)
                .font(type.font(.callout))
                .foregroundStyle(Color.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: AppSpacing.md) {
                Button {
                    LibraryDates.answer(.standard)
                    onOpenSettings()
                } label: {
                    Text("Settings").modifier(DatesHitArea())
                }
                Button { LibraryDates.answer(.standard) } label: {
                    Text("OK").modifier(DatesHitArea())
                }
            }
            .buttonStyle(.plain)
            .font(type.font(.callout, weight: .semibold))
            .foregroundStyle(Color.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(Color.paperOverlay, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

/// The one line under the dates once the notice has been answered.
public struct DatesFootnote: View {
    let onOpenSettings: () -> Void
    @Environment(\.libraryType) private var type

    public init(onOpenSettings: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        Button(action: onOpenSettings) {
            Text(LibraryDates.footnote)
                .font(type.font(.caption))
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.leading)
                .modifier(DatesHitArea())
        }
        .buttonStyle(.plain)
    }
}
