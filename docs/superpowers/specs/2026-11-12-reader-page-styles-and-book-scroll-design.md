# The reader: page styles, book-long scrolling and headings

Design agreed with Matt on 2026-11-11 and 2026-11-12. It changes the reader on both apps (Mac and iPhone, shared through `ScriptureUI`) and extends `2026-10-26-reading-through-scripture-design.md`. `DESIGN.md` section 3 (Page Styles), the `ink.verse` token in section 2 and the amended One Saturated Voice Rule already record the visual decisions; this document is the rest.

Lines marked **(call)** are choices Claude made that Matt has not explicitly confirmed. Everything else under "What Matt decided" is his.

The mockups Matt reacted to are saved beside this file in `2026-11-12-reader-mockups/` (HTML fragments from the brainstorming companion; open them in a browser): `typography-directions.html` (the four styles; he chose A, Printed), `later-chapter-heading.html` (he chose 3, the running head), `book-scroll.html` (a working sketch of the book-long scroll), `reading-settings.html` (the settings, which he approved with the phone change in section 5.4).

## 1. Intent

Matt compared this app with bible-rs (github.com/michaelshimeles/bible) and liked how its page looks: a large book title with a subtitle ("The Gospel According to John"), a spaced CHAPTER label, section headings, verse numbers in a warm color, all in Literata. He wants the reader to look that good out of the box and to let him adjust the font, size and spacing.

While looking at how later chapters should open, he asked for a second change: one scroll per book, so he can read on through two or three chapters without pressing Next each time. The chapter heading becomes a running head that names the chapter in view, and the progress line restarts with each chapter.

Success: John opens on a page that looks typeset, scrolling carries straight on from chapter to chapter with the head keeping up, a chapter appears as fast as today, and nothing he relies on now (highlights, notes, lookups that keep his place, the assistant's chapter scope) gets worse.

## 2. Goals, non-goals, anti-goals

### Goals

1. Four page styles (Printed, Lectern, Study, Classic) as `DESIGN.md` section 3 describes them, Printed the default.
2. Book titles, subtitles and section headings on the page, from bundled sources, wherever a translation can have them.
3. One continuous scroll per book, with a pinned running head and a per-chapter progress line.
4. Reading settings: page style, font, size, line spacing, column width, layout, verse numbers, section headings, justification and appearance (with a new Sepia), in Settings and in a Text & Layout popover on the Mac.
5. The same reader on the iPhone.

### Non-goals

- **Online translations and publishers' own headings.** NLT, NTV, ESV headings from Crossway's API, Spanish, NIV: parked in `2026-11-12-online-translations-handover.md`. This project only has to leave a headings layer those can fill.
- **Scrolling across books.** A book ends; the next book is one click on.
- **Parallel translations or compare views.**
- **Small caps for LORD.** The bundled text has "Lord" in title case everywhere (milestone 6 found this), so there is nothing to set.
- **The phone fixes and Library links** brainstormed the same day: their own design, `2026-11-12-phone-notes-swipes-library-design.md`.

### Anti-goals

- A page that feels like a web page: the TextKit column, measure, margins and baseline rhythm stay (`DESIGN.md`, Don'ts).
- A slower reader. Opening a chapter must stay within the milestone 6 budget (Psalm 119 in ESV at 18 pt with sixty highlights appears within a second; scrolling drops no frames), now with a whole book behind it.
- Headings that look like they belong to the translation when they don't. Borrowed headings are labelled as borrowed (section 4.2).
- Losing a highlight, a note or the reader's place because the chapter boundary moved.

## 3. What Matt decided

### 3.1 Page styles

- **Printed is the default; all four ship** and the reader can switch in Settings. Matt asked "how difficult is it to ship all 4 and let the user decide" and, given the cost (section 7), kept all four.
- The styles are exactly as `DESIGN.md` section 3, Page Styles, describes them. That section is the visual spec; don't restate it here, and change it there if a value moves during the build.
- Verse numbers and the CHAPTER label in Printed use the new `ink.verse` bronze (`#7A5320` light, `#DDB683` dark), darker than the mockup so it holds 4.5:1 on the page and on every mark fill. Matt asked for the DESIGN.md update himself.
- **Study's accent verse numbers fail on a highlight** (the light accent is about 4:1 on Yellow). **(call)** In Study, a verse number that sits on a mark fill draws in `ink.secondary` instead of the accent; elsewhere it stays accent. Add the pairings to `PaletteTests`.

### 3.2 Chapter openings and the running head

- **Chapter 1 opens with the full title block** in the style's form: in Printed, the book title, the subtitle, then CHAPTER 1.
- **Every later chapter opens with a label only** (Matt chose option 3): in Printed, the spaced CHAPTER 3 label in the text, with the air above it the mockup shows (about 2.4 × the reader size above, 1.2 × below; **(call)** on the exact figures, tune by eye).
- **As the reader scrolls, the title block gives way to a running head** pinned at the top of the reader: "JOHN · CHAPTER 1" in the chapter-label style. Matt's words: "as the user scrolls down Chapter 1 it morphs into the running head only." In the sketch the in-text label fades as the pinned head fades in over the last ~60 pt before the label reaches the head's line; a cut under Reduce Motion.
- **The head always names the chapter in view**: the chapter whose text crosses the line just under the head. Each chapter's own label hands over to the head as it passes that line.
- **The progress line moves under the running head and restarts for each chapter**: 2 pt of `accent` across the measure, growing as the reader moves through the chapter in view, empty when a chapter starts. It keeps its existing rules otherwise (no animation, hidden at the very top of the book).
- **On the iPhone (call), the navigation bar's title is the running head.** The phone already shows "John 3" and the translation in the bar's centre (`PhoneChapterTitle`) with the progress line under the bar, and the text runs under the bars. So the phone draws no second pinned strip: the bar's title names the chapter in view and changes at each chapter label, it is hidden while the book's title block is on screen and appears as the block scrolls under the bar (like a large title collapsing), and the progress line stays where it is and restarts per chapter. Later chapters still open with their label in the text. On the Mac, the running head is the pinned strip described above.
- **Per style (call):** the running head takes each style's own label voice. Printed: "JOHN · CHAPTER 3" as in the sketch. Lectern: small capitals "John · 3" in `ink.secondary`. Study: SF Pro uppercase label "JOHN 3" in `ink.secondary`. Classic: "John 3" in New York semibold at `.headline`. Later chapters open in the text with the same voice; Lectern opens every chapter with its drop numeral (it has no label).

### 3.3 One scroll per book

- **All of a book's chapters are one continuous scroll.** Opening John 3 from the Library lands at chapter 3 with chapters 1 and 2 above.
- **The end of a book stops, with a way on to the next** ("Acts →", like today's Next link). Matt: "When you get to the end it stops, with a way on to Acts." **(call)** The top of a book, above the title block, shows nothing; ⌥⌘← (Previous Chapter) at chapter 1 opens the previous book at its last chapter, as today.
- **Everything that says "this chapter" follows the running head** (Matt agreed to this playback): the window and toolbar title, the notes column on the Mac, Notes in This Chapter on the phone, Ask About This Chapter and the chapter prompts' scope, and the chapter-note mark (section 4.4).
- **Your place moves as you scroll**, as it does now when you scroll five lines on. The lookup rules stay, widened from "the chapter being read" to "the book being read" **(call)**: a lookup (a note from the browser, a search hit, Open on a verse in an assistant reply) shows the passage without moving your place. A lookup inside the book you are reading, in the same translation, becomes your place once you scroll five lines from where it landed (up or down), as a jump within the chapter does today. A lookup into another book or another translation stays a lookup however far you scroll, until Read From Here, Next or Previous, as today. Crossing a chapter label does not by itself end a lookup **(call)**: only the five-line rule does, so a lookup landing at verse 1 is not ended by a nudge across its label.
- **Back and Forward history (call):** scrolling from one chapter into the next updates the current history entry's chapter and verse; it does not push an entry. Next, Previous, choosing a chapter in the Library and every lookup push an entry, as they do today. So after reading on through three chapters by scrolling, ⌘[ returns to wherever you came from before this book, not chapter by chapter; after pressing Next three times it steps back chapter by chapter, as now.
- **Previous and Next** become jumps to the previous and next chapter label within the book (⌥⌘← and ⌥⌘→, the Go menu, the phone's equivalents), and to the neighbouring book at either end. The per-chapter footer links go; only the end-of-book link remains.

### 3.4 Reading settings

All of these in Settings › Reading on both apps, and in a **Text & Layout popover** from a new toolbar button on the Mac (`textformat.size`, label "Text & Layout", ⌘T **(call)**; the full set, **(call)**, since the popover has room and Matt did not ask to trim it):

| Setting | Values | Default | Notes |
|---|---|---|---|
| Page style | Printed, Lectern, Study, Classic | Printed | Four tiles, each "Aa" in its face |
| Font | The style's font, Literata, Iowan Old Style, Source Serif 4, New York, Charter | The style's font | Overrides the face only; the style's heading arrangement and colors stay. **(call)** Stored on its own, so an override stays when the page style changes; choosing "The style's font" ends it |
| Size | 14 to 28 pt, step 1 | 18 | Extends today's 14 to 24; the measure range must grow to match |
| Line spacing | Compact, Normal, Relaxed | Normal | As today |
| Column width | Narrow, Normal, Wide | Normal | New. **(call)** 0.85 ×, 1 ×, 1.15 × today's measure, still clamped by the window |
| Layout | Paragraphs, Verse per line | Paragraphs | New. Verse per line starts each verse on its own line; poetry keeps its lines |
| Verse numbers | on, off | on | New |
| Section headings | on, off | on | New. Book titles and chapter labels always show |
| Justify text | on, off | off | New. With hyphenation when on |
| Appearance | System, Light, Sepia, Dark | System | Sepia is new (section 4.6) |

**On the phone**, the reader's `ellipsis` menu holds only Page style, Size, Line spacing, Appearance (Light / Sepia / Dark, **(call)** with System too, as a submenu with checkmarks) and **More Settings…**, which opens Settings at Reading. Matt: "Just limit the reader's menu to page style, size, line spacing, light/dark mode, and more settings. The rest can live in the settings." This replaces today's Text Size item; the menu's other items (translation, Notes in This Chapter, Settings) stay **(call)**.

**Sync (call):** page style, font, layout, verse numbers, section headings and justify travel through the iCloud key-value store like the other synced preferences (`PreferenceSync`), since they are taste. Size, line spacing, column width and appearance stay with each device, as size, spacing and appearance do now, since they depend on the screen and the light.

## 4. The how, as far as it was decided

### 4.1 Fonts

Bundle Literata and Source Serif 4 (both SIL OFL 1.1; include the licence texts and credit them in an acknowledgements place, **(call)** a Settings › About line or the README if the app has no such screen). Variable fonts are fine if the weights in `DESIGN.md` render correctly on both platforms; otherwise ship the static weights used (Literata Light, Regular, Italic, Medium for the chapter numerals if needed; Source Serif 4 Regular, Italic, Semibold). Iowan Old Style, New York and Charter are system faces on macOS 26 and iOS 26; check Charter on iOS before relying on it, and drop it from the Font list if it isn't there. Register the bundled faces so both the TextKit reader (`ReaderTypography`) and SwiftUI (`Font.custom(_:size:relativeTo:)` for the quoted rows and the front page's chapter numerals) can use them.

### 4.2 Headings data

The reader needs, per translation: a book title, a subtitle, and section headings keyed by verse. This project ships only bundled sources; the online-translations project fills the same layer later from publishers' APIs (the handover says so).

- **Book titles and subtitles:** the app's own table of the 66 books, in English. Title = the book's name ("John"); subtitle = the traditional long title ("The Gospel According to John", "The First Book of Moses, called Genesis" or a plainer modern form). **(call)** Use a plain modern set in the app's table and leave the wording to the builder, checked by Matt in review. For the KJV, use the KJV's own `\mt1` titles from eBible.org's `eng-kjv_usfm` ("The Gospel According to St. John"), title-cased. A book with no subtitle shows the title alone.
- **Section headings:** no bundled translation has its own (holybooks has none; the KJV has none). The fallback is the **Berean Standard Bible's headings** (eBible.org `engbsb_usfm`, public domain since 2023-04-30): its `\s1` (3,017) and `\s2` (80) lines keyed by the verse they precede. Exclude `\d` psalm superscriptions (they are scripture text in the BSB's own wording, not editorial headings, and would put BSB words into another translation) and `\r` parallel-passage lines.
- **Label the borrowing.** Because BSB headings are a different editor's outline (in John 1 the BSB has "The Word Became Flesh" at 1:14, where other Bibles have it at 1:1), the Section headings setting carries a footnote: "Headings from the Berean Standard Bible." **(call)** Nothing on the page itself names the source. When a translation later brings its own headings, those replace the BSB's for that translation.
- **Build-time import, pinned.** Extend the importer (`Scripts/build-bible.sh`, `bible-importer`) to fetch the two eBible USFM zips at pinned URLs with SHA-256 digests (as holybooks is pinned to a commit), and write a headings table into `bible.sqlite`. **(call)** Schema: a `heading` table (`source` = `bsb` / `kjv`, `book_id`, `chapter`, `verse`, `level`, `text`, and an `ordinal` for two headings before one verse) and a `book_title` table (`translation_id` nullable for the app's own table, `book_id`, `title`, `subtitle`). The builder may shape it differently; keep it queryable per book in one read.
- **Alignment.** A heading keyed to a verse a translation lacks (small versification differences) attaches to the next verse that exists in that chapter, or is dropped if none does.
- **No borrowed headings for the CPDV (call).** The bundled CPDV follows the Vulgate's numbering (its Psalm 22 is Psalm 23 elsewhere, its psalm titles are verse 1, and chapters differ in Joel, Malachi, Esther and Daniel), so BSB headings keyed by number would land on the wrong passages. The CPDV shows book titles and chapter labels only; its Section headings setting has nothing to show. A numbering map is possible later if Matt reads the CPDV.

### 4.3 The book-long scroll

The builder chooses the architecture; these are the constraints:

- Today one `ChapterTextController` (Mac) or `PhoneChapterTextController` (phone) owns a TextKit 2 text view showing one chapter. The book scroll may be one text view per book (TextKit 2 lays out only the viewport, and Psalms is about 2,500 verses) or a stack of per-chapter text views; measure before choosing. Psalms and Psalm 119 are the cases to measure.
- **A jump lands exactly** (a verse from search, a note from the browser, a Library chapter), with no visible settle, as today.
- **Selection stays within one chapter** (**call**): a drag that crosses a chapter label stops at the chapter's end, because `SelectionReport` and markup anchors are per chapter. This matches bible-rs.
- **Highlights, noteless anchors, bookmarks' gutter glyphs and the focused-highlight outline** draw across the whole book as they do in one chapter now. Applying a highlight still lands within a frame.
- **Section headings, chapter labels and the title block are not selectable and not part of any verse's text**, so they never shift a highlight's character offsets. VoiceOver reads headings with the header trait and the chapter label as a heading.
- **Translation switch** keeps the reader at the same verse.
- **Window resize** keeps the reading verse (milestone 6 checked this for one chapter; it must still hold).
- `ReadingPosition` keeps storing chapter and verse; what changes is that scrolling past a chapter label updates the chapter.

### 4.4 Things that move with the chapter in view

- **Chapter-note mark** (`ChapterNoteMark`): **(call)** it sits at the trailing end of each chapter's opening line in the text (beside the title block's CHAPTER 1 label, and beside each later chapter's label), and also at the trailing end of the running head for the chapter in view. Same symbol, count and behavior as now.
- **Notes column (Mac):** lists the chapter in view's notes and highlights. **(call)** It changes when the running head changes, not continuously; a row being edited keeps its chapter until editing ends.
- **Assistant:** Ask About This Chapter and the chapter prompts use the chapter in view. A conversation scoped to the chapter stays with the chapter it was started in.
- **Heading click:** a plain click on the running head (or the title block) goes back to the book's chapter grid, as a click on today's heading does; its context menu offers Ask About This Chapter.

### 4.5 Verse per line, verse numbers off, justify

- **Verse per line:** each verse starts a new line, flush left, with the verse number before it (not hung in the margin, **(call)**, to keep the measure and the bookmark gutter as they are). Poetry keeps its line structure and hangs as today; prose paragraphs lose their first-line indent.
- **Verse numbers off:** numbers disappear; the gutter's bookmark glyph and the margin marks on the phone still show.
- **Justify:** full justification with hyphenation (`NSParagraphStyle.hyphenationFactor` or the TextKit 2 equivalent) for prose; poetry stays ragged.

### 4.6 Sepia

A warm paper appearance, new to the app. **(call)** It is the light appearance with sepia values for `paper.page`, `paper.panel`, `paper.overlay`, `ink.primary`, `ink.secondary`, `ink.tertiary` and `ink.rule` (the mockup used `#F4ECDD` page, `#2B2219` ink, `#6A5B49` secondary, `#DCCFB8` rule as a starting point), applied app-wide like Light and Dark; the marks keep their light values, `ink.verse` and the accent keep theirs. Every existing contrast pairing in `PaletteTests` must also pass in Sepia. System controls stay light. On macOS the app sets its appearance through `NSApp.appearance` today; Sepia needs the token layer to know it's active (an environment value or a third case resolved by `ColorToken`), which is the builder's to design.

## 5. What's left to the builder

- The book-scroll architecture (4.3), measured on Psalms.
- The headings schema and importer changes (4.2), within the pinned-source rule.
- The book-title table's wording (4.2), for Matt to check.
- How the running head's morph is implemented (overlay view above the text view is the obvious route).
- Lectern's drop numeral: an exclusion path in the text container plus a drawn numeral is the likely route; it must survive resize, size changes and a highlight on verse 1. It is the riskiest part; schedule it last. If it fights back, Lectern may open with a centred numeral above the text instead, and say so in the plan's record.
- Exact spacing values not given in `DESIGN.md`, by eye, as `ReaderTypography` multiples of the size.
- Updating `DESIGN.md` wherever a value changes during the build, and recording the build in the main spec's milestone list (this is milestone 9 **(call)**).

## 6. Verification

Run on the Mac and on the iPhone (Debug build, `.dev` identity; never Matt's Release store):

1. John 1 in Printed, light and dark: title, subtitle, CHAPTER 1, BSB headings, bronze verse numbers, as the mockup. The same for Lectern, Study and Classic.
2. Scroll John 1 into John 2: the title gives way to the running head; the head changes at the CHAPTER 2 label; the progress line restarts; the toolbar title, the notes column and the chapter-note mark follow.
3. Open John 3 from the Library: it lands at John 3:1 with John 2 above. End of John shows "Acts →".
4. Psalm 119 in ESV at 18 pt with sixty highlights appears within a second inside the whole of Psalms; an end-to-end scroll through Psalms drops no frames (Animation Hitches).
5. A lookup (a note from the browser in another chapter of the same book) keeps your place; scrolling five lines on makes it your place. A search hit in another book stays a lookup however far you scroll, until Read From Here. After scrolling through three chapters, ⌘[ goes back to before the book; after Next three times, it steps back a chapter at a time.
6. Highlights made before the change are all still in place, including ones on the first and last verse of a chapter.
7. Every setting in 3.4 changes the page at once, on both apps; the synced ones arrive on the other device.
8. `PaletteTests` covers `ink.verse` and Sepia; Study's verse number on a mark passes.
9. VoiceOver reads a section heading as a heading and the running head as the chapter.

## 7. Sizing and risks

- Shipping all four styles costs roughly a third more than Printed alone, most of it Lectern's drop numeral.
- The book-long scroll is the largest part: it touches both text controllers, the navigation model's idea of the current chapter, the notes column and the assistant's scope.
- Risk: performance on Psalms. Measure early, before the styles are built on top.
- Risk: markup offsets. Keeping headings and labels outside verse text is what protects them; test with existing highlights.
