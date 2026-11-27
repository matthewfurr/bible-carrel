import Foundation

/// When the reader's text takes keyboard focus, so its single keys work without a click first:
/// when a chapter opens, a note's edit is finished, the palette or the shortcuts sheet closes, or a
/// verse panel's popover goes down;
/// never from a field being typed in, except the very field the request leaves (the note's
/// editor, the palette's field) for a finished note or a closed palette.
public enum ReaderFocusRule {
    public enum Reason: Sendable, CaseIterable { case chapterOpened, noteEditFinished, paletteClosed, shortcutsClosed, versePanelClosed }

    /// What holds keyboard focus in the reader's window when a request is settled.
    public enum Holder: Sendable, CaseIterable {
        case reader          // the reader's text already
        case fieldBeingLeft  // the field that had focus when the request was made (the note's editor, the palette's field)
        case typing          // any other field being typed in
        case other           // the window, a row, a button
    }

    public static func takes(for reason: Reason, from holder: Holder) -> Bool {
        switch holder {
        case .reader, .typing: false
        case .other: true
        case .fieldBeingLeft: reason == .noteEditFinished || reason == .paletteClosed
        }
    }
}

/// A request for the reader to take focus, made anew (a new `serial`) each time the reason occurs.
public struct ReaderFocusRequest: Equatable, Sendable {
    public let reason: ReaderFocusRule.Reason
    public let serial: Int

    public init(reason: ReaderFocusRule.Reason, serial: Int) {
        self.reason = reason
        self.serial = serial
    }
}
