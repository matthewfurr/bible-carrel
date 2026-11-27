#if os(macOS)
import AppKit
import ScriptureData

extension ReaderKeyStroke {
    /// The bare key an event is, or nil when ⌘, ⌥ or ⌃ is held. Escape and the left and right
    /// arrows by key code, Shift as held; otherwise the first character ignoring modifiers, a
    /// letter lower-cased with Shift as held, anything else with `shift` false (so ⇧/ is "?",
    /// and Caps Lock and the keypad change nothing).
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.isDisjoint(with: [.command, .option, .control]) else { return nil }
        let shift = flags.contains(.shift)
        switch event.keyCode {
        case 53: self.init(.escape, shift: shift)
        case 123: self.init(.leftArrow, shift: shift)
        case 124: self.init(.rightArrow, shift: shift)
        default:
            guard let character = event.charactersIgnoringModifiers?.first else { return nil }
            if character.isLetter, let lower = character.lowercased().first {
                self.init(.character(lower), shift: shift)
            } else {
                self.init(.character(character))
            }
        }
    }
}

extension ReaderKeyAction {
    /// A colour, 0, N, B, C and R: they change the reader's markup or ask for a panel, so a held
    /// one acts once.
    var actsOnMarkup: Bool {
        switch self {
        case .color, .noColor, .note, .bookmark, .compareTranslations, .crossReferences: true
        default: false
        }
    }
}

extension ChapterTextController {
    /// One reader key. J and K step to the next or previous verse, ⇧J and ⇧K move the selection's
    /// free end, each scrolling the verse that moved into view; Esc collapses a selection; the rest go to
    /// `onReaderKey`, the selection's actions with the selection they act on (none: nothing
    /// happens). False leaves the key to `NSTextView`. While `keysAreLive` says no, every key is
    /// swallowed: it does nothing, and AppKit does not beep. So is every key while a verse panel's
    /// popover is up, Esc excepted, which closes it (`swallowsKeyForVersePanel`).
    func perform(_ action: ReaderKeyAction) -> Bool {
        guard keysAreLive() else { return true }
        if swallowsKeyForVersePanel(action) { return true }
        switch action {
        case .nextVerse, .previousVerse:
            guard let layout else { return false }
            let step: VerseStep = action == .nextVerse ? .next : .previous
            if let range = ReaderTextLogic.verseStep(step, from: keySelection(), firstVisible: lastReportedPosition, in: layout) {
                selectVerses(range, anchor: range.location)
                keyRange = range
                reveal(range)
            }
            return true
        case .extendDown, .extendUp:
            guard let layout else { return false }
            let step: VerseStep = action == .extendDown ? .next : .previous
            if let extended = ReaderTextLogic.verseExtension(step, of: keySelection(), anchor: verseAnchor,
                                                              firstVisible: lastReportedPosition, in: layout) {
                selectVerses(extended.range, anchor: extended.anchor)
                keyRange = extended.range
                reveal(Self.freeEnd(of: extended.range, anchor: extended.anchor, in: layout))
            }
            return true
        case .clearSelection:
            guard textView.selectedRange().length > 0 else { return false }
            collapseSelection()
            return true
        case .color, .noColor, .note, .bookmark, .compareTranslations, .crossReferences:
            guard let report = reportForAction() else { return true }
            return onReaderKey(action, report)
        case .previousChapter, .nextChapter, .showShortcuts:
            return onReaderKey(action, nil)
        }
    }

    /// The verse ⇧J or ⇧K just moved: the text range of the verse at the end of `range` away from
    /// the anchor's verse (the one added, or the one now at the end after a verse was dropped).
    /// One verse selected: that verse.
    static func freeEnd(of range: NSRange, anchor: Int, in layout: BookLayout) -> NSRange {
        let touched = ReaderTextLogic.verses(touching: range, in: layout)
        guard let first = touched.first, let last = touched.last else { return range }
        return NSLocationInRange(anchor, first.fullRange) ? last.textRange : first.textRange
    }

    /// The selection J, K, ⇧J and ⇧K start from: nil when it is a caret outside every verse, or
    /// when none of it is on the visible page under the head (the reader scrolled away from it).
    /// The range the keys themselves last selected always counts, until a scroll that is not
    /// theirs: a held key steps on while its reveal is still scrolling, the clip not there yet.
    private func keySelection() -> NSRange? {
        let range = textView.selectedRange()
        guard let layout, range.location != NSNotFound else { return nil }
        if let keyRange, range == keyRange { return range }
        if range.length == 0, ReaderTextLogic.verses(touching: range, in: layout).isEmpty { return nil }
        let page = visiblePage
        let inset = textView.textContainerInset
        let rects = range.length > 0
            ? segmentFrames(of: range)
            : [lineFrame(forCharacterIndex: range.location, ensuringLayout: contentHeight <= 0)?.offsetBy(dx: inset.width, dy: inset.height)].compactMap { $0 }
        return rects.contains { $0.intersects(page) } ? range : nil
    }

    /// The visible rect under the running head's line, in the text view's coordinates.
    var visiblePage: NSRect {
        let visible = scrollView.documentVisibleRect
        return NSRect(x: visible.minX, y: visible.minY + headLineY, width: visible.width, height: max(0, visible.height - headLineY))
    }

    /// Scrolls the least that shows `range` wholly between the head's line and the visible
    /// bottom: its top `outlineMargin + scrollLeadIn` under the head's line when it is above it
    /// or taller than the page, else its bottom `outlineMargin` above the visible bottom.
    /// Animated, or a cut under Reduce Motion. Measured from where the page is going: the end of
    /// the keys' reveal still in flight, else the clip.
    private func reveal(_ range: NSRange) {
        guard !isTransientFrame else { return }
        let rects = segmentFrames(of: range)
        guard let top = rects.map(\.minY).min(), let bottom = rects.map(\.maxY).max() else { return }
        let clip = scrollView.contentView.bounds
        let landing = currentKeyScroll()?.to ?? clip.minY
        guard top < landing + headLineY || bottom > landing + clip.height else { return }
        let topY = top - Self.outlineMargin - Self.scrollLeadIn - headLineY
        let bottomY = bottom + Self.outlineMargin - clip.height
        // Taller than the page (the bottom's place would take the top under the head): the top's place.
        let y = clampedScrollY(top < landing + headLineY || topY < bottomY ? topY : bottomY)
        guard abs(y - landing) >= 0.5 else { return }
        // Before the scroll: the clip's moves from here to `y` are the keys' own, for as long as
        // the scroll can take; an animation cut short (a hand scroll) never arrives to end it.
        keyScroll = (clip.minY, y)
        keyScrollDeadline = Date().addingTimeInterval(Self.keyScrollLifetime)
        if reducesMotion() {
            scroll(toY: y)
            return
        }
        let origin = NSPoint(x: clip.minX, y: y)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.revealDuration
            context.allowsImplicitAnimation = true
            scrollView.contentView.animator().setBoundsOrigin(origin)
        }
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    /// The reveal's animation, and how long after it starts its band still filters clip moves.
    static let revealDuration: TimeInterval = 0.2
    static let keyScrollLifetime: TimeInterval = 0.3

    /// The clip moved: a move along the keys' reveal is theirs (and ends it on arrival); any
    /// other is the reader's or another jump's, after which the keys' range must be on screen
    /// again to count. True for a move along the keys' reveal.
    @discardableResult
    func noteClipMoved() -> Bool {
        let y = scrollView.contentView.bounds.minY
        if let scroll = currentKeyScroll(), y >= min(scroll.from, scroll.to) - 0.5, y <= max(scroll.from, scroll.to) + 0.5 {
            if abs(y - scroll.to) < 0.5 { keyScroll = nil }
            return true
        }
        keyScroll = nil
        keyRange = nil
        return false
    }

    /// The keys' reveal while its time lasts; nil (and forgotten) once it is up.
    func currentKeyScroll() -> (from: CGFloat, to: CGFloat)? {
        if keyScroll != nil, let deadline = keyScrollDeadline, Date() >= deadline { keyScroll = nil }
        return keyScroll
    }

    // MARK: - Focus

    /// Asks for the reader's text to take keyboard focus, settled on the next turn of the main
    /// queue (or once the text view has a window). One request waits at a time: a finished note
    /// or a closed palette is not replaced by a chapter opening or the shortcuts closing. The
    /// field being typed in when it is made is remembered, as the field the request leaves: for
    /// a text field, the field the window's shared field editor is editing, not the editor.
    func requestFocus(_ reason: ReaderFocusRule.Reason) {
        let keepsWaiting = (waitingFocus == .noteEditFinished || waitingFocus == .paletteClosed)
            && (reason == .chapterOpened || reason == .shortcutsClosed || reason == .versePanelClosed)
        if !keepsWaiting {
            waitingFocus = reason
            let responder = textView.window?.firstResponder
            focusFieldBeingLeft = responder !== textView && Self.isTyping(responder) ? responder : nil
            focusFieldBeingLeftOwner = Self.editedField(of: focusFieldBeingLeft)
        }
        guard textView.window != nil else { return }
        DispatchQueue.main.async { [weak self] in self?.resolveFocus() }
    }

    /// Settles a waiting request now: the reader takes focus when `ReaderFocusRule.takes` says so
    /// for whatever holds it.
    func resolveFocus() {
        guard let reason = waitingFocus, let window = textView.window else { return }
        let fieldBeingLeft = focusFieldBeingLeft
        let ownerBeingLeft = focusFieldBeingLeftOwner
        waitingFocus = nil
        focusFieldBeingLeft = nil
        focusFieldBeingLeftOwner = nil
        let responder = window.firstResponder
        let holder: ReaderFocusRule.Holder
        if responder === textView {
            holder = .reader
        } else if let fieldBeingLeft, responder === fieldBeingLeft, Self.editedField(of: responder) === ownerBeingLeft {
            // Every NSTextField in a window edits through one shared field editor, so the same
            // responder is not enough: the editor must still be editing the same field. Another
            // field that took focus meanwhile (the assistant's composer) is typing, and keeps it.
            holder = .fieldBeingLeft
        } else if Self.isTyping(responder) {
            holder = .typing
        } else {
            holder = .other
        }
        if ReaderFocusRule.takes(for: reason, from: holder) { window.makeFirstResponder(textView) }
    }

    /// The view's request (`ChapterTextView.focusRequest`), taken when it differs from the last one.
    func apply(_ request: ReaderFocusRequest?) {
        guard let request, request != appliedFocusRequest else { return }
        appliedFocusRequest = request
        requestFocus(request.reason)
    }

    /// A field being typed in: a text view, or a text field's editor, that is editable.
    private static func isTyping(_ responder: NSResponder?) -> Bool {
        (responder as? NSText)?.isEditable == true
    }

    /// For a field editor, the text field it is editing (its delegate); nil for anything else.
    private static func editedField(of responder: NSResponder?) -> AnyObject? {
        guard let editor = responder as? NSTextView, editor.isFieldEditor else { return nil }
        return editor.delegate
    }
}
#endif
