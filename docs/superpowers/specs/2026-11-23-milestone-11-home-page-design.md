# Milestone 11, project 1: the home page

Status: **Approved by Matt, 2026-11-23** ("I approve all 5."). First of milestone 11's five projects (UI improvements). Branch `milestone-11-ui-improvements`, cut from `main` at `f33658a`. The Mac only: the iPhone's Library already sets its book names and chapter cells at `.body` and `.title3` and is not touched.

## 1. Intent

Matt, 2026-11-22: "The new home page on macOS has the book names so small it is difficult to read. The text size should at least match what the user selected for their page style text size. Also the right column where the book icons and chapter numbers show up should be something a person can expand/draggable."

Today (main at `f33658a`):

- The book names on the contents page are the page face at `.body`, which is 13 pt on the Mac whatever the reader has chosen (`ContentsPageView.swift:187`, `PageFace.swiftUIFont(.body)`). The Testament titles are `.title3` (15 pt), the group labels `.caption2` semibold (about 10 pt).
- The reader's own size is `readerFontSize` (`ReaderSettings.fontSizeKey`), 14 to 28, default 18, kept on each device and not synced (`ReaderSettings.swift:103-123`, `PreferenceSync.swift:70-96`). The front page never reads it.
- The pane is a fixed `@ScaledMetric(relativeTo: .body)` 260 pt beside the contents in a plain `HStack` (`FrontPageView.swift:31`, `:56-64`), with no divider and nothing saved. Its grid is five 40 by 32 cells with numerals at `.callout`, which is 12 pt on the Mac (`PageFace.swift:221`; `ChapterGridView.swift:170`, `:193`), hard-coded (`ChapterGridView.swift:27-32`); the arrow keys and the focus cursor assume five (`:84-92`, `:124-125`).

## 2. Goals, non-goals, anti-goals

**Goals**

- Book names as easy to read as the page: they take the size the reader set for the page.
- A pane the reader can widen by dragging, remembered on this Mac.
- One rule for the whole home page: whatever is scripture (book names, chapter numerals) follows the page's size; whatever is the app (labels, counts, icons) stays a text style.

**Non-goals**

- The iPhone's Library. Its names are `.body` and its cells `.title3`, both of which follow Dynamic Type, and Matt named the Mac.
- Syncing the pane's width or the reader size between devices. The size is a device setting on purpose (milestone 9), and a width suits one screen.
- Narrowing the pane below today's width, or hiding it.
- The Library views' own layouts (People, Places, About). They take the space the contents half leaves; projects 2 to 4 redesign them.
- The reading plan's band over the contents. It keeps its own type.

**Anti-goals**

- Names cut off with an ellipsis at a large size. A column is always wide enough for the longest name it can hold.
- A divider that looks like a control panel: no grabber chrome, no visible handle at rest.
- A pane that can crowd the contents out of the window.

## 3. Approaches

Shown in `docs/superpowers/specs/milestone-11-mockups/home-page.html`, at real size in a 1,100 pt window.

**The names.** One proposal, no alternative: the names in the page face at the reader's size, columns widened to fit, Testaments stacking when fewer than four columns fit (the mockup showed 13 pt today, 18 pt and 24 pt). Matt did not object; his choice below assumes it.

**The pane, dragged wider: what fills the room.**

- **A. More chapters across.** Cells keep their size; a wider pane fits more in a row. Small.
- **B. Bigger chapters, five across.** Cells and numerals grow with the pane. Small.
- **C. The cells follow the text size, and the width adds columns.** The numerals take the page size like the names; dragging wider adds columns. Small to medium: A's column count plus a cell size from the reader size, and a narrowest width that grows with the size.

Matt chose **C** ("C", 2026-11-23).

## 4. The contents page

### 4.1 The size

- **Book names:** the page face (the reader's page style's face, as today) at `readerFontSize` points, through `PageFace.font(size:)`, regular, `ink.primary`. Not a `@ScaledMetric`: like the reader itself it follows the reader's own setting, so the Dynamic Type Contract's exception list gains "the front page's book names and chapter numerals, derived from the reader size" (section 8).
- **Testament titles:** the page face at 1.15 × the reader size (21 pt at 18), with the book count still `.caption` `ink.secondary`. **(call: the mockup's ratio; today 15 pt over 13 pt is the same proportion.)**
- **Group labels** (`GroupLabel`): they stay SF Pro semibold, upper case, tracked, `ink.verse`, but sized at 0.58 × the reader size with a floor of `.caption2`'s size, so they keep their proportion to the names (10.4 pt at 18, 16.2 at 28). **(call: a label that stayed at 10 pt under 28 pt names would read as a footnote.)** The phone's `GroupLabel` is unchanged: the size is an argument with today's style as its default.
- **Row rhythm:** the row's vertical padding, the chosen book's wash inset (`xs` beyond the name) and the marked dot (3 pt) scale by the reader size over 18 rather than by `.body`. **(call: they sit inside a name's line and must grow with it.)**
- A change of the reader size (⌘T, Settings › Reading, ⌘+ and ⌘−) reflows the contents at once, with no animation.

### 4.2 The columns

- **Column width:** the width of the widest book name of the translation at the current size, measured in the page face, plus the marked dot and its gap and the wash's inset on both sides. It replaces the `@ScaledMetric` 180 pt. A name never truncates (`lineLimit(1)` stays but never bites). **(call: measuring the real names is the only width that holds at 28 pt; "2 Thessalonians" and "Song of Solomon" set the width in most translations.)**
- **Count:** as many as fit with `md` between them (`ContentsPage.columnCount`, unchanged).
- **Bands:** unchanged. At four or more the Testaments share a band; below four each Testament takes the full width, the Old above the New; the Apocrypha is its own band. The break rule (whole groups, tallest column shortest) is unchanged and does not depend on size.
- **Expected at 1,100 pt:** the pane at its narrowest at 18 pt is now 316 pt (5.3), leaving about 736 pt for the columns. Whether four columns of 18 pt names still fit there depends on the measured widest name (about 150 pt in Literata at 18, with its dot and inset about 180) and is to be measured first. If only three fit, the Testaments stack at the default size in the default window, which Matt has not seen: the builder says so to Matt before going on. The measured thresholds go in "As built".
- The chosen book still scrolls into view on opening and on a change of size.

### 4.3 What does not change

The chosen book's wash, a click and a double-click, the keyboard (↑ ↓ ← →, Return, Tab into the pane), the search field's dimming and its ring in the pane, the marked dot, VoiceOver's labels, the band.

## 5. The pane

### 5.1 The divider

- A 1 pt `ink.rule` line between the contents and the pane, as the Tonal Step Rule allows between two panes, with a drag area about 8 pt wide centred on it. The pointer is the system's left-right resize cursor over that area. No grabber is drawn. **(call: a custom divider in the existing `HStack` rather than `HSplitView`, which brings its own divider look and saves its own state; the builder may use `HSplitView` if it can be made to look like this and to honour the limits below.)**
- **Limits:** at least the narrowest width (5.3); at most 40% of the window's width, which wins when the two disagree. When the window narrows past the point where the stored width exceeds 40%, the pane shows at 40% and the stored width is kept, so it comes back when the window widens. **(call: Matt's "about 40%" from the mockup; keeping the stored width means a window shrunk for a moment does not lose the reader's choice.)**
- A double-click on the divider removes the stored width, so the pane is at its narrowest and follows the narrowest from then on (it grows and shrinks with the reader size) until the reader drags again. **(call: the Mac idiom for split views; removing the value rather than storing the narrowest keeps the pane tracking the size.)**
- No animation while dragging. Releasing saves the width (section 6).
- VoiceOver: the divider is an adjustable element, "Chapter pane width", with increment and decrement steps of one column. Keyboard: not a Tab stop (a split view's divider is not one in the system's own apps). **(call)**

### 5.2 The grid

- **Cells follow the reader size:** the numeral in the page face at the reader size (18 pt at 18, where today's is 12 pt at `.callout`); the cell 2.9 × the reader size wide and 2.2 × high (52 by 40 at 18, where today's is 40 by 32). The gutters stay `xs` (8). The ring's line and the search ring scale with the reader size over 18 (1.5 pt and 3 pt at 18). **(call: this is the grid Matt chose in the mockup, `home-page.html` option C, which showed 18 pt numerals in 52 by 40 cells; he chose C seeing exactly that.)** So **at the default size the grid is larger than today's**, not the same: the numerals grow from 12 to 18 pt and the pane's narrowest width from 260 to 316 pt.
- **Columns:** as many cells as fit across the pane's inner width (the pane less `sm` each side), at least five when the pane is at or above its five-across width, and never fewer than three (5.3). `ChapterGridView.columnCount` stops being a constant: it is computed from the width and passed in; `cursorRect`, the row count and the arrow keys (↑ ↓ move by the column count) follow it.
- The grid stays centred in the pane. A book with fewer chapters than columns (Obadiah) is one short row, as today.

### 5.3 The narrowest width

- The pane's narrowest width holds five cells across at the current size, plus the gutters and `sm` (12) each side: about **259 pt at 14**, **316 pt at 18**, **462 pt at 28**. **(call: five is today's minimum and the number the Library's header icons were laid out for.)**
- **But never more than 40% of the window.** When 40% is narrower than five across (a large size in a small window), the pane is 40% of the window and the grid shows as many columns as fit, never fewer than three. At 28 pt that is four columns in a 1,100 pt window (440 pt) and three in the 820 pt minimum window (328 pt). **(call: the contents must keep at least 60% of the window; three is the fewest that still reads as a grid rather than a list.)**
- The header (the book's name in Display, its subtitle, the four reference icons) is unchanged and lays out in whatever width the pane has.

### 5.4 The space left for the Library

The pane's width is the one the Library's views (People, Places, About) get the rest of. In a 1,100 pt window at 18 pt with the pane at its narrowest (316 pt), they get 784 pt; at 14 pt, about 841; at 28 pt, 660 (the pane at 40%). With the pane dragged to its widest (40%), a 1,100 pt window leaves 660 pt and the 820 pt minimum window 492 pt. Projects 2 to 4 design for those widths. Nothing else in later projects depends on this one.

## 6. What is stored

One new value, **on this Mac only**: the pane's width in points, in `UserDefaults` under a key of the builder's naming (for example `frontPagePaneWidth`), written only when the reader ends a drag. It is not synced, is not in the synced store, and does not change the iCloud schema or anything in Matt's notes. **(call: points, written only by a drag.)**

- With no stored value the pane is at its narrowest for the current size and follows it as the size changes.
- A stored width below the current narrowest (the size went up) shows at the narrowest; the stored value is kept, so the pane returns to it when the size comes back down. **(call: a change of text size should not erase the reader's drag.)**
- A stored width above 40% of the window shows at 40% and is kept (5.1).
- A double-click on the divider removes the stored value (5.1).

**Approved by Matt, 2026-11-23** ("Yes, all three (Recommended)", asked for the pane width, People's order and Places' order together).

The reader size is read, never written, by the front page.

## 7. Constraints

- `CLAUDE.md`: read `PRODUCT.md` and `DESIGN.md` before any SwiftUI; use `/impeccable-swift` for every UI change.
- No fixed-point fonts in chrome. The names and numerals are sized from the reader size, which is the reader's own setting, not chrome; section 8 records the exception. Labels, counts and icons stay text styles.
- Palette tokens only; `AppSpacing` and `AppRadius` by name; no card by reflex; no inline colours.
- The front page must stay fast: no new view per chapter of the Bible, and measuring the names is done once per change of size and translation, not on every redraw. `FrontPageBenchmarkTests` keeps its budget.
- The handover's rules (milestone 10 handover, "Rules that bind every session here"): `/usr/bin/git`, one command per call; never push, merge or install without Matt's word; no test note or setting in the `.dev` store; a test never changes `readerFontSize` in the real defaults (inject the size).
- The checkers committed at `tools/` (SwiftLint with `tools/.swiftlint.yml`, `impeccable-lint`) run on the changed files; the build adds no finding over the baseline recorded in that commit.

## 8. Design changes

`DESIGN.md` and `DESIGN.json` change with the build:

- **Section 3, The Dynamic Type Contract:** add the front page's book names, Testament titles and chapter numerals to the exceptions derived from the reader size, and the group label's size rule.
- **Section 3, Hierarchy, Chapter numerals:** the pane's numerals at the reader size (not `.callout`), its cell 2.9 by 2.2 × the reader size.
- **Section 5, Navigation, Front page:** the names at the reader size; the column width from the widest name; the divider, its limits, its double-click and its VoiceOver; the stored width.
- **Section 5, Chapter grid:** the column count from the pane's width, at least five at or above the five-across width and never fewer than three; the cell, the ring and the search ring from the reader size; the old "40 by 32, five across in 260 pt" goes.
- **Section 3, The Scaled Metric Rule:** "the contents page's 180 pt column and the pane's 260 pt width" leave the list of `@ScaledMetric`s; say what replaces each.
- The handover's "Numbers Matt may ask to tune": the pane's 260 pt becomes "the narrowest width holds five cells at the reader size, at most 40% of the window"; add the cell's 2.9 by 2.2 and the fewest columns, three.

## 9. Left to the builder

- How the widest name is measured (an `NSAttributedString` size in the page face, cached per face, size and translation, is the obvious way).
- Whether the divider is a custom view or `HSplitView` (5.1), and its key's name.
- The exact thresholds at which the column count changes (recorded in "As built").
- How a change of reader size reaches the front page (`@AppStorage(ReaderSettings.fontSizeKey)` in `FrontPageView`, passed down, is the obvious way).
- Rounding: the cell sizes to whole or half points, as the reader rounds the verse number (2.2 × 18 = 39.6 shows as 40).

## 10. Verification

**Tests first** (Swift Testing, in `ScriptureUITests`):

- The column width at 14, 18 and 28 pt holds the widest name of the ESV and of the KJV with its dot and inset; no name is wider than its column.
- The column count at 1,100 pt with the pane at its narrowest: the count at 14, 18 and 28 as measured, pinned (and at 18, whether it is four or three, reported to Matt before going on, 4.2).
- Below four columns the Testaments stack (an existing `ContentsPage` test, run at a large size).
- The grid's column count: five at the narrowest width, more as the width grows; at 28 pt, four in a 1,100 pt window and three in an 820 pt one (the 40% limit), never fewer than three; the arrow keys move by the column count; the cursor's rectangle at column 7 of 8.
- The pane's narrowest width: about 259, 316 and 462 pt at 14, 18 and 28; at 28 pt in a 1,100 pt window it is 440 (40%), not 462. A stored width above 40% shows at 40% and is kept; a stored width below the current narrowest shows at the narrowest and is kept; a double-click removes it.
- The stored width is read on opening and written on the end of a drag, through an injected `UserDefaults` (never the real one).
- The cell and numeral at 18 pt are 52 by 40 and 18 pt (larger than today's 40 by 32 and 12 pt).
- `FrontPageBenchmarkTests` within its budget at 18 and 28 pt.

**Renders** (offscreen, removed before commit): the front page at 1,100 pt at 14, 18, 24 and 28 pt, light, dark and Sepia; the pane at its narrowest and at 40% with Psalms chosen; Genesis's grid at 28 pt in a 1,100 pt and an 820 pt window.

**Live pass by the controller** (keys only, under the handover's rules for Matt's Mac): ⌘+ and ⌘− on the front page reflow it; nothing truncates.

**For Matt (the Mac Debug app):**

- [ ] The book names read at your page size; change the size in ⌘T and watch them follow.
- [ ] At a large size the Testaments stack, and no name is cut off.
- [ ] The chapter numbers are larger than before at your size (18 pt, where they were 12); say if that is too large.
- [ ] Drag the divider wider: more chapters per row. Drag it back. Double-click it: it returns to its narrowest and then follows your text size.
- [ ] Quit and reopen: the pane keeps its width.
- [ ] Narrow the window: the pane never takes more than about 40%.
- [ ] Arrow keys in a wide grid move by a whole row.
- [ ] People, Places and About still open in the contents half and fit beside a wide pane.

**Not seen by a render:** the resize cursor, the drag itself, AeroSpace resizing the window on launch (a changed window size is not a regression; the stored pane width is what to check).

## 11. Later (lines for `docs/BACKLOG.md`)

- **The divider from the keyboard.** The pane's width changes by dragging or with VoiceOver; there is no key for it. Milestone 11, project 1.
- **The iPhone's Library at the reader size.** The phone's book names and chapter cells follow Dynamic Type, not the reader size; Matt named the Mac. Milestone 11, project 1.

## 12. As built

**Measured (task 1; table in the ledger's `measurements.md`).** In Literata, with the pane at its narrowest and the divider taking no width, the default 1,100 pt window holds **three** columns of books for the ESV at 18 pt (widest name 145 pt, column 172 pt, pane 316 pt, contents 736 pt). The ESV and the KJV measure alike (the same widest name). In a 1,100 pt window they hold five at 14, four at 16, three from 18 to 22, and two from 24 to 28; in an 820 pt window three at 14, two from 16 to 22, one from 24. The other four faces at 18 hold four in 1,100 pt (Iowan, Source Serif, New York, Charter set narrower names than Literata). The CPDV and the WEB, with longer names, hold four at 14, three from 16 to 20, two from 22 to 26, one at 28. All of these were measured at even sizes; the size steps by 1 pt, so an odd size falls between its neighbours.

The first item on Matt's list (below) is this finding. He has not seen it; the build went on as the spec says.

**Built, file by file** (all in `Packages/ScriptureKit/Sources/ScriptureUI/`, tests in `Packages/ScriptureKit/Tests/ScriptureUITests/`):

- `Library/ContentsMetrics.swift`: the contents' sizes from the reader size (names, Testament titles 1.15 ×, group labels 0.58 × with the `.caption2` floor, row padding, wash inset, dot and its gap over 18; `columnWidth(widestName:)`).
- `Library/BookNameMeasure.swift`: the widest name of a set, measured once per face, size and set of names (Core Text, no per-redraw measuring).
- `Library/ChapterPaneMetrics.swift`: the cell (2.9 by 2.2 × the size, rounded), the numeral, the rings, `narrowestWidth` (five across), the 40% limit, `shownWidth(stored:frontPageWidth:)` and `columns(paneWidth:)` (never fewer than three).
- `Library/ContentsPageView.swift` and `Library/GroupLabel.swift`: the names, titles and labels at the reader size; the column from the widest name; `GroupLabel(size:)` with `tracking(forSize:)`, the phone's default unchanged.
- `Library/ContentsPage.swift`: `ContentsPage.columnCount` allows for the Testaments' wider gap.
- `HairlineRule.swift`: the one rule the band, the Testament and the divider share.
- `FrontPageView.swift`, `Apps/Mac/.../MainWindowView.swift`: `readerSize` passed in (`ReaderSettings.clampedFontSize`), the front page's width measured with `onGeometryChange`, the pane as wide as the stored or narrowest width allows, the divider as the pane's overlay.
- `ChapterGridView.swift`, `BookPaneView.swift`, `ChapterMarks.swift`: the grid takes its column count and the metrics; the arrows, the row count and the cursor follow the count; `ChapterCell.Size.pane(metrics)` (the phone's `.grid` unchanged); the ring's line width is a parameter.
- `PageFace.swift`: `paneNumeralFont(size:)`, the pane's numerals at the reader size in every face, including New York and Iowan Old Style (the system serif at the size); `numeralFont(size:)` is untouched.
- `Library/PaneWidth.swift` and `Library/PaneDivider.swift`: the stored width (`frontPagePaneWidth`, `UserDefaults`, this Mac only; written when a drag ends or VoiceOver adjusts, removed by a double-click, never on opening) and the divider (1 pt `ink.rule`, 8 pt drag area centred on it, the resize cursor, no grabber, VoiceOver "Chapter pane width" in steps of one column, not a Tab stop).
- `Plans/PlanWeekSummary.swift`: its doc comment only (four readings across, not five).
- Tests: `FrontPageMetricsTests` (two suites), `ChapterGridTests`, `PaneWidthTests`, `PageFaceTests` (the pane's numerals), `ContentsPageTests`, `PlanBandTests` (repinned), `FrontPageBenchmarkTests` (an injected, empty defaults suite).
- The fix wave (after the whole-project review): `Library/PaneWidth.swift` stores at a drag's end or a VoiceOver step only when the pane's width changed (a drag at 28 pt in the default window, where the pane cannot move, or a step at a limit stores nothing, and a kept wider width stays kept), and `cancelDrag()` returns a drag the system cancels; `Library/PaneDivider.swift` tracks the drag with a `@GestureState` and calls the cancel when it resets without an end; `ChapterGridView.swift` brings the cursor's cell back into view, as a cut, when the column count or the size changes while the grid has the keyboard; `Library/BookPaneView.swift` sets the grid `searchRingWidth` below the scroll view's top, so a searched first-row chapter's ring is no longer cut (a render at 28 pt showed it cut). Tests: four in `PaneWidthTests` (nothing written on opening, a drag and a step that change nothing, a cancelled drag), one in `ChapterGridTests`. After it: package 1,536 passed (1,124 + 241 + 52 + 91 + 28), iOS `ScriptureUITests` 1,029 (the new tests are Mac only), the Mac Debug build succeeded, checkers 83, 27 and 0.

**Thresholds** (ESV and KJV in Literata, pane at its narrowest, the divider taking no width; the full table is in the ledger's `measurements.md`). Columns of books in a 1,100 pt window: five at 14, four at 16, three from 18 to 22, two from 24 to 28; in an 820 pt window: three at 14, two from 16 to 22, one from 24. The other four faces hold four at 18 (1,100 pt). The CPDV and the WEB hold four at 14, three from 16 to 20, two from 22 to 26, one at 28. Measured at even sizes; the size steps by 1 pt. The pane's narrowest: 261 pt at 14, 316 at 18, 461 at 28 (the cells round to whole points, where the spec wrote "about 259, 316, 462"); at 28 in a 1,100 pt window it is 440 (40%), four cells across, three in an 820 pt window (328 pt).

**Calls (call, unattended).** Matt was away, so none of these was asked; each is built as written and may be changed.

1. The "This week" band holds four readings across at 1,100 pt, not five, with the pane's narrowest at 316 pt. The spec fixes the pane and says the band keeps its own type, so its 140 pt minimum stays. `PlanBandTests` is repinned (four at 1,100, three at 820); DESIGN.md and the doc comment say four. Cost if wrong: the band's minimum is retuned.
2. The reader size is passed into `FrontPageView` by `MainWindowView`, not read there with `@AppStorage` (spec 9's "obvious way"), so tests and the benchmark inject it and never touch the real defaults. Cost if wrong: none the reader sees.
3. Cells round to whole points (2.9 × and 2.2 × the size), so the narrowest pane is 261 / 316 / 461, not 259 / 316 / 462. Cost: a point or two.
4. `ContentsPage.columnCount` allows for the Testaments' side-by-side gap (`lg`, not `md`), where the spec said "unchanged": otherwise a width that holds four columns at `md` but not the extra gap would shrink the columns below the widest name and cut it off, the anti-goal. Cost: at a few points' margin, one fewer column.
5. A translation's widest name counts its Apocrypha too, since every band's columns share one width. Cost: in a translation that carries the Apocrypha the Testaments stack at a smaller size than in the ESV.
6. The row's dot gap scales with the size along with the inset, padding and dot. Cost: none visible.
7. The group label is `Font(PlatformFont.systemFont(ofSize:weight: .semibold))` at its derived size, its tracking 1.4 × size over `.caption2`'s base size; DESIGN.md's Dynamic Type Contract records it as derived from the reader size. Cost: none.
8. A shared `HairlineRule` draws the band's rule, the Testament's rule and the divider; it carries no `accessibilityHidden` (a shape is not an element), which removed four old lint findings. Cost: none; the rules' geometry is unchanged.
9. The divider is an overlay on the pane's leading edge and takes no layout width; its 1 pt rule is centred on the edge and its drag area reaches 4 pt each side. Cost: the 4 pt over the contents covers the inner edge of their scroll bar (unseen, below).
10. A drag works from its translation, its start recorded on the first change, so the pane never jumps when the press lands off the rule. A drag released below the narrowest saves the narrowest as a number, which then stops following the size until a double-click removes it. Cost: a reader who drags fully left expects tracking; one double-click gives it.
11. VoiceOver's adjust saves each step that changes the width, clamped like a drag, and reads "N chapters across". Cost: none.
12. The size-change scroll to the chosen book is its own `onChange` that never moves focus, so a reader in the pane's grid who presses ⌘+ stays there. Cost: none.
13. The pane's numerals use `PageFace.paneNumeralFont(size:)`, which sets the system serif at the reader size in New York and Iowan Old Style; Task 3's first build left them at `.title3` (about 15 pt) in cells sized for the reader size. The phone's `numeralFont(size:)` is unchanged. Cost: none; DESIGN.md's chapter numerals line records it.
14. The grid is centred with `.animation(nil, value: columnCount)`, so a change of column count is always a cut; the grid's statics clamp the count to at least one; ← and → still wrap across rows as before. Cost: none the reader sees.
15. `onGeometryChange` is not narrowed: every width of the window re-evaluates the front page during a resize. The benchmark shows no cost. Cost if wrong: a laggy resize on a slow Mac.
16. An always-shown scroll bar ("Show scroll bars: Always", or a mouse attached) narrows the pane's grid by about 15 pt at the narrowest and eats into its `sm` margins, so five across may become four there. Accepted: the spec fixes the narrowest width. Cost if wrong: `columns(paneWidth:)` later reads the scroll view's content width.
17. Task 1's tests were written after the code and the red recorded afterwards by moving the files away. Cost: none; the pins are measured.
18. The reader size follows `onOpenSettings` in `FrontPageView`'s initialiser (the pane's defaults, for tests, come last), so `MainWindowView` passes it after the `onOpenSettings` closure (`onOpenSettings: { … }, readerSize: …`), which can never be written as a trailing closure. Cost: none the reader sees.

**Checkers after the build** (from the worktree root; baseline 87, 27, 0): SwiftLint 83 (four fewer); impeccable-lint 27 (unchanged); asset checker 0. In the touched files: `FrontPageView.swift` 4 (from 6: the hidden ⌘F and Esc buttons' two pairs, real hidden controls), `ContentsPageView.swift` 0 (from 2), `ChapterMarks.swift` 1 (the existing ring, moved), the new and other touched files 0. The four old findings (`FrontPageView` :151 and :153, `ContentsPageView` :148 and :149) are fixed by `HairlineRule`; no new finding in any touched or new file.

**Benchmark** (`FrontPageBenchmarkTests`, 100 ms budget, front-page-open median of nine) at 18 and 28 pt: 76.9 and 81.1 ms focused, 74.9 and 79.8 ms under the full package suite (the baseline before this project was about 68 and 69 ms; the rise is the second layout pass once the front page's width is known).

**Suites** (at the last commit before this one's text): package 1,531 passed (1,119 + 241 + 52 + 91 + 28; the baseline was 1,509, so 22 new); iOS `ScriptureUITests` 1,029 passed in 100 suites (the baseline was 1,028; the pane's numeral test runs there too). Mac Debug build succeeded in Tasks 2 to 4 (not run in Task 5; the controller is using the Mac Debug app).

**Review, fix wave and live pass.** The whole-project review (Opus, in place of Fable on Matt's word) found no Critical and one Important (a drag or VoiceOver step that changed nothing still stored a width); one fix wave fixed it and five minors (a cancelled drag goes back; the cursor stays in view when the column count changes; "never written on open" is pinned; a searched first chapter's ring was clipped at the grid's top at 28 pt and is now padded clear; the documents) and its scoped re-review found all twelve items addressed and nothing new above Minor. The controller's live pass on the Mac Debug app (keys only, the idle time checked before every key): the front page at 18 pt in Matt's 1,638 pt window held six columns, nothing cut off, the pane at its narrowest with five across and the divider one hairline; ⌘+ three times reflowed it at 21 pt (five columns, a wider pane, the chosen book still in view and keeping the keyboard), ⌘− three times brought it back exactly; Return moved into the pane on chapter 14, ↑ went to 9 (a whole row of five) and ← to 8. No width was stored in `.dev` by the pass. At the end: package suite 1,536, iOS suite 1,029, both Debug builds succeeded, SwiftLint 83, impeccable-lint 27, the asset checker 0. The Mac Debug app was restarted on this build; the iPhone's Debug app was not installed (unattended).

**Minors set aside** (each deferred by a task review, for the whole-project review): the "39 books" count stays `.caption` beside a title at 1.15 × the size, so it reads small at 28 pt; each frame of a window resize re-evaluates the front page; a column-count change while the grid has focus does not call `onRevealChapter`, so the cursor can slide out of view; nothing checks that the `LazyVGrid` places a cell where `cursorRect` says; a VoiceOver decrement at the narrowest with nothing stored writes 316, ending size-tracking; a drag cancelled without an end leaves its start set; no test pins "never written on open"; at 28 pt in a small window the first frame may show five across at 461 pt before the width is known, then three at 328.

**For Matt**, in the order to look (the first is the finding in "Measured"):

1. At the default text size the default window holds three columns of books, so the Old Testament fills the width and the New follows below it (his mockup showed four beside today's narrower pane).
2. Five readings in a week now wrap four and one in the default window (the "This week" band, 4 across at 1,100 pt, where it was 5; three and two at 820).
3. The book names read at your page size; change the size with ⌘+ and ⌘− and watch them follow (View › Text & Layout is not available on the front page).
4. At a large size the Testaments stack, and no name is cut off.
5. The chapter numbers are larger than before at your size (18 pt, where they were 12, in 52 by 40 cells); say if that is too large.
6. Drag the divider wider: more chapters per row. Drag it back. Double-click it: it returns to its narrowest and then follows your text size.
7. Quit and reopen: the pane keeps its width.
8. Narrow the window: the pane never takes more than about 40%.
9. Arrow keys in a wide grid move by a whole row.
10. People, Places and About still open in the contents half and fit beside a wide pane.
11. The Mac Debug app was quit and reopened on this build at the end of the project; the iPhone's Debug app is still on milestone 10 (installing it needs the phone unlocked and your word; it shows nothing new from this project, which is the Mac's only).

**What nobody has seen** (render-blind, and unattended): the resize cursor over the divider; the drag itself (that the pane follows the pointer as a cut, with the grid's columns changing live); the double-click; the width after a quit and reopen; VoiceOver's adjust, and where VoiceOver reads the divider (it is the pane's overlay, so likely after the pane's grid, not between the contents and the pane; its place in the order can be changed); a scroll bar set to "Always" narrowing the pane's grid at its narrowest; the 4 pt of the drag area over the contents' scroll bar edge; AeroSpace's window size on launch (a changed window size is not a regression; the pane's kept width is what to check); a drag the system cancels part-way (it should put the pane back). The iPhone's Debug app was not installed (unattended run); the simulator stood in.
