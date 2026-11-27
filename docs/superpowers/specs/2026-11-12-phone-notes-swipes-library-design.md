# Notes that read, edge swipes, and Library references

Design agreed with Matt on 2026-11-12. Three changes, mostly on the iPhone, with the reference links and the Library row reaching the Mac too because the code is shared (`ScriptureUI`). It extends `2026-11-09-milestone-8-ios-design.md`.

Lines marked **(call)** are choices Claude made that Matt has not explicitly confirmed. Everything else under "What Matt decided" is his.

Mockups beside this file in `2026-11-12-phone-fixes-mockups/`: `phone-note-card.html` (he chose A) and `library-icons.html` (he chose the rounded-square outlines, with `play.rectangle`).

This is independent of the reader project (`2026-11-12-reader-page-styles-and-book-scroll-design.md`) and can be built before or after it. Where the two touch (the reader's tap handling, the Library), the second one built adapts to the first.

## 1. Intent

Three frictions from daily use on the phone:

1. **Notes show as raw markdown and their references don't link.** Matt often saves an assistant reply as a note, then can't jump to the verses it names. And any reference he types himself ("Gen 1:1") should link too. Today tapping a marked verse shows the edit bar; Edit Note opens a sheet that is always the editor, so he only ever sees markdown.
2. **Leaving the Ask screen is awkward.** Its composer takes the keyboard as the tab opens, so he has to swipe the keyboard down to reach the tab bar.
3. **No way into material about a book.** He wants each book in the Library to link to BibleProject's overview video, with room for People, Places and About later.

## 2. Goals, non-goals, anti-goals

Goals: a note reads as a note with live references, on the phone and the Mac; moving between the phone's main screens is one swipe from either edge; each book links to its BibleProject video, with placeholders for what comes next.

Non-goals: People, Places and About content (placeholders only); BibleProject's logo (section 5.3); changing how notes are stored.

Anti-goals: a reference link that changes the note's text (links are found at display time, never written in); an edge swipe that fights the system back gesture inside a navigation stack, the highlighter, or text selection; a confirmation before any delete (deletes stay undoable).

## 3. Notes that read like notes (Matt chose option A)

### 3.1 What Matt decided

- **Tapping a highlight that has a note opens the note first**, at half height, rendered (no markdown symbols), with its references as links. The same for a noteless anchor (the dotted underline) that has a note.
- **Edit** at the top right turns the same sheet into the editor with the keyboard up. **Done** returns to the rendered note; a swipe down closes the sheet either way. Every change is saved as it's typed, as today; nothing is discarded; a note left empty is removed, as today.
- **The mark's actions run along the foot of the sheet:** the color chip (which opens the list of colors, as the edit bar's does), bookmark, Ask, and delete. Delete closes the sheet and is undoable (shake or three-finger swipe, as everywhere on the phone).
- **A highlight without a note, or a bookmark alone, keeps today's edit bar**, since there is nothing to read.
- **(call) Copy, Copy with Reference and Share stay reachable:** the sheet's foot ends with an `ellipsis.circle` menu holding them (the same three as the edit bar, fed by `MarkupModel.menuItems(for:)` so the two never disagree).
- **(call) With the highlighter pen on, a tap on a highlight keeps today's pen behavior** (select it for recoloring and resizing, with `makeUnderMark`'s menu). The pen is for marking, so the note sheet opens only with the pen off. The pen menu's Edit Note opens the same sheet straight into the editor.
- **Tapping a reference** shows that verse inside the sheet (a push in the sheet's navigation stack) with Back to the note and **Open in Read**. Open in Read is a lookup: it shows the passage and keeps the reader's place, as references in assistant replies already do (`PhoneVerseSheet`, `VersePreviewView`).
- **Any reference typed in a note links, not only ones from the assistant.** Matt: "anyone can type in a reference that should be clickable. Like my typing in Gen 1:1 should become a link." Upper-case forms too ("GEN 1:1").
- **On the Mac**, the same links appear in the notes column's rendered notes and the Notes browser; a click shows the verse in the popover assistant replies already use, with its Open button.

### 3.2 Link rules

The finder is `ReferenceLinker`, used today only for assistant replies (`ChatTurnRow`). It reads `chapter:verse` with optional ranges, and books by name, short name or alias through `ReferenceParser` ("Gen 1:1", "Genesis 1:1–3", "1 Cor 13:4-7", "Ps 91:1"). For notes it changes as follows:

- **Case-insensitive book names** for `chapter:verse` forms: "gen 1:1", "Gen 1:1" and "GEN 1:1" all link. (Today a candidate book must start with a capital or a digit.) **(call)** on lower case; Matt asked for upper case.
- **A bare "5:3" links to the note's own book**, as replies use their conversation's book.
- **A chapter alone links** ("Romans 8", "ROM 8") **only when the book name starts with a capital letter** **(call)**, so prose like "mark 2 items" or "acts 1 by one" is never a link. In assistant replies a chapter alone stays unlinked, as now (**call**: unchanged there).
- Links are computed when the note is shown, never stored. Existing notes get them with no change to their text, and the editor shows plain text.
- A link to a verse the current translation lacks still opens, showing the nearest it has, as replies do now.

### 3.3 Where the rendered note appears

- The new phone sheet (3.1). It replaces `PhoneNoteSheet`'s always-editing behavior: **(call)** a brand-new empty note (Add Note) still opens straight into the editor with the keyboard, since there is nothing to read.
- Notes tab rows and search results keep their current behavior (they open the passage in the reader); the note sheet opens from there by tapping the mark.
- Notes in This Chapter (the phone's chapter-note list) opens the same sheet for a row **(call)**.
- Mac: `NoteRowView`'s rendered (not editing) state and the Notes browser rows gain links; editing is unchanged.

## 4. Edge swipes between the phone's screens

### 4.1 What Matt decided

- **A swipe in from the left edge moves one screen left: Ask → Notes → Read → Library.** **A swipe in from the right edge moves the other way: Library → Read → Notes → Ask.** Matt: "Yes, swipe both directions."
- **It works with the keyboard up**: on Ask the keyboard goes down as the screen changes. This is the problem being solved.
- **Inside a pushed screen, the system back swipe comes first** (agreed in playback): in a conversation inside Ask, the left-edge swipe goes back to the Ask screen; the next one goes to Notes. Only at a tab's root does the left edge change tabs.
- **The screen follows the finger** and settles or springs back on release (agreed in playback); under Reduce Motion it is a cut once the swipe passes the threshold.

### 4.2 Details

- Search sits outside the chain: no edge swipe leads to or from it **(call)**.
- Read's left edge brings in the Library, which is a full-screen cover today (`PhoneShellModel.isLibraryShown`). The Library's right edge closes it back to Read. **(call)** The Library's own left edge does nothing (it is the end of the chain); inside the Library, a book's expanded chapters do not change this.
- The edge zone is the system's (about 20 pt). A drag that starts inside the text, including the highlighter's hold-then-paint and selection handles, is never an edge swipe.
- **(call) Inside the edge zone the edge swipe wins over a list row's swipe actions.** On Notes, a leftward drag that starts within the right edge zone goes to Ask; a row's full-swipe delete starts further in. This way ordinary navigation can never delete a row by accident.
- Sheets over a screen (a note, Ask over the page, Settings) take the swipe for themselves or ignore it; an edge swipe never changes tabs underneath an open sheet.
- VoiceOver users keep the tab bar; the swipe is an addition, not the only way **(call)**: add accessibility actions or rely on the tab bar, the builder's choice.
- The builder chooses the mechanism (a custom container with interactive transitions, or edge-pan recognizers driving `TabView` selection with a matched transition). The system Liquid Glass tab bar stays.

## 5. Reference links in the Library (Mac and phone)

### 5.1 What Matt decided

- **A row of four outlined icons, each with its label underneath, between the book name and its chapters:** BibleProject, People, Places, About.
- **Outlines are rounded squares** (they echo the chapter cells), and BibleProject's icon is the SF Symbol `play.rectangle`. Matt: "Stick with the play.rectangle then and rounded-square outlines."
- **BibleProject opens its video at once when the book has one video, or a small menu listing them when it has more** (John has two, "John 1–12" and "John 13–21").
- **People, Places and About are placeholders** for later features (maps, people, the book's author and background).
- **On the iPhone the video opens in a Safari sheet inside the app** (`SFSafariViewController`); **on the Mac it opens in the default browser.**

### 5.2 Details

- **Placement.** Mac: on the front page's shelf, under each book's name in Display and above its five-across grid (`BookshelfView`, `ChapterGridView`). Phone: inside an expanded book in `PhoneLibraryScreen`, under the book's name, above `LibraryChapterGrid`.
- **Look (call, from the mockup):** each icon a 36 pt (scaled, `@ScaledMetric(relativeTo: .title3)`) rounded square at `AppRadius.lg` with a 1.25 pt outline and the symbol in `accent` at `.body` size; the label beneath in `.caption2` `ink.secondary`, one line. Icons spaced `md` (16) on the Mac, `xs` (8) on the phone; the row `xs` below the name and `sm` above the grid. The outline is a stroke around a button, not a card: no fill. `DESIGN.md` gets this component and the new symbols (`play.rectangle`, `person.2`, `map`, `info.circle`) in its inventory.
- **Placeholders:** shown, not tappable, outline in `ink.rule` and symbol and label in `ink.secondary` at reduced emphasis **(call)**; VoiceOver reads "People, coming later". `person.2` for People, `map` for Places, `info.circle` for About. Labels: "Places" and "About" (Matt offered "Maps" or "Author" as alternatives; **(call)** the shorter general words, so the features can grow).
- **The video table.** A bundled table from book to BibleProject's book overview videos (title and URL). A book may have more than one (Genesis, Exodus, Isaiah, Ezekiel, Matthew, Luke, John, Acts and Romans, among others, are split in two), and every book with more than one gets the menu. A video may cover two books (1–2 Samuel) and then appears under both. **(call)** Links are bibleproject.com video pages, not YouTube: the publisher's own page is the stable address and plays the video in the Safari sheet. The builder compiles the table from bibleproject.com's book overview series and checks every URL resolves; Matt reviews it. Books without an overview video show the BibleProject icon as a placeholder too.
- **One-chapter books on the phone** (Obadiah, Philemon, 2 John, 3 John, Jude) open their chapter directly when tapped in the Library and never expand. **Their icon row always shows under the book's name** (Matt, 2026-11-12, chose this over expanding them or a trailing button): tapping the name still opens the chapter in one tap, and the row is its own set of buttons beneath. `LibraryList`'s one-chapter rules (commit 848f29f) are unchanged. On the Mac every book already shows its grid, so nothing differs there.
- No network access is added to the app beyond opening the URL; nothing is fetched or cached.

### 5.3 BibleProject's logo

Not used. It is BibleProject's trademark; an App Store release would need their permission. The SF Symbol stands in; if Matt later gets permission, swapping the symbol for the logo is a one-asset change.

## 6. Verification

On the iPhone (Debug build, `.dev` identity, seeded with `-phoneSeed YES`) and the Mac:

1. A note containing "see GEN 1:1, Rom 8 and 5:3" on John 15:5: tapping the highlight opens the rendered note with Gen 1:1, Romans 8 and John 5:3 as links; tapping each shows the verse in the sheet with Back; Open in Read keeps the reading place.
2. Edit, type, Done: back to the rendered note with the change; reopen shows it; the Mac's column shows the same links.
3. A highlight without a note shows the edit bar; Add Note opens the editor with the keyboard.
4. Delete from the sheet's foot, then shake: the highlight and note return.
5. On Ask with the keyboard up, a left-edge swipe lands on Notes with the keyboard down; continue to Read and Library; right-edge swipes walk back to Ask. Inside a conversation, the first left swipe goes back to the Ask screen.
6. The highlighter and text selection near the edges never trigger a tab change.
7. John in the Library: the BibleProject icon offers "John 1–12" and "John 13–21", as Genesis' offers its two; Ruth's opens directly; 1 Samuel and 2 Samuel open the same video; Jude shows its row under its name without expanding, and a tap on the name still opens Jude; the video opens in a Safari sheet (phone) or the browser (Mac). People, Places and About do nothing and VoiceOver says "coming later".

## 7. Open questions

None. The one raised in review (where one-chapter books show their icons) is answered in 5.2.

## 8. As built (2026-11-13): sections 4 and 5

Section 3 (notes that read) was built later the same week; see "Section 3 as built" below.

- **Edge swipes** are `PhoneEdgeSwipes`: two plain pans on the window. Each takes only touches that start in its 24 pt edge zone and begins only on an inward, mostly sideways move. The system's screen-edge pan never began for the simulator's touches. A swipe that starts while the last one is still settling lands the last one at once, so quick swipes walk several screens. Between tabs, the screen being left is a picture and the arriving tab is live from the first frame; the tab bar stays put. The release rule is the system back swipe's: past half the width, or a 300 pt/s flick. Under Reduce Motion the screen cuts once the finger is 60 pt in. **(call)** The edge zone is 24 pt.
- **(call) Library is no longer a full-screen cover.** It is a layer over the tabs and the tab bar that slides in from the left. Its button, Close and a chosen chapter use the same slide, so it always comes from where the swipe says it lives.
- **(call) The right edge works inside a pushed screen** (only the left edge belongs to the back swipe there).
- **The video table** (`BibleProjectVideos`) comes from BibleProject's Old and New Testament Overviews collections. All 66 books have a video and 10 have two. Videos shared between books: 1 & 2 Kings, 1 & 2 Chronicles, Ezra–Nehemiah, 1–3 John. **1 and 2 Samuel have separate videos**, not one shared video as section 5.2 supposed. Daniel's and Esther's "Second Edition" videos are the Deuterocanon's longer versions and are left out. Each page answered 200 to a browser; the site challenges plain command-line requests (a bot check), which does not affect opening the links.

### After Matt's first look (2026-11-16)

- **One-chapter books open like the others**, showing the icons and a single "1". The name no longer reads the chapter at once. This replaces section 5.2's rule that their icons always show under a name that opens the chapter.
- **The icons sit in four equal columns** across the row, each centred, with rounder outlines (`AppRadius.xxl`, 14).
- **Swipes are drawn in pictures only.** The live tabs never move, because the Notes and Ask titles were seen against the left edge after a swipe. The glass bar buttons are missing from the pictures, so they disappear for the length of a swipe.
- **A slow drag in from an edge never began.** When the pan asked whether to begin, its translation still read zero, so the inward test failed. The pan now measures from where the touch came down.
- **At the chain's ends** (Ask's right edge, Library's left) the edge pan holds the drag and nothing moves. Before, the drag passed to whatever was underneath.

### Section 3 as built (2026-11-16)

- **`ReferenceLinker`'s note rules** follow 3.2, with one addition **(call)**: a lower-case word of one or two letters is never a book, so "this is 5:3" is not Isaiah while "IS 5:3" is. A book's own short name typed in lower case still links ("mat 1:1", "act 3:2"). A chapter alone links only behind a capital, and not as part of a range ("Romans 1-3"), a decimal or a larger number.
- **`NoteBodyText`** renders a note on both apps: markdown blocks with the links in the accent. On the Mac a click shows the verses in a popover on the note, with Open. The Notes browser's rows show the first block with its links.
- **The phone's note sheet** follows 3.1. Taps on a highlight with a note (pen off), on a note's margin mark, or on a Notes in This Chapter row open it to read. Add Note, the pen's Edit Note and an empty note open in the editor. **Done** returns to reading.
- **(call)** The sheet's two pages sit on `paper.page` rather than the sheet's glass, so nothing of the note shows through behind a pushed verse.
- **(call)** The colour menu lists the colours and No Color; Add Color stays on the edit bar.
- **(call)** A chapter note's foot has delete alone.
- **(call)** A reference to verses the translation lacks opens nothing, as in a reply. Section 3.2's "the nearest it has" was not built.
