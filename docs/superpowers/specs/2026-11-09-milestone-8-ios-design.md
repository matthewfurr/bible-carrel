# Milestone 8: the iPhone app

Design agreed with Matt on 2026-11-09. It extends `2026-10-26-reading-through-scripture-design.md` (the spec), whose milestone 8 line reads: "iOS target reusing `ScriptureUI`, adaptive layouts for iPad and iPhone, share sheet, keyboard shortcuts. Deliverable: the mirror on an iPhone." Where this document and the spec disagree, this document wins for milestone 8.

Lines marked **(call)** are choices Claude made that Matt has not explicitly confirmed. Everything else under "What Matt decided" is his.

The mockups Matt approved are saved beside this file in `milestone-8-mockups/`. They are HTML fragments from the brainstorming companion: open them in a browser for the phone drawings; the surrounding page layout is missing outside the companion. They show structure and behaviour, not final pixels. Colors, type and spacing come from `DESIGN.md` and `Palette.swift`, never from the mockups.

## 1. Intent

Matt reads through the Bible on his Mac and wants the same app on his iPhone 17 Pro Max (iOS 27.0). On the phone he does the same jobs as on the Mac: read the day's chapters, highlight, write notes, look up a verse.

The phone also has one job the Mac never has. At his group's discussion time he wants to pull up what he wrote while other people are talking. Today that is a paper notebook, and he has to hunt for the spot. He wants to:

- scroll the passage being discussed and see where his notes and highlights sit;
- search across all his notes;
- narrow to what he wrote in a recent stretch, from the past week up to the past year;
- ask the assistant a question that came up in the room and get an answer with references he can open.

Recall in the room is the thing to get right. It ranks ahead of comfortable long-form typing on the phone.

## 2. Goals, non-goals, anti-goals

### Goals

1. An iPhone app with the Mac's full feature set: reader, highlights in his colors, notes, bookmarks, the notes browser, the assistant, settings, sync.
2. Finding a past note or highlight in a few seconds, by passage, by word, or by how recently it was written.
3. Asking a question quickly from anywhere and getting an answer whose references open the verse.
4. Marking text on a touch screen that is as quick as the Mac's drag-select: a pen mode, plus the standard iPhone selection.
5. The system Liquid Glass tab bar and system chrome throughout. Matt asked for this by name.
6. The cross-device checks milestone 7 deferred (section 7) run and pass between the Mac and the phone.
7. The shared improvements in section 5 land on the Mac as well, since the code is shared.

### Non-goals

- **iPad.** Matt has no iPad he would read on. The app is iPhone-only for now (**call**: set the target's device family to iPhone so it does not ship an untested iPad layout). The spec's "iPad keeps the side column" waits for a later milestone.
- A landscape-specific layout. Portrait is designed; landscape must work but gets nothing special (**call**).
- App Store or TestFlight listing. `PRODUCT.md` holds this until translation licensing is settled.
- Moving the Release build to CloudKit's Production environment (**call**). It stays on Development, as it went live in milestone 7. Risk 3 in section 8 says why this is worth a thought before the phone joins.
- Apple Pencil, widgets, Apple Watch, Live Activities.
- Turning references inside Matt's own notes into links. Only assistant replies get tappable references (**call**).
- The "known minors" backlog at the end of the milestone 7 plan, except where this work touches the same code.
- Sharing notes with other group members.

### Anti-goals

These would make the milestone a failure even if every feature works.

- Putting Matt's real synced data at risk during development. The Release identity and its store stay off limits until he gives a go-ahead (section 6).
- A pen that makes scrolling unreliable, or scrolling that paints by accident.
- Custom-drawn glass that imitates or re-skins the system's, or glass on content (rows, tiles, cards, the page).
- Regressions on the Mac from moving code into shared, cross-platform form.
- The anti-references in `PRODUCT.md`: a consumer Bible app, a web page in a window, a card grid, chrome that competes with the page. One bottom bar that shrinks on scroll is the whole of the navigation chrome.

## 3. Constraints and facts found in the code

- Native Swift and SwiftUI. The reader uses TextKit through a representable, as the spec says: `UITextView` on iOS where the Mac uses `NSTextView`.
- `Packages/ScriptureKit/Package.swift` already declares `.iOS(.v26)`. Deployment target stays iOS 26.0 (**call**); any iOS 27 API is gated with `#available`.
- The Mac app target is thin: five files, under 1,000 lines, in `Apps/Mac`. The spec reserves `Apps/iOS/` for the iOS target.
- Of 73 files in `ScriptureUI`, 17 touch AppKit and 20 carry platform conditionals. Most are small (colors, fonts, the export panel). The Mac-only core is the reader: `ChapterTextController` (about 670 lines plus two `NSView` subclasses), `ChapterTextView`, `MarkupGutterView`, `MarkupContextMenu`, and `NoteTextEditor` (an `NSTextView` subclass).
- `ThreadScope` already has a `general` case, so a conversation about anything needs no model or sync-schema change.
- API keys are stored as synchronizable keychain items (`SecretStore.swift`), so iCloud Keychain can carry Matt's cloud key to the phone.
- The Mac's entitlements derive the iCloud key-value store identifier and the keychain access group from the bundle identifier. For reading position, settings and the API key to line up across devices, the iOS app uses the **same bundle identifiers** as the Mac app: `com.matthewfurr.ReadingThroughScripture.dev` for Debug and `com.matthewfurr.ReadingThroughScripture` for Release, team `SFQ7B3J933`, same CloudKit container (**call**, following from how milestone 7 wired these).
- **Both configurations sync through CloudKit's Development environment** (`project.pbxproj` sets `CLOUDKIT_ENVIRONMENT = Development` for Debug and Release; `README.md`; milestone 7 Ruling 15). They differ by container: Debug uses `iCloud.com.matthewfurr.ReadingThroughScripture.dev`, Release uses `iCloud.com.matthewfurr.ReadingThroughScripture`, which holds Matt's real notes. "Reset Development Environment" in CloudKit Console must never be used on the Release container.
- `SyncConfiguration.current()` reads entitlements with `SecTask` on macOS and returns nil elsewhere "until milestone 8". iOS needs its own way to learn the container and environment.
- The Mac's ⌘K palette (`CommandPaletteView`, `PaletteItem`, `PaletteRanker`) is one flat list of references, books, translations, verses, notes and commands. Notes carry no color. Bare highlights, bookmarks and conversations are not searched there.
- The notes browser (`NotesBrowser*`) already searches, sorts by date or reference, and filters by kind (all, notes, highlights, bookmarks, threads). It has no time filter. Each entry has a `modifiedAt`.
- The assistant's replies render markdown; references in a reply are plain text today. Prompts already appear as tonal tiles (`PromptTilesView`).
- `DESIGN.md` says no `.glassEffect()` is applied by the app and Liquid Glass appears only where the system puts it. It has no iOS section yet.
- Project rules in `CLAUDE.md` apply on iOS: semantic text styles, palette tokens only, no card by reflex, deletes undoable without confirmation.
- Testing limits already known in this repo: `swift test` runs on macOS and cannot load asset-catalog colors, so tokens live in `Palette.swift`; UIKit code cannot run under `swift test` at all.
- Toolchain on Matt's Mac today: macOS 26.3.1, Xcode 26.6 with the iOS 26.5 SDK, **no iOS simulator runtime installed, no device paired**. His phone runs iOS 27.0. Matt's decision: if Xcode 26.6 cannot install to the phone, move to **Xcode 27 for both apps**, updating macOS if Xcode 27 requires it. See section 8.
- Matt's assistant is set to answer with Claude (`assistantProvider = anthropic`), and that setting is synced, so the phone has it too.

## 4. What Matt decided: the phone

Mockups: `tab-structure.html` (he chose A), `marking.html` (he chose B), `notes-ask.html`, `search-and-ask-v2.html`.

### 4.1 The tab bar

- The system Liquid Glass tab bar with three tabs and search: **Read**, **Notes**, **Ask**, and the trailing **Search** button (the system search tab). No Library tab.
- Tabs are places. Read is the chapter where he left it and is how he returns from Notes or Ask.
- The bar shrinks out of the way when the chapter scrolls.

### 4.2 Read

- **Library** is a button at the top left of the reader, not a tab. It opens the Mac's bookshelf and chapter grid (`BookshelfView`, `ChapterGridView`) as a full screen that dismisses back to the page (**call** on the presentation).
- The **pen** button and a **⋯** menu sit at the top right.
- The page shows highlights in his colors and, in the right margin, a mark for a note and a mark for a bookmark. Seeing where his marks sit while scrolling is one of the three recall paths. Matt approved this in the mockups.
  - The note mark is **new design for the phone**, not a port. The Mac's gutter draws only a bookmark glyph, in the left margin (`MarkupGutterView.swift`), and shows notes in its side column, which the phone does not have.
  - **(call)** Both marks sit in the right margin on the phone and the Mac is unchanged. The glyphs, and how two marks on one verse stack, are settled in the new iOS section of `DESIGN.md`.
- Tapping a note mark opens that note in a sheet over the lower half of the page; dragging the sheet up gives full height for writing. The ⋯ menu has "Notes in this chapter" for the whole list (**call**).
- **(call)** Chapters do not change by swiping sideways. Sideways drags belong to the pen and to the system back gesture. The chapter ends with the Mac's "Next: John 16" link, with a matching way back, and Library and Search reach anything else.
- **(call)** The ⋯ menu holds translation, text size, Notes in this chapter, and Settings.

### 4.3 The pen

Matt's idea, as he approved it in option B:

1. Tapping the pen turns it on. The button takes the accent tint. The tab bar is replaced by a glass bar of his highlight colors, the current one ringed, with a check button at the trailing end.
2. He drags a finger across words, part of a verse or several verses, and they take the ringed color. The range snaps to whole words, as on the Mac.
3. The new mark is selected. It shows handles for stretching or shrinking it, and a menu appears **under the mark** with **Note, Bookmark, Ask, Delete**.
4. Tapping another color in the bar recolors the selected mark and becomes the pen's color.
5. The check button, or the pen button again, turns the pen off and brings the tab bar back.

Details:

- Tapping an existing highlight while the pen is on selects it the same way.
- **Bookmark** bookmarks the verse or verses the mark touches and keeps the highlight. Bookmarks stay whole-verse, as on the Mac. Matt saw this stated as an assumption and did not object.
- Delete is undoable and never asks, per `CLAUDE.md`.
- **(call)** The color bar shows his colors in their saved order and scrolls sideways if they do not fit. It has no "add color" button; new colors are made in Settings.
- **(call)** The pen stays on across the chapter-end link and turns off when he opens Library.
- `DESIGN.md` already calls for `.sensoryFeedback(.selection)` when a highlight is applied on iOS.

**The open question in this flow** is how one finger both paints and scrolls. Claude's proposal was that a drag starting sideways along a line paints and a drag starting vertically scrolls. This cannot be judged in a simulator. Part 1 of the work (section 6) is a throwaway build on Matt's phone to settle it. If no rule feels reliable, the choice comes back to Matt before anything else is built on it.

### 4.4 Selecting text with the pen off

Matt confirmed this explicitly: pressing and holding on a word selects text the usual iPhone way, and the menu offers the same choices, **including Ask**. The full list follows the Mac's selection menu in the spec: the color swatches, Add Note or Edit Note, Remove Highlight when inside one, Bookmark, Copy, Copy with Reference, Share, and Ask about this passage.

- Tapping an existing highlight with the pen off selects that whole highlight and offers the same menu, as a single click does on the Mac (**call**).
- **Ask from a selection** opens the conversation as a sheet over the page, so he stays in the passage. The conversation also appears in the Ask tab afterwards (**call**).
- The pen is never the only way to mark. Press-and-hold selection, and VoiceOver's text selection, reach every action.

### 4.5 Notes tab

The notes browser, laid out for the phone:

- A list of everything he has marked, newest first by default.
- Three menus above the list:
  - **How far back:** any time, past week, past month, past three months, past year. This is new. It filters on each entry's modified date.
  - **What kind:** the existing filter (everything, notes, highlights, bookmarks, conversations).
  - **Order:** the existing sort (newest first, or Bible order).
- Each row shows the reference, the date, the marked words with their highlight color, and the start of the note.
- Tapping a row opens the chapter at that verse in the Read tab. A conversation row opens it in the Ask tab (**call**).
- **(call)** The time filter starts at "any time" and remembers its last setting on that device. It is not synced.
- **(call)** Export goes through the share sheet from the ⋯ menu. Rows delete with a swipe, undoably.

### 4.6 Ask tab

- The question field is ready as soon as he lands on the tab.
- A tag above it says what the question is about. It starts as the chapter he was last reading ("About John 15"). Removing the tag makes it a question about anything: a `general` conversation, which the Mac already offers as "No context".
- **Prompts** appear as tiles, the same tonal tiles the Mac's assistant uses, under a heading that says they start something.
- **Earlier conversations** appear below as a plain dated list with the conversation icon. Matt asked that prompts and recent conversations be clearly different; tiles against a list is the answer he approved.
- **(call)** The list shows all conversations, newest first, not only those for the current chapter as the Mac's panel does. Recall in the room wants the history.
- **(call)** Prompt tiles show only while the chapter tag is on, since chapter prompts need a chapter's text.
- Each reply keeps the Mac's Copy and Add as Note, and the label saying which model answered.
- Matt's phone supports the on-device model, so a question can be answered with no signal. Because his setting is Claude, that needs the offline fallback in 5.4.

### 4.7 References in an answer

- Every Scripture reference in an assistant reply is a link.
- On the phone, tapping one slides the verse or verses up in a sheet over the lower part of the screen, in the current translation, so he can read them aloud without losing the answer. A button opens the chapter in Read.
- This is new behaviour and lands on the Mac too, where the verse shows in a popover with the same button (**call** on the Mac presentation).
- **(call)** Recognised forms: full references ("John 1:32", "1 John 2:6", "Ps 91:1", ranges like "John 15:4-5"), and a bare chapter:verse resolved against the conversation's own book. Text that does not parse stays plain. The builder may ask the model, in the system prompt, to cite references in full.

### 4.8 Search

One search for everything, reached from the round search button. Matt approved the two result layouts in `search-and-ask-v2.html` and asked for three things by name: results surfaced by type, a note's highlight color shown subtly, and the per-kind icons kept.

- Results are **grouped by kind**, each group with a heading, its icon and a count. Chips across the top narrow to one kind.
- **A word** ("abide"): Your notes first, then conversations ("Asked"), then Scripture in the current translation.
  - A note row shows the words he marked **in the color he gave them**, then the start of the note. The matched word is bold.
  - A verse he has marked carries a small dot in that mark's color.
- **A passage** ("john 15"): the way in ("Go to John 15"), then **everything he marked there in verse order**: notes, bare highlights, bookmarks and conversations. This is the "find the spot" job in one step. It was Claude's addition and Matt approved it.
- Books and translations keep their own groups and icons when the query matches them.
- **(call)** A bare highlight whose words match appears in Your notes with the highlighter icon. Bookmarks appear only in passage results.
- **(call)** App commands (Open Settings and the like) stay a Mac-palette feature and do not appear in phone search.
- **(call)** Before he types, the screen shows one line naming the forms it accepts, in the manner of the Mac palette's no-matches line.
- **(call)** Scripture results show a first batch with a way to see all; the limit is the builder's.

### 4.9 Settings, sharing, keyboard

- **(call)** Settings open from the ⋯ menu as a sheet and reuse the existing settings views: translation, reading, highlight colors, prompts, assistant provider, iCloud status. Text size, line spacing and appearance stay per-device, as Matt chose in milestone 7.
- **(call)** The daily local backup and Restore from milestone 7 run on the phone too, since signing out of iCloud empties the synced store there as well. "Show in Finder" has no phone equivalent.
- Share on a selection uses the system share sheet, with the text and its reference.
- With a hardware keyboard attached, ⌘K opens Search (spec). Other Mac shortcuts carry over where they map; which ones is the builder's.

## 5. What Matt decided: shared changes that also land on the Mac

1. **Grouped search in the ⌘K palette.** The same grouping as the phone: headings with counts, notes showing the marked words in their color, a dot on marked verses, conversations and bare highlights searchable, and a passage query listing his marks there. Keyboard navigation keeps working across groups. Books, translations and commands keep their icons. Matt called the palette's recent updates nice and asked for this as the improvement.
2. **The time filter** in the Mac's notes browser, the same five choices.
3. **Tappable references** in assistant replies (4.7).
4. **An offline fallback for Ask.** Matt's decision: when the chosen cloud provider cannot be reached and the question fits the on-device model, the on-device model answers and the reply's label says so. Today the router always uses a chosen cloud provider that has a key (`LLMRouter.swift`), and a failure shows only the unreachable notice with Try Again.
   - **(call)** The fallback applies when the request fails to connect, before any of the reply has arrived. A reply that breaks off midway keeps today's behaviour. If the request does not fit on-device, or the on-device model is unavailable, the unreachable notice stays.
5. **Looking something up does not move his place.** Matt's decision: jumping to a verse from Notes, from Search, or from a reference in an answer opens the passage with a way back to where he was reading, and only reading on moves the reading position that both devices reopen to. Today any chapter opened becomes the position, it is synced (`PreferenceSync.swift`), and the Mac adopts it at next launch.
   - **(call)** What counts as a lookup: a row in the Notes tab or the Mac's notes browser, a note, mark or verse result in search, and "Open" from a verse sheet or popover. What counts as reading: Library, the chapter-end links, and a "Go to" reference or book result in search, since that is navigating on purpose.
   - **(call)** A lookup becomes his place if he reads on from it, by following its chapter-end link or by dismissing the way back. How the way back looks on each device is the builder's; the Mac already has back and forward history.
   - **(call)** The rule lives in the shared navigation model and applies on the Mac as well as the phone.
   - The cross-device check "the reading position follows" (section 7) means this reading place.

A question about anything needs no Mac work: the Mac's assistant already starts one through "No context" (`README.md`).

The ranking and grouping logic should be one shared, platform-neutral model that both the palette and the phone's search render, so it can be unit-tested with `swift test`.

## 6. Order of work

Matt agreed to three parts, with the phone first.

**Part 1: the reader on his real phone, as a throwaway.** A rough build with the chapter text in a `UITextView`, highlights drawn, and the pen's drag-to-paint, installed on the 17 Pro Max. Its only purpose is to settle the paint-versus-scroll rule (4.3) and to prove the toolchain reaches the phone (section 8). No tests, not kept. What it teaches goes into the plan for part 2.

**Part 2: the iPhone app.** The iOS target in `Apps/iOS`, the tab shell, the reader port, the pen and selection menu, note and Ask sheets, Library, the Notes and Ask tabs, the verse sheet, Search, Settings, sync and backups on iOS, the app icon, and the cross-device checks.

**Part 3: the shared improvements** in section 5. They do not depend on the phone and may be built before, after or alongside part 2. The phone's Search and Notes tabs need the grouped-results model and the time filter, and its jumps need the lookup rule (5.5), so those pieces are in practice built with part 2 and the Mac's views pick them up.

Throughout, the phone runs the **Debug** build: the `.dev` identity and the `.dev` container, paired with the Mac's Debug build. Matt's real notes live under the Release identity and its own container. Installing a Release build on the phone is the go-live step and happens only on his word, as it did in milestone 7.

## 7. Carried from milestone 7

The spec and the milestone 7 plan (Ruling 14) deferred these to "the iPhone in milestone 8". They are done when run between the Mac and the phone while both apps are open:

- a highlight made on one device appears on the other within a minute;
- the reading position follows from one device to the other;
- a change of default translation arrives.

A real iCloud sign-out is still not run on Matt's devices. Identical highlights made offline on two devices still stay as two.

## 8. Risks and things to verify first

1. **Xcode and the phone's iOS version.** The Mac has Xcode 26.6 and the iOS 26.5 SDK; the phone runs iOS 27.0. Xcode 26.6 may refuse to install to it. This is the first thing to check, by pairing the phone. If it refuses, Matt has chosen to move to Xcode 27 for both apps, updating macOS if needed. Installing Xcode and updating macOS are his to do. The Mac app then builds against the 27 SDK, so the "no Mac regressions" check widens from the code that moved to the whole Mac app, and iOS 27 APIs become available behind `#available`.
2. **No simulator runtime.** An iOS simulator runtime must be downloaded before any simulator verification. It is several gigabytes.
3. **The CloudKit environment, if it ever changes.** Release stays on Development in this milestone, so the phone's Release build copies the Mac's settings and nothing below applies. It is recorded because the cost grows with each device: moving Release to Production needs a schema deploy, a fresh store and a copy (milestone 7 Rulings 14 and 15), on every device that holds the store. Separately, a development-signed iOS build receives development push tokens, and Production may not deliver its silent pushes to such a build, which would leave the phone refreshing only on launch or foreground. Neither is planned work.
4. **Paint versus scroll** (4.3), settled by part 1.
5. **The reader port.** `ChapterTextController` holds layout, selection snapping, highlight drawing and hit-testing in AppKit terms. How much becomes shared and how much is rewritten for UIKit is the largest engineering decision in the milestone. Mac behaviour must not change.
6. **Bundled Bible text on the phone.** Eight translations ship inside the app. Confirm the database loads from the iOS bundle and that search speed is acceptable on the device.

## 9. Left to the builder

- How the reader code is split between shared logic and the two platform views.
- How the pen's color bar and the under-mark menu are built, with one rule: use system components (the bottom toolbar, the edit menu, sheets, `searchable`, the search tab) wherever one exists. Any custom `glassEffect` must be justified and recorded in `DESIGN.md` as a named exception to its "the app applies no glass" rule.
- An **iOS section in `DESIGN.md`**, written before the iOS views: the tab bar, the pen, sheets and detents, the SF Symbols added (`highlighter` already exists there; a Library symbol and any others), and how the type ladder and spacing scale apply on the phone. New color pairings go into `PaletteTests`.
- How `SyncConfiguration` learns the container and environment on iOS.
- Hardware keyboard shortcuts beyond ⌘K.
- Result limits and ranking details in search.
- Empty states and copy, in the voice `PRODUCT.md` sets.
- Test strategy: logic in platform-neutral types under `swift test`; UIKit and layout verified in the simulator and on the device.

## 10. What done looks like

- The Debug build installs on Matt's iPhone and opens to the chapter he was reading on the Mac's Debug build.
- He can read, switch chapters and translations, highlight with the pen and with press-and-hold, write and edit a note, bookmark a verse, and undo a delete.
- The Notes tab narrows to the past week and to the past year, and a row opens its verse.
- From the Ask tab he asks a question with no chapter tag, gets an answer, taps a reference in it, reads the verse in the sheet, and opens the chapter from there. The same works with the phone in Airplane Mode while "Answer with" is still set to Claude: the on-device model answers and the label says so.
- After opening a verse from a Notes row, a search result and an answer's reference, quitting and reopening either app returns to the chapter he was reading, not to the verse he looked up.
- Searching a word shows grouped results with his note in its color; searching a passage shows his marks there in verse order.
- The Mac's ⌘K palette shows the same grouping, the Mac's notes browser has the time filter, and references in the Mac's assistant replies open the verse.
- The three cross-device checks in section 7 pass between the two Debug builds.
- The Mac test suite passes and the Mac app behaves as before wherever this milestone did not mean to change it.
- VoiceOver can reach every action without the pen; Dynamic Type and Dark Mode hold on every screen.
- Go-live on the Release identity happens only after Matt says so.
