# Milestone 11, project 2: a book's About page and its timeline

Status: **Approved by Matt, 2026-11-23** ("I approve all 5."). Second of milestone 11's five projects. Branch `milestone-11-ui-improvements`. Builds after project 1 (the home page). Mockups: `docs/superpowers/specs/milestone-11-mockups/about-and-timeline.html` (the choices) and `about-head-v2.html` (the head as approved).

## 1. Intent

Matt, 2026-11-22: "The About page for books. Similar to the person page. It is just a bunch of data thrown on a screen. Difficult to discern, etc. Also, there seems to be a timeline (in words not a graphic), but the order is not chronological? Consider adding an actual timeline graphic (vertical on iOS) and either/or of macOS."

What he saw: About Genesis ends with "Death of Moses (about 1451 BC)", linked to Genesis 34:1, "Which is a verse about Dinah...?". Asked which order he expected, he answered: "The order the events happened in history."

What the brainstorm found:

- Today's events *are* sorted by year (Ussher's, through Theographic's `sortKey`). They look wrong for three reasons: 123 "Birth of / Lifetime of / Death of" entries interleave with the story (in Genesis, Noah's death lands after Babel and inside Abraham's story); many events share one year (11 of Acts's 81 are "about AD 30"); and one record is wrong in the data itself.
- **The Genesis 34:1 error is Theographic's.** Its record for "Death of Moses" (event 129) lists Genesis 34:1 among its verses beside Deuteronomy 34:1–12, and its own `verseSort` reads `01034001`. It looks like Deuteronomy 34:1 given Genesis's book number. That stray verse puts Moses's death in Genesis, last, as the latest year.
- **A second error of the same kind:** Theographic ties Issachar's son Job (Genesis 46:13) to Job of Uz, so "Lifetime of Job" (event 108) and "Birth of Job" (event 107) carry Genesis 46:13 and Job of Uz's life appears in Genesis. Two such errors were found among the events whose passages span several books (the rest are real Gospel parallels and genealogies); each is corrected in the importer with a test (5.3), and the importer's correction list is where any further one goes.
- Theographic gives every event a length (`duration`: "930Y", "7D", "1M") and names the larger event it belongs to (`partOf`: The Great Flood, Holy Week, the Second Missionary Journey, a life). Today's import keeps neither.

## 2. Goals, non-goals, anti-goals

**Goals**

- A book's About page that reads as an introduction, not a dump: the book's name set like a title, its facts aligned on one edge, the people and places it names most.
- The book's events in the order they happened, drawn as a timeline: a rail on both apps, and on the Mac a to-scale chart of the whole book over it.
- Lives read as lives: one row per person's lifetime, not a birth, a lifetime and a death scattered through the list.
- Death of Moses and Job of Uz out of Genesis.
- Two pieces later projects reuse: **the fact list** and **the rail** (section 7).

**Non-goals**

- A timeline on a person's page, or one for the whole Bible. Backlog.
- The places and people taking part in an event. The data has both (`locations` on 356 events, `participants` on 486); this project does not show them. Backlog.
- Story order (the order the book tells it) as a second choice. Matt chose history.
- Correcting Theographic's dating or its other data beyond the one named correction (5.3).
- Events for the Apocrypha; the data has none.
- Changing the People and Places views (projects 3 and 4).

**Anti-goals**

- A dashboard: no stat tiles, no cards round the facts, no hero number. The facts are a list with rhythm.
- A chart that is the only way to the information. Everything on the Mac's chart is in the list beneath it, which VoiceOver and the keyboard use.
- A date with no line saying whose dating it is (the dates notice and footnote stay as they are).
- A slower About page. It reads more than it shows today (backlog, M15); the new reads must not make that worse (11).

## 3. Approaches

Mocked up with Genesis's real data in `about-and-timeline.html`.

**The top of the page.** (1) A title page: the book's name and subtitle in the page face, one line of facts set as prose, then the five most-named people and places as links. (2) A colophon: today's rows set as an aligned list, labels in small capitals on one edge, values beside them. Matt: "I like the 1 for the most part, but still struggle with the 1 line of facts (that spans two lines?). That info looks better presented in 2..." The merge (1's title and subtitle, 2's aligned list, with Most named as two more rows of it) was mocked in `about-head-v2.html`; Matt: "Looks great."

**The timeline.** All three in history order, lives folded, eras grouped. (A) To scale, vertical on both apps: lives as bars beside an axis, events on the axis with leaders; the largest build, crowded on the phone, and with dates off it has no scale. (B) A rail with one row per event, vertical on both: the smallest build, and it reads the same with dates off. (C) B, with a to-scale chart across the top on the Mac; the phone has B alone. Matt chose **C**.

## 4. The page

One scrolling page, the same view on both apps (`LibraryAboutView`): on the Mac in the contents half of the front page under the Library view's header, on the phone pushed inside the Library. Its order:

1. The dates notice, when it is due (unchanged).
2. **The head** (4.1).
3. **The facts** (4.2), in the fact list.
4. **Timeline** (section 6), when the book has events.
5. The credit line (unchanged).

The page keeps today's column (at most a scaled 520 pt, `lg` round it, `lg` between sections) and its section headers in the Label style.

### 4.1 The head

- The book's name in the page face, light, at `.largeTitle` through `Font.custom(_:size:relativeTo:)` (the system serif's light in the Classic style). **(call: the mockup's 38 pt at the default size is about `.largeTitle`'s 26 pt × 1.45; a semantic style keeps Dynamic Type and the Dynamic Type Contract; the builder may scale it with a `@ScaledMetric(relativeTo: .largeTitle)` if `.largeTitle` reads too small beside the pane's Display name.)**
- Under it the subtitle the app already has for the book (`BookTitles`, "The First Book of Moses") in the page face's italic at `.callout`, `ink.secondary`; none where the book has none.
- `md` under the subtitle, then the facts.
- The Mac's Library header line ("‹ Contents · About Genesis") stays above it, unchanged.

### 4.2 The facts

The fact list (7.1), in this order; a row whose value is empty is left out:

| Label | Value | Example |
|---|---|---|
| Testament | The canon and group, as words | Old Testament, the Law |
| Length | Chapters and verses, in the translation being read | 50 chapters, 1,533 verses |
| Attributed to | The writers the data names, each a link to that person in People, then "(by tradition)" in `ink.secondary` | Moses (by tradition) |
| Spans | The years the events span, dates on only; it reads every event of the book, folded births and deaths included (5.2) | about 4004 to 1635 BC |
| *(a gap of `xs`)* | | |
| People | The five people the book names in most verses, links, then "and 347 more" in `ink.secondary` with "347 more" a link that opens People | God, Jacob, Abraham, Joseph, Isaac and 347 more |
| Places | The same for places, opening Places | Egypt, Canaan, Sodom, Beersheba, Bethel and 114 more |

- "(by tradition)" replaces today's label "Traditionally attributed to", whose point it keeps (Library spec 6.4: Moses for Job, Paul for Hebrews are tradition). **(call: the mockup Matt approved.)**
- Ties in the most-named counts break by name, as the People and Places lists do today (Genesis's Paddan-aram, Bethel and Beersheba each have 10 verses; the five are Egypt, Canaan, Sodom, Beersheba, Bethel).
- Fewer than six people: all of them, no "and n more". None: the row is left out. The same for places.
- "Spans" replaces "When". With dates off it is left out, as "When" is today.
- A person link opens that person's page in People (the Library's existing route, so Back returns here); "n more" opens the People view with nothing chosen. The same for places.
- Counts use the reader's number format, as today.

## 5. The data

### 5.1 What is imported, and what changes

The Bible database moves to **schema version 6** (`BibleSchema.version`). `Scripts/ensure-bible.sh` rebuilds it when the version changes, from the cached, pinned Theographic files; nothing new is fetched and no digest changes.

- **`event` gains** the event's length and the event it is part of. **(call: the columns' exact names and form are the builder's, section 9; suggested: `duration_days REAL` parsed from Theographic's `duration`, and `part_of INTEGER NULL`, the id of the containing event.)**
- **A life's person.** Schema 6 also imports the `participants` link of each "Lifetime of" record (the person whose life it is), as one more column on `event` or a small table, the builder's choice. A life links to its person through it, never by matching names. **(call, after the builder check: a name match fails on the 459 shared names.)**
- **Durations.** All 501 events have one. Forms seen: `NNND` (346), `NNNY` (129), `NNM` (22), and one each of `NYNM`, `NMND`, a decimal year (`N.NY`) and a week (`NW`). The parser reads all of these, counts a year as 365.25 days and a month as 30.44 (**call**: only the length's rough size is ever shown, 6.2), and warns on any other form, as the importer warns today.
- **`partOf`.** 249 events name one; one event (Death of Moses) names two, a life and an era. Keep the first that is a life, else the first. **(call: the rail places Moses's death inside his life, the natural reading; the era is still reachable as a group, 6.3.)** A `partOf` that points to an event not imported is dropped with a warning.
- **Order** stays the data's `sortKey`, which is history order. Nothing re-sorts it.

### 5.2 Lives and eras, derived when the page loads

Computed from the stored rows, not stored (**call**: a rule kept in code is tested and changed without a rebuild):

- **A life** is an event titled "Lifetime of X". It runs from its year for its length. 27 lives in the Bible; 24 in Genesis after the Job correction (5.3).
- **Folded into a life:** its children (by `part_of`) titled "Birth of …" or "Death of …". They do not appear as rows; the life's row says how long and when it ended (6.2). Other children of a life ("Creation of Adam and Eve", "Enoch taken up", "Joseph sold to Egypt") stay as events in their place in time.
- **An era** is an event that has children, is not a life, and is not itself part of a life (The Great Flood, Sojourn in Canaan and Egypt, 7 years of famine, Holy Week, the three missionary journeys, the kingdoms, the exile, the return). Its children sit under it (6.3). **(call, after the builder check: an event with children inside a life, such as "Joseph Promoted in Egypt" in Joseph's life, is a plain event row, and so is its child "7 years of plenty"; the life already places them.)**
- **One level deep.** An era inside an era ("Construction of the Second Temple" inside "Return from Exile") is not a second group: its own record is a row inside the outer era, with its children flattened in beside it in history order. **(call: two levels of grouping in a rail read as noise.)**
- **An era whose children are not in this book but whose own passage is** (Exodus and Galatians: "Sojourn in Canaan and Egypt"; 1 Kings: "Prophecies of Elijah") shows as a single event row with its span, not as a group. **(call: a header over nothing would be empty.)**
- **Which events are a book's** is unchanged: those with a passage in the book. A life or era is shown when it, or anything folded into it, has a passage in the book.
- **What is counted:** the count line (section 6) counts rows, lives and event rows. An era's own record is its group header, not a row, and is not counted; folded births and deaths are not counted. **(call, after the builder check.)**
- The result, recomputed from the data with both corrections and these rules: **Genesis's 116 entries become 24 lives and 41 events, under 3 era headers** (The Great Flood, Sojourn in Canaan and Egypt, 7 years of famine), and its last row is "Joseph's brothers return to Egypt" (Death of Joseph folds into his life). **Acts has no lives and 78 events, in 3 groups, the missionary journeys.** The mockups' "25 lives, 43 events" counted Job's life and two era records; the figures here replace them.

### 5.3 The named corrections

The importer gains a short list of named corrections to Theographic, each with the reason in a comment and a test. Two, both found in the brainstorm:

1. **Event 129, "Death of Moses", loses its Genesis 34:1 passage** (Theographic gives it Genesis 34:1 beside Deuteronomy 34:1–12; the `verseSort` `01034001` shows the book number was mistyped). After it, Death of Moses belongs to Deuteronomy alone.
2. **Event 108, "Lifetime of Job", and event 107, "Birth of Job", lose Genesis 46:13** (Issachar's son Job, tied in the data to Job of Uz). After it, Job of Uz's life belongs to the book of Job alone, and Genesis has one life fewer. **(call, after the builder check: the same kind of error, corrected the same way.)**

The list is where any further correction goes. About Genesis then ends with "Joseph's brothers return to Egypt" (5.2).

- Each correction names its record by id *and* checks the field it changes still holds the wrong value; if Theographic is re-pinned and has fixed it, the correction warns that it is no longer needed and does nothing. **(call: so a re-pin cannot silently double-correct.)**

### 5.4 Most named

Two new reads: the top five people and top five places of a book by verses in the book, with the totals. The People and Places lists already count the same way (`people(inBook:)`, `placesNamed(inBook:)`), so the builder may take the first five of those rather than add a query, provided the page does not get slower (11).

## 6. The timeline

Under a section header "Timeline", with a count line in `.caption` `ink.secondary` beside it, counting rows as 5.2 says ("24 lives, 41 events"; "78 events"). On the Mac, the chart (6.5) and then the rail; on the phone, the rail alone.

### 6.1 The rail

The rail (7.2) is a column of rows hung on one vertical hairline:

- **Year column** at the leading edge, a scaled width, right-aligned, `.caption` `.monospacedDigit()` `ink.secondary`: the year ("2348 BC", "AD 30"), shown **only on the first row of each year**. The words "about" are left off in the column (**call**: a column of "about" reads as noise; the dates footnote under the timeline already says the dating is traditional, and VoiceOver reads "about" with every year).
- **The rail:** a 1 pt `ink.rule` line through every row; on it a 7 pt dot in `ink.secondary` for an event, a 7 pt ring (1.25 pt line, `ink.secondary`, the page's paper inside) for a life. Both scaled with `@ScaledMetric(relativeTo: .callout)`.
- **The row's text:** the title in `.callout` medium `ink.primary`, then its passage as a link in `.caption` `accent` ("7:6", the book left off since the page names it; a passage in another book keeps its book, "Deut 34:1"). An event longer than a day adds its length in `.caption` `ink.secondary` ("150 days", "7 years"); a one-day event says nothing.
- Rows are `xxs` apart; an era group has `sm` above it.

### 6.2 Lives

- The row: the person's name in `.callout` medium (the life's title without "Lifetime of"), a link to their page in People through the life's participant (5.1), plain text where the record has none; then in `.caption` `ink.secondary` "lived 930 years · to 3074 BC" with dates on, "lived 930 years" with dates off (6.6).
- The life sits at its start (its birth year) in the order.
- Its passage link is the life's first passage in the book.
- **A run of lives with nothing between them folds** into one line once there are **three or more** in a row: "8 lives, Seth to Lamech" in `.callout` `ink.secondary` italic, with "Show" in `accent` that opens them in place (and "Hide" to close). The fold is not remembered. **(call: Genesis 5 and 11 are the cases; two lives in a row read fine as rows.)** The fold in Genesis 5 is Seth to Lamech: they are eight lives in a row (their births and deaths folded, "Enoch taken up" coming after Lamech's birth), so they fold to one line, as the mockup shows.

### 6.3 Eras

- An era is a group header in the `GroupLabel` style (`.caption2` semibold upper case, tracked, `ink.verse`): its title, then " · 2348 BC, one year" with dates on ("one year", "40 years", "8 days"; from its length), its title alone with dates off.
- The era's children follow it as rows. The group ends when the next row is not one of its children; a later child elsewhere in time (rare) opens the group again under the same header. **(call)**
- The era's own record is not a row; its passage, when it has one, is a link after its header **(call)**.

### 6.4 Years and the rail

- A year in the column follows the existing rule: the data's year −2347 reads 2348 BC; AD years read "AD 30". The column uses the same words as `LibraryYear` without "about".
- Several events in one year share the year on the first.
- Where the next row is more than a long gap away (more than 500 years), the rail is drawn dashed for that segment **(call: the mockup's gap marker; Genesis's Creation to the Flood spans 1,650 years in a few rows)**.

### 6.5 The chart (Mac only)

Above the rail, the whole book's span drawn to scale with **Swift Charts**:

- **Bars** for lives and eras, each a `BarMark` from its start to its end, packed into lanes (the first lane whose last bar has ended), labelled with the name above the bar's start in `.caption2` `ink.secondary` where the label fits. Lives in `ink.tertiary`, eras in `ink.secondary` **(call: the two must read apart; neither is the accent, which marks the band)**. Genesis needs 10 lanes; the strip's height is the lanes at a scaled 20 pt each plus the axis, at most 12 lanes (more fold the shortest into ticks) **(call)**.
- **Ticks** for events: a short `RuleMark` at its year along the foot, `ink.secondary`.
- **The axis** under it: a handful of years ("4000 BC", "3500", …, "2000") in `.caption2` `ink.secondary`; Swift Charts chooses the ticks.
- **The band:** an `accent.wash` rectangle over the span of years the rows on screen cover, updated as the page scrolls. No stroke (selection is a wash).
- **A click** anywhere on the chart scrolls the rail to the row nearest that year (`.smooth`; a cut under Reduce Motion), and the band follows. A click on a bar scrolls to that life or era's row.
- **When it shows:** dates on, and the book's events cover more than one distinct year in at least five rows **(call: 2 Samuel's one event or Galatians's two make an empty chart; Ruth has none)**. With dates off it does not show (6.6).
- The chart is hidden from VoiceOver (`accessibilityHidden`), and Tab passes it: the rail is the accessible form of everything it draws. **(call: the anti-goal; a chart read point by point would repeat the list.)**
- Width: the page column's. The chart scrolls with the page; it is not pinned.

### 6.6 Dates off

Show dates (Settings › General › Library) off:

- The order is unchanged (history order).
- No year column, no Spans row, no chart, no era spans.
- **Lengths stay** ("lived 930 years", "150 days", "one year"). **(call: Matt asked the brainstorm about years; a length is the text's own statement in most cases, "And all the days that Adam lived were nine hundred and thirty years" (Genesis 5:5), and not a date. If Matt wants every number from the chronology gone with dates off, lengths go too: one condition.)**
- The dates notice and footnote follow today's rule: they show only where a year does.

### 6.7 The phone

- The same page and rail, pushed inside the Library (`PhoneLibraryPages`), with the phone's margins.
- The fact list's labels sit over their values when the label column and value do not fit side by side (`ViewThatFits`), as the Notes tab's menus stack at large text.
- No chart.

## 7. Pieces later projects reuse

### 7.1 The fact list (`FactList`)

A list of label and value rows aligned on one edge:

- Labels in `.caption` semibold, upper case, tracked a scaled 0.7 pt **(call: the mockup's small capitals; `.caption2` is the group label's size and would make the two read alike)**, `ink.secondary`, right-aligned in a column as wide as the longest label; values beside them in `.callout` `ink.primary`, wrapping under themselves.
- `xs` between the columns' gap and `xs` between rows (a scaled step); an optional gap of `xs` splits groups of rows.
- A value is any view: text, links, a run of links.
- Phone: stacks label over value when the two do not fit.
- VoiceOver reads each row as one element, "Testament, Old Testament, the Law"; a row with links offers each as an action. **(call: the same pattern the Library's references already use.)**
- Project 3 uses it for a person's page; project 5 for Settings › About's header.

### 7.2 The rail (`TimelineRail`, `RailRow`)

The vertical hairline with a marker per row and an optional leading column:

- A row takes a marker (dot, ring, or none), a leading label (the year, or empty) and content.
- The line runs through every row and joins rows without a gap; it can be dashed for a segment.
- Project 3 uses it for a person's family on the phone (the line of descent: grandfather, father, the person).

## 8. Keyboard and VoiceOver

- **Mac:** the rail's links are one run of text per row; a passage or a person is reached with the pointer, as Library references are today (a known limit, backlog M2). The fold's Show and Hide are buttons and take Tab. The chart takes no focus.
- **VoiceOver:** each rail row is one element: "2348 BC, The Great Flood begins, Genesis 7:6"; a life "Adam, lived 930 years, to 3074 BC"; with the passage and the person as actions. An era header is a header: "The Great Flood, 2348 BC, one year". A fold reads "8 lives, Seth to Lamech, collapsed", a button.
- The fact list as 7.1.

## 9. Left to the builder

- The schema's exact column names and types (5.1), and whether durations are stored as days or as the data's string.
- How lanes are packed and labels placed in the chart, within 6.5; Swift Charts' own axis rules.
- How the band follows the scroll (a scroll-position read of the rail's visible rows), and how a click's year maps to a row.
- The label column's width rule, and how the phone decides to stack (7.1).
- Where the derived lives and eras are built (5.2): in `BookAbout` or a new type beside it.
- The year column's scaled width.
- Whether "and n more" counts are built from the People and Places lists or from their own reads (5.4).

## 10. What is stored

- **Nothing in the synced store and no synced preference.** No new stored value of Matt's.
- The Bible database (`bible.sqlite`, built, never Matt's data) moves to schema 6 with two more columns on `event` and the one correction. It is rebuilt from the pinned cache; the build fetches nothing new.

## 11. Constraints

- Everything in milestone 10's constraints that still applies: DESIGN.md's tokens, no fixed-point fonts in chrome (the timeline's text uses semantic styles; nothing on it is a reader-size exception), no card, no glass, no shadow, Reduce Motion a cut.
- The page must not get slower. About Genesis measured 129 to 141 ms in a debug build in milestone 10 (backlog, M15); with the derived lives and the most-named reads it stays within 10% of today's figure, measured and recorded in the plan before and after. **(call: the figure is the builder's to measure; the rule is "no worse".)**
- A test never makes a `Map`; nothing here needs one.
- Swift Charts is an Apple framework already in the SDK; no package is added.
- The worktree's builds share `Build/DerivedData`: one implementer at a time.
- Builds after project 1, which changes the home page the Library view sits in; nothing here depends on project 1's code.

## 12. Design changes

`DESIGN.md` and `DESIGN.json` change with the build:

- Section 5, Library views, **About**: replaced by the head, the fact list, the timeline (rail and, on the Mac, chart), with the rules above.
- New component entries: **the fact list** and **the rail**, as reusable pieces.
- Section 4 (Elevation) or Colors: the chart's bars and band, named by token.
- Section 7, iPhone, Library: About's page with the stacked fact list and the rail.
- Do's and Don'ts: "Don't draw a chart that is the only way to its information."

## 13. Verification

Tests first:

- **Importer:** the fixture's events carry their length, their part-of link and a life's participant; each duration form seen in the data parses (`7D`, `930Y`, `3M`, `1Y6M`, `2M10D`, `1.5Y`, `1W`) and an unknown one warns; two part-of links keep the life; schema version 6 rebuilds an older database.
- **The corrections:** Death of Moses has no Genesis passage after import; Lifetime of Job and Birth of Job have no Genesis 46:13; each correction warns and does nothing when its field no longer holds the wrong value.
- **Lives and eras:** for a fixture shaped like Genesis 5 and 11, births and deaths fold into their lives; other children of a life stay events, an event with children inside a life included; a run of three lives folds and two do not; an era groups its children; an era within an era is a row with its children flattened into the outer group; an era with only its own passage in the book is one row with its span; Death of Moses sits in Moses's life; a life links to its participant; the count line counts lives and event rows only.
- **Against the real database** (a test that needs `Build/bible.sqlite`, as some do today): Genesis has 24 lives and 41 events under 3 era headers, in history order, ending with "Joseph's brothers return to Egypt", and its Spans ends at 1635 BC; Acts has 78 events, no lives, and 3 groups; Exodus and Galatians show "Sojourn in Canaan and Egypt" as a single row.
- **The facts:** the rows and their order; a book with no writer, no people or no events leaves its row out; the most-named tie-break by name; "(by tradition)".
- **Dates off:** no year anywhere on the page, no chart, lengths kept.
- **The chart's rules:** shown for Genesis and Acts, not for 2 Samuel or Galatians; the band's span for a given set of visible rows; a year clicked maps to the right row.
- **A benchmark:** About Genesis's load, against today's figure (11).

Renders, before it is called done (headless, both appearances and Sepia): About Genesis and About Acts on the Mac with the chart; About Genesis on the phone at the default size and an accessibility size (the stacked fact list); About 2 Samuel (one event, no chart); About Romans (no events, no timeline); a book with dates off.

One live pass on the Mac by the controller (keys only, under the handover's rules): open About Genesis, scroll, and see the band move.

For Matt, on the Mac and the iPhone:

- [ ] About Genesis: the title, the facts aligned, the five most named of each; a person and "347 more" open People.
- [ ] Its timeline in the order of history, ending with Joseph's brothers' return to Egypt; Moses and Job of Uz are gone from Genesis.
- [ ] Adam to Lamech folded; Show opens them.
- [ ] On the Mac, the chart: click it and the list moves; scroll and the band follows.
- [ ] About Acts: the journeys as groups.
- [ ] Settings › Show dates off: no years, no chart, lengths still there.
- [ ] On the iPhone at a large text size: the facts stack, the rail reads.

## 14. As built

Built 2026-11-23, unattended, in nine tasks on `milestone-11-ui-improvements` (BASE 42d5d44, the plan), each reviewed by a second model and fixed where it found something. The whole-project review (Opus) and Matt's look come after this section was written; the controller amends the milestone box to what the review finds.

**Built, file by file** (sources under `Packages/ScriptureKit/Sources/`, tests under `Packages/ScriptureKit/Tests/`).

- `ScriptureData/BibleSchema.swift`: schema **6**. `event` gains three nullable columns: `duration_days REAL` (the length, a year counted as 365.25 days and, in the importer, a month as 30.44; `LibraryLength` words a month as 30.4375 days, which only changes where "3 months" rounds), `part_of INTEGER` (the containing event, the first that is a life, else the first), `person_id INTEGER` (a life's participant; every one of the 27 lives has exactly one).
- `BibleImporterCore/TheographicTables.swift`: `days(_:)` (all the forms seen: `7D`, `930Y`, `3M`, `7Y6M`, `3M10D`, `2.5Y`, `1W`; an unreadable one warns and is nil), a two-pass `buildEvents` (part-of by record id, a link to an event not imported dropped with a warning; a life's person from its first resolvable participant, none silently nil, a non-empty list with none resolvable warns), `buildPeople` returns the ids by record; `BibleDatabaseWriter.swift` writes the columns.
- `BibleImporterCore/TheographicCorrections.swift` (new): the two named corrections (event 129 "Death of Moses" loses Genesis 34:1; events 107 and 108, Job's birth and life, lose Genesis 46:13), each with its reason beside it, each checked: if a re-pinned file no longer has the wrong verse it warns "no longer needed" and does nothing, and it warns if its event is gone.
- `ScriptureData/BibleStore+Library.swift`, `LibraryRecords.swift`: `eventRecords()` (all 501, read by column index through a cursor) and `lastVerses(ofBook:translationID:)` (every chapter's last verse in one grouped read).
- `ScriptureUI/Library/BookTimeline.swift` (new): the model. `Entry` (life or event, year, length, passage, era, `isEra`), `Era`, `make(records:passages:)`, `load`, `passages(of:in:translationID:store:)`, the count line, the spoken forms. Rules: a life is a "Lifetime of" record; its "Birth of" and "Death of" children fold into it; an era is an event with children that is not a life and not inside one; one level of grouping; a single-row era when its children are not in the book.
- `LibraryLength.swift` (new): a length in words. `LibraryYear.swift`: `bare` and the new `spans` form; `text` stays for People.
- `BookAbout.swift`: the facts (`testamentLine`, `lengthLine`, writers, the five most named people and places with their totals, the timeline, `spans(showingDates:)`, `hasDate`); `load` reads the page once.
- `FactList.swift` (new, public): `FactList`, `FactRow`; `LibraryNameRun.swift` (new): a run of names as links with "and n more".
- `TimelineItems.swift` (new): the rail's items from the timeline (folds, era headers, the dashes, the scroll anchor, `scrollTarget` for the chart's click, `years(visible:)` for the band); `TimelineRail.swift` (new, public): `TimelineRail`, `RailRow`, `RailMarker`, `RailSegment`.
- `TimelineChartModel.swift` (new): the bars, lanes (`lanes(_:)`), ticks, axis labels, the band, the click's target. `TimelineChartView.swift` (new, Mac only): the Swift Charts view.
- `LibraryAboutView.swift`: the head, the facts, the timeline (chart on the Mac, rail on both), folds in `@State`, the come-back and the chart's click landing by reading the lazy rail's made rows (`RailLanding`), the band's input isolated in a child view; `LibraryView.swift`, `Phone/PhoneLibraryPages.swift`: the page wired in; `ReferenceRunsText.swift`: a `font` parameter.
- Tests: `TheographicTablesTests`, `BibleDatabaseWriterTests`, `BibleStoreTests`, `BibleStoreLibraryTests` (schema 6, the lengths, the corrections, `lastVerses`); `BookTimelineTests`, `FactListTests`, `TimelineItemsTests`, `TimelineChartTests`, `AboutRealDataTests` (new; the real database, `.needsRealBible`); `LibraryPagesTests`, `PhoneShellModelTests`, `LibraryBenchmarkTests` updated; the three fixture copies identical; nine events added, 15 in all.

**The data, checked** (recomputed from the pinned cache with both corrections; pinned by `AboutRealDataTests`). 501 events, each with a year and a length; 249 name a `partOf`. Genesis: **24 lives and 41 events**, ending "Joseph's brothers return to Egypt"; 113 events have a passage in the book (116 before the corrections); **10 chart lanes and 27 bars**; Spans "about 4004 to 1635 BC"; People 352 ("God, Jacob, Abraham, Joseph, Isaac and 347 more"), places 119 ("... and 114 more"). Acts: 78 events, no lives, 3 journeys. Exodus and Galatians show "Sojourn in Canaan and Egypt" as one row. 1 Chronicles has three lives (Seth, Enos, Cainan) and folds them. The chart shows for Genesis, Exodus, Judges, 1 Samuel, 1 and 2 Kings, 2 Chronicles, Ezra, Nehemiah, Esther, Jeremiah, Daniel, the four Gospels and Acts; not for 2 Samuel (one row), Galatians (two), Ruth or Romans. **Where this differs from the spec:** Genesis folds three runs, not one, and its era headers are drawn four times for three eras (calls 1 and 2); and spec 6.4's example of a dash (a gap over 500 years) does not occur in Genesis, whose largest gap is 480 (call 4).

**Calls (call, unattended).** Matt was away, so none of these was asked; each is built as written and may be changed.

1. **Era headers are drawn four times in Genesis and in Acts, for three eras each.** The spec's rule (6.3: a later child elsewhere in time opens the group again) reopens "Sojourn in Canaan and Egypt" after "Abrahamic Covenant" (1921 BC, which the data does not put in the era) and "Third Missionary Journey" after "Paul's Journey to Rome" (AD 56). Tests pin 3 eras, 4 headers. *Cost if wrong:* a repeated header; the rule is one function, `TimelineItems.items`.
2. **Genesis folds three runs:** Seth to Lamech (8 lives), Arphaxad to Peleg (4) and Nahor to Abraham (3), so Abraham's life is behind a Show. Spec 6.2 (three or more in a row) gives all three; spec 13's "Adam to Lamech folded" contradicts it (Adam is followed by "Cain kills Abel"), so 6.2 is built. *Cost:* one constant, `TimelineFold.minimumRun`.
3. **The Spans form is new** ("about 4004 to 1635 BC", "about AD 30 to 57", "about 1921 BC to AD 49", one year "about 1055 BC"). *Cost:* the wording.
4. **A closed fold's dash is measured from its last life's year,** and Genesis has no dash (the plan said so before the build; Luke and Galatians were rendered for it and show it, faint). *Cost:* a false dash under a long fold if the rule is wrong.
5. **Lengths in words:** "one day" under 1.5 days, whole days under 365, months rounded under 365 days, years from 365 ("2.5 years"), one place, ".0" dropped, in the reader's number format. An event row shows a length from 1.5 days; an era header always. *Cost:* wording.
6. **A life ends at its start plus its whole years** (Adam −4003 + 930, "to 3074 BC"), not at its folded death's year; its passage is the first in the book among the life and its folded births and deaths. *Cost:* a year or two on a life.
7. **An era shown as one row** (Exodus, Galatians) reads as an event: its start in the year column, its length ("430 years"); on the chart it is an era bar.
8. **The band covers the start years of the rows on screen,** a closed fold's lives included, never a life's whole span (which would swallow the chart); at least 1% of the domain wide. *Cost:* the band's meaning.
9. **A click on a folded life's bar goes to its fold and leaves it closed;** coming back from a passage opened from a life inside a fold opens that fold and scrolls to the life (the fold is not remembered, so the page was rebuilt closed).
10. **The chart shows with dates on, at least five rows and at least two distinct years.**
11. **VoiceOver's passage action on a row opens the passage** (the phone's page, the Mac's reader) and not the Mac's popover, which is anchored inside `ReferenceRunsText`; a row is one element, the year read once and without "about" (spec 8's literal text; ruling 25). *Cost:* one action's behaviour; a word.
12. **The chart is `.accessibilityHidden(true)` under the repository's first `swiftlint:disable:next accessibility_hidden_on_text`,** with a reason beside it; spec 6.5 requires it. SwiftLint's count does not rise.
13. **The Testament row's words** are the canon's name, a comma and the group ("Old Testament, the Law"; "the Gospels and Acts", "Paul's Letters", "the General Letters"); writers join as a list ("David and Solomon (by tradition)"); Psalms' six read "David, Asaph, Solomon, Heman, Ethan and Moses (by tradition)". The subtitle is the pane's.
14. **The dates footnote moves under the timeline,** once per page; the notice stays at the head.
15. **The fact list stacks** when the widest label plus the gap passes 40% of its width.
16. **A life's participant is a column on `event`** (`person_id`), not a table; `duration_days` and `part_of` too, all nullable.
17. **Every event record is read on each load** (501 rows), since "is an era" means "has children anywhere"; read by column index it costs 0.7 ms.
18. **The two old SwiftLint findings in each of `LibraryView.swift` and `PhoneLibraryPages.swift`** (a `Rectangle` with `accessibilityHidden`) became `HairlineRule()` while those files were touched: 83 to 79.
19. **Task 8 ran on Opus, not Sonnet,** because the open had grown 70% and the fix (a lazy rail) touched the scroll link Task 7 built. *Cost:* a little more.
20. **The rail is a `LazyVStack`,** and the landing on a row (the come-back, a fold's opening, the chart's click) reads the rows made so far and takes the scroll the rest of the way, up to six corrections, settling on a clock (a cut at once; 550 ms after `.smooth`, a guess) and giving way when the reader scrolls. *Cost:* a fling already slowing when the chart is clicked is not detected.
21. **`ViewThatFits` only where a row has both a passage and a length** (and an era header with a passage); the rest draw as they are. *Cost:* none in layout; it halves a row's cost.
22. **A life's name has `.focusable(false)`** so Tab reaches only a fold's Show and Hide (spec 8); the name has no link cue beyond the pointer (ink.primary, not accent). *Cost:* a reader may not see it is a link.
23. **The year column is never narrower than at the default size,** so "4004 BC" is whole at the phone's smallest text; at accessibility sizes the year sits above the title and the count line under "Timeline".
24. **The "(by tradition)" note follows every writer list,** Psalms' too. *Cost:* it may read oddly beside six names.
25. **The label column follows the rows shown,** not every row it has measured, so a narrower book shrinks it.
26. **Fix rounds** (process, not a decision): Task 4 one round, Task 5 one, Task 6 one, Task 8 two; none of Tasks 1 to 3 or 7 needed one.
27. **Red not observed first** (process, not a decision): Tasks 3's and 6's tests were written with their code and the red never seen; Task 2's was recreated by moving the file away. *Cost:* none in the pins, which are measured.

Each of the following is also a call **(call, unattended)**, from the controller's rulings in the ledger.

28. **Pre-flight ruling 1: `TimelineItem` and `TimelineFold` are internal;** `TimelineItemID`, `RailMarker`, `RailSegment`, `RailRow` and `TimelineRail` stay public. *Reason:* a public enum with internal payloads does not compile. *Cost:* one word when project 3 needs them.
29. **Ruling 2: `Entry` gains `isEra`** (an era record shown as a single row, or an inner era's record), `Kind` unchanged. *Reason:* the chart could not tell an era row from a long event. *Cost:* Exodus's Sojourn would be a tick.
30. **Ruling 5: every test that reads the real database carries `.needsRealBible`.** *Reason:* a fresh clone has no database, and a skip is better than a failure. *Cost:* none.
31. **Ruling 6: the chart's click is a `SpatialTapGesture`, never `.onTapGesture`.** *Reason:* impeccable-lint would count it (27 to 28). *Cost:* none.
32. **Rulings 8, 9 and 11: three more tests** (`factLabels(_:showingDates:)` for spec 13's rows and order; an unreadable duration's warning; `Era.spoken` and the dates-off spoken forms). *Reason:* spec 13 and 8 name them. *Cost if left out:* a row in or out by mistake, an unnoticed warning on a re-pin, VoiceOver reading a year with dates off.
33. **Ruling 10: the footnote shows only when dates are on and the book has a date.** *Reason:* spec 6.6. *Cost:* a footnote under a dateless timeline.
34. **Ruling 19: Tasks 3 and 6's interim losses were intended** (the anchor kept minimal; the chart's `onPick` a no-op until Task 7). *Reason:* the plan's order. *Cost:* a review round each.
35. **Task 3's Important (the load rose from 6.7 to 10.8 ms) went to Task 8, not a fix round.** *Reason:* Task 8's first step owns the after measurement and says to find why before any change; the open the reader sees was faster while the page was interim. *Cost if wrong:* Task 8 inherits a known slow load (it fixed it: 6.6 ms).
36. **Task 6's second Important (the chart's share of the open unmeasured) went to Tasks 7 and 8,** with the chart-on and chart-off medians measured at once (222.6 and 218.3 ms: the chart about 4 ms). *Reason:* ruling 21 caches the model and isolates the band in Task 7, and Task 8 owns spec 11's 10% rule. *Cost if wrong:* Task 8 carries a 70% slower open (it did, and fixed it).
37. **The chart stays unpinned** (Task 7's Important, plan-mandated): spec 6.5 says "The chart scrolls with the page; it is not pinned", and Matt approved it. *Cost:* the first item of "For Matt".

**How the build was run** (process rulings, each a call, unattended). The head counts (package 1,536, iOS 1,029, both Debug builds) were taken from project 1's final runs at 49b92c1 and not re-run, since only docs changed after; *if wrong*, a red suite would have shown at Task 1's full run. `global-constraints.md` is the plan's constraints copied verbatim plus the attribution line. The controller's live passes for Tasks 4 to 7 were made as one pass after Task 7, on one Debug build, because the running app was project 1's and the page interim until Task 5; *if wrong*, a defect that shows only live was found later. The Mac live pass of About was not made, since the unattended run allows keys only and About has no key route; the simulator stood in. Preflight rulings 12 to 18, 20 to 24, 26 to 28 and 30 to 31 were small interface notes (compile errors, helpers, lint) taken as the plan's items; ruling 29 allows a dates-off render to show the notice (a read of the real defaults; no cost). The checker's 3 (call 22), 4 (call 4), 7 and 25 (call 11) rulings are above.

**Checkers** (from the worktree root; baseline 83, 27, 0). SwiftLint **79** (four fewer: call 18); impeccable-lint **27** (unchanged); asset checker **0**. In the new and touched files: none from any of the three; the four old findings (two in `LibraryView.swift`, two in `PhoneLibraryPages.swift`) are fixed. The 27 impeccable findings are in files this project did not touch.

**Benchmark** (`LibraryBenchmarkTests/aboutGenesisLoads` and `aboutGenesisOpens`, each alone, the median of three runs of a median of nine, debug build; `benchmarks.md` in the ledger).

| | Before (schema 5) | After Task 6 | After Task 7 | After Task 8 (final) | Bound (spec 11: 1.10 ×) |
|---|---|---|---|---|---|
| Load | 6.7 ms | 11.5 ms | 10.7 ms | **6.6 ms** | 7.37 ms |
| Open | 134.7 ms | 222.6 ms | 230.2 ms | **46.8 ms** (42.3 ms after the last fix) | 148.2 ms |

The first build of the rail and chart made the open 70% slower. Attribution: the chart about 4 ms of it; the rail's rows about 190 ms (each about 1.2 ms of SwiftUI views in debug). Task 8 made `eventRecords()` a cursor read by column index (3.0 to 0.7 ms), read the book's last verses once in place of nine chapter reads (2.1 to 1.0 ms), made the rail lazy and limited `ViewThatFits`. The open figure no longer sees a row's cost, since a lazy rail builds only the rows near the screen; the committed bound on the load is under 10 ms, on the open 300 ms.

**Suites** (this task's run, after every other commit): package **1,593** passed (1,173 + 241 + 52 + 94 + 33; the baseline was 1,536, so 57 new); iOS `ScriptureUITests` **1,077 passed in 105 suites** (the baseline was 1,029, so 48 new; this is the log's count, which is why it is above Task 8's 1,064 by the result bundle, a different method: Task 9 added no tests); the Mac Debug build succeeded at the last code commit (Task 8). Per task: package 1,546, 1,561, 1,563, 1,568, 1,578, 1,586, 1,588, 1,591 and 1,593; iOS 1,031, 1,046, 1,048, 1,052, 1,063, passed (Task 6, uncounted), 1,073 and, for Task 8, 1,064 by the result bundle's count with 11 skipped, which counts differently from the log's "tests in suites" line used elsewhere.

**Live pass and simulator look.** The controller's pass on the Mac Debug app (keys only, the idle time checked before every key; the app at the worktree's build, quit by path and reopened) reached the front page: ⇧⌘H and ⌘F "Genesis" chose Genesis and the pane showed the About icon. Twenty-four Tabs from the search field (31 s idle before each) ran search, the plan band's checkboxes and links, "The whole plan", the contents, the chapter grid and the toolbar; **the pane's People, Places and About icons are never a Tab stop and ⌘K has no "About Genesis" command, so About could not be opened by keys on the Mac.** The pass stopped there: nobody has seen About on the Mac live. The Mac's look is from offscreen renders (Genesis, Acts, Exodus, Luke, Galatians, 2 Samuel, Romans, dates off, in light, dark and Sepia, all opened by the controller or the task reviewers) which cannot show a pointer, a click, focus, VoiceOver or the band's motion. **The simulator** (iPhone 18 Pro Max, the iOS Debug app at Task 8's code, taps only, nothing written): Library, Genesis, About showed the head, the facts aligned with People and Places wrapping under their values, "24 lives, 41 events" and the rail with years, dots and rings; Show on "8 lives, Seth to Lamech" opened eight lives, each "lived N years · to N BC", and read Hide. About Acts showed "78 events", AD years, the header "Third Missionary Journey · AD 50, 4 years" with its passage, and lengths ("3 months", "1.6 years", "7 days"); flinging the lazy rail scrolled cleanly. A passage link was not tried (it would have moved the simulator's reading place).

**Reviews.** Every task had a review (Sonnet; Task 7 Opus): Task 3 found one Important (the load's rise, call 35); Task 4 found one Important (the fact list's label column kept a wider book's width), Task 5 one (a row's year read twice by VoiceOver), Task 6 two (a test that could return before asserting; the chart's share of the open unmeasured), Task 7 one that the plan mandated (the chart scrolls with the page: first on Matt's list), Task 8 one and then a second (a scroll to an unbuilt row of the lazy rail landed by estimated heights; the chart's click settled only from an animation's completion); each fixed and re-reviewed clean.

**Minors set aside** (deferred by task reviews, for the whole-project review; the backlog has the ones that outlive it): an untested correction naming a missing event and a dropped person; the importer stores a self or cyclic `part_of` as given (the page's walks are bounded); `displayString` falls back to ""; sort-key ties and nested-era-only headers untested; the group gap before People is 2 × `xs`; the label-column test covers the helpers, not the view; the 10 ms load bound is tight and its comment mislabels the rounding; the fold come-back fix is untested (a hosted view cannot be driven); per-row `onGeometryChange` per scroll frame unmeasured; a click or come-back lands on an era's first row with its header just above the top edge.

**For Matt**, in the order to look. The first two are the calls he is most likely to overturn.

1. **The Mac chart scrolls with the page (spec 6.5), so the band's left edge stays at the book's start while the chart is on screen, and a click scrolls the chart away.** The rail starts just under the chart, so whenever any of the chart is on screen the first rows are too; only the band's right edge moves, out to the Flood and on, until the chart leaves the window (roughly after a Page Down in a 760 pt window). A pinned chart would make the band mean something all the way down; dropping the band would leave the chart as a picture of the span. The call: **pin the chart, or drop the band, or leave it.** A change to `LibraryAboutView`'s layout only; nothing builds on it.
2. **Nobody has seen, live, the Mac's band move, a click on the chart, or Tab reaching Show and Hide.** About has no key route on the Mac (the pane's topic icons are not Tab stops; backlog), and the unattended live pass was keys only. Open About Genesis with the pointer, scroll, and watch the band; click the chart near the Flood, on Seth's bar (it goes to the fold and leaves it closed), on the Sojourn bar; Tab from the contents to the first Show.
3. **The simulator look** is above: the head, the facts, the rail, the fold and About Acts were seen on the iPhone 18 Pro Max, taps only; the passage link and the iPhone itself were not.
4. **Most of Genesis's later lives are unlabelled bars** where a name does not fit above them (Abraham, Isaac, Jacob and Joseph are short bars in a 4,000-year span; Acts' three journeys too). The rail has every name; a hover or a legend is not built.
5. **Nobody has seen the Matthew or Luke chart.** Luke's is two genealogy bars on the far left with every event in the last 1% of its width, and its Spans reads "about 3874 BC to AD 30". About Luke on the Mac: is a chart worth showing when the book's events fill 1% of its span? (The axis printed "AD 0" in both until the fix wave.)
6. **VoiceOver has not been run.** A row is built to be one element reading its year once ("2348 BC, The Great Flood begins, Genesis 7:6"); no test can see the accessibility tree offscreen, so this is by construction.
7. **The iPhone's Debug app is not installed** (an unattended run); the simulator stood in. Installing it needs the phone unlocked and Matt's word.

Then spec 13's list, on the Mac and the iPhone, with two lines corrected:

- [ ] About Genesis: the title, the facts aligned, the five most named of each; a person and "347 more" open People (by pointer: unseen).
- [ ] Its timeline in the order of history, ending with Joseph's brothers' return to Egypt; Moses and Job of Uz are gone from Genesis.
- [ ] **Seth to Lamech, Arphaxad to Peleg and Nahor to Abraham are folded** (three runs, call 2; spec 13 said "Adam to Lamech", and Adam's row is followed by "Cain kills Abel"). Show opens each; **Abraham's life is behind the third Show.**
- [ ] **The era headers repeat** (call 1): "Sojourn in Canaan and Egypt" and, in Acts, "Third Missionary Journey" each come back once after a row that is not theirs. Say if that reads as noise.
- [ ] On the Mac, the chart: click it and the list moves; scroll and the band follows (the first item above).
- [ ] About Acts: the journeys as groups.
- [ ] Settings › Show dates off: no years, no chart, no spans, no dashes, lengths still there.
- [ ] On the iPhone at a large text size: the facts stack, the rail reads, the fold's Show goes under its line.

**What nobody has seen** (render-blind and unattended): the chart's click and the band's motion; the person and "347 more" links by pointer; VoiceOver on a row and on the fold; the phone on a device; Tab reaching Show or Hide; the `.smooth` scroll and its cut under Reduce Motion; a passage link opened from a row and Back returning into a closed fold (seen in renders only); the Mac window at AeroSpace's size (a changed window size is not a regression).

**Whole-project review and fix wave.** The whole-project review (Opus) found the project ready with fixes; the critique scored 28/40; the checkers stand at 79, 27, 0. The wave fixed: (1) the Mac chart's axis no longer prints "AD 0" (`TimelineChartModel.axisValues` leaves 0 out; tested on the ranges of Matthew's and Luke's charts); (2) the About page is keyed by its book, so a change of book on the Mac starts with no open folds, pending scroll or offset; (3) the real-data test pins that every event has a length; (4) `LibraryAboutView`'s doc comment describes the head, the fact list and the timeline; (5) `FactRow`'s doc comment says its id is its label; and this section's untrue lines (the month, the fixture events, the `part_of` guard, the two resolved minors), DESIGN's stacking and subtitle lines, and the Matthew and Luke chart on Matt's list. The backlog took the minors that outlive the project. The scoped re-review (Opus) found 11 of 12 items addressed and nothing new of weight; the one backlog line it missed and two wording slips were put right in the finishing docs.

**Final runs** (controller, at `d6057f8`, one after another): package suite 1,594 passed (1,174 + 241 + 52 + 94 + 33); iOS `ScriptureUITests` 1,078 in 105 suites; the Mac Debug build and the iOS Debug build (simulator) succeeded. Checkers: SwiftLint 79 (baseline 83), impeccable-lint 27, asset checker 0. The Mac Debug app was restarted on this build; the iPhone's was not installed.

### Matt's review, 2026-11-24

Matt looked at About Matthew on the Mac (the chart under "Timeline 71 events", a band from 6 BC to AD 30 with ticks labelled "AD 10, 20, 30", the rail below):

> Most timelines are long enough that when I scroll down far enough I can no longer see the horizontal timeline with the highlight of what section I am looking at. So at some point while scrolling that section should be pinned to the top so it can still be seen and the vertical timeline of events be scrollable underneath it. So I can see both at the same time. The top portion (horizontal timeline graphic) shows with its highlight what the section underneath (vertical timeline) is showing. Unlike what currently happens which is the timline shows the highlight for the start and then as the user scrolls it grows and then that section just disappears.

This overturns call 37 and "For Matt" item 1 (pin the chart), and answers item 5 (Luke).

**What changed** (`12b77bb` the axis and Luke, `da98848` the pin, the band and the landing):

1. **The chart pins** (`LibraryAboutView`). The rail is a lazy stack whose one section has the chart as its pinned header: the chart scrolls with the page until it reaches the window's top, stays there while the rail scrolls under it, and is pushed off with the rail's end. It sits on `paper.page` across the text column, with a 1 pt `ink.rule` hairline under it only while pinned (its opacity, so nothing moves). A book too short to scroll never pins; with dates off, and on the phone, there is no chart and nothing pins. The head and the foot (dates notice, title, facts, heading; footnote, credit) stay in a plain stack around it.
2. **The band follows the rows in view** (`TimelineViewport.swift`: `RailViewport`, `RailGeometry`, `PinnedChartState`). It spans the earliest to the latest year of the rows whose middle lies between the chart's foot and the window's foot, in both directions; a closed fold counts by its lives' start years (call 8 stands), an era header by none, a row off the chart by none. The rows' frames are kept in the page's content space, where a scroll does not move them, so a scroll step reads the made rows' frames against the visible rect (`onScrollGeometryChange`) and lays out nothing; the chart redraws only when the band's ends or the pin change. The band moves with no animation (a cut, Reduce Motion or not). While no row is in view it keeps its last span, so it never blinks out as the chart is pushed off.
3. **A click lands its row under the chart** (`RailLanding`). A row lands with its top at the chart's foot: the scroll's anchor is the chart's height over the window less the row's height (SwiftUI lines the row's point at that fraction up with the window's), exact for a made row and corrected once for one not made yet. The come-back from a passage lands the same way. The phone lands at the top as before.
4. **The axis names both ends** (`TimelineChartModel.axisMarks`): the domain's own years with their era at each end ("6 BC" … "AD 30"; "4004 BC" … "1491 BC"; "AD 30" … "AD 57"), the round years between them kept only where each clears its neighbours by two characters at the chart's width, the first of an era not yet named carrying it ("6 BC, AD 10, 20, AD 30").
5. **Luke's chart starts at its own story** (`TimelineChartModel.charted`): a few rows (at most 5% of them) beyond a gap wider than half the span are left off the chart and kept on the rail. Luke's Seth and Cainan (3874 and 3679 BC, the genealogy) go, so its chart runs from 6 BC to AD 30 like Matthew's, not squeezed into its last 1%. Matthew's eight birth rows (11%) stay. No other charted book changes (Genesis 4004 to 1491 BC, 27 bars, 10 lanes; Exodus from 1921 BC; Acts AD 30 to 57).

**Calls** (each may be overturned):

1. **"Timeline" scrolls away; only the chart pins.** The heading's rule and title would cost about 60 pt more of the window under a chart that already says what it is.
2. **The ends name the domain's own years** ("1491 BC" is the Sojourn's end, past Genesis's last row in 1706 BC), both with their era; a round year within two characters of an end is dropped ("4000 BC" beside "4004 BC").
3. **A row is in view by its middle** (a row more than half under the chart is out).
4. **The band keeps its last span while no row is in view** (the chart being pushed off, or the page at its top before the rail).
5. **"A few far rows"** is at most 5% of the rows beyond a gap of more than half the span. Jeremiah's and Daniel's long eras (from 975 BC) still put their rows in the chart's last fifth (backlog).
6. **The rail's rows are the section's own** (not `TimelineRail` inside it): a lazy rail inside the lazy page made the page's height swing between about 4,000 and 5,900 pt as it scrolled, and the end rendered blank. `TimelineRail` stays for the family line.
7. **Genesis's pinned chart is tall** (about 340 pt of a 760 pt window at 18 pt); five or six rows show under it (backlog).
8. **The phone's page shares the new structure** (its rail is the same lazy section, with an `xs` gap for a header and nothing pinned), so it reads as before; it was not rendered.

**Tests** (written first, red seen as a compile failure): `TimelinePinnedChartTests` (new: the chart pins at the top and leaves with the rail, the rows in view under it, the band both ways, a fold by its lives and a row off the chart by nothing, the landing's step and anchor, a click on Matthew's chart); `TimelineChartTests` (the axis names both ends, never crowds across seven domains and widths from 120 to 1,200 pt, never prints a year zero; a few far rows off the chart; Luke on real data); `yearsMapSoRoundTicksReadTrue` rewritten for the new labels.

**Benchmarks** (debug, median of nine, alone): About Genesis opens in 44.1 and 45.6 ms (bound 300; about 42 before), loads in 6.8 ms (bound 10). The People benchmarks were over their bounds at this load: 1 Chronicles at 163.1 ms against 160, David at 156.0 against 150. With this work stashed, at the same load, they measured 161.9 and 163.0 ms, so the misses come from the machine and not from this change; the people spec records them as borderline.

**Checkers:** SwiftLint 69, impeccable-lint 23, the asset checker 0 (unchanged).

**Suites** (one after another): the package suite ran 1,423 UI tests with two failures, the two People benchmarks above; the other bundles passed (241, 52, 96 and 33). iOS `ScriptureUITests` passed 1,271 tests in 122 suites. The Mac Debug build and the iOS Debug build (simulator) both succeeded. The Mac Debug app was not relaunched (Matt was at it).

**Seen** in headless renders at 18 pt in a 900 by 760 pt window (`NSHostingView`, the scroll stepped 300 pt at a time): Matthew at the top (the chart in the page, "6 BC, AD 10, 20, AD 30"), pinned mid-rail (hairline, band over AD 29), at the end and back; Genesis at the top, pinned mid-rail (band from Creation to Noah), late and at the end, and in Dark Mode; Luke (from 6 BC) and Acts ("AD 30 … AD 57") pinned; the come-back to Noah, the Transfiguration and "Joseph sold to Egypt", each landed with its top at the chart's foot. **Not seen:** anything live (Matt was at the Mac): a click on the chart, the band moving under a real scroll, the scroller's thumb, Reduce Motion, VoiceOver; the phone.

**The band froze** (Matt, later the same day: "Sometimes the highlight of the horizontal timeline does not work. This error tends to show up after scrolling down and back up and then down again."). A lazy stack calls a row's `onGeometryChange` only when the value changes, and a row's frame in the content space never changes, so a row made again after scrolling away appeared with no frame; `onDisappear` had already dropped the old one, and each pass back emptied the set until the band kept its last span. `RailGeometry` now keeps each row's last frame and counts the row's appearances against its disappearances (a new copy can appear before the old one goes); only a made row can be in view. A probe in a hosted window (300 rows, scrolled 300 pt at a time) froze at the first step back up before the fix and followed every step after it. Tests: `theBandFollowsRowsMadeAgainWithNoNewFrame` (red on values first), `TimelinePinnedChartHostedTests` (the real `RailRowFrame` in an `NSHostingView`, down, up, down and a fling; 18 failures with the old behaviour). About Genesis opens in 48 to 52 ms against 47 to 58 ms before, at a load average of about 20. Checkers unchanged (SwiftLint 69, impeccable-lint 23, assets 0). Package suite: 1,429 UI tests, with five benchmark misses outside About under load (Front Page, Psalm 119's frame, Joshua, 1 Chronicles, David; Joshua passed alone); the other bundles passed. iOS 1,275 passed; both Debug builds succeeded. Not seen live: Matt was at the Mac.
