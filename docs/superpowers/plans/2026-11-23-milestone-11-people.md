# Milestone 11, Project 3: People and the Family Tree Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task: one fresh implementer and one fresh task reviewer per task, on the model each task's **Run** line names (no Fable anywhere in milestone 11), then one whole-project review on Opus with its report written to a file, one fix wave and one scoped re-review. Steps use checkbox (`- [ ]`) syntax for tracking. The ledger is `.superpowers/sdd/2026-11-23-milestone-11-people/progress.md`.

**Goal:** A person's page set like About (the name as a title, an aligned fact list, the first paragraph of the dictionary whole), a family that is a drawn tree on the Mac that never scrolls sideways and a line and household on the phone's rail, a person's (and a place's) verses as one line per chapter that the Mac's arrow keys walk, and a People list in two orders.

**Architecture:**
- **Data, no schema change.** One new batched read, `BibleStore.parents(of:)`, run twice by `PersonPage.load` (the parents' parents, the children's other parent). A pure `FamilyTree` (spec 5.1) is built from the relatives and those two reads.
- **Pure models in `ScriptureUI/Library`.** `VerseLine`/`VerseLines` (spec 6), `DictionaryEntry` (spec 4.2's cut), `PeopleOrder` (spec 7), and for the Mac `FamilyTreeFolding`/`FamilyTreeGeometry`/`FamilyTreeKeys` (spec 5.2) and for the phone `FamilyLine` (spec 5.3). Each is tested without a view.
- **Views.** `LibraryPageTitle` (About's head, shared), `PersonPageView`'s fact list (project 2's `FactList`), `DictionaryEntryView`, `VerseLinesView`/`VerseLineView` (shared by the person's and the place's page, both apps), `LibraryOrderPicker`, `FamilyTreeView` (Mac: a `Layout` for the names and a `Canvas` for the lines, from one geometry) and `FamilyLineView` (phone: `TimelineRail` with a new branch).

**Tech Stack:** Swift 6.2, SwiftUI, Core Text, GRDB, Swift Testing, macOS 26 and iOS 26.

**Spec:** `docs/superpowers/specs/2026-11-23-milestone-11-people-design.md` (approved 2026-11-23). Section numbers below are the spec's. Mockups: `docs/superpowers/specs/milestone-11-mockups/people-and-family.html` (tree C on the Mac, B on the phone) and `person-page-v2.html` (verses, option 2). Matt's corrections after the mockups are in the spec and bind over them: the whole first paragraph (3.3), Show more with no count (3.3), arrows through the runs (6). Handover: `docs/superpowers/specs/2026-11-23-milestone-11-handover.md`, run unattended.

Paths: `PK` is `Packages/ScriptureKit`; `DATA` `PK/Sources/ScriptureData`; `SUI` `PK/Sources/ScriptureUI`; `LIB` `SUI/Library`; `TD` `PK/Tests/ScriptureDataTests`; `T` `PK/Tests/ScriptureUITests`. Renders go to `RENDERS` = `/private/tmp/claude-501/-Users-matt-Code-reading-through-scripture/833408d4-1099-4a4f-9996-0bb2a261fbb6/scratchpad/renders/project-3`.

**Built on, read in the code at `26e0136` (project 2 finished).**
- `PersonPage` (`LIB/PersonPage.swift`): `person: PersonRecord`, `parents, partners, siblings, children: [PersonSummary]`, `here: VerseGroup?`, `elsewhere: [VerseGroup]`, `alsoCalledLine`, `hasDate`, `life(showingDates:)`, `opensEveryBookUpTo = 40`, `opensEveryBook`, `static func load(_ id: Int, inBook book: String?, store: BibleStore) throws -> PersonPage?` (reads `store.person`, `store.relatives(of:)`, `store.verses(ofPerson:)`). `NavigationModel.personPage(_:inBook:)` wraps it.
- `BibleStore` (`DATA/BibleStore+Library.swift`): `relatives(of:) -> [Relative]` (kind in `Relation.allCases` order, then `ordinal`), `people(inBook:)` (verses in the book desc, name NOCASE, id). `Relation` is `father, mother, partner, sibling, halfSibling, child`; `Relative(kind:person:)`; `PersonSummary(id:name:label:verseCount:)`; `PersonRecord` (`label`, `alsoCalled: [String]`, `birthYear`, `deathYear`, `verseCount`, `dictionary`). Table `person_relation(person_id, kind, ordinal, relative_id)`, primary key `(person_id, kind, ordinal)`.
- `PersonPageView` (`LIB/PersonPageView.swift`): `init(page:bookName:navigation:openBooks:anchor:onWalk:onShow:onOpen:)`, `@AppStorage(LibraryDates.showKey)`, scaled 520 column, `lg` padding and spacing, `heading` (`.title2` semibold), `FamilyView(page:onWalk:)`, `LibraryVersesHereSection`, `LibraryVersesByBookSection`, `LibraryCreditLine`, `seedOpenBooks()`, a come-back scroll to `LibraryScrollID.group(anchor.book.id)`. Hosted by `LibraryPeopleView.detail` (`.id(person.person.id)`) and `PhoneLibraryPageView` (`.entity(book, .person)`).
- `FamilyView.swift` holds `FamilyView` and `FlowLayout` (`FlowLayout(spacing:isCentered:)`, also used by `PlacePageView`'s "At the same spot").
- `DictionaryEntryView(_ text:)` (`LIB/DictionaryEntryView.swift`): `pageFace.quoteFont()`, `ink.primary`, three lines by a hidden full text, "Show more", "Easton's Bible Dictionary, 1897" in `.caption` `ink.secondary`. Used by `PersonPageView` and `PlacePageView`.
- `LIB/LibrarySections.swift`: `LibrarySectionHeader(_:)`, `LibraryScrollID.group(_:)`, `LibraryVersesHereSection(title:group:navigation:onShow:onOpen:)` and `LibraryVersesByBookSection(title:groups:openBooks:navigation:onShow:onOpen:)` (both draw `ReferenceRunsText`), `LibraryDatesNotice(hasDate:)`, `LibraryDatesFootnote()`, `LibraryListRow`, `LibraryChosenRowShape`.
- `VerseRuns.references(_:) -> [Reference]` and `VerseGroup(book:count:references:)`, built only in `VerseGroup.groups(_:)` (`LIB/VerseRuns.swift`). `ReferenceRunsText` (one `Text`, a popover at the pointer through `LibraryPassageView(passage:onOpen:)`, which shows `VersePreviewView`) stays for About's rail.
- Project 2's pieces: `FactList(_ rows: [FactRow])`, `FactRow(_ label:, spoken:, startsGroup:, actions: [FactRow.Action], value:)` (`LIB/FactList.swift`); `LibraryNameRun(_ names: [LibraryNameRun.Name], more:, tail:, onWalk:, onMore:)` with `Name(entity:name:)` (`LIB/LibraryNameRun.swift`); `TimelineRail { }` (a `LazyVStack`), `RailRow(marker:leading:above:below:showsLeadingColumn:spoken:content:)`, `RailMarker { dot, ring, none }`, `RailSegment { none, solid, dashed }` (`LIB/TimelineRail.swift`); About's head inline in `LibraryAboutView.head` (`pageFace.swiftUIFont(.largeTitle, weight: .light)`, `ink.primary`, header trait; subtitle `pageFace.swiftUIFont(.callout, italic: true)` `ink.secondary`; `xxs` between; `md` under the head, before the facts). `LibraryYear.bare`, `text`, `spans(_:)`, `life(birth:death:)`, `span(_:)`.
- People's list: `BookPeople(book:rows:)`, `Row(person:label:)` (label only for a shared name), `title`, `countLabel` ("12 named · by mentions"), `load(book:store:)` (`LIB/BookPeople.swift`). Mac: `LibraryPeopleView` (a scaled 200 pt list, `LibraryListRow`s in a `LazyVStack`, `move(_:in:proxy:)` on ↑ ↓, a `Rectangle` rule at :33); its header count from `LibraryView.countLabel(_:_:)`. Phone: `PhonePeoplePage(people:onChoose:)` with `PhoneLibraryRow`s (`SUI/Phone/PhoneLibraryPages.swift`).
- `PaneWidth.key = "frontPagePaneWidth"` is the pattern for a device-only default (`UserDefaults`, tests on a suite). `SyncedPreferences.keys` (`SUI/PreferenceSync.swift`) is pinned by tests that assert a key is absent.
- Tokens: `Color.accent`, `accentWash`, `inkPrimary`, `inkSecondary`, `inkTertiary`, `inkRule`, `paperPage`, `paperPanel`; `AppSpacing.xxs…xxxl` (4, 8, 12, 16, 24, 32, 48, 64); `AppRadius.md` (6); `HairlineRule(.horizontal / .vertical)`, `HairlineRule.thickness`; `PageFace.font(size:weight:italic:)`, `quotePlatformFont()`, `PageFace.baseSize(_:)`.
- Tests: `FixtureStore.make()` (13 people: David with father Jesse and child Solomon; Mary with partner Joseph and child Jesus, and Jesus with mother Mary and no father; Joseph 1710 with father 682, whose father is Isaac 616). `BenchmarkChapter.realStore()`, `.needsRealBible`, `ReaderBenchmarkTests.median(_:runs:prepare:_:)`, `TestWindow.make(frame:)` (iOS), `LibraryBenchmarkTests.host(_:in:)` (1,100 by 760). Pinning today's family: `LibraryPagesTests.aPersonsPageHasFamilyByGenerationAndVersesHereAndElsewhere` and `LibraryBenchmarkTests.davidsFamilyHasItsSiblings`.
- **Head counts:** package 1,594, iOS `ScriptureUITests` 1,078. SwiftLint 79, impeccable-lint 27, asset checker 0. Old findings in files this plan touches: `FamilyView.swift:68-69` 2 (a `Rectangle` rule), `LibraryPeopleView.swift:33` 2 (the same), `DictionaryEntryView.swift:35` 1 (`accessibilityHidden` on the hidden measuring text); impeccable-lint none in any.

If a name differs when a task is built, say so before going on.

## The data, checked against `Build/bible.sqlite` (schema 6)

- Relations: child 1,785, father 1,584, halfSibling 488, mother 200, partner 207, sibling 4,660, as the spec says. 963 people have children. **806** of them (not 834) have no partner and no child with a named mother; nothing tests this figure. 16 children have a named mother who is not their father's partner. Only four relations repeat a person within one family, all Lot's: each daughter is her son's mother and his half-sibling, and Lot is both her father and her son's father.
- **David (994):** label none; born −1084, died −1014 ("about 1085 to 1015 BC"). Father Jesse; Jesse's father Obed (his only grandparent). Siblings by ordinal: Abinadab, Eliab, Elihu, Nethaneel, Ozem, Raddai, Shammah. Half-siblings: Abigail (27), Zeruiah. Partners by ordinal: Abigail (26), Abital, Ahinoam, Bathsheba, Eglah, Haggith, Maacah, Michal (the only one without children). Named mothers: Bathsheba of Nathan, Shobab, Solomon, Shammua (in that order); Eglah of Ithream; Maacah of Absalom; Abital of Shephatiah; Haggith of Adonijah; Ahinoam of Amnon; Abigail (26) of Daniel. Not named (11): Eliphalet, Elpalet, Elishua, Tamar, Eliada, Ibhar, Jerimoth, Japhia, Elishama, Nepheg, Nogah. 896 verses in 28 books; in 2 Samuel 226 verses in 23 chapters, 116 runs, chapter 1 "1-5, 11, 13-17", chapter 3 "1-2, 5-6, 8-10, 12, 14, 17-22, 26, 28, 31, 35". Dictionary: 26 paragraphs (separated by a blank line, `"\n\n"`), the first 331 characters.
- **Jacob (682):** label "Israel"; born −1835, died −1688. Father Isaac, mother Rebekah; grandparents Abraham and Sarah (Isaac's), Bethuel (Rebekah's). Sibling Esau. Partners Bilhah (Dan, Naphtali), Leah (Levi, Issachar, Reuben, Dinah, Zebulun, Simeon, Judah), Rachel (Benjamin, Joseph), Zilpah (Gad, Asher); every child's mother is named.
- **Jesus Christ (905):** father Joseph (1715), mother Mary (1938); grandparents Jacob (683, Joseph's), Heli (Mary's). Siblings James, Joses, Jude, Simon. 24 other names.
- **Jesse (903):** father Obed; grandparents Boaz and Ruth. Children by ordinal: Abinadab, Shammah, Ozem, Eliab, Raddai, David, Elihu, Nethaneel; no partner, no named mother. One-paragraph entry (513 characters).
- **Judah (1751, "patriarch"):** no partner in the data. His children's mothers are both named and neither is his partner: Daughter of Shuah (993) of Onan, Shelah, Er; Tamar (2821) of Pharez, Zerah. Siblings 6, half-siblings 6. See Departure 1.
- **A person with no family:** Ziba (3060), in 2 Samuel (13 verses), no relations, a one-paragraph entry.
- **Daughter of Lot - Younger (984):** child Ben-ammi, who is also listed as her half-sibling; half-sibling Moab; father Lot, who is also Ben-ammi's father.
- **The dictionary:** 2,773 entries (1,814 people, 959 places); 2,530 one paragraph; 171 with a first paragraph over 850 characters; the longest first paragraph 4,016 characters (Nehemiah, 2172). Jerusalem (place 636) has 14 paragraphs, the first 742 characters.
- **God (1324):** 8,587 verses; in Psalms 962 verses in 150 chapters (12 lines shown, then "138 more chapters").
- **Data names, not the spec's:** "Pharez", not "Perez"; David's half-siblings by ordinal are Abigail, Zeruiah (the mockup wrote Zeruiah, Abigail). Labels can be references ("1 Samuel 22:5") and are shown as the data has them (spec 4.1).

## Before Task 1 (the controller)

1. Copy this plan's Global Constraints to `.superpowers/sdd/2026-11-23-milestone-11-people/global-constraints.md`.
2. Run the pre-flight scan the handover describes against the code as it is; write `preflight.md` beside the ledger and rule each conflict in a "Pre-flight rulings" section of this plan before Task 1.
3. Record the suites' head counts in the ledger (1,594 and 1,078 expected).

## Pre-flight rulings (controller, before Task 1)

The scan is `.superpowers/sdd/2026-11-23-milestone-11-people/preflight.md` (68 interfaces: 63 match, 3 differ, 1 partly, 1 not run; 5 conflicts, 7 gaps, 23 notes). Each item is ruled as the scan proposed; the numbers are the scan's. Each binds the task it names over the task's own text.

1. (Task 1) The nearer relation wins by an explicit precedence `[.father, .mother, .partner, .child, .sibling, .halfSibling]` in `FamilyTree.make`; `Relation`'s case order is untouched. Departure 7's "`Relation.allCases` order" is read as this list.
2. (Tasks 8-10) Tests that call `SystemFamilyTreeMeasure` or `FamilyTreeSpeech` are `#if os(macOS)`; `FixedMeasure` tests, `FamilyChip`, `FamilyFold`, `FamilyTreeFolding`, `FamilyTreeGeometry`, `FamilyTreeKeys` stay unguarded; in `FamilyTreeLayout.swift` only `SystemFamilyTreeMeasure` is guarded.
3. (Task 8) The lines add: each grandparent pair's bar and a drop from its midpoint (or from a lone grandparent) to its parent's top; the two parents' bar and the drop from its midpoint; a rise to every slot on the mothers' row, its chip and the "not named" label included; a drop from the label to its first child or its chip. `everyNameHangsFromALine` stands.
4. (Task 10) At an edge `next` returns the same id and the key is handled (focus stays). "No move stays put" means "no move lands on nothing".
5. (Tasks 4, 5, 9, 10) The tree's names, chips and "Fewer" carry `.focusable(false)`, so the tree's own `.focusable()` is its one Tab stop; a verse run is a `Text` whose `AttributedString` carries the link (clicks through `openURL`, as `ReferenceRunsText`) or a `.focusable(false)` button, never a bare `Button`; "n more chapters", Show more and Show less stay buttons and take Tab.
6. (Tasks 1, 8, 9) A grandparent's slot id carries its parent ("grandparent-2841-58"); each sits over its own parent (Terah twice over Isaac's parents, as Departure 6 for Lot); `FamilyTreeSpeech` names a grandparent once; `FamilyTreeTests` adds a shared-grandparent case.
7. (Task 7) `peopleOrder:` defaults to `.mostNamed` so Places' `countLabel` calls stand; Task 7's Files add `T/LibraryPagesTests.swift`.
8. (Task 7) Labels compare with `localizedStandardCompare` too (none first), then id.
9. (Task 7) `switchingOrderKeepsTheChosenPerson` is replaced by a test of `nonisolated static func chosenID(showing: LibraryEntity?, in rows: [BookPeople.Row]) -> Int?` on `LibraryPeopleView` (the body uses it), in both orders on the fixture. The scroll into view is the controller's live pass.
10. (Task 13) DESIGN.md:507 (the phone's People and "A person") is updated too.
11. (Task 7) Renders add Sepia on the Mac and Dark and Sepia on the phone.
12. (Task 4) The report greps `ReferenceRunsText(` and shows only About's rail (`LibraryAboutView.swift`) left (spec 3.4).
13. (Task 1) `Relative` gains `public init(kind: Relation, person: PersonSummary)`; Files add `DATA/LibraryRecords.swift`.
14. (Task 1) No tuple arrays in `#expect`: compare mapped ids separately or as strings.
15. (Task 5) `let handled = focus.move(1, count: 3)` then `#expect(handled && focus.index == 2)`; no mutating call inside `#expect`.
16. (Task 7) `theOrderIsKeptOnThisDeviceOnly` is `@MainActor`.
17. (Task 11) Departure 25 built as written, each head and run of children set in by the elbow; a call for Matt in As built.
18. (Task 6) The never-written words bind text the app composes (speech, `FamilyLine`, summaries, facts), not the stored label, which is shown as stored (spec 4.1; the importer builds "son of …" from the source's gender, which the database does not keep). As built says so.
19. (Task 1) The interim heading writes `"also called " + alsoCalled`; `lived(birth:death:)` is `spans` for both years and `life(birth:death:)` otherwise, so the born/died words live once.
20. (Tasks 3, 9, 12) `DictionaryEntryView` shows the first paragraph whole until a width is known; `FamilyTreeNamesLayout` computes and caches the geometry from its proposed width so the first pass draws the tree, and the `Canvas` reads the same memo; if it stays width-driven, Task 12's benchmarks spin the run loop once before timing and say so.
21. (Task 3) The entry's memo is computed in the `onGeometryChange` action and `.onChange(of:)` the scaled size and face; `body` only reads it.
22. (Task 4) `PersonPageView` and `PlacePageView` seed `allChapters` in `init` with `State(initialValue: LibraryVersesAnchor.initialChapters(…))`.
23. (Task 4) Run frames live in a reference holder in `@State` (as `RunPointer`), not `@State` values.
24. (Task 4) The chapter column is `ZStack(alignment: .trailing) { Text("000").hidden(); Text(chapter) }`, no frame width, no `accessibilityHidden`.
25. (Tasks 4, 11) Task 4's render checks the chapter number's baseline; if off, `FlowLayout` gains `explicitAlignment(of:)` for `.firstTextBaseline` (its first row).
26. (All UI tasks) A chevron `Image(systemName:)` is written inside its `Button`'s label (or a `Label`); every `RoundedRectangle` is `.continuous`; no literal in `.frame`; no `.onTapGesture` without a label.
27. (Task 8) If David's folded mothers at 472 are not 3, pin what is measured, report the widths, record it in As built; no rule changes to force three.
28. (Task 8) The eleven are measured against every mother's column before the mothers' row folds.
29. (Task 9) The folded siblings read in their group's place as the chip ("7 siblings, folded"); a call in As built.
30. (Task 10) Add `static func fallback(for id: String, in geometry: FamilyTreeGeometry) -> String` (the chip that holds the id, else "person").
31. (Task 8) `SystemFamilyTreeMeasure` keeps no font in a `static let`; fonts per call or in `init`, widths by `CTLine`, as `BookNameMeasure`.
32. (Task 11) A one-name row is one element ("Obed, grandparent") with the link trait and its action; a run row is one element reading its text with a named action per name and for "and n more".
33. (Task 13) As built corrects the figures: Lot's younger daughter has a sibling; 815 (not 806) have children and no partner and no other named parent; Simon's child Judas Iscariot has no parent link back. No test pins them.
34. (Task 11) `theWordsAreTheDatasOwn` tests, as whole words, the strings the app composes, not the data's names.
35. (Note) The APIs the plan uses exist on macOS 26 and iOS 26; no ruling needed.

## Departures and open calls

Each is built as written. Each is **(call, unattended)**, and each that Matt may want otherwise goes on his list in the spec's "As built" (Task 13).

1. **Judah has no partner.** Spec 13 says Judah's tree has "a column for Tamar beside his partner"; the data has no partner for him, so his mothers' row is two non-partner mothers, Daughter of Shuah (Onan, Shelah, Er) then Tamar (Pharez, Zerah), in the order their children appear. The test pins that. *Cost if wrong:* none in the code; the rule is 5.1's.
2. **The fold at the default width is measured.** The rule is 5.2's as written: a side of the person's generation folds only when its names do not fit it. With the system font, David's two half-siblings may fit at 472 pt and stay open, where the mockup folded them. Task 8's real-data test asserts spec 13's figures where they hold (the siblings, Michal, Maacah and Haggith into "3 more", the eleven) and pins the measured state of the half-siblings, with the widths written in the task report and As built. No rule is added to force a fold. *Cost if wrong:* one constant or condition in `FamilyTreeFolding.fold`.
3. **"Nothing at a width wide enough" means nothing across.** The eleven's fold is by height (5.2: taller than the tallest mother's column plus three lines), which no width changes, so at 2,000 pt David still shows "11". *Cost:* a tall column if Matt wants it open when there is room.
4. **The folded "Mother not named" keeps its label;** the eleven become a chip "11" under it. VoiceOver: "Children, mother not named: 11, folded" and the button trait.
5. **The other parent.** A child's column is headed by its `mother`, or by its `father` when the person is that mother (5.1's call). With no other parent named, the column is "Mother not named", or "Father not named" when the person is the child's mother. In the fixture, Mary's son Jesus sits under "Father not named", beside her partner Joseph's empty column.
6. **Lot shows twice on each daughter's page,** as her father and over her son's column. Hiding him would lose the fact that he fathered the son; it happens on two pages. *Cost:* a repeated name there.
7. **One relation per person in a tree,** the nearer winning, in `Relation.allCases` order (father, mother, partner, child, sibling, halfSibling): a child who is also a half-sibling is a child; a mother who is also a half-sibling is a mother.
8. **The Family fact** counts the household when the person has a partner or a child ("8 partners, 21 children", "5 children"), else the family they were born to ("2 parents, 4 siblings"), half-siblings counted among the siblings; singulars "1 partner", "1 child", "1 parent", "1 sibling". This is how the spec's two examples read.
9. **Grandparents are links drawn in `ink.tertiary`,** not the accent (5.2's first row sets their ink; 5.1 makes every name a link). *Cost:* a link that does not look like one.
10. **An open chip's run** is a band the tree's width directly under the generation it belongs to (siblings and half-siblings under the person's row, the mothers and the eleven under the children), joined by a 1 pt line from where the chip stood, ending in `chevron.up` "Fewer". An opened "3 more" lists each mother with her children after her ("Haggith: Adonijah · Maacah: Absalom · Michal").
11. **Too narrow for a chip beside the person:** the generation becomes one row centred as a whole; if that is still wider than the column, the siblings' chip, the person and the half-siblings' chip each take a line. The tree is never wider than its column.
12. **The tree's keys:** Tab enters on the person; ← → go to the nearest name on the same line; ↑ ↓ to the nearest name wholly above or below (least vertical gap, then least distance between centres, ties to the leading side); Return walks to a name and also opens or closes a chip; Space opens or closes a chip and does nothing on a name; Return on the person does nothing.
13. **The verse lines' keys:** Tab onto a line focuses its first run; ← → stop at the line's ends (Tab goes on); the system ring is drawn on the focused run's rounded rectangle and the run is on `accent.wash`; a click anchors the popover at the clicked run, not at the pointer. Focus returns to the line when the popover closes.
14. **Coming back to a run past the twelfth line** opens that book's lines and scrolls to the run's chapter line (`LibraryScrollID.line`), not only to the book.
15. **"n more chapters" has no way back** once opened (an Elsewhere book still closes by its row). The phone's "and n more" siblings and partners likewise.
16. **Ten lines are counted with Core Text** (`CTFramesetter` at the column's width and the Quote font's size), which can break a line differently from SwiftUI by a word; sentences come from `String.enumerateSubstrings(options: .bySentences)`, which may end a sentence after an abbreviation ("2 Sam."). *Cost:* a cut a line early or late, or after an abbreviation.
17. **Show less** reads "Show less of the dictionary entry" to VoiceOver.
18. **A to Z** compares names with `localizedStandardCompare` (case and numbers as Finder sorts), then the data's label (none first), then id; the header's count reads "12 named · by name" in that order ("· by mentions" stays for Most named).
19. **People's order is stored under `libraryPeopleOrder`** ("mostNamed", "alphabetical"). The phone's control is at the regular size (touch), the Mac's at `.small`.
20. **Lived** is `LibraryYear.spans` for a birth and a death ("about 1085 to 1015 BC", "about 4 BC to AD 30"), "born about 1755 BC" or "died about 1056 BC" for one; the footnote sits under the fact list when Lived shows.
21. **The title is one view,** `LibraryPageTitle`, taken out of About's head unchanged and used by both pages (project 5 takes it too).
22. **Named:** "226 verses here, 896 in 28 books"; "12 verses here" when every verse is in this book; "896 verses in 28 books" on a whole-Bible page and on a book's page where the person has no verse; singulars "1 verse", "1 book".
23. **The phone's folds hide two or more:** siblings show three then "and n more" only when n ≥ 2 (else all); partners show three then "and n more partners" only when n ≥ 2 (Jacob's four all show). The fold counts partners only; non-partner mothers and "Mother not named" follow the fold line.
24. **The phone's line is one rail row per person** (Jacob: Abraham, Sarah, Bethuel, Isaac, Rebekah, then Jacob), each with its relation word.
25. **The rail's branch:** the trunk's line runs on below the person as the household's line, with an elbow (`RailMarker.elbow`) to each head and a short inline elbow (`RailElbow`) before each run of children; the last row's line stops at its elbow. The person's dot is `RailMarker.accent`.
26. **The performance budgets** (spec 11): David in 2 Samuel and God's whole-Bible page with Psalms open each open (hosted, 1,100 by 760) under 150 ms, milestone 10's People budget; David's load under 50 ms, as God's. If a before figure (Task 1) is over 150, the bound is 1.5 × it rounded up to 10 ms, as project 2's Departure 17, and As built says so.
27. **The backlog's M17 line holds two items;** its first (the middle row) is deleted, its second (the data's own capitals in labels and titles) stays as a line of its own.
28. **The section header's count** ("In 2 Samuel · 226 verses") shows on a place's page too, since the section is shared.
29. **The Mac's narrow render** is `PersonPageView` alone, 380 pt wide (the tree at 332); a whole window that narrow would not show the list.
30. **Open chips are `@State` of `PersonPageView`** (a `Set<FamilyChip>`), reset per person, not remembered.
31. **One-chapter books** are a named set, `VerseLines.oneChapterBooks = ["OBA", "PHM", "2JN", "3JN", "JUD"]` (spec 6's list; people and places are only in the 66).
32. **A long first paragraph stops at the last sentence that ends within ten lines.** Spec 4.2 says "the end of the sentence that reaches the tenth line", which could include a sentence running on to the twelfth; spec 13's check says "stops at a sentence end within ten lines". The check is built. *Cost if wrong:* up to one sentence less shown; one comparison in `DictionaryEntry.shown`.

## Global Constraints

**Where and how to work**
- Work only in `/Users/matt/Code/reading-through-scripture/.claude/worktrees/milestone-11-ui-improvements`, branch `milestone-11-ui-improvements`. Never push or merge; never commit to `main`.
- Git: `/usr/bin/git -C <worktree>`, one git command per Bash call, no `cd … &&`, loops or shell variables. Every commit message ends with the `Co-Authored-By:` line your session gives you, as a second `-m`.
- `rtk` shortens command output; `rtk proxy <command>` when all of it is needed.
- One implementer in the worktree at a time; implementers dispatch no subagents. Rules: `docs/superpowers/process/implementer-rules.md`, `reviewer-rules.md`.
- **Implementers never launch, quit, relaunch or send keys to the Mac Debug app or the simulator's app.** The live passes are the controller's, under milestone 10's handover rules (keys only, the Debug app frontmost and matched by pid, idle time checked first).

**Matt's data**
- Never touch the Release apps, `Scripts/install-app.sh`, `/Applications`, `~/Library/Application Support/ReadingThroughScripture` or its keychain item. The `.dev` store and its preferences get nothing.
- **No test writes `UserDefaults.standard`.** An order or dates setting in a test or render is `.defaultAppStorage(suite)` on the hosted view with a `UserDefaults(suiteName: "<Suite>-\(UUID().uuidString)")!` removed at the end, or a parameter of a pure function.

**What is stored (spec 9)**
- **People's order, on this device only: `UserDefaults` key `libraryPeopleOrder`, values `"mostNamed"` (the default) and `"alphabetical"`,** read and written through `@AppStorage(PeopleOrder.key)`. Not in `SyncedPreferences.keys`, not in the store, not in the export. Approved by Matt, 2026-11-23 ("Yes, all three (Recommended)").
- Nothing else. Open chips, opened chapters and "Show more" are `@State`. The Bible database stays at schema 6; no import, no digest change.

**The spec's values (verbatim)**
- **Head (4.1):** the name in the page face at the book title's size on About (`pageFace.swiftUIFont(.largeTitle, weight: .light)`, `ink.primary`, header trait); the subtitle under it in the page face's italic `.callout` `ink.secondary`: the data's own `label` where it has one ("son of Boaz", "father of Abijah"), nothing where it has none; the app never builds a subtitle of its own.
- **Fact list rows, in this order, each only when it has something:** Father, Mother (each a link that walks to that person); Also called (the names, comma-joined); Lived ("about 1085 to 1015 BC", only with Show dates on and only where the data gives a birth or death year); Named ("226 verses here, 896 in 28 books" on a book's page; "896 verses in 28 books" on a whole-Bible page; "12 verses here" when every verse is in this book); Family ("8 partners, 21 children", "2 parents, 4 siblings"; leaves out a kind with none; absent with no family; "siblings", never "brothers").
- **Never written by the app:** "son", "daughter", "brother", "sister", "eldest", "youngest", "grandfather". The data's own "father" and "mother" may be said.
- **Dictionary (4.2):** the first paragraph whole (paragraphs are the stored newlines); a first paragraph longer than about ten lines at the page's width stops at the end of the sentence that reaches the tenth line, no ellipsis; a sentence that alone runs past ten lines is cut at the tenth line with an ellipsis; **Show more**, in the accent, under the text, only when anything is hidden, **no count beside it**; it opens the whole entry in place; **Show less** closes it; "Easton's Bible Dictionary, 1897" under it; ink `ink.primary`; VoiceOver reads the shown text, Show more is a button "Show more of the dictionary entry".
- **Order of the page (4.4):** head, dictionary entry, **Family**, **In <book>**, **Elsewhere**, the credit line; the dates notice at the head when it shows; section headers in the Label style (`.caption` semibold `ink.secondary`, header trait).
- **The Mac's tree (5.2):** generations top to bottom, names centred in their places, 1 pt `ink.rule` lines (a vertical drop from a parent, a horizontal bar across a generation, a vertical rise to each name); the tree's width is the column's, never a sideways scroll. Rows: 1 grandparents, `ink.tertiary`, `.callout`, each over its own parent; 2 parents, `.body`, links; 3 the person's generation: siblings to the leading side, half-siblings to the trailing side on a dashed bar (`ink.rule`, dashed), the person in the middle on `accent.wash` at radius `md`, `.body` semibold `ink.primary`; siblings and half-siblings hang from the parents' drop; 4 the mothers' row: partners and non-partner mothers, `.body` links, on a bar that drops from the person, no relation word written over anyone; 5 children, `.callout` links, stacked under each mother one name per line, and "Mother not named" as the last column, its label `.caption` italic `ink.secondary`, only when the mothers' row exists; a partner with no children has an empty column. With no mothers' row, the children are one row hanging from the person, `.callout` links side by side, and past the width an "n more" chip at the row's end. A row with nobody in it is left out with its lines; a person with no relations shows no tree and no Family section.
- **Names:** SF Pro semantic styles; the Library's link style (the accent) for every name but the person's own.
- **Folding:** when a generation's names do not fit across it at their size with `sm` between them: siblings fold first into "7 siblings" (leading side), then half-siblings into "2 half-siblings"; the mothers' row folds from its end (childless partners first) into "3 more", a folded mother's children with her; children under one mother never fold sideways; "Mother not named" folds into a count chip "11" when it would be taller than the tallest mother's column plus three lines.
- **The chip:** a capsule on `paper.panel` with the count and `chevron.down` in `.callout`, the text in the accent; the one filled shape in the tree; a button, not a card. Clicking opens its names in place as a wrapped run under the bar it hangs from, still joined to it, with `chevron.up` "Fewer" at the run's end; opening never widens the tree. The fold is recomputed when the column's width changes; an open chip stays open across a resize.
- **Sizes:** every gap a step on `AppSpacing`, lines 1 pt, the row pitch a `@ScaledMetric(relativeTo: .body)`. The tree's layout is a `Layout`, not `GeometryReader` nests, and does not re-lay on every scroll.
- **The tree's keyboard:** one Tab stop; ← → within a generation, ↑ ↓ to the nearest name in the generation above or below; Return opens the focused name; Space opens a focused chip; the system focus ring on the focused name's rounded shape.
- **The tree's VoiceOver:** by relation: the person ("David"), "Grandparents: Obed", "Parents: Jesse", "Siblings: …", "Half-siblings: …", each partner then her children ("Bathsheba, partner. Children: Nathan, Shobab, Solomon, Shammua"), each non-partner mother the same way ("Tamar, mother of Pharez and Zerah"), then "Children, mother not named: …" (or "Children: …" with no mothers' row). Each name a link element with its relation as its hint. A folded chip "7 siblings, folded", a button.
- **Motion:** a chip opens or closes with `.snappy` on opacity; a cut under Reduce Motion; lines do not animate.
- **The phone's line and household (5.3):** on project 2's rail. Grandparents: a ring dot, the name `.callout` `ink.tertiary`; parents: ring dots, `.body` links; the person: a filled dot in the accent, the name semibold `ink.primary`; relation words in `.caption` `ink.secondary` after each name: "grandparent", "father", "mother". Under the parents: "Siblings: Abinadab, Eliab, Elihu and 4 more" and "Half-siblings: …" in `.callout` `ink.secondary`, names as links, "and 4 more" a link that opens the list in place. The household indented under the person on a branch line with elbows: each partner a `.body` link, under her after a short elbow her children as a run of `.callout` links; partners with children first; after the third partner the rest fold into "and 5 more partners"; non-partner mothers follow in the same form; then "Mother not named" (italic `.callout` `ink.secondary`) and its children; with no partner and no named mother, the children follow the person as one run of links with no label. Each name pushes that person's page. VoiceOver reads top to bottom, each name a link with its relation.
- **Verses (6):** one line per chapter: the chapter number in `.callout` semibold `ink.secondary` `.monospacedDigit()`, right-aligned in a column wide enough for three figures, then the chapter's runs as links, comma-separated (`3   1-2, 5-6, 8-10, 12, 14, 17-22, 26, 28, 31, 35`); a line wraps under its own runs, never under the chapter number; the app's hyphen ("1-5"); a one-chapter book's runs on one line with no number; a run is one link (Mac: a click opens all its verses in the popover, `VersePreviewView` with Open; phone: a tap pushes the passage page), its reference the whole run ("2 Samuel 1:1-5"); a book with more than **12** chapters' lines shows the first 12, then "n more chapters" in the accent, opening the rest in place. Mac keys: each line one Tab stop; ← → from run to run (the focused run on `accent.wash` at radius `md`); Return opens the focused run's popover; Tab line to line. VoiceOver: "Chapter 3", then each run a link: "2 Samuel 1:1 to 5"; a single verse "2 Samuel 1:11". Header "In 2 Samuel · 226 verses"; an Elsewhere book row keeps its count, opens and closes as before (`opensEveryBookUpTo` 40 unchanged).
- **The list (7):** a segmented control of two, **Most named** (today's order) and **A to Z** (by name, then the data's label, then id): the system `Picker`, `.segmented`, `.small` control size, inside the list's column, `xs` from its top; switching keeps the chosen person chosen and scrolls them into view; one choice for People in every book; the phone shows it at the head of its list; VoiceOver: the system's segmented control labelled "Order".

**UI rules**
- `CLAUDE.md`'s three rules; read `PRODUCT.md` and `DESIGN.md` first; `/impeccable-swift` for every UI change, its command named in each task. Palette tokens only; `AppSpacing`/`AppRadius` by name, `@ScaledMetric` for sizes tied to text; no card, no glass, no shadow; no `.font(.system(size:))`. A rule is `HairlineRule`, not a `Rectangle` with `accessibilityHidden`.
- **Checkers, from the worktree root:** `swiftlint lint --config tools/.swiftlint.yml`; `tools/impeccable-lint/.build/release/impeccable-lint Packages/ScriptureKit/Sources/ScriptureUI Apps`; `swift tools/asset-catalog-checker/check.swift Apps/Mac/ReadingThroughScripture/Assets.xcassets`. Baseline 79, 27, 0. A task adds none in a file it touches or creates; the five old findings above go when their files are touched (79 → 74 expected by the end).

**Speed (spec 11)**
- The largest family (David in 2 Samuel) and the most verses (God, whole Bible, Psalms open) open within Departure 26's budgets; the before figures are Task 1's, the after Task 12's. A row repeated many times (a verse line, a tree name) is its own `View`. No store read per redraw: the page reads once per person, book and translation (`LibraryView`'s cache, the phone's `LoadCache`); a person's lines are built at load (`VerseGroup.lines`), the tree's fold and geometry once per width and open set.

**Tests**
- Swift Testing. Pure tests carry no platform guard; a test that hosts a view is `@MainActor`, in a `.serialized` suite, `#if os(macOS)` for `NSHostingView`. Real-data tests are `.needsRealBible`, in `T/PeopleRealDataTests.swift` (`@Suite struct PeopleRealDataTests`) unless a task says otherwise.
- `swift test` cannot load the package's Color Sets; tokens come from `Palette.swift`. A test never makes a `Map` (a place's page is rendered as `PlacePageView`, never `LibraryPlacesView` or `PhonePlacePage` for the whole Bible). A test never writes the clipboard, the `.dev` store or the network.
- Known flake: `ReaderBenchmarkTests.scrollingWhileTheThumbRevealsKeepsTheFrameCost` and other timing benchmarks under full-suite load; rerun alone.
- Package: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit` (`--filter <Suite>` while iterating). iOS: `xcodebuild test -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath Build/DerivedData -only-testing:ScriptureUITests`. Mac Debug build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData -allowProvisioningUpdates build`. One at a time.

**Renders (every UI task)**
- **Mac:** a temporary `@MainActor` test, `T/PeopleRenderScratch.swift` (`#if os(macOS)`), offscreen, real store. A book's person: `LibraryView` at `LibraryPlace(book:, topic: .people, trail: [.person(id)])` in an `NSHostingView` 1,100 by 3,000 (as `LibraryBenchmarkTests.host`, taller so the page shows whole), the default column. Narrow: `PersonPageView` alone, 380 by 3,000 (Departure 29). A place: `PlacePageView` for Jerusalem (636) in Acts, 600 by 3,000 (never a map). Light and Dark by the host's `NSAppearance`; Sepia by `SepiaMode.set(true)` and `.followsSepia()`, reset after. PNGs to `RENDERS`.
- **Phone:** a temporary test, `T/PhonePeopleRenderScratch.swift` (`#if os(iOS)`), `PersonPageView` (or `PlacePageView`) in a `NavigationStack` in `TestWindow.make(frame:)` 402 by 2,400 on the real store, `window.layer.render(in:)` (never `drawHierarchy`), Light and Dark by `overrideUserInterfaceStyle`, Sepia as above, sizes by `.environment(\.dynamicTypeSize, .large)` and `.accessibility5`; run with `-only-testing:ScriptureUITests/PhonePeopleRenderScratch`.
- Open every PNG with Read. **Delete both scratch files before committing.** A render cannot show the pointer, a click, focus or its ring, a key, a popover, VoiceOver, motion or a text size on the Mac; say so.

## Review Focus

The cases a person meets that the spec's own test list does not pin, most likely first; each has its test in the owning task.

1. **Back from a run past the twelfth chapter line** (David, 2 Samuel 20): the reader expects that line in view, not a closed "11 more chapters" (Task 2, `aComeBackPastTheTwelfthLineShowsThemAll`; Task 4, `theComeBackOpensTheLinesAndScrollsToTheChapter`).
2. **A woman's own page** (Mary in the fixture; the data has no sex): her son sits under "Father not named" beside her partner's empty column, never under "Mother not named" (Task 1, `whenThePersonIsTheMotherTheFatherHeadsTheColumn`).
3. **A first paragraph that is one long sentence:** ten lines and an ellipsis, never the whole 4,016 characters, never nothing (Task 3, `oneSentencePastTenLinesIsCutWithAnEllipsis`).
4. **A narrow column:** the tree never wider than its column, at 320 pt as at 472 (Task 8, `theTreeIsNeverWiderThanItsColumn`).
5. **↑ ↓ in the list after switching to A to Z:** the next row in the order shown, not in the old one (Task 7, `upAndDownFollowTheOrderShown`).

---

### Task 1: The family's data: grandparents and each child's other parent, in two batched reads

**Run:** implementer Sonnet; task reviewer Sonnet. Not a UI change (the old `FamilyView` and `PersonPageView` only keep compiling); the review runs the three checkers.

**Files:**
- Create: `LIB/FamilyTree.swift`
- Modify: `DATA/BibleStore+Library.swift`, `LIB/PersonPage.swift`, `LIB/LibraryYear.swift`, `LIB/FamilyView.swift` and `LIB/PersonPageView.swift` (read the new fields only)
- Test: `TD/BibleStoreLibraryTests.swift`, `T/FamilyTreeTests.swift` (new), `T/PeopleRealDataTests.swift` (new), `T/LibraryPagesTests.swift`, `T/LibraryBenchmarkTests.swift`

**Interfaces:**
- Produces:
  - `BibleStore.parents(of ids: [Int]) throws -> [Int: [Relative]]`: one read (`… WHERE r.kind IN ('father', 'mother') AND r.person_id IN (…)`), each id's father before its mother; an id with neither is absent; `[]` reads nothing.
  - `public struct FamilyTree: Equatable, Sendable` with `public struct Grandparent: Equatable, Sendable { public let person: PersonSummary; public let kind: Relation; public let parentID: Int }`; `public struct Household: Equatable, Sendable, Identifiable { public enum Head: Equatable, Sendable { case partner(PersonSummary), otherParent(PersonSummary, Relation), notNamed(Relation) }; public let head: Head; public let children: [PersonSummary]; public var id: String }` (`notNamed(.mother)` is "Mother not named", `notNamed(.father)` "Father not named"; `otherParent`'s relation is the kind the child names them by); `public let person: PersonSummary, father: PersonSummary?, mother: PersonSummary?, grandparents: [Grandparent], siblings: [PersonSummary], halfSiblings: [PersonSummary], households: [Household], children: [PersonSummary]`; `var parents: [PersonSummary]`, `var hasMothersRow: Bool` (`!households.isEmpty`), `var isEmpty: Bool`, `var summary: String?` (Departure 8); `static func make(person: PersonSummary, relatives: [Relative], parentsOfChildren: [Int: [Relative]], parentsOfParents: [Int: [Relative]]) -> FamilyTree`.
  - `make`, spec 5.1 exactly: one relation per person (Departure 7); grandparents in the order father's father, father's mother, mother's father, mother's mother; siblings, half-siblings and children in `ordinal` order; a child's other parent per Departure 5; households only when the person has a partner or some child has a named other parent, ordered: partners with children (`ordinal`), partners without (`ordinal`), other parents in the order their first child appears, then `notNamed` when any child has no other parent; each household's children in the person's `ordinal` order.
  - `PersonPage` loses `parents, partners, siblings, children` and gains `public let family: FamilyTree`; `alsoCalledLine` becomes `alsoCalled: String?` ("Lord, Son", no "also called"); `life(showingDates:)` becomes `lived(showingDates:) -> String?`; new `namedLine: String` (Departure 22, from `here` and `elsewhere`'s counts). `load` reads the person, the relatives, `parents(of:)` of the parents' ids, `parents(of:)` of the children's ids and the verses: two reads more than today.
  - `LibraryYear.lived(birth: Int?, death: Int?) -> String?` (Departure 20).

- [ ] **Step 1: The benchmarks, before any code change.** Add to `LibraryBenchmarkTests`: `davidsPageLoads` (the median of `PersonPage.load(994, inBook: "2SA", store:)`, `#expect(page != nil && median < .milliseconds(50))`); `davidsPageInSecondSamuelOpens` (hosted by `host(_:in:)` at `LibraryPlace(book: "2SA", topic: .people, trail: [.person(994)])`); `godsWholeBiblePageOpensWithPsalmsOpen` (hosted at `LibraryPlace(book: nil, topic: .people, trail: [.person(1324)])` with `openBooks = ["PSA"]`); both opens `#expect(median < .milliseconds(300))` for now. Run each, and `theWholeBiblePageOfGodLoadsWithinFiftyMilliseconds`, three times alone on today's code. Write the medians and each test's median of three to `.superpowers/sdd/2026-11-23-milestone-11-people/benchmarks.md` and the report. Commit the tests alone: "The person's page's benchmarks, measured before project 3".
- [ ] **Step 2: Write the failing tests.**
  - `TD/BibleStoreLibraryTests.parentsOfManyAreOneRead`: on the fixture, `parents(of: [1710, 905, 1493])` is `[1710: [father 682], 905: [mother 1938]]` (by kind and id); `parents(of: [])` is `[:]`.
  - `T/FamilyTreeTests.swift` (`@Suite struct FamilyTreeTests`), relatives built in code with a helper `person(_ id:, _ name:)`:
    - `childrenSitUnderTheirMotherAndTheRestUnderNotNamed`: partners A (ordinal 0, no child) and B (1); children c1 (mother B), c2 (no mother), c3 (mother M, not a partner): `households.map(\.head)` is `[.partner(B), .partner(A), .otherParent(M, .mother), .notNamed(.mother)]`, children `[c1]`, `[]`, `[c3]`, `[c2]`.
    - `withNoPartnerAndNoNamedMotherTheChildrenHangFromThePerson`: three children, no partner, no mother: `households.isEmpty`, `!hasMothersRow`, `children` in ordinal order.
    - `aChildWhoIsAlsoAHalfSiblingShowsOnceAsAChild`: Lot's daughter's shape (child X also a half-sibling, half-sibling Y): `children == [X]`, `halfSiblings == [Y]`; a mother who is also a half-sibling is only `mother`.
    - `whenThePersonIsTheMotherTheFatherHeadsTheColumn` (Review Focus 2): the person is child k1's `mother` and k1's father is F (not a partner): `.otherParent(F, .father)`; the person has partner P and child k2 whose mother is the person and who has no father: `[.partner(P), .notNamed(.father)]`.
    - `grandparentsSitOverTheirOwnParent`: father F (parents FF, FM), mother M (father MF): `grandparents.map { ($0.person.id, $0.parentID) } == [(FF, F), (FM, F), (MF, M)]`.
    - `theSummaryCountsTheHouseholdElseTheBirthFamily`: "2 partners, 3 children"; "1 partner"; "5 children"; with no partner or child "2 parents, 4 siblings" (two siblings, two half-siblings), "1 parent", "1 sibling"; an empty tree `isEmpty` and `summary == nil`.
  - `PeopleRealDataTests` (real data, figures from "The data, checked"):
    - `davidsTreeHoldsHisGrandparentHouseholdsAndTheEleven`: `PersonPage.load(994, inBook: "2SA")`: `grandparents` Obed over Jesse; siblings and half-siblings in the data's order; `households` heads in order Abigail (26), Abital, Ahinoam, Bathsheba, Eglah, Haggith, Maacah, Michal, `.notNamed(.mother)`; Bathsheba's children Nathan, Shobab, Solomon, Shammua; Michal's none; the last household's eleven in order; `summary == "8 partners, 21 children"`; `namedLine == "226 verses here, 896 in 28 books"`; `lived(showingDates: true) == "about 1085 to 1015 BC"`, `(false) == nil`.
    - `jacobsTreeHasThreeGrandparentsAndFourMothers`: grandparents Abraham, Sarah over Isaac, Bethuel over Rebekah; four partner households (Bilhah, Leah, Rachel, Zilpah) with the children listed, no `notNamed`; `summary == "4 partners, 13 children"`.
    - `jesusAndJesseAndJudah`: Jesus (905, `inBook: "MAT"`): father Joseph, mother Mary, grandparents Jacob (683) over Joseph and Heli over Mary, four siblings, no households, `summary == "2 parents, 4 siblings"`. Jesse (903, `"RUT"`): grandparents Boaz and Ruth, eight children in order, `!hasMothersRow`, `summary == "8 children"`. Judah (1751, `"GEN"`, Departure 1): heads `[.otherParent(Daughter of Shuah, .mother), .otherParent(Tamar 2821, .mother)]` with Onan, Shelah, Er and Pharez, Zerah; no `notNamed`.
    - `lotsDaughterHasHerSonOnceAndLotOverHisColumn`: 984: `children == [Ben-ammi]`, `halfSiblings == [Moab]`, heads `[.otherParent(Lot, .father)]`.
    - `aPersonWithNoFamilyHasAnEmptyTree`: Ziba (3060, `"2SA"`): `family.isEmpty`.
  - `LibraryPagesTests.aPersonsPageHasFamilyByGenerationAndVersesHereAndElsewhere` changed, not deleted: `david.family.parents.map(\.name) == ["Jesse"]`, `family.children.map(\.name) == ["Solomon"]`, no households; `david.lived(showingDates: true) == "about 1085 to 1015 BC"`; `david.namedLine == "2 verses here, 3 in 2 books"`, the whole-Bible page's `"3 verses in 2 books"`; Joseph (1715): `family.parents.map(\.id) == [683]`, heads `[.partner(Mary)]`; Jesus: `alsoCalled == "Lord, Son"`, `lived(showingDates: true) == "about 4 BC to AD 30"`; Mary (1938, `"MAT"`): heads `[.partner(Joseph), .notNamed(.father)]` with Jesus in the second; Joseph 1710: `family.grandparents.map(\.person.id) == [616]`.
  - `LibraryBenchmarkTests.davidsFamilyHasItsSiblings` changed: `family.parents.count == 1 && family.households.count == 9 && family.siblings.count == 7 && family.halfSiblings.count == 2 && family.children.count == 21`.
- [ ] **Step 3: Run them and see them fail** (`--filter BibleStoreLibraryTests`, `FamilyTreeTests`, `PeopleRealDataTests`, `LibraryPagesTests`): compile failures.
- [ ] **Step 4: Implement** as the Interfaces say, each rule documented with its spec section. `FamilyView` draws from `family` (parents; partners from the households, the person, siblings and half-siblings; children) so the page still shows the family until Tasks 9 and 11 replace it; `PersonPageView`'s heading uses `alsoCalled` and `lived`.
- [ ] **Step 5: Run them and see them pass,** then `--filter LibraryBenchmarkTests` (record David's load and both opens, informational).
- [ ] **Step 6: Run the full package suite and the full iOS `ScriptureUITests`, one after the other;** the three checkers (no new finding).
- [ ] **Step 7: Commit:** "A person's family as a tree: grandparents and each child's other parent, read in two batches".

---

### Task 2: Verses as one line per chapter: the model

**Run:** implementer Sonnet; task reviewer Sonnet. Not a UI change.

**Files:**
- Modify: `LIB/VerseRuns.swift`
- Test: `T/VerseLinesTests.swift` (new), `T/PeopleRealDataTests.swift`

**Interfaces:**
- Produces:
  - `public struct VerseLine: Equatable, Sendable, Identifiable { public let chapter: Int?; public let runs: [Reference]; public var id: Int }` (`id` is the chapter, 0 for a one-chapter book).
  - `VerseGroup` gains `public let lines: [VerseLine]`, built in `groups(_:)` from its references (once, at load).
  - `public enum VerseLines { public static let shownChapters = 12; static let oneChapterBooks: Set<String> = ["OBA", "PHM", "2JN", "3JN", "JUD"]; static func lines(_ references: [Reference], book: Book) -> [VerseLine]; static func runText(_ reference: Reference) -> String; static func spoken(_ reference: Reference) -> String; static func chapterSpoken(_ chapter: Int) -> String; static func shown(_ lines: [VerseLine], showingAll: Bool) -> (lines: [VerseLine], hidden: Int); static func moreLine(_ hidden: Int) -> String; static func showsAll(_ lines: [VerseLine], anchor: Reference?) -> Bool }`. `runText` is the verses alone ("1-5", "11"); `spoken` is `displayString` with "-" read as " to " ("2 Samuel 1:1 to 5", "2 Samuel 1:11"); `chapterSpoken` "Chapter 3"; `moreLine` "11 more chapters", "1 more chapter"; `showsAll` is true when the anchor's chapter is a line past the twelfth.

- [ ] **Step 1: Write the failing tests** in `T/VerseLinesTests.swift`:
  - `runsGroupIntoOneLinePerChapter`: references Matthew 1:18-20, 1:24, 2:1: two lines, chapters 1 and 2, `runs.map(VerseLines.runText) == ["18-20", "24"]` and `["1"]`; each run's `displayString` is the whole run ("Matthew 1:18-20").
  - `aOneChapterBookHasNoChapterNumber`: Jude 1:9, 1:14-15: one line, `chapter == nil`, runs "9", "14-15".
  - `twelveLinesShowThenTheRestFold`: 23 lines: `shown(…, showingAll: false)` gives 12 and `hidden == 11`, `moreLine(11) == "11 more chapters"`, `moreLine(1) == "1 more chapter"`; `showingAll: true` gives 23 and 0; 12 lines give 12 and 0.
  - `runsReadInFullWords`: `spoken` of 2 Samuel 1:1-5 is "2 Samuel 1:1 to 5", of 2 Samuel 1:11 "2 Samuel 1:11"; `chapterSpoken(3) == "Chapter 3"`.
  - `aComeBackPastTheTwelfthLineShowsThemAll` (Review Focus 1): `showsAll(lines, anchor: a reference in the 13th line's chapter)` is true; in the 3rd line's, false; nil, false.
  - `PeopleRealDataTests.davidsVersesInSecondSamuelAreTwentyThreeLines`: `here?.lines.count == 23`; the first line chapter 1 with runs "1-5", "11", "13-17"; the third line chapter 3 with the ten runs of "The data, checked"; the sum of runs 116; `here?.count == 226`.
- [ ] **Step 2: Run them and see them fail** (`--filter VerseLinesTests`).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Run the full package suite and the full iOS `ScriptureUITests`, one after the other;** the three checkers.
- [ ] **Step 6: Commit:** "A person's and a place's verses as one line of runs per chapter".

---

### Task 3: The dictionary entry opens with its first paragraph

**Run:** implementer Sonnet; task reviewer Sonnet. `/impeccable-swift typeset`. Review: `/impeccable-swift audit` on `DictionaryEntryView`, plus the three checkers.

**Files:**
- Create: `LIB/DictionaryEntry.swift`
- Modify: `LIB/DictionaryEntryView.swift`
- Test: `T/DictionaryEntryTests.swift` (new)

**Interfaces:**
- Produces:
  - `enum DictionaryEntry { static let shownLines = 10; struct Shown: Equatable { let text: String; let endsInEllipsis: Bool; let hidesMore: Bool }; static func paragraphs(_ entry: String) -> [String]; static func shown(_ entry: String, fits: (String) -> Bool) -> Shown; static func lineCount(_ text: String, font: PlatformFont, width: CGFloat) -> Int }`. `paragraphs` splits on blank lines and drops empty ones. `shown`: one paragraph that fits is `(whole, false, false)`; several, the first fitting, `(first, false, true)`; a first paragraph that does not fit is cut to its longest prefix of whole sentences (`enumerateSubstrings(options: .bySentences)`) that fits, found by a binary search over the sentence ends, `hidesMore: true` (Departure 32); when not even its first sentence fits, that sentence with `endsInEllipsis: true` (the view sets `.lineLimit(10)` and truncates the tail). `lineCount` lays the text out with a `CTFramesetter` at `width` and counts its lines (Departure 16).
  - `DictionaryEntryView(_ text: String)` (same signature): the width from `onGeometryChange`; the Quote font's size `@ScaledMetric(relativeTo: .callout)` seeded from `PageFace.baseSize(.callout)` and its platform font `pageFace.font(size:italic: true)`, so the count follows the text size and the face; `shown` computed once per width, size and face (`@State` memo), never per redraw.

- [ ] **Step 1: Write the failing tests** in `T/DictionaryEntryTests.swift`, with `fits` closures by character count where the font does not matter:
  - `aOneParagraphEntryShowsWholeWithNoShowMore`: `shown("One. Two.", fits: { _ in true }) == Shown(text: "One. Two.", endsInEllipsis: false, hidesMore: false)`.
  - `theFirstParagraphShowsWholeAndTheRestIsHidden`: "A. B.\n\nC." gives "A. B." and `hidesMore`.
  - `aLongFirstParagraphStopsAtASentenceEnd`: four 30-character sentences, `fits: { $0.count <= 70 }`: the first two sentences, `hidesMore`, no ellipsis, the text ending in a full stop.
  - `oneSentencePastTenLinesIsCutWithAnEllipsis` (Review Focus 3): one 500-character sentence, `fits: { $0.count <= 100 }`: the sentence, `endsInEllipsis`, `hidesMore`.
  - `linesAreCountedAtTheWidth`: `lineCount` of a 2,000-character text in the Quote platform font at 12 pt is greater at 200 pt wide than at 472, and one short word is 1.
  - `theRealEntriesFollowTheRule` (`.needsRealBible`): with `fits` = `lineCount(…, quotePlatformFont(), 472) <= 10`: Jesse's entry shows whole with no Show more; David's shows his first paragraph (331 characters) and `hidesMore`; Nehemiah's (2172) 4,016-character first paragraph stops at a sentence end (no ellipsis) within ten lines and is shorter than the paragraph.
- [ ] **Step 2: Run them and see them fail** (`--filter DictionaryEntryTests`).
- [ ] **Step 3: Implement** the model, then the view per Global Constraints › Dictionary: the shown text (or, expanded, the whole entry with its paragraphs), Show more and Show less (`.callout`, the accent, plain buttons, accessibility labels "Show more of the dictionary entry" and "Show less of the dictionary entry"), the source line. The hidden measuring text and its `accessibilityHidden` go (SwiftLint 79 → 78).
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Render:** the Mac's David (2 Samuel) and Jesse (Ruth) pages and the narrow David; Jerusalem in Acts (`PlacePageView`); the phone's David at the default size and `.accessibility5`; all Light, David also Dark and Sepia. Check: David's whole first paragraph and Show more under it with no count; Jesse's whole and no Show more; Jerusalem the same rule. Delete the render files.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers.
- [ ] **Step 7: Commit:** "The dictionary entry opens with its whole first paragraph; Show more with no count, and Show less".

**Controller live pass:** a person's page in the Debug app (David in 2 Samuel, by keys: the pane's People is not a Tab stop, so if it cannot be reached by keys, Matt's list); capture; Tab to Show more, Space, capture; Show less.

---

### Task 4: The verse lines on both apps

**Run:** implementer Sonnet; task reviewer Sonnet. `/impeccable-swift craft` (a new shared component) then `typeset` (the chapter column). Review: `/impeccable-swift audit` on `VerseLinesView`, `LibrarySections`, `PersonPageView` and `PlacePageView`, plus the three checkers.

**Files:**
- Create: `LIB/VerseLinesView.swift` (`VerseLinesView`, `VerseLineView`)
- Modify: `LIB/LibrarySections.swift`, `LIB/PersonPageView.swift`, `LIB/PlacePageView.swift`
- Test: `T/VerseLinesTests.swift`

**Interfaces:**
- Consumes: `VerseGroup.lines`, `VerseLines` (Task 2).
- Produces:
  - `LibraryScrollID.line(_ bookID: String, _ chapter: Int?) -> String`.
  - `struct VerseLinesView: View { init(group: VerseGroup, showsAll: Bool, navigation: NavigationModel, onShowAll: @escaping () -> Void, onShow: ((Reference) -> Void)?, onOpen: @escaping (Reference) -> Void) }`: the shown lines, then "n more chapters" (`.callout`, the accent, a plain button) when lines are hidden.
  - `struct VerseLineView: View { init(line: VerseLine, book: Book, navigation: NavigationModel, onShow: ((Reference) -> Void)?, onOpen: @escaping (Reference) -> Void) }`, its own view: the chapter number in a column as wide as "000" in its own font (measured by a hidden `Text("000")`, so it follows the font), then the runs in `FlowLayout(spacing: 0, isCentered: false)`, each run a `Text(runText)` link in the accent followed by ", " in `ink.secondary` (none after the last), so the line wraps under its runs. Each run's frame in the line's named coordinate space is kept in `@State` (`onGeometryChange`). Mac: a click on a run sets `shown` and the line's one `.popover(item:attachmentAnchor: .rect(.rect(runFrame)))` shows `LibraryPassageView`; phone: `onShow(run)`. VoiceOver: the chapter number an element "Chapter 3", each run an element with `spoken`, the link trait and its action.
  - `nonisolated static func anchorRect(_ index: Int, frames: [Int: CGRect]) -> CGRect?` on `VerseLineView` (the clicked run's frame; nil when unknown, then the popover anchors to the line).
  - `LibraryVersesHereSection(title:group:showsAll:navigation:onShowAll:onShow:onOpen:)` with `nonisolated static func title(bookName: String, count: Int) -> String` ("In 2 Samuel · 226 verses", "In Ruth · 1 verse"); `LibraryVersesByBookSection(title:groups:openBooks:showsAll:navigation:onShowAll:onShow:onOpen:)` where `showsAll: Set<String>` and `onShowAll: (String) -> Void` take a book id; an open book shows `VerseLinesView` indented as today.
  - `enum LibraryVersesAnchor` (in `LibrarySections.swift`, shared by both pages): `static func initialChapters(here: VerseGroup?, elsewhere: [VerseGroup], anchor: Reference?) -> Set<String>` (the anchor's book when its line is past the twelfth, `VerseLines.showsAll`) and `static func scrollID(_ anchor: Reference) -> String` (`LibraryScrollID.line(book, chapter)`, Departure 14).
  - `PersonPageView` and `PlacePageView`: `@State private var allChapters: Set<String>`, seeded from `initialChapters` before the come-back's scroll to `scrollID`.

- [ ] **Step 1: Write the failing tests** in `VerseLinesTests`:
  - `theSectionTitleCountsVerses`: `title(bookName: "2 Samuel", count: 226) == "In 2 Samuel · 226 verses"`, `(…, count: 1) == "In Ruth · 1 verse"`.
  - `aClickAnchorsAtTheRun`: `anchorRect(2, frames: [2: CGRect(x: 40, y: 0, width: 30, height: 16)])` is that rect; an unknown index nil.
  - `theComeBackOpensTheLinesAndScrollsToTheChapter` (Review Focus 1; `.needsRealBible`): for David's page in 2 Samuel and an anchor at 2 Samuel 20:1, `LibraryVersesAnchor.initialChapters(here:elsewhere:anchor:) == ["2SA"]` and `scrollID(anchor) == LibraryScrollID.line("2SA", 20)`; with an anchor in chapter 3, `[]`; with none, `[]`.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement** the views and the sections; both pages hand their `allChapters` and its insert to the sections. `ReferenceRunsText` stays for About's rail. A line is its own `View`; nothing reads the store per line.
- [ ] **Step 4: Run them and see them pass,** and `--filter LibraryBenchmarkTests` (record the medians).
- [ ] **Step 5: Render:** the Mac's David (2 Samuel): "In 2 Samuel · 226 verses", 12 lines and "11 more chapters", the chapter numbers right-aligned on one edge, chapter 3's line wrapping under its runs; a scratch state with `allChapters = ["2SA"]` (23 lines); God's whole-Bible page with Psalms open; Jerusalem in Acts; a person in a one-chapter book (Jude, Philemon or Obadiah: the first the real data names); the phone's David at the default size and `.accessibility5` (the chapter column grows, lines still wrap under their runs); David Light, Dark, Sepia on both. Delete the render files.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers (nothing new in `VerseLinesView.swift`, `LibrarySections.swift`, `PersonPageView.swift`, `PlacePageView.swift`).
- [ ] **Step 7: Commit:** "A person's and a place's verses as lines per chapter, twelve shown, each run one link".

**Controller live pass:** David in 2 Samuel; capture the verses; a click on a run goes on Matt's list (keys only; Task 5 adds the keys).

---

### Task 5: The verse lines' arrow keys and the popover on the focused run (Mac)

**Run:** implementer **Opus**; task reviewer **Opus** (a focus model of our own inside a line, the popover anchored to the focused run). `/impeccable-swift craft`. Review: `/impeccable-swift audit` on `VerseLinesView`, plus the three checkers.

**Files:**
- Modify: `LIB/VerseLinesView.swift`
- Test: `T/VerseLinesTests.swift`

**Interfaces:**
- Consumes: `VerseLineView`, its run frames and `anchorRect` (Task 4).
- Produces: `struct VerseLineFocus: Equatable { var index: Int?; mutating func enter(); mutating func move(_ step: Int, count: Int) -> Bool }` (`enter` sets 0; `move` clamps at the ends and returns whether the key was the line's, always true while focused, Departure 13). On macOS each `VerseLineView` is `.focusable()` with `@FocusState`; `onKeyPress(.leftArrow / .rightArrow)` moves; `onKeyPress(.return)` opens the focused run's popover at `anchorRect(index, frames:)`; the focused run on `accent.wash` at radius `md`, and `.contentShape(.focusEffect, …)` the run's rounded rectangle (as `LibraryPeopleView` shapes its ring with `LibraryChosenRowShape`), so the system ring is drawn on the run. No `focusEffectDisabled` on any ancestor.

- [ ] **Step 1: Write the failing tests:**
  - `arrowsWalkTheRunsAndStopAtTheEnds`: `enter()` gives 0; `move(1, count: 3)` twice gives 2; again stays 2 and returns true; `move(-1)` from 0 stays 0.
  - `returnOpensThePopoverAtTheFocusedRun`: `VerseLineView.popoverAnchor(focus: VerseLineFocus(index: 1), frames:)` is frame 1 (a `nonisolated static` helper the Return handler uses).
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.** Focus returns to the line when the popover closes. Nothing on the phone.
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Render** David's lines on the Mac, Light (nothing should have moved). Say that focus, the ring and the popover are seen only live.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers.
- [ ] **Step 7: Commit:** "On the Mac, arrows walk a verse line's runs and Return opens the focused run's verses".

**Controller live pass (spec 13):** David in 2 Samuel in the Debug app; Tab to the first line, capture (the ring on "1-5"); → twice, capture; Return, capture (the popover at "13-17"); Esc; Tab to the next line, capture.

---

### Task 6: The person's page head: the title, the subtitle and the facts

**Run:** implementer Sonnet; task reviewer Sonnet. `/impeccable-swift typeset`. Review: `/impeccable-swift audit` on `PersonPageView` and `LibraryPageTitle`, plus the three checkers.

**Files:**
- Create: `LIB/LibraryPageTitle.swift`
- Modify: `LIB/PersonPageView.swift`, `LIB/LibraryAboutView.swift` (its `head` becomes `LibraryPageTitle`)
- Test: `T/LibraryPagesTests.swift`, `T/PeopleRealDataTests.swift`

**Interfaces:**
- Consumes: `PersonPage.family`, `alsoCalled`, `lived`, `namedLine` (Task 1).
- Produces:
  - `struct LibraryPageTitle: View { init(_ title: String, subtitle: String?) }`: About's head, unchanged in look (Departure 21).
  - `PersonPageView.Fact: String { case father = "Father", mother = "Mother", alsoCalled = "Also called", lived = "Lived", named = "Named", family = "Family" }` and `nonisolated static func facts(_ page: PersonPage, showingDates: Bool) -> [Fact]` (the order of Global Constraints, each only with a value). Father and Mother are `LibraryNameRun` with one name (`onWalk(.person(id))`, a `FactRow.Action` each); the rest plain `.callout` `ink.primary`. `LibraryDatesFootnote()` under the fact list when `.lived` is among the facts.
  - The page in spec 4.4's order: `LibraryDatesNotice`, the head (`LibraryPageTitle(page.person.name, subtitle: page.person.label)`, `md` under it, the `FactList`), the dictionary entry, Family, the verses, the credit line.

- [ ] **Step 1: Write the failing tests:**
  - `LibraryPagesTests.aPersonsFactsReadInOrder` (fixture): David in Matthew: `facts(_, showingDates: true).map(\.rawValue) == ["Father", "Lived", "Named", "Family"]`; dates off drops Lived; Joseph (1715): `["Father", "Named", "Family"]`; Jesus: `["Mother", "Also called", "Lived", "Named", "Family"]`.
  - `PeopleRealDataTests.theRealFactsAndSubtitles`: Jacob (Genesis) `["Father", "Mother", "Lived", "Named", "Family"]`, `person.label == "Israel"`; Ziba (2 Samuel) `["Named"]`; Judah's `lived(showingDates: true) == "born about 1755 BC"`.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.** About's page draws as before (its render is the check).
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Render:** the Mac's David, Jacob, Jesus (Matthew), Jesse (Ruth), Judah (Genesis), Ziba (2 Samuel) at the default width and David narrow; About Genesis on the Mac (the title unchanged); the phone's David, Jacob, Jesse at the default size and `.accessibility5` (the facts stack); David Light, Dark, Sepia on both; David with dates off (a suite with `LibraryDates.showKey` false). Check: the title light and larger than the facts; Jacob's "Israel" in italic under it, David none; labels right-aligned on one edge; Father a link; the footnote under the facts only with Lived. Delete the render files.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers.
- [ ] **Step 7: Commit:** "A person's page set like About: the name as a title, the data's label, the facts on one edge".

**Controller live pass:** David in 2 Samuel; capture the head.

---

### Task 7: People's order: Most named or A to Z

**Run:** implementer Sonnet; task reviewer Sonnet. `/impeccable-swift craft` (the order control, built to take Places' third segment in project 4). Review: `/impeccable-swift audit` on `LibraryOrderPicker`, `LibraryPeopleView` and `PhonePeoplePage`, plus the three checkers.

**Files:**
- Create: `LIB/LibraryOrder.swift`
- Modify: `LIB/BookPeople.swift`, `LIB/LibraryPeopleView.swift` (`:33` → `HairlineRule(.vertical)`), `LIB/LibraryView.swift` (the count), `SUI/Phone/PhoneLibraryPages.swift` (`PhonePeoplePage`)
- Test: `T/LibraryOrderTests.swift` (new)

**Interfaces:**
- Produces:
  - `public enum PeopleOrder: String, CaseIterable, Sendable { case mostNamed, alphabetical; public static let key = "libraryPeopleOrder"; public var title: String }` ("Most named", "A to Z").
  - `BookPeople` gains `public let rowsByName: [Row]` (sorted once at load, Departure 18), `func rows(_ order: PeopleOrder) -> [Row]`, `func countLabel(_ order: PeopleOrder) -> String` ("12 named · by mentions", "12 named · by name"), replacing `countLabel`; `LibraryView.countLabel(_:_:peopleOrder:)` (its header reads the same `@AppStorage`). Existing callers and tests of both move to the new forms, unchanged in what they assert for Most named.
  - `struct LibraryOrderPicker<Order: Hashable>: View { init(selection: Binding<Order>, orders: [Order], title: @escaping (Order) -> String) }`: `Picker("Order", …)` `.pickerStyle(.segmented)`, `.labelsHidden()`, `.controlSize(.small)` on macOS (Departure 19).
  - `LibraryPeopleView`: `@AppStorage(PeopleOrder.key) private var order: PeopleOrder = .mostNamed`; the picker over the list, `xs` from the column's top and sides; the rows `people.rows(order)`; on a change of order the chosen row scrolls into view (`proxy.scrollTo(chosenID, anchor: .center)`); `nonisolated static func neighbour(of id: Int?, step: Int, in ids: [Int]) -> Int?` used by ↑ ↓. `PhonePeoplePage` the same control at the head of its list, `lg` at the sides, `sm` above and below.

- [ ] **Step 1: Write the failing tests** in `T/LibraryOrderTests.swift`:
  - `aToZSortsByNameThenLabelThenID` (fixture, Matthew): `rows(.alphabetical)` names are in `localizedStandardCompare` order; the two Herods by label ("Matthew 2:1" before "Matthew 14:1"); the two Jacobs ("father of Joseph" before "Israel"); `rows(.mostNamed) == rows`; `countLabel(.alphabetical) == "12 named · by name"`.
  - `upAndDownFollowTheOrderShown` (Review Focus 5): `neighbour(of: 7, step: 1, in: [3, 7, 5]) == 5`, `(of: nil, step: 1, …) == 3`, `(of: nil, step: -1, …) == 5`, `(of: 5, step: 1, …) == nil`.
  - `theOrderIsKeptOnThisDeviceOnly`: `PeopleOrder.key == "libraryPeopleOrder"`; `!SyncedPreferences.keys.contains(PeopleOrder.key)`; `PeopleOrder(rawValue: "alphabetical") == .alphabetical`.
  - `switchingOrderKeepsTheChosenPerson` (`#if os(macOS)`, `@MainActor`, `.serialized`, `.needsRealBible`): host `LibraryView` (as `LibraryBenchmarkTests.host`, with `.defaultAppStorage(suite)`) on 1 Chronicles with its first row chosen; set the suite's `PeopleOrder.key` to "alphabetical"; lay out; `navigation.libraryPlace?.showing == .person(firstID)`; remove the suite.
- [ ] **Step 2: Run them and see them fail** (`--filter LibraryOrderTests`).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass,** and `--filter LibraryBenchmarkTests/peopleInFirstChroniclesOpensWithItsFirstPersonChosen` (within 150 ms).
- [ ] **Step 5: Render:** People in 2 Samuel on the Mac with David chosen, both orders (a suite per order), Light and Dark; the phone's People in 2 Samuel at the default size and `.accessibility5`. Check: the control inside the list's column, `xs` from its top; the rows' order; the header's count. Delete the render files.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers (79 → 76 with Task 3's and this task's fixes).
- [ ] **Step 7: Commit:** "People in two orders, Most named or A to Z, kept on this device".

**Controller live pass:** People in 2 Samuel; Tab to the control, capture (it takes focus); Tab to the list, ↓, capture. The switch itself is not pressed: it would write the Debug app's preferences, which get nothing; it is on Matt's list.

---

### Task 8: The Mac's tree: folding and geometry

**Run:** implementer **Opus**; task reviewer **Opus** (the family tree's layout). Not a view yet.

**Files:**
- Create: `LIB/FamilyTreeLayout.swift`
- Test: `T/FamilyTreeLayoutTests.swift` (new), `T/PeopleRealDataTests.swift`

**Interfaces:**
- Consumes: `FamilyTree` (Task 1).
- Produces:
  - `public enum FamilyChip: Hashable, Sendable { case siblings, halfSiblings, households, notNamed, children }`.
  - `struct FamilyFold: Equatable, Sendable { var siblings = false, halfSiblings = false; var foldedHouseholds = 0; var notNamed = false; var childrenShown: Int? }` (`childrenShown` nil: all; `foldedHouseholds` counts from the households' end, `notNamed` never among them).
  - `enum FamilyTreeStyle: Sendable { case grandparent, name, person, child, chip, notNamedLabel }` and `protocol FamilyTreeMeasure { func size(_ text: String, _ style: FamilyTreeStyle) -> CGSize }`; `struct SystemFamilyTreeMeasure: FamilyTreeMeasure` (`#if os(macOS)`: `NSFont.preferredFont(forTextStyle:)` for `.callout` (grandparent, child), `.body` (name), `.body` semibold plus the wash's `xs` sides and `xxs` top and bottom (person), `.callout` plus the chevron's width and the capsule's `sm` sides and `xxs` top and bottom (chip), `.caption` italic (the label); widths rounded up, by Core Text as `BookNameMeasure.width` does).
  - `enum FamilyTreeFolding { static let gap = AppSpacing.sm; static let notNamedSlack = 3; static func chipLabel(_ chip: FamilyChip, count: Int) -> String; static func fold(_ tree: FamilyTree, width: CGFloat, measure: some FamilyTreeMeasure) -> FamilyFold }`. Labels: "7 siblings", "1 sibling", "2 half-siblings", "3 more", "11", "5 more". The rules are Global Constraints › Folding with the person centred (each side holds `(width − person) / 2 − gap`; Departure 11 when even a chip does not fit); a mothers' column is as wide as its widest of head, children and chip; the eleven fold first (by height, against the shown mothers), then the mothers' row folds one more from its end until it fits with its "n more" column; with no mothers' row, `childrenShown` is the most names that fit with an "n more" chip.
  - `struct FamilyTreeGeometry: Equatable { struct Slot: Equatable, Identifiable { enum Kind: Equatable { case grandparent(PersonSummary), parent(PersonSummary, Relation), person, sibling(PersonSummary), halfSibling(PersonSummary), head(FamilyTree.Household), child(PersonSummary, household: String?), notNamedLabel(Relation), chip(FamilyChip, label: String), fewer(FamilyChip) }; let id: String; let kind: Kind; let frame: CGRect }; struct Line: Equatable { let from: CGPoint, to: CGPoint; let dashed: Bool }; let fold: FamilyFold; let slots: [Slot]; let lines: [Line]; let size: CGSize; static func make(_ tree: FamilyTree, width: CGFloat, open: Set<FamilyChip>, rowPitch: CGFloat, measure: some FamilyTreeMeasure) -> FamilyTreeGeometry }`. Rows as Global Constraints › The Mac's tree; the person's centre on the column's centre; a pair of grandparents centred over their parent; each mothers' column spread across the width (equal gaps), its children stacked under its head's centre one `rowPitch` apart; an open chip per Departure 10 (its names flow at the tree's width, then a `fewer` slot). The lines: the drop from the parents (from the midpoint of a two-parent bar) to the person's generation's bar; a rise to each sibling, chip and the person; the half-siblings' bar and rises `dashed`; a drop from the person to the mothers' bar and a rise to each head; a drop from each head to its first child; for no mothers' row, a drop from the person to the children's bar and a rise to each. Slot ids are stable across widths ("person", "sibling-44", "chip-siblings", …), for focus (Task 10).

- [ ] **Step 1: Write the failing tests** in `T/FamilyTreeLayoutTests.swift`, with a synthetic `FixedMeasure` (every style 10 pt a character wide and 16 pt tall) where the case is by hand:
  - `aSideFoldsOnlyWhenItsNamesDoNotFit`: person "Pat", siblings four "Abelard", half-siblings two "Hana": at 800 nothing folds; at 600 `siblings && !halfSiblings` (316 > 273; 92 fits). Half-siblings three "Hannelore": at 600 both fold.
  - `theMothersRowFoldsFromItsEndChildlessFirst`: heads Anna (child "Bo"), Beth (child "Cy"), Cara, Dora (both childless): at 200 `foldedHouseholds == 0`; at 180 `== 2` (Cara and Dora into "2 more").
  - `theUnnamedFoldWhenTallerThanTheTallestMotherPlusThree`: a mother with 4 children and 7 not named: not folded; 8: folded, `chipLabel(.notNamed, count: 8) == "8"`.
  - `childrenWithNoMothersRowShowWhatFitsThenAChip`: eight children "Abcde": at 500 `childrenShown == nil`; at 300 `== 3` (and "5 more").
  - `theTreeIsNeverWiderThanItsColumn` (Review Focus 4): with `SystemFamilyTreeMeasure`, David, Jacob, Jesse, Judah and Jesus at 472, 320 and 2,000 (and David at 472 with every chip open): every slot's frame inside `0...width`, `size.width <= width`, no two slots' frames overlap.
  - `thePersonIsCentredAndGrandparentsSitOverTheirParent`: David at 472: the person's and Jesse's `midX` are 236 (± 0.5); Jacob: the mean of Abraham's and Sarah's `midX` equals Isaac's, Bethuel's equals Rebekah's (± 0.5).
  - `childrenStackUnderTheirMother`: David at 2,000: Bathsheba's four children share her `midX`, in order, each one `rowPitch` below the one before.
  - `everyNameHangsFromALine`: David and Jesse at 472: each slot below the first row, except a child that is not its column's first, has a vertical line ending at its top centre (± 0.5); the half-siblings' lines are `dashed`, no other line is.
  - `anOpenChipReplacesItsCountWithItsNames`: David at 472 with `open: [.siblings]`: seven `sibling` slots in order, no `chip(.siblings)`, a `fewer(.siblings)` slot after them, all inside the width.
  - `PeopleRealDataTests.davidsTreeFoldsAtTheDefaultWidth` (Departures 2 and 3): `fold(david, width: 472, measure: SystemFamilyTreeMeasure())` has `siblings`, `foldedHouseholds == 3` (Michal, Maacah, Haggith), `notNamed`, and `halfSiblings` as measured (the widths of both sides in the report); at 2,000, `siblings == false`, `halfSiblings == false`, `foldedHouseholds == 0`, `notNamed`. `jacobFoldsNothingAtTheDefaultWidth`: `FamilyFold()` at 472 (or the fold measured, in the report and As built, as the spec allows).
- [ ] **Step 2: Run them and see them fail** (`--filter FamilyTreeLayoutTests`).
- [ ] **Step 3: Implement.** Pure: no SwiftUI views, no store. Document each rule with its spec section or Departure.
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Run the full package suite and the full iOS `ScriptureUITests`, one after the other;** the three checkers (the file is under `ScriptureUI`, so it is scanned).
- [ ] **Step 6: Commit:** "The Mac's family tree as geometry: folds that keep it inside the column, and its lines".

---

### Task 9: The Mac's tree drawn

**Run:** implementer **Opus**; task reviewer **Opus** (the family tree's layout). `/impeccable-swift craft` then `layout`. Review: `/impeccable-swift critique` on `FamilyTreeView` beside the mockup's C (the anti-goals: no card, no boxed people), plus the three checkers.

**Files:**
- Create: `LIB/FamilyTreeView.swift` (`FamilyTreeView`, `FamilyTreeNamesLayout`, `FamilyTreeSpeech`)
- Modify: `LIB/PersonPageView.swift` (the Family section on macOS; `@State private var openChips: Set<FamilyChip>`)
- Test: `T/FamilyTreeLayoutTests.swift`, `T/PeopleRealDataTests.swift`

**Interfaces:**
- Consumes: `FamilyTreeGeometry`, `FamilyTreeFolding`, `SystemFamilyTreeMeasure`, `FamilyChip` (Task 8).
- Produces:
  - `struct FamilyTreeView: View { init(tree: FamilyTree, open: Binding<Set<FamilyChip>>, onWalk: @escaping (PersonSummary) -> Void) }` (`#if os(macOS)`): the width by `onGeometryChange`; the geometry memoized per width and open set (`@State`), so a scroll does not re-lay it; `@ScaledMetric(relativeTo: .body)` row pitch; the names, chips and "Fewer" as subviews of `FamilyTreeNamesLayout: Layout`, which places each at its slot's frame and reports the geometry's size; a `Canvas` behind them strokes `geometry.lines` at `HairlineRule.thickness` in `Color.inkRule` (`dash: [3, 3]` where `dashed`). Names are plain buttons (`onWalk`); a chip a plain button toggling `open` in `withAnimation(reduceMotion ? nil : .snappy)` with an `.opacity` transition; the lines never animate. Styles per Global Constraints.
  - `enum FamilyTreeSpeech { static func reading(_ tree: FamilyTree, geometry: FamilyTreeGeometry) -> [String] }`: the relation order of spec 5.2, one string per group; the view's elements follow it (`accessibilitySortPriority`), each name an element with the link trait, its name as label and its relation as hint ("grandparent", "father", "mother", "sibling", "half-sibling", "partner", "child"); a head's label "Bathsheba, partner" or "Tamar, mother of Pharez and Zerah" (names joined ", " and " and "); a chip's "7 siblings, folded" with the button trait.
  - `PersonPageView` on macOS: the Family section shows `FamilyTreeView` when `!page.family.isEmpty`; the phone still shows `FamilyView` until Task 11.

- [ ] **Step 1: Write the failing tests:**
  - `PeopleRealDataTests.davidsTreeReadsByRelation`: `reading` at 472 (with the fold measured in Task 8; the half-siblings' line follows it) is `["David", "Grandparents: Obed", "Parents: Jesse", "7 siblings, folded", <"2 half-siblings, folded" or "Half-siblings: Abigail, Zeruiah">, "Abigail, partner. Children: Daniel", "Abital, partner. Children: Shephatiah", "Ahinoam, partner. Children: Amnon", "Bathsheba, partner. Children: Nathan, Shobab, Solomon, Shammua", "Eglah, partner. Children: Ithream", "3 more, folded", "Children, mother not named: 11, folded"]`; at 2,000 the siblings' line is "Siblings: Abinadab, Eliab, Elihu, Nethaneel, Ozem, Raddai, Shammah" and Haggith, Maacah and "Michal, partner" have their own lines.
  - `judahsAndJessesTreesRead`: Judah at 2,000 holds "Daughter of Shuah, mother of Onan, Shelah and Er" and "Tamar, mother of Pharez and Zerah"; Jesse at 2,000 ends "Children: Abinadab, Shammah, Ozem, Eliab, Raddai, David, Elihu, Nethaneel".
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass,** and `--filter LibraryBenchmarkTests` (David's open; record).
- [ ] **Step 5: Render** (Mac): David (2 Samuel), Jacob (Genesis), Jesus (Matthew), Jesse (Ruth), Judah (Genesis) and Ziba (no Family section) at the default width; David and Jacob narrow; `FamilyTreeView` for David hosted alone at 472 with `.constant([.siblings])` and with `.constant([.households, .notNamed])` (a chip open); David Light, Dark and Sepia. Check against the mockup's C: generations top to bottom; the lines meet each name's centre with no gap or overshoot; the dashed half-siblings' bar; the person on the wash; chips the one fill; nothing past the column; Jesse's eight in one row. Delete the render files.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers (nothing new in `FamilyTreeView.swift`, `PersonPageView.swift`).
- [ ] **Step 7: Commit:** "On the Mac, a person's family as a drawn tree that folds to stay inside the column".

**Controller live pass:** David in 2 Samuel; capture the tree; the window narrowed is not tried (never resize Matt's windows): Matt's list.

---

### Task 10: The tree's keyboard (Mac)

**Run:** implementer **Opus**; task reviewer **Opus** (focus and keys in a layout of our own). `/impeccable-swift craft`. Review: `/impeccable-swift audit` on `FamilyTreeView`, plus the three checkers.

**Files:**
- Create: `LIB/FamilyTreeKeys.swift`
- Modify: `LIB/FamilyTreeView.swift`
- Test: `T/FamilyTreeKeysTests.swift` (new)

**Interfaces:**
- Consumes: `FamilyTreeGeometry` and its slot ids (Task 8), `FamilyTreeView` (Task 9).
- Produces: `enum FamilyTreeKey { case left, right, up, down }`; `enum FamilyTreeKeys { static func next(from id: String, _ key: FamilyTreeKey, in geometry: FamilyTreeGeometry) -> String; static func start(_ geometry: FamilyTreeGeometry) -> String }` (Departure 12; every slot but a `notNamedLabel` is a stop; no move stays put). `FamilyTreeView`: `.focusable()` once for the whole tree (one Tab stop), `@FocusState`, `@State focused: String?` set to `start` on focus; `onKeyPress` for the four arrows, Return (walk a name, toggle a chip or "Fewer") and Space (toggle a chip); `.contentShape(.focusEffect, …)` the focused slot's rounded rectangle (radius `md`), so the system ring is drawn there. After a fold changes (a resize, a chip), a focused id that is gone falls back to the chip that took it, else the person.

- [ ] **Step 1: Write the failing tests** in `T/FamilyTreeKeysTests.swift` (`.needsRealBible`, geometry of David at 472 and 2,000 with `SystemFamilyTreeMeasure`):
  - `tabEntersOnThePerson`: `start == "person"`.
  - `upAndDownGoToTheNearestGeneration`: from the person ↑ is Jesse, from Jesse ↑ Obed, from Obed ↑ Obed; from the person ↓ the head nearest the centre; from Bathsheba ↓ Nathan, from Nathan ↓ Shobab, from Shammua ↓ Shammua.
  - `leftAndRightStayOnTheLine`: at 2,000 from the person ← is the nearest sibling and → the nearest half-sibling; from the first head ← stays.
  - `aStopThatFoldsAwayFallsBackToItsChip`: `FamilyTreeKeys.fallback(for: "sibling-44", in: geometryAt472) == "chip-siblings"` (add it).
- [ ] **Step 2: Run them and see them fail** (`--filter FamilyTreeKeysTests`).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Render** David's tree, Light (nothing should have moved). Say that focus and its ring are seen only live.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers.
- [ ] **Step 7: Commit:** "The family tree is one Tab stop: arrows between names, Return to walk, Space to open a fold".

**Controller live pass (spec 13):** David in 2 Samuel; Tab into the tree, capture (the ring on David); ↑, capture; ↓ twice and →, capture; Tab to "7 siblings", Space, capture (open); Space on "Fewer"; Return on a name walks (capture the header's "‹ David").

---

### Task 11: The phone's line and household

**Run:** implementer Sonnet; task reviewer Sonnet. `/impeccable-swift craft` (the rail's branch, added to a shared component) then `layout`. Review: `/impeccable-swift audit` on `FamilyLineView` and `TimelineRail`, plus the three checkers.

**Files:**
- Create: `LIB/FamilyLine.swift` (`FamilyLine`, the model), `LIB/FamilyLineView.swift`, `LIB/FlowLayout.swift` (moved from `FamilyView.swift`)
- Modify: `LIB/TimelineRail.swift`, `LIB/PersonPageView.swift` (the phone's Family section)
- Delete: `LIB/FamilyView.swift` (SwiftLint 76 → 74)
- Test: `T/FamilyLineTests.swift` (new)

**Interfaces:**
- Consumes: `FamilyTree` (Task 1), `TimelineRail`, `RailRow` (project 2).
- Produces:
  - `RailMarker` gains `case accent` (the dot filled in the accent) and `case elbow` (no dot: a 1 pt `ink.rule` line from the rail's line to the content's first line, Departure 25); `public struct RailElbow: View` (the short └ before a run, a scaled `sm` wide, to the first line's middle). `LibraryAboutView` is unchanged by this.
  - `enum FamilyLine { static let shownNames = 3; enum Row: Equatable, Identifiable { case grandparent(PersonSummary), parent(PersonSummary, Relation), siblings([PersonSummary], more: Int, half: Bool), person(PersonSummary), head(FamilyTree.Household), moreHeads(Int), children([PersonSummary]); var id: String }; static func rows(_ tree: FamilyTree, open: Set<FamilyChip>) -> [Row]; static func namesText(_ label: String, _ names: [String], more: Int) -> String; static func moreHeads(_ count: Int) -> String }` (Departures 23 and 24). `namesText("Siblings", …, more: 4) == "Siblings: Abinadab, Eliab, Elihu and 4 more"`; `moreHeads(5) == "and 5 more partners"`.
  - `struct FamilyLineView: View { init(tree: FamilyTree, open: Binding<Set<FamilyChip>>, onWalk: @escaping (PersonSummary) -> Void) }` on `TimelineRail` with no leading column; each row one `RailRow` per Global Constraints › The phone's line and household; names as `LibraryNameRun`-style links in one `Text` per row; "and n more" and "and n more partners" links insert into `open`. VoiceOver top to bottom, each name a link with its relation ("Obed, grandparent", "Jesse, father").

- [ ] **Step 1: Write the failing tests** in `T/FamilyLineTests.swift`:
  - `PeopleRealDataTests`-style (`.needsRealBible`) `davidsLineAndHousehold`: `rows(david, open: [])` is grandparent Obed, parent Jesse (father), siblings (Abinadab, Eliab, Elihu; more 4), half-siblings (Abigail, Zeruiah; more 0), person, heads Abigail, Abital, Ahinoam, `moreHeads(5)`, then the `notNamed` head; with `open: [.siblings, .households]` the siblings have all seven and all eight partners show.
  - `jacobsFourPartnersAllShow` (Departure 23): Jacob's rows hold three grandparent rows, Isaac (father), Rebekah (mother), Esau, Jacob, the four heads, no `moreHeads`.
  - `jessesChildrenFollowHimWithNoLabel`: Jesse's rows end person, `children` of eight.
  - `theWordsAreTheDatasOwn`: `namesText` and `moreHeads` as above; a tree with exactly four partners or four siblings yields no `moreHeads` and `more == 0` (Departure 23); no row's text contains "son", "daughter", "brother", "sister" or "grandfather".
  - (`RailMarker.accent`, `.elbow` and `RailElbow` are drawing; their check is the render.)
- [ ] **Step 2: Run them and see them fail** (`--filter FamilyLineTests`).
- [ ] **Step 3: Implement.** `PersonPageView` on iOS shows `FamilyLineView`; `FamilyView.swift` goes, `FlowLayout` moves unchanged to its own file.
- [ ] **Step 4: Run them and see them pass.**
- [ ] **Step 5: Render** (phone): David, Jacob and Jesse at the default size and `.accessibility5`; David Light, Dark and Sepia; About Genesis on the phone (the rail unchanged). Check: the trunk joins Obed to David with no gap; the branch's elbows meet each partner's first line; the short elbow before each run; "Mother not named" italic; at `.accessibility5` names wrap under themselves and the line still joins. Delete the render files.
- [ ] **Step 6: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers (SwiftLint 74).
- [ ] **Step 7: Commit:** "On the phone, a person's family as their line and household on the timeline's rail".

**Controller live pass:** in the simulator, David in 2 Samuel (the Library tab, 2 Samuel, People, David); screenshot; tap "and 4 more"; screenshot; tap Jesse (pushed); back. No setting changed, no notice answered.

---

### Task 12: Speed, and a polish pass

**Run:** implementer Sonnet; task reviewer Sonnet. `/impeccable-swift polish` over `PersonPageView`, `DictionaryEntryView`, `VerseLinesView`, `FamilyTreeView`, `FamilyLineView` and `LibraryOrderPicker`. Review: `/impeccable-swift audit`, plus the three checkers.

**Files:**
- Modify: as the polish and the benchmarks require (only the files this plan created or changed)
- Test: `T/LibraryBenchmarkTests.swift`

- [ ] **Step 1: Measure after:** Task 1's four benchmarks three times each, alone; append to `benchmarks.md`. Each open must be under 150 ms and David's load under 50 ms (Departure 26). If one is not, find why before any change (time the two `parents(of:)` reads, `FamilyTree.make`, the lines, the fold and geometry, the layout) and fix it within the spec (the geometry's memo, the lines built at load, a lazy stack for a book's opened lines); measure again.
- [ ] **Step 2: Set the bounds** (Departure 26): both opens `< .milliseconds(150)` (or 1.5 × a before figure over it), David's load `< .milliseconds(50)`. Run them.
- [ ] **Step 3: Polish** per the command: the rhythm between head, facts, entry, Family and the verses; the tree's row pitch and gaps on the scale; the chips' and "Fewer"'s hit areas (at least a scaled 24 pt on the Mac, 44 pt on the phone); Reduce Motion (a chip's change a cut); Increase Contrast where `Palette` has the variants. Fix within the spec; list anything outside it for the backlog.
- [ ] **Step 4: Render the whole set** (Global Constraints › Renders): the Mac's David (2 Samuel), Jacob (Genesis), Jesus (905, Matthew), Jesse (Ruth), Judah (Genesis) and Ziba (2 Samuel) at the default width and narrow; David's tree with a chip open; the phone's David, Jacob and Jesse at the default size and `.accessibility5`; David Light, Dark and Sepia on both; Jerusalem in Acts on both. Delete the render files.
- [ ] **Step 5: Run the full package suite, the full iOS `ScriptureUITests` and the Mac Debug build, one after the other;** the three checkers (record the totals).
- [ ] **Step 6: Commit:** "A person's page measured against its old open; spacing, sizes and motion settled".

---

### Task 13: The record

**Run:** implementer Sonnet; task reviewer Sonnet. No view changes; the review checks each document against the code as built and runs the three checkers for the final counts.

**Files:**
- Modify: `DESIGN.md`, `DESIGN.json`, `README.md` (its People paragraph, if it describes the page or the family), `docs/superpowers/specs/2026-11-23-milestone-11-people-design.md` (section 15), `docs/BACKLOG.md`

- [ ] **Step 1: DESIGN.md** (spec 10), section 5's Library entry: **People** (`DESIGN.md:374` today): the list's Order control, and the person's page head (the title, the subtitle rule, the fact rows) replacing "the name in `.title2` semibold, the label, 'Also called …' and the years"; the dictionary entry's first-paragraph rule with Show less replacing "three lines then Show more"; **Family** (`:376`) rewritten: the Mac's tree with its folding rule and chip, the phone's line and household, and the sentence "The middle row wraps, and the eye cannot tell a partner from a sibling (backlog)" gone; **A reference** (`:375`) becomes the one-line-per-chapter runs with the Mac's arrow keys. **Rail** (`:389`): the branch (`RailMarker.accent`, `.elbow`, `RailElbow`). New component entries **Verse lines** (`VerseLinesView`, `VerseLineView`) and **Order control** (`LibraryOrderPicker`, for Places' third segment in project 4), and **Page title** (`LibraryPageTitle`). SF Symbols inventory: `chevron.down` and `chevron.up` in the tree's chips and "Fewer". Do's and Don'ts: "Don't write a relation the data does not record (son, brother, eldest)."
- [ ] **Step 2: DESIGN.json:** the same entries ("Family Tree", "Family Line", "Verse Lines", "Order Control", "Page Title", the Rail's branch, People's page); `python3 -m json.tool DESIGN.json > /dev/null`.
- [ ] **Step 3: README.md:** the People paragraph, if any: the page's head and facts, the tree and the household, the verse lines, the two orders.
- [ ] **Step 4: The spec's "As built"** (section 15): what was built, file by file in a line each; every call from this plan's Departures and the ledger's rulings, each marked "(call, unattended)" with its reason and cost; the data's figures (this plan's "The data, checked") and where they differ from the spec (806 not 834; Judah; Pharez; the half-siblings' order); the fold measured for David and Jacob at 472 with the widths; the benchmarks' before and after medians; the checker counts (total and in the touched files; the five old findings fixed); both suites' counts. Then **"For Matt"**: spec 13's "Matt's look" list (David's tree and its chips; the first paragraph and Show more on David, a short entry with none; the verse lines on David and on Jerusalem in Acts; the Order switch and that it is remembered; the phone's line and household for David and Jacob), then the calls he may want otherwise (Departures 1 to 3, 6, 8, 9, 23), then what nobody has seen (the tree at a resized window, a click on a run or a chip by pointer, VoiceOver on the tree and the lines, the phone on a device, the arrow keys if the live pass could not reach the page).
- [ ] **Step 5: docs/BACKLOG.md** (spec 14), under "The Library and study data": add **Grandchildren and great-grandparents on the family tree** and **A person's own timeline**, in the spec's words; delete **A keyboard way to a verse on a Library page (the final review's M2)**; delete the first half of **The family's middle row (M17)** and keep its second half (the data's own capitals) as a line of its own (Departure 27); any item the polish set aside.
- [ ] **Step 6: Run the full package suite, then the full iOS `ScriptureUITests`, one after the other;** record both counts (above 1,594 and 1,078); the three checkers, recorded in "As built".
- [ ] **Step 7: Commit:** "docs: People and the family tree as built: DESIGN, README, the spec's As built and the backlog".

**After Task 13 (the controller):** the whole-project review on Opus (`/impeccable-swift critique` over `PersonPageView`, `FamilyTreeView`, `FamilyLineView`, `VerseLinesView`, `DictionaryEntryView` and `LibraryOrderPicker`), one fix wave, one scoped re-review; then the handover's "Before a project is called done": both suites and both Debug builds one after another, the Mac Debug app restarted after the idle check, **the main spec's milestone 11 box 3 ticked by the controller** (`docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md`: "Built 2026-11-23, unattended; reviewed whole; waiting on Matt's look", the spec named), the handover's table, the ledger copied to `docs/superpowers/ledgers/milestone-11/2026-11-23-milestone-11-people.md`.
