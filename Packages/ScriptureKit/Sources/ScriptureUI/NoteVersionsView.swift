import ScriptureData
import ScriptureModel
import SwiftUI

/// Both (or all) versions of a note, or a kept version whose note is gone, with the choices that
/// settle them (spec 4.1, 4.2; the mockup `note-kept-versions.html`): the title and a sentence that
/// nothing was lost, then each version under a hairline rule, its name and time, its text, and
/// under a kept one its choices. No cards: the versions are told apart by their names and rules.
///
/// It reads its subject from the model on every draw, so a choice made anywhere, an undo or a
/// sync shows at once, and calls `onSettled` once nothing is left to settle.
public struct NoteVersionsView: View {
    /// One version as the view shows it: this version (no `keptID`, no choices) or a kept one.
    struct Block: Equatable, Identifiable {
        let id: UUID
        let keptID: UUID?
        let name, time, spoken, body: String
        let choices: [VersionChoice]
        let prominent: VersionChoice?
    }

    let subject: VersionsSubject
    let model: NoteVersionsModel
    let undoManager: UndoManager?
    let onSettled: () -> Void

    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    public init(subject: VersionsSubject, model: NoteVersionsModel, undoManager: UndoManager?, onSettled: @escaping () -> Void = {}) {
        self.subject = subject
        self.model = model
        self.undoManager = undoManager
        self.onSettled = onSettled
    }

    public var body: some View {
        let content = read(now: Date())
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if let content {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(content.title)
                        .font(.headline)
                        .foregroundStyle(Color.inkPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text(content.subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                ForEach(content.blocks) { block in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Color.inkRule
                            .frame(height: 1)
                            .accessibilityHidden(true)
                        VersionBlock(block: block, book: content.book) { choice in
                            guard let keptID = block.keptID else { return }
                            model.perform(choice, on: keptID, undoManager: undoManager)
                        }
                        .equatable()
                    }
                }
            }
        }
        .onChange(of: content == nil, initial: true) { _, settled in
            if settled { onSettled() }
        }
    }

    private struct Content: Equatable {
        let title, subtitle: String
        let book: Book?
        let blocks: [Block]
    }

    private func read(now: Date) -> Content? {
        switch subject {
        case .note(let id):
            guard let versions = model.versions(forNote: id) else { return nil }
            return Content(
                title: VersionText.title(count: 1 + versions.kept.count), subtitle: VersionText.subtitle,
                book: BookCatalog.book(code: versions.book),
                blocks: Self.blocks(for: versions, now: now, calendar: calendar, locale: locale))
        case .orphan(let id):
            guard let version = model.orphan(id: id) else { return nil }
            return Content(
                title: VersionText.orphanTitle, subtitle: VersionText.orphanSubtitle,
                book: BookCatalog.book(code: version.book),
                blocks: Self.blocks(forOrphan: version, now: now, calendar: calendar, locale: locale))
        }
    }

    /// This version, then the kept ones, newest first.
    nonisolated static func blocks(for versions: NoteVersions, now: Date, calendar: Calendar, locale: Locale) -> [Block] {
        let current = versions.current
        let this = Block(
            id: versions.noteID, keptID: nil,
            name: VersionText.name(kept: false, deviceKind: current.deviceKind),
            time: VersionText.time(current.modifiedAt, now: now, calendar: calendar, locale: locale),
            spoken: VersionText.spoken(kept: false, deviceKind: current.deviceKind, at: current.modifiedAt, now: now, calendar: calendar, locale: locale),
            body: current.body, choices: [], prominent: nil)
        let kept = versions.kept.sorted { ($0.writtenAt, $0.uuid.uuidString) > ($1.writtenAt, $1.uuid.uuidString) }
        let prominent = VersionChoice.prominent(hasNote: true, keptCount: kept.count)
        return [this] + kept.map { block(for: $0, hasNote: true, prominent: prominent, now: now, calendar: calendar, locale: locale) }
    }

    /// One block: Restore as a Note (prominent) and Discard.
    nonisolated static func blocks(forOrphan version: KeptVersionSnapshot, now: Date, calendar: Calendar, locale: Locale) -> [Block] {
        [block(for: version, hasNote: false, prominent: VersionChoice.prominent(hasNote: false, keptCount: 1), now: now, calendar: calendar, locale: locale)]
    }

    private nonisolated static func block(for version: KeptVersionSnapshot, hasNote: Bool, prominent: VersionChoice?,
                                          now: Date, calendar: Calendar, locale: Locale) -> Block {
        Block(
            id: version.uuid, keptID: version.uuid,
            name: VersionText.name(kept: true, deviceKind: version.deviceKind),
            time: VersionText.time(version.writtenAt, now: now, calendar: calendar, locale: locale),
            spoken: VersionText.spoken(kept: true, deviceKind: version.deviceKind, at: version.writtenAt, now: now, calendar: calendar, locale: locale),
            body: version.body, choices: VersionChoice.offered(hasNote: hasNote), prominent: prominent)
    }
}

/// One version: its name with the time trailing (under it when they do not fit on one line), its
/// text rendered as a note's is but with no links (a popover over a popover), then its choices in
/// a row, or stacked when the row does not fit. VoiceOver reads it as one element: the name and
/// time, then the text, with one action per choice.
struct VersionBlock: View, Equatable {
    let block: NoteVersionsView.Block
    let book: Book?
    let onChoose: (VersionChoice) -> Void
    #if os(iOS)
    @ScaledMetric(relativeTo: .callout) private var labelHeight: CGFloat = 31
    #endif

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.block == rhs.block && lhs.book == rhs.book
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                    name
                    Spacer(minLength: AppSpacing.xs)
                    time
                }
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    name
                    time
                }
            }
            NoteBodyText(block.body, book: book, font: .callout)
                .environment(\.noteLinks, nil)
                .fixedSize(horizontal: false, vertical: true)
            if !block.choices.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.xs) { choices(rigid: true) }
                    // Stacked, a button wraps its words where the width is less than they need (at
                    // the accessibility sizes) rather than run past the edge.
                    VStack(alignment: .leading, spacing: AppSpacing.xs) { choices(rigid: false) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(block.spoken)
        .accessibilityValue(block.body)
        .accessibilityActions {
            ForEach(block.choices, id: \.self) { choice in
                Button(choice.title) { onChoose(choice) }
            }
        }
    }

    private var name: some View {
        Text(block.name)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.inkSecondary)
    }

    private var time: some View {
        Text(block.time)
            .font(.caption)
            .foregroundStyle(Color.inkSecondary)
    }

    @ViewBuilder
    private func choices(rigid: Bool) -> some View {
        ForEach(block.choices, id: \.self) { choice in
            choiceButton(choice, rigid: rigid)
        }
    }

    @ViewBuilder
    private func choiceButton(_ choice: VersionChoice, rigid: Bool) -> some View {
        #if os(iOS)
        // The regular control size, whose bordered button is about 34 pt tall: the label is as tall
        // as it needs to be for the button to be 44 pt, the thumb's hit area, and taller with the
        // text size, never shorter (the floor is the max with the scaled metric).
        let button = Button { onChoose(choice) } label: {
            Text(choice.title).frame(minHeight: max(31, labelHeight))
        }
        .help(choice.help)
        .fixedSize(horizontal: rigid, vertical: true)
        #else
        let button = Button(choice.title) { onChoose(choice) }
            .help(choice.help)
            .fixedSize(horizontal: rigid, vertical: true)
        #endif
        if choice == block.prominent {
            button.buttonStyle(.borderedProminent)
        } else {
            // On the Mac, plain ink as the mockup drew them, under a window that tints its controls
            // (Notes); on iOS `tint(nil)` is the app's accent.
            button.buttonStyle(.bordered).tint(nil)
        }
    }
}
