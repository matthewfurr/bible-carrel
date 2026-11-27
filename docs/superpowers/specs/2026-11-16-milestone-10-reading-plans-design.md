# Milestone 10, project 5: reading plans

Status: approved by Matt, 2026-11-16, including the two new kinds of record in iCloud (section 7). Fifth of milestone 10's six projects. Branch `milestone-10-study-tools`. Builds after project 4 (the Mac's contents page, which the "This week" band sits over).

Built 2026-11-19, reviewed whole, fixed in one wave and re-reviewed. The older-build rehearsal was run on 2026-11-19 and passed, with a finding: an older build must never be run on a store this build has used (section 12). No controller live pass was made; Matt looked himself in the Debug apps and said "Everything else looks good", and once the rehearsal had passed, "Yes, it's done": the project is finished and accepted, 2026-11-19.

## 1. Intent

The app is named for a two-year Reading Through Scripture group. Its plan arrives as a PDF: a table of weeks, each with a handful of readings, each reading a Wisdom chapter and an Old or New Testament passage. Matt follows Gen 1 (five readings a week, 67 weeks, no dates); another group follows Gen 2 (four a week, 86 weeks, a meeting date per week). The group meets weekly to discuss the week's chapters. On 2026-11-16 Matt was on week 63, meeting on Tuesday the 17th.

Matt: "I will show you the reading plan we get so you can determine the best way to import or best way to build the UI for a user to add these manually."

The main spec set plans aside because "the church plan arrives as a PDF and will not be hard-coded." This project reads the PDF.

## 2. Goals, non-goals, anti-goals

**Goals**

- See this week's readings from wherever the app opens, go to any of them in one click, and tick each off. The Mac opens where the reader left off reading, not on the front page, so the week is also one click away in the reader (5.1).
- Bring the church's PDF in without retyping it, check what was read from it, and correct it.
- Type a plan in by hand when there is no PDF the app can read.
- The plan and its ticks are the same on the Mac and the iPhone.

**Non-goals**

- Built-in plans (a year through the Bible, the Gospels in a month). On the backlog.
- Catching up or rescheduling. A week missed stays as it was; the group moves on together.
- A note for the week or the meeting. Matt, 2026-11-16: "chapter and verse notes work. And the notes can be filtered to the last week." The plan window's "Your notes this week" line from the mockup is dropped for the same reason.
- Reminders, streaks, reading-time estimates.
- Ticking a reading automatically when its chapters have been read.
- Sharing a plan with other people from inside the app.
- Reading a scanned PDF (one with no text in it).

**Anti-goals**

- A plan saved with a reading the app could not understand.
- A tick lost because two devices ticked different readings before they synced.
- A tracker that nags: no badges, no counts in the Dock, no colour for "behind".

## 3. Approaches

**Getting the plan in.** (1) Read the PDF's table from where each word sits on the page. (2) Ask the assistant to read it. (3) Paste or type it. (4) Ship the church's plans inside the app. A test on both PDFs (2026-11-16) showed (1) works with Apple's PDFKit alone: all 67 Gen 1 weeks and all 86 Gen 2 weeks came out right, checked against the pages, in about a second, where reading the PDF's text in order does not (it comes out column by column after page 1; a hand count from it put week 63 two rows out). (2) is unreliable over 335 rows and needs a network or a large model. (4) is what the main spec ruled out, and the next group's plan would need a new build. Chosen: (1), behind a review screen that shows every week before anything is saved and is also the editor for (3). The reader is built for this church's layout and says plainly when a PDF is not one it can read.

**Where the plan lives.** Mocked up (`reading-plan-where.html`) and not objected to: a "This week" band over the Mac's front page, a plan window like the Notes Browser, and a Plan tab on the iPhone.

**Dates.** One model for both plans: every week has a meeting date. Gen 2's come from the PDF. Gen 1 has none, so the reader gives one anchor ("week 63 meets Tuesday 17 November") and the rest follow a week apart.

**What is stored.** The plan as one record, and one small record per tick, so ticks made on two devices merge instead of one device's list replacing the other's.

## 4. The plan

- **A plan** has a title and its weeks in order.
- **A week** has its number, a meeting date, an optional label ("Leader Dinner", "OFF", "Meet in Homes") and its readings in order. Weeks need not have the same number of readings (Gen 2's last nine have three).
- **A reading** is one row of the church's table: one or more passages, shown together, ticked together. Each reading keeps an identity of its own inside the plan, so a tick follows its reading when rows are reordered or others are removed. Usually two, a Wisdom chapter and an Old or New Testament passage. A row marked "NT Focus", "NT Focus Week" or "Holidays", or left blank, has no Wisdom passage and keeps that label, shown quietly beside it.
- **A passage** is a book with a chapter or a run of chapters ("Genesis 1–3"), or part of a chapter ("Psalms 119:1–16"). "Proverbs 18–19" is one passage of two chapters. "2, 3 John, Jude 1" is three passages in one reading. This is a new type with its own reader: the app's references today name one chapter and cannot hold "Esther 7–8".
- **Several plans** can be kept. One is the plan being followed; the band and the Plan tab show that one. **(call)**

### 4.1 This week

- This week is the first week whose meeting date is today or later. The day after the meeting, the next week becomes this week.
- Before the first week's date it is week 1. After the last week's date the plan is finished: the band goes, and the plan window and tab say so in one line.
- **Changing a date:** each week's date can be edited. Moving a week's date moves every later week by the same number of days, so one edit covers a week the group skipped. **(call)** A week's label can be edited too.
- **Anchoring a plan without dates:** on first following it, the app asks which week the group is on and when it next meets. From that every week gets a date, seven days apart, earlier weeks backwards.
- A date the PDF gives that does not exist (Gen 2's "Feb 29" in 2027) is flagged in the review (6.2) for the reader to set.

### 4.2 Ticks

- Each reading has a circle. A click or tap ticks it; again unticks it. Ticking is the reader's to do; nothing ticks by itself.
- A week shows how many of its readings are ticked; the plan shows how many of all its readings are, as the thin progress line.
- Ticks sync. Two devices ticking different readings both keep theirs; the same reading ticked on both is one tick.

## 5. Where it shows

### 5.1 Mac: the band, and the same in the reader

**In the reader:** a toolbar button, `calendar`, present while a plan is followed and not finished, opens a system popover holding exactly what the band holds: the title line, the week's readings with their circles, the progress line and "The whole plan ›". Its help tag is "This week's readings". The Mac opens where the reader left off, so this is how the week is reached without leaving the page. **(call; not in the mockup.)**

**On the front page:** over the contents (project 4), when a plan is followed and not finished:

- "This week" in the page's title face; beside it "Week 63 of 67 · meets Tue 17 Nov" ("meets today" on the day; the label after it when the week has one) in `.callout` `ink.secondary`; trailing, "The whole plan ›" in the accent, which opens the plan window.
- The week's readings side by side in equal columns, wrapping to a second row when they do not fit: each a tick circle and its passages, one to a line. A passage is a button in the accent that opens it for reading; a ticked reading's passages fall to `ink.tertiary` and still open.
- The plan's progress as a 2 pt line in the accent across the band's foot, on `ink.rule`, as the reading progress line is drawn.
- An `ink.rule` hairline closes the band. No fill, no card.
- With no plan followed there is no band; the front page is as project 4 leaves it.

### 5.2 Mac: the plan window

A window like the Notes Browser, opened by "The whole plan ›", by View › Reading Plan (⌥⌘P) and by a "Reading Plan" command in ⌘K. **(call: the shortcut; it joins the shortcuts catalogue.)**

- **Sidebar:** the weeks, each "Week 63" with its meeting date and "done", "3 of 5" or nothing; weeks past with nothing ticked are not marked in any colour. It opens on this week.
- **Detail:** the week's number as its title, "Meets Tuesday 17 November · 2 of 5 read" with its label, then the readings as rows with rhythm: the circle, the passages as buttons.
- **Toolbar:** a menu of the kept plans with the followed one checked; Import…; New Plan; Edit Plan…; and, in the detail's context, Change Meeting Date….
- With no plan: `ContentUnavailableView`, "No reading plan", "Import your group's plan, or type one in." with Import… and New Plan.

### 5.3 iPhone: the Plan tab

A fourth tab, Plan (`calendar`), between Read and Notes. **(call: the symbol.)**

- This week at the head: the same title line, then the readings as rows, each a circle (a 44 pt touch area) and its passages as buttons.
- Below, the weeks to come, each a row that opens to its readings; the weeks before are above, reached by scrolling up. The tab opens scrolled to this week.
- The `ellipsis` menu: the kept plans, Import…, New Plan, Edit Plan…, Change Meeting Date….
- With no plan: the same empty state as the Mac.
- **Edge swipes:** the chain becomes Ask, Notes, Plan, Read, Library. `DESIGN.md` section 7 changes to say so.

### 5.4 Opening a passage

A passage opened from the band, the window or the tab is reading, not a lookup: it becomes the reader's place, at the passage's first chapter (its first verse, for part of a chapter). On the iPhone the Read tab comes forward.

### 5.5 VoiceOver

A reading is one element, "Reading 3 of 5, Psalms 84, Esther 7 to 8, not read", a button whose action ticks it, with an action per passage to open it. A week row reads its number, date and count.

## 6. Bringing a plan in

### 6.1 Reading the PDF

Import… takes a PDF or a text file (the system's file picker on both apps; a PDF can also be dropped on the plan window).

- The reader rebuilds the table from the position of each word (PDFKit, on the device, no network): the header row names the columns, rows are grouped by height, a tinted gap or a date row ends a week, and the "Wk" column numbers it.
- It handles what these two plans have: a week that runs across a page break; a merged "Holidays" or "NT Focus Week" cell covering a whole week; a blank Wisdom cell; a name wrapped inside its cell ("Lamentation" / "s"); "Song" for Song of Solomon; "119:1-16"; "18-19"; "2,3 John, Jude"; and a date with a label ("Sept 15 / Leader Dinner", "Nov 17 - OFF").
- The test's working method and numbers are the starting point for the builder: the script at the path in the plan, 67 × 5 readings for Gen 1, and 86 weeks for Gen 2 of which 77 have four readings and the last nine three.
- A PDF without the header it expects, or with no text in it, is not guessed at: "This PDF isn't laid out like a plan Bible Carrel can read. You can type the plan in instead." with New Plan.
- Dates in a PDF carry no year. Years are counted on from the first date, rolling over each time the dates pass December. The first date's year is the one that puts today inside the plan's span; when no year does, the one that brings the plan nearest to today. The review shows the first date with its year and lets the reader change it, and every later date follows. **(call)** With Gen 2 read on 16 November 2026 that gives a start of 15 September 2025, and "Feb 29" falls in 2027 and is flagged. (Overturned by Matt's answer of 2026-11-19: the import prefers the year whose dates all exist and fall on one weekday, so Gen 2 starts 15 September 2026 and nothing is flagged; see section 12.)

### 6.2 The review, which is also the editor

Nothing is saved until the reader accepts it here. The same screen is New Plan and Edit Plan….

- The plan's title, editable ("RTS Gen 1" from the file's name).
- **To check,** when there is anything: a short list at the head, each line naming a week and what is wrong, and a click going to it. What is flagged: a book the app does not know; a chapter the book does not have; a date that does not exist or is out of order; a week numbered out of sequence.
- **The weeks,** each with its number, its date and label, and its readings one to a line as text that can be edited: `Psalms 84; Esther 7-8`. Passages are separated by a semicolon; a line is a reading. Book names are read as the app reads them everywhere (any accepted name or short form); after the name comes a chapter ("84"), a run of chapters ("7-8"), or verses of one chapter ("119:1-16"). A line that cannot be read is marked where it stands.
- Add a week, remove a week, add or remove a reading, reorder by dragging.
- **Save** is off while any reading cannot be read. Dates may be left unset on a plan with none; following it asks for the anchor (4.1).
- Editing a plan already in use keeps its ticks: a tick stays with its reading through reordering, renumbering and changes to its passages, and goes only when that reading is removed. **(call)**

### 6.3 Text

A text file or pasted text is read with the editor's own form: a line "Week 12" (optionally followed by a date and a label) starts a week, then one reading to a line.

### 6.4 Removing a plan

Delete Plan asks first, as the Notes Browser's Delete does (the reader's own deletes never ask; this is not the reader), and can be undone from the plan window. Its ticks go and come back with it.

## 7. What is stored

Two new kinds of record in the synced store. **This is a change to what iCloud holds, and needs Matt's approval of this spec.**

- **A plan:** its identity, title, when it was made and changed, and its weeks (numbers, dates, labels, readings) held as one encoded value inside the record. A plan is edited rarely and as a whole, so the later change winning is acceptable.
- **A tick:** its identity, the plan and the reading it belongs to (the reading's own identity, not its position), and when it was ticked. Unticking removes the record. Two ticks for one reading are merged to the earlier after each import from iCloud, as two bookmarks on one verse are.
- **Which plan is followed** is a synced preference, not a record.
- Both follow the store's rules: every value optional or defaulted, nothing unique, identities that are the same on every device.
- **The daily backup** already copies the whole store; **Restore** learns to bring back missing plans and ticks. As with bookmarks, Restore brings back a tick the reader has since removed, if the backup has it.
- **The store moves forward only.** Adding the two kinds is a change the store makes by itself the first time the new build opens it. After that an older build cannot open that store on that device, nor restore from a backup taken since. Nothing is lost by this, but there is no going back to an older build without a backup from before. The handover says so, and the Release apps are updated together. [Note, 2026-11-19: the rehearsal showed this sentence is wrong. An older build does not refuse such a store; it opens it, and Core Data migrates it down, dropping both plan tables, so the plans and ticks are gone from that store. With sync on they return from iCloud when the new build next opens it (what had not yet been sent to iCloud would not); with sync off, only a backup holds them. The rule that holds: never run an older build on a store the new build has used. See section 12.]
- **An older build on another device** will not show plans, and must not lose them: it leaves records of kinds it does not know alone. This is what Apple's sync is understood to do; the builder confirms it with a stand-in second store before anything reaches Matt's Release apps. [Note, 2026-11-19: confirmed by the rehearsal: the older build skipped the unknown records and the plan and ticks were still in iCloud, unchanged, afterwards. See section 12.]
- The Release apps sync through iCloud's Development environment, where new kinds of record are added as they arrive; nothing is reset.

## 8. Design changes

`DESIGN.md` and `DESIGN.json`: the band and the plan window (section 5), the Plan tab, its place in the edge swipes and the tab bar's four tabs (section 7), the tick circle (`circle` and `checkmark.circle.fill` in the accent), `calendar` in the symbol inventory. Tokens only; rows and never cards; the progress line as the existing one.

## 9. Constraints

- Everything in project 1's section 10.
- The stored note format is untouched; only the two new kinds are added.
- No test touches iCloud or Matt's stores, and the `.dev` store gets no test plan: it syncs to his phone's Debug app. Plans in tests live in memory or the temporary directory.
- The two PDFs are Matt's church's documents. They are not committed to the repository. The PDF reader's tests use small PDFs the tests draw themselves in the same layout, plus text fixtures of the tricky rows. **(call)**

## 10. Left to the builder

- The table reader's thresholds and how it finds columns when a header wraps.
- The encoded form of a plan's weeks, and its version number so it can change later.
- The editor's layout on the iPhone.
- Whether a week row on the iPhone opens in place or pushes a screen (a pushed screen gives its left edge to the system's back swipe).
- How the plan window and the band are told about a change made on the other device.

## 11. Verification

Tests first:

- The plan model: this week before, during, on the meeting day, the day after, and after the last week; moving a date moves the later weeks; anchoring fills every date; a finished plan.
- Parsing readings from text: each form in section 4 and 6.2, the labels, unknown books, chapters past a book's end.
- The PDF reader against drawn PDFs: a week across a page break, a merged cell over a week, a blank cell, a wrapped name, a date row with a label, weeks of different lengths, a missing header, a PDF with no text.
- The review's flags: each kind in 6.2; Save off with an unreadable line.
- Ticks: tick, untick, counts; two ticks for one reading merge; reordering, renumbering and removing rows keep and drop ticks as 6.2 says.
- Years: a plan read partway through gets the year that puts today inside it; a date that does not exist in its year is flagged; changing the first date's year moves the rest.
- The reader's toolbar button shows only while a plan is followed and not finished.
- Storage: the new records obey the store's rules; backup and Restore carry them; deleting a plan and undoing it.
- Opening a passage is a reading move, not a lookup.

Run once by the builder against the two real PDFs, outside the test suite, and the counts recorded in the plan: Gen 1 gives 67 weeks of five; Gen 2 gives 86 weeks, 77 of four and nine of three, with "Feb 29" flagged.

Seen by eye before it is called done: the band, the plan window and the review on the Mac; the Plan tab and the review on the iPhone; light, dark and Sepia.

For Matt:

- [ ] Import the Gen 1 PDF; the review shows 67 weeks and nothing to check; week 63 is Psalms 71 · Esther 1–3, Psalms 73 · Esther 4–6, Psalms 84 · Esther 7–8, Psalms 90 · Esther 9–10, Psalms 92 · Ezra 1–3.
- [ ] Say week 63 meets Tuesday 17 November; the band shows it; the day after, it shows week 64.
- [ ] Tick a reading on the Mac; it is ticked on the iPhone, and the other way round.
- [ ] Open a passage from the band and from the Plan tab.
- [ ] Move one week's date for a break and see the later weeks follow.
- [ ] Import the Gen 2 PDF and see "Feb 29" flagged. (Overturned by Matt's answer of 2026-11-19: Gen 2 now starts 15 September 2026 with nothing flagged. Section 12, "For Matt", has the item rewritten.)

## 12. As built

Built on 2026-11-19 on `milestone-10-study-tools`, after the spec and a plan (`0330ff5`) of thirteen tasks. Twelve building tasks (`2815814` to `e995356`; Task 4's rehearsal was run by the controller, see below), each reviewed, then a whole-project review of the code (`docs/superpowers/specs/2026-11-19-milestone-10-reading-plans-final-review.md`: ready with fixes, 1 Critical, 5 Important, 15 Minor, and a fix list of 38), one fix wave of four commits (`9671435`, `423a4a8`, `f719e5a`, `a9e4efe`) and one scoped re-review that found all 37 items addressed, then this section and the other documents (Task 13). The ledger is `.superpowers/sdd/2026-11-19-milestone-10-reading-plans/progress.md` and the reports beside it (git-ignored, on disk in the worktree).

**Finished and accepted by Matt on 2026-11-19.** After using both Debug apps he said "Everything else looks good"; told the rehearsal had passed and asked whether that called project 5 done, he answered "Yes, it's done". He did not say which items he tried, so the lists below of what nobody has seen stand. No controller live pass was made. Every picture the sessions made is an offscreen render or a test-window render, but for an implementer's look-only screenshots of the simulator's Debug app in Task 10 (the tab bar's order, the empty Plan tab, the edge swipes); Matt looked himself in the Debug apps and said "Everything else looks good" (what he tried is not recorded). **The older-build rehearsal was run on 2026-11-19 and passed, with a finding** (below): the older build leaves plans and ticks alone in iCloud, but does not refuse a store the new build has used and strips the plans and ticks from it. The main spec's milestone 10 box stays unticked.

**Tests at `a9e4efe`, the code head, as Task 13 ran them on 2026-11-19, one after another:** the package suite 1,356 tests, all passing (1,059 in 100 suites in the main bundle, beside 126, 52, 91 and 28 in the others; no known issue left); the iOS `ScriptureUITests` 986 tests in 93 suites, passing; the Mac Debug build and the iOS Debug build (simulator) each succeed. At the head of the project the counts were 1,258 and 934, so the project added 98 package tests and 52 iOS tests. The check of the church's two real files, run once where they lie (`RealPlanPDFTests`, opt-in): 2 tests passed, Gen 1 67 weeks of five (335 readings, no dates, nothing flagged), Gen 2 86 weeks (77 of four, nine of three, 335 readings), first date 15 September 2026, nothing flagged, 0.21 s and 0.24 s for the whole read of each (the two ran together). The timing benchmarks can fail under full-suite load and pass alone; none failed in this run, and any that does must be rerun alone before it is called real.

### Where the code differs from the sections above

The plan's eight departures, each told to Matt, each with what it costs if wrong:

1. **Section 7 has the builder confirm with "a stand-in second store".** A second store of the Debug build is on the same iCloud database as the `.dev` store, so a plan made in it would reach the phone's Debug app. The confirmation was to be made in a rehearsal identity (its own bundle identifier and iCloud container, permanent and empty on Matt's account), which he approved; it was built and the rehearsal run in it on 2026-11-19 (below). If wrong: nothing is lost by the choice; the empty container stays on his account for good.
2. **Sections 5.1 and 5.2 write dates day first ("Tue 17 Nov").** Dates are written as the system writes them for the reader's region ("Tue, Nov 17"), as every other date in the app is. Matt chose this (2026-11-19, "Your region's order"). If wrong: one formatter.
3. **Section 5.1 says "meets today" on the day.** The mockup kept the date ("meets today, Mon 16 Nov"); so does the build. If wrong: one string.
4. **Section 6.2 gives the title "RTS Gen 1" from the file's name.** No rule gives that from "Gen 1_ RTS Reading Plan.pdf". The title is the file's name without its extension, underscores as spaces ("Gen 1 RTS Reading Plan"); it can be edited. If wrong: one rule.
5. **Section 6.2 says "reorder by dragging".** Readings are dragged within their week; weeks are not dragged, because a week's place is its number and its date and both can be edited. If wrong: dragging whole weeks is on the backlog.
6. **Section 8 puts the tick circle "in the accent".** The ticked circle is in the accent; the empty one is `ink.secondary`, as the mockup drew it grey: an accent ring on every unread reading would be the loudest thing on the front page. If wrong: one colour.
7. **Section 11 says the two real PDFs are read "outside the test suite".** The check is a test that is skipped unless an environment variable names the folder that holds the PDFs, so it can be run again and the PDFs are never copied. If wrong: nothing; the files are still never in the repository.
8. **The mockup's hairlines between a week's readings in the plan window** are not drawn: `DESIGN.md` separates rows by rhythm. If wrong: one modifier.

**Two of the spec's own results were overturned by Matt's answers (2026-11-19).** Section 6.1 expected Gen 2 to start on 15 September 2025 with "Feb 29" flagged, and the last item of section 11's list for Matt expected that flag to be seen. The plan found that the rule as written does not choose (both 2025 and 2026 put today inside the two-year span; the plan broke the tie toward the earlier year, which gives the spec's result) and that the PDF's own dates say 2026: starting 15 September 2026 all 86 dates are Tuesdays a week apart and 29 February 2028 exists, while starting in 2025 they are Mondays until 22 February 2027, "Feb 29" does not exist and the eighteen dates after it are Sundays. Matt chose "Prefer dates a week apart": the import takes the first year in which every date exists and all fall on one weekday, and among several such years, or when none is, the spec's rule decides. **Gen 2 now starts 15 September 2026 and nothing is flagged**; stepping Starts in back to 2025 shows the flag. The change is one function (`PlanYears.firstYear`) and its tests, built after Task 6 (`d49c0ee`) and re-reviewed. If wrong: the same function.

### Decided here

The spec's **(call)** items stand as written unless a departure names them. What the plan decided where the spec left the choice to the builder, each with what it costs if wrong:

- **The table reader's thresholds** start from the spike's (a character joins the word before it within 2 pt; words within 2.5 pt of height are one line; a gap of more than 28 pt ends a Gen 1 week; a wrapped fragment joins the nearest reading row within 17 pt; a header that wraps is the first line of page 1 holding "Wisdom" with any line within 14 pt of it). They read both real files with no warning, so none moved. If wrong: a named constant each, and the reader is built for this church's two layouts only.
- **The stored form of a plan's weeks** is JSON with short keys and a version number, 1: small (the 86-week plan is 35,308 bytes), readable in a backup, and a later version is recognised; a plan stored by a version this build does not know is listed by its title, shown as unreadable in one line, and never written over. If wrong: a version 2 reader beside version 1.
- **The phone's editor** is the Mac's list in a full sheet, one section per week: one editor to keep right. **A week row on the phone opens in place,** one at a time, as a book does in the Library, so nothing is pushed and the tab's left edge is always the edge swipes'. If wrong: a second editor; a pushed screen.
- **How the window and the band hear of a change from the other device:** every model is reloaded after each import from iCloud, as before; the plan model joins that list, and is also reloaded when the followed-plan preference arrives, and told when the day changes (and, after the fix wave, the time zone) or the app comes forward. If wrong: a late refresh.
- **A meeting date is a calendar day** (year, month, day), never an instant, so two devices in different time zones agree which day a week meets. If wrong: a day's error at midnight across zones.
- **A week with no date among dated ones** (Gen 2's week 68 until it is set) is passed over when finding this week. The anchor question is asked only of a plan in which no week has a date. **Setting a date that was unset moves nothing else; moving a date moves every later dated week by the same number of days.** If wrong: one rule.
- **Which plan is followed:** the plan named by the synced preference `followedPlanID`; if it names none of the kept plans (it has not arrived yet, or the plan was deleted elsewhere), the newest, without writing the preference. Choosing a plan in the menu follows it, and so does saving a new one. There is no "none": the band goes when the last plan is deleted. If wrong: a menu item.
- **The year a plan starts in:** Matt's rule above.
- **A passage is written** as the spec and the church's table write it, the book's full name and an en dash ("Psalms 84", "Esther 7–8", "Psalms 119:1–16"); the editor's text uses a hyphen; the app's own reference writer is not used, because it cannot hold a run of chapters and writes "Psalm 84". **A reading's label in text** is a trailing "(…)": `John 11-12 (NT Focus Week)`. If wrong: one writer.
- **What blocks Save:** a line that cannot be read, and a book the app does not know. A chapter the book lacks, a date that does not exist or is out of order and a week out of sequence are flagged and do not block, because chapter counts are the translation being read's and another translation may have the chapter. If wrong: a flag that blocks.
- **A passage the translation being read lacks** (Tobit in the ESV) is dimmed and says "Not in the ESV." as its help; it is never a button that does nothing. If wrong: one view.
- **Ticks without a home** (their reading was removed on another device, or their plan deleted) are never counted and never deleted on import, because an import can deliver a tick before its plan and deleting it then would lose a tick. If wrong: stray records stay.
- **The store's code is a second store on the same container** (as the assistant's is), with its own delete and restore; the notes store's own are not widened. The undo is registered by the plan model in the window's undo manager. If wrong: a refactor.
- **Delete Plan…** is last in the plans menu on the Mac and last in the phone's `ellipsis` menu (the destructive item goes last). The phone's confirmation says nothing of undo, because the phone has no Edit menu and its notes delete without saying anything of undo. If wrong: one menu order and one string.
- **The reader's toolbar button** is in the toolbar on both screens while a plan is followed and not finished, dimmed on the front page where the band is, as Text & Layout is. **The band is not shown over a Library view:** People, Places and About each have a header of their own and the band would take the map's height. If wrong: one condition each.
- **Pasted text** comes in through the system's Paste button in a new plan's editor; no test reads the real clipboard. **⌥⌘P is free:** Matt's window manager binds only Option chords without Command, and no menu of the app uses it. **Change Meeting Date… on the phone** in the `ellipsis` menu is this week's; another week's is in that row's context menu. If wrong: one binding; one menu.
- **The real PDFs are read by an opt-in test; the stand-in and large plans are made by a Debug-only probe** that refuses the main store of the `.dev` and the real containers. If wrong: nothing reaches a real store by the probe, whichever way.

### Rulings made on Matt's behalf

Named as the ledger names them (R for the controller's first two, P for the pre-flight scan's, then one for each task that needed one), each with what it costs if wrong. The whole-project review judged R1, R2 and P1 to P13 sound ("I would have ruled the same"), P14 sound for the build with its consequence added (until the rehearsal ran, the work could be reviewed and fixed but not accepted in `.dev` beside an older phone build; it has since run and passed), and every ruling after them sound except one it would have ruled differently (Task 10's gap, below).

- **R1: the build began without waiting for Matt's three answers.** Tasks 1 to 3 depended on none but the year, which was built as the spec says. If wrong: one function and its tests (which is what the answer cost: `d49c0ee`).
- **R2: no rehearsal identity was made and no plan went into `.dev` until he answered question 1.** A new iCloud container can never be deleted, so it was his word. If wrong: the live passes wait. (He approved it; the container and App ID now exist, empty.)
- **P1: Task 3's on-disk table check used a throwaway test.** A test must not leave a file behind. Costs nothing.
- **P2: the old Debug app was copied for Procedure B** before any build. Costs nothing.
- **P3: the plan window is Mac-only; the date and anchor views are content with no platform chrome,** each wrapped by the Mac's popover or the phone's sheet. If wrong: a small refactor.
- **P4: Task 10's look in the simulator's Debug app** (tabs, scrolling, screenshots only) moves that simulator store forward; its notes do not sync and no older build reads it again. If wrong: the simulator's store only.
- **P5: the phone's delete confirmation names no menu.** One string.
- **P6: the one exception to "never used as a fixture"** is the opt-in real-PDF test, which copies nothing. Nothing.
- **P7: the model takes a calendar and a locale** and the views read them from it, so no rule reads the system's. One init parameter.
- **P8: one test helper** makes a model on an in-memory store with a scratch defaults suite and a fixed day. A helper.
- **P9: the detail line always says "N of M read"** ("0 of 5 read", "5 of 5 read"); the sidebar keeps "done", "3 of 5" or nothing. One string.
- **P10: Delete Plan… is last** (above). One line.
- **P11: straight apostrophes,** as the app's copy writes them. A find and replace.
- **P12: the probe refuses any store of the default name with sync off** (that file is the Debug app's local store). One condition.
- **P13: one `small` fixture, and the tick merge shares the survivor rule** (the earliest, ties the lowest id) with the bookmark merge through one helper. A refactor.
- **P14: the build went on past Task 4's gate** (Tasks 5 to 13 build on the storage before the rehearsal), because a parked session buys nothing and Apple's sync is understood to skip kinds of record a build does not know. **If wrong: if the rehearsal shows plans or ticks lost, the storage and what reads it are rebuilt (Tasks 3, 6 and 13 reopen). This is the ruling the rehearsal tested, and it held: nothing was lost or changed in iCloud (the older build's stripping of a store it should never open is a separate finding, below).**
- **Task 4's fix: the probe compares the store's name without case.** A case-insensitive volume would otherwise open the main store for `-storeName markup`. One line.
- **Task 8's column: the band's scaled column minimum went from 150 to 140** so Matt's week 63, five readings, sits in one row at 1100 pt (the controller saw the fifth wrap). If wrong: one number, changed back.
- **Task 10's gap: a reading's passages keep their 44 pt targets and the gap between readings opens to at least twice the gap inside one** (the reviewer's first fix; the second was a natural pitch with enlarged hit shapes). Five readings now take about 640 pt of the phone's height. The whole-project review would have ruled otherwise (a reading's passages on one line where they fit, which halves the height) and left it to Matt at the live look. If wrong: the other fix.
- **Task 12: the bounds stay; the one over-bound expectation was wrapped as a known issue until the fix wave.** The wave brought both figures under and the wrapper was removed.
- **The fix wave took the review's list as written, items 1 to 37,** and the review's own rulings: Remove Week and Remove Reading became undoable in the editor (they had asked nothing and could not be undone); the ticked passages' ink, the band's two closing rules and the word "tick" in the Restore sentence stayed Matt's. If wrong: a wave of 37 items is large, and what it did not finish was to be reported, not dropped (nothing was left).
- **Three items the re-review left open were parked to the backlog:** a week number typed with a leading zero ("05") is not stored, so the week keeps its old number while the field shows 05 (the week then shows in To check as out of sequence, so it is seen before Save); sidebar and editor rows keep the old date format after a change of region or time zone until their own values change (before the wave both were frozen for the whole app); and opening one draft over another does not clear the editor's undo, which no path does today. No second wave, nothing builds on them, and the first is one line to fix if Matt types week numbers with leading zeros.

### What was built

**Task 1: a plan's values and rules** (4, 4.1). A plan, its weeks, its readings and their passages; a meeting date as a calendar day; this week, moving a date, anchoring a plan that has none; a reading as a line of text and back; the stored form. One fix round: a book name carrying digits ("Psalms 1 2") was read as Psalms 2 with the 1 dropped, and is no longer read as a book. **Task 2: the draft, the text form, years and the review's flags** (4.1, 6.1 to 6.3). What the review edits; text read in the editor's own form; years counted on from the first date; each flag the review raises. **Task 3: the store** (4.2, 6.4, 7). Two kinds of record in the synced store, a plan and a tick, with exactly the spec's attributes; ticks merged to the earlier after every import by the rule the bookmarks use; Restore brings back missing plans and ticks; a delete takes a plan's ticks and an undo puts them back, byte for byte even for a plan a newer build wrote. **Task 4, Steps 1 to 3 only: a Debug probe** that makes, enlarges and clears a stand-in plan, refused in the main store (a fix round made the refusal ignore the case of the store's name). **The rehearsal (Steps 4 to 13) was not run.**

**Task 5: the PDF's table** (6.1, 6.3). The church's table is rebuilt from where each word sits (PDFKit, off the main thread), refused from its first page when it is not a plan; a text file is read by the editor's own form. Read once against the real files by an opt-in test, with no threshold moved. **The year rule's change** (Matt's answer) followed Task 6. **Task 6: the plan model** (4.1, 4.2, 5.4, 5.5, 7). One observable model every surface reads: which plan is followed, this week, ticks and counts, a passage opened as a reading move, a delete that can be undone, VoiceOver's words; reloaded after every import and every new day. **Task 7: the Mac's plan window** (5.2, 6.4). The sidebar of weeks, the chosen week's readings, the plans menu, a changed date and the anchor, Delete Plan with its dialog, ⌥⌘P, View › Reading Plan and ⌘K's Reading Plan (33 commands now). **Task 8: the band and the reader's button** (5.1, 5.4). The week over the contents, the same in a popover from the toolbar's `calendar`, and the model's undo manager handed to whichever window is key. **Task 9: the review that is also the editor, and Import…** (6.1 to 6.3, 5.2's toolbar). The review, the file panel and drop, the alert for a PDF that is not a plan with New Plan offered; three changes outside its own files (the reader's classification of "Esther 7 - 8" as unreadable; the reference parser's tables worked out once; the reading row laid out in one pass). **Task 10: the Plan tab** (5.3). Between Read and Notes, this week at the head, a week opening in place, the menu, the edge swipes' new chain; a fix round put the gap between readings at twice the gap inside one. **Task 11: the phone's editor, Import… and menu** (5.3, 6.1, 6.2). The Mac's editor in a full sheet, the file picker, the menu's rule (what can be done now). **Task 12: the largest plans, measured** (11). Benchmarks on 86 weeks and 335 readings; two figures over their bounds, answered by the fix wave.

### The PDFs, measured

The spike's script was run once against both PDFs on 2026-11-19 (both 612 by 792 pt pages), and the app's own reader read them once in Task 5 and again, with Matt's year rule, after it and in Task 13. The numbers, with the church's files never quoted beyond what this spec already quotes:

| | Gen 1 (12 pages) | Gen 2 (13 pages) |
|---|---|---|
| Weeks | 67, every one of five readings | 86: 77 of four readings and the last nine (78 to 86) of three |
| Readings | 335 | 335 |
| Dates | none | one per week; "Feb 29" is week 68's |
| Rows with no Wisdom passage | 40: 15 "Holidays", 25 "NT Focus Week" (32 of them take the label from a merged cell printed once in the week) | 40: 25 "NT Focus" (printed on each row), 15 blank |
| Flags | none | none from 2026 (the year the dates fit); "Week 68: Feb 29 is not a date in 2027" from 2025 |
| How long the app's reader took, PDF open to draft | 0.29 s (Task 5), 0.21 s (Task 13) | 0.36 s (Task 5), 0.24 s (Task 13); the two read together |
| First date | none | 15 September 2026 |

Week 63 of Gen 1 reads as the spec lists it. An 86-week PDF the tests draw (13 pages) reads in about 0.1 to 0.2 s on both apps. **The finding about Gen 2's year** and Matt's answer are above, under "Where the code differs". The geometry the reader relies on (every cell centred in its column, rows 18.5 pt apart, a tinted gap between Gen 1's weeks and a date on a row of its own after Gen 2's readings, merged "NT Focus Week" and "Holidays" cells printed once, "Lamentation" and "s" wrapped across a row, "Song" for Song of Solomon, "119:1-16", "2,3 John, Jude") is the plan's section "The PDFs, measured".

### The rehearsal: run, and passed, with a finding

Run by the controller on 2026-11-19 as Procedure A (the plan's "Rehearsal results" has every step's counts and times), on Matt's word ("I signed in to Xcode, run the rehearsal. Everything else looks good."). Three earlier tries failed with "No Accounts"; a fourth, after he signed in to Xcode, was refused for Apple's updated licence agreement, which he then agreed to. NEW was this code (`a9e4efe`); OLD was project 4's code (`f2717f6`), in the same identity.

**The confirmation passed.** NEW made a stand-in plan and two ticks. OLD, on a store of its own, stayed running (past two minutes and seventeen seconds), made no plan tables and no crash report, and Core Data logged "Skipping unknown updated record" three times: for `CD_PlanTick` (twice) and `CD_PlanRecord` (once). OLD then exported a bookmark of its own. A fresh store on NEW held the plan, both ticks and that bookmark within 5 seconds, the plan unchanged ("Stand-in plan", 464 bytes of weeks). OLD's own store, opened by NEW, received the plan, ticks and bookmark within 5 seconds. The spec's sentence that an older build on another device leaves them alone is confirmed.

**The finding: an older build does not refuse a store the new build has used.** The plan and this section expected the older build to say the notes could not be opened. OLD opened the store NEW had used, and Core Data migrated it down ("Migration: CloudKit tables detected. Adding migration statements for removed table: ZPLANTICK", and the same for `ZPLANRECORD`), dropping both plan tables: the plans and ticks were gone from that store. One export ended with Cocoa error 134301 (the history token expired); the next three ended with failure none; no crash report. iCloud was not changed: a fresh store on NEW still reached 1 plan, 2 ticks, 1 bookmark in 5 seconds. When NEW reopened that store the tables were made again and the plan, ticks and bookmark came back from iCloud within 5 seconds.

**What it costs.** What would not come back: anything not yet sent to iCloud at that moment, and, with sync off, everything but what a backup holds. So the section 7 sentence that after the new build opens a store "an older build cannot open that store" is wrong. **The rule: never run an older build on a store the new build has used.** The Release apps are updated together, and no older build is ever run again on a store the new one has opened.

**What was left on iCloud: nothing of the stand-in records.** NEW cleared the plan and ticks and toggled the bookmark off; a fresh store a minute after launch, import finished, held 0, 0, 0. The rehearsal's own store folder, its preferences and both scratch builds were deleted; the `.dev` and real store folders were not touched. For good, as Matt approved, on his account: the App ID `com.matthewfurr.ReadingThroughScripture.rehearsal` and the iCloud container `iCloud.com.matthewfurr.ReadingThroughScripture.rehearsal` (Development), now empty of plans and bookmarks (the app's seed records, if any were exported, remain).

**The gates.** Both Debug apps are on this code (the Mac's Debug app was restarted on it and the phone's installed, on Matt's word "Yes, both", on 2026-11-19, so the `.dev` store on this Mac has moved forward), so the gate that forbade a plan in the `.dev` store is met. The gate on the Release apps was the rehearsal, which has passed, with the finding as its condition: the Release apps are updated together, and no older build is ever run again on a store the new one has opened. The Release apps are untouched and wait for Matt's word. A build that refuses a store a newer build has used is in `docs/BACKLOG.md`, wanted before any Release update and his to decide.

### The measured figures

All in a debug build on Matt's Mac, the median of nine unless said, run alone for the figures in the first two columns and as Task 13 ran them in the whole suite for the third. Bounds are the ones the tests hold.

| | Task 12 (before the wave) | After the fix wave | Task 13's run in the whole suite | Bound |
|---|---|---|---|---|
| A tick with 334 of 335 ticked, store write and reload | 14.1 ms | 11.3 ms | 11.5 ms | 16 ms |
| Reload after an import (2 plans, 335 ticks each) | 10.5 ms | | 11.7 ms | 20 ms |
| Decode of 86 weeks (35,308 bytes encoded) | 2.5 ms | | 2.5 ms | 5 ms |
| Choosing each week (128 key moves over 67 weeks) | **25.0 ms** (over) | 8.4 ms (slowest 13.8) | 10.5 ms (slowest 16.8) | 16 ms |
| The band, a full week at 820 pt | 15.5 ms | | 10.9 ms (10.9 wrapped at 512 pt) | 30 ms |
| The Plan tab on week 63 of 67 (iOS) | 117 ms | | 125 to 140 ms | 250 ms |
| An 86-week drawn PDF, 13 pages, read | about 0.1 s | | 0.17 s (iOS 0.19 s) | 3 s |
| One tick with the window observing | 22.6 to 25.7 ms | 11.8 ms | 13.4 ms | 20 ms (was 40) |
| One keystroke in the editor, the model's part, the real chapter counts | 17.5 ms (on a draft that flagged 325 lines) | 0.45 ms | 0.45 ms | 2 ms |
| The same on the 325-flag worst case | 17.5 ms | 0.97 ms | 1.0 ms | 30 ms |
| One keystroke in the hosted 86-week editor, a visible week | **104 to 120 ms** (no bound) | 9.0 ms | 10.0 ms | 33 ms |
| The same in a week off screen | 118 ms | 6.5 ms | 8.8 ms | 33 ms |
| The plan window opening on 86 weeks | 90 ms | | 78.6 ms | 150 ms |
| The review opening on 86 weeks | 256 ms | | 112 ms | 300 ms |
| The review's flags on 86 weeks | 9 ms | | 9.5 ms | 20 ms |
| The front page with the band | 73.7 ms (was 57 before the band) | | 73.0 ms | 100 ms |

**The encoded size of a plan:** 35,308 bytes for the 86-week, 335-reading shape; under 100 KB for either church plan. The two bold figures were over their bounds (or had none) before the wave, which is why the review asked for one; both are under their bounds now, and the "known issue" wrapper on the week-choosing expectation was removed. The figures in the third column were taken under load in one run each and are not a second set of bounds.

### The fix wave

The whole-project review (by reading; nothing run) found one possible trap, five Important findings and fifteen Minor, and a fix list of 38 items; the 38th is this section and the documents. One fix wave took items 1 to 37 in four commits and **34 are done, 3 done differently, none left.** The scoped re-review (four passes, by reading) found all 37 addressed, no new Critical or Important finding, nothing new stored, and the UI rules holding.

**What it changed:**

- **The editor's plumbing (`9671435`).** The editor's fields used to write through positions into a draft that Save and Cancel set to nothing, which could trap at Save, Cancel or Remove, or reopen a blank sheet, and a week number typed just before Save was lost because the field had not finished editing. Fields now write by the line's or week's own identity, do nothing once the editor has closed, and a week number is written as it is typed. A save the store refuses (a full disk, or a plan a newer build made unreadable while the editor was open) no longer closes the editor and throws the draft away: the sheet stays with its draft and says so, once. Remove Week, Remove Reading and a move can be undone (⌘Z, a shake on the phone) in the sheet's own undo manager. The mark under a flagged line no longer repeats "Week N:"; To check focuses the line a turn after it scrolls; the reading field has a help tag; a file panel's failure says "That file could not be read." on both apps; on the phone the second security scope is gone and the keyboard goes down on a drag; the placeholder pairing is pinned in `PaletteTests`. The keystroke's cost fell from about 120 ms to 9 ms: the session parses a line by its text and works Save's rule out from the flags (0.45 ms), and each week and its lines are compared views, so a key redraws one row and not 86 sections.
- **The window and the tick (`423a4a8`).** The chosen week left the window's root, the sidebar rows and the detail are compared views and the detail's rows are updated in place, which took choosing a week from about 25 ms to 8.4 ms. A tick fetches ticks only and a reload assigns only what changed (11.8 ms with the window observing). The plan window follows the day (when the old this week was chosen, it moves to the new one), the time zone as well as the day moves today, a plan with no weeks says "This plan has no weeks yet.", the anchor form starts on the chosen week (Mac) and says "Later weeks move by the same number of days." only for a week that has a date, a failure from the band or the popover is shown in the main window, the week popover is cleared when the button goes, and an unavailable passage is `ink.tertiary` text with its help and not a dimmed button.
- **The store (`f719e5a`).** Records sharing one identity (two devices that each restore one backup) are treated as one plan: listed once, saved together, deleted together; same-identity tick twins are left alone by the merge, since no rule can make two devices keep the same one. Tests added for a save over an unreadable stored plan, a delete and restore of an unreadable plan, and a stored day that is not a date. The probe's refusal moved beside the store's location and is tested; a Debug launch refreshes after the probe only when one ran.
- **The rest (`a9e4efe`).** The Plan tab is warmed like Notes without its side effects, a week's date can be set only through the draft's own method, tests for the phone's list at an out-of-range week and an earlier open week, the year rule's two cases made to discriminate, and a stale comment.

**Three items done differently, and why:**

- **Item 4, the compared views.** Header, line and foot as compared views, as asked, left the keystroke at 33 ms because the editor's body still re-ran the list's diff of 86 sections. Each week is therefore also one compared section view, which took it to 9 ms. A row's own list modifiers are not seen through that, so the insets, separator and background are given to the section from outside (a render matched the old spacing). Costs: the focus binding is passed through compared views, which only a live look can confirm.
- **Item 7, undo.** Not a whole-draft snapshot: each undo puts back the one thing taken (the week at its place, the line at its place, the week's old order), so text typed in another line after a remove survives its undo (a test checks it). Undo and redo both register, every action does nothing once the editor has closed and closing removes the session's actions from the manager. Costs: whether the field's own typing undo interleaves with these is unseen.
- **Item 13, the placeholder.** The system's placeholder colour is not a token, so no test could hold it. The phone's week fields draw their prompt ("Label") in `ink.tertiary` and the pairing is tested; the Mac keeps the system's prompts. Costs: the Mac's prompts are not pinned.

**What the re-review left open** (three items; the controller parked them to the backlog with these rulings): a week number typed with a leading zero is not stored; sidebar and editor rows keep the old date format after a change of region or time zone; opening one draft over another does not clear the editor's undo (no path does today). Item 19 (a delete's or restore's undo registers only after a write that succeeded) has no test, because the in-memory store cannot be made to fail one; it rests on reading. Decisions the review did not settle are in the fix wave's report, among them that an emptied week-number field keeps the week's number until digits are typed, that a refused save is said once, in the sheet, and that with both the plan window and the main window open an error is said by the one in front.

### Known limits

- **The reader is built for this church's two layouts.** Another group's PDF that is not laid out like these is refused with "This PDF isn't laid out like a plan Bible Carrel can read. You can type the plan in instead." and New Plan. The thresholds are named constants; none was tested against any other layout.
- **A table reader's two edges, found in review and left because neither real file has them:** a row holding only a date, with no reading rows since the last date, becomes an empty week (a wrapped date cell would add a phantom week), and a wrapped fragment's date-column words are dropped when it joins a row. The review shows both.
- **A verse past a chapter's end is not flagged.** A chapter a book lacks is flagged, a verse run is not checked against the chapter.
- **A reading moves to another week only by retyping.** Readings drag within their week; weeks are not dragged.
- **A plan edited on two devices at once ends as the later edit,** as the spec accepts for a record edited as a whole. **A save from an editor left open while another device's edit arrived replaces that edit whole** and deletes the ticks of readings it added; the editor does not compare the stored change time with its draft's. (Later: say so before saving.)
- **A leftover twin record.** When two devices each restore one backup before the other's restore has arrived, there are two plan records with one identity. The store treats the two as one plan (listed once, saved and deleted together) and the extra record stays; same-identity tick twins stay as well. The bookmark merge has had the same shape since milestone 7 and is outside this project.
- **A plan-only store's backup is skipped** when nothing is highlighted or noted and the newest backup on disk has marks in it, because the daily backup counts highlights and notes only (`StoreBackup.markCount`). A store that holds plans and no marks is taken as empty. The backup file still carries plans and ticks whenever it is taken.
- **The store moves forward only, and an older build does not refuse it.** After a build with plans has opened a store, an older build run on that store strips the plans and ticks from it (the rehearsal's finding, above); with sync on they return from iCloud when the new build next opens it, but what was not yet sent, and everything with sync off but what a backup holds, does not. Never run an older build on a store the new build has used; update every device before the first plan is made, and the Release apps together. Nothing in the code yet stops it (see `docs/BACKLOG.md`).
- **A plan stored by a newer version** is listed by its title and shown as unreadable, never written over; a stored passage is not checked when it is read back (a chapter below 1, an end before its start), because only a malformed record has one and the passage then cannot be opened.
- **An empty text file opens an editor with no weeks and says nothing,** and a text file that is not a plan opens a review of unreadable lines; the review catches both.
- **Closing the plan window drops its undo manager and so Delete Plan's undo;** the spec asks only for undo from the plan window. On the phone a shake undoes it on the Plan tab. The phone's confirmation does not mention undo.
- **Flags are not recomputed when the translation being read changes with the editor open,** and chapter counts are the translation being read's.
- **Ticks whose reading was removed elsewhere or whose plan has not arrived** are kept and never counted.
- **The iPad is not built,** and the spec does not ask for it.
- **The band at the larger text sizes was not seen;** its columns' minimum scales, so five readings wrap at a large size, as expected.
- **A week with no date among dated ones** is passed over when finding this week (Gen 2's week 68 until it is set).
- **Parked by the re-review:** a leading zero in a week number; the old date format kept by sidebar and editor rows after a change of region or time zone; opening a draft over a draft keeps the old undo.

### Seen live, and by whom

- **Matt, in the Debug apps, and by his word only.** He looked himself and said "Everything else looks good"; what he tried is not recorded. **An implementer, once.** In Task 10 an implementer launched the simulator's Debug app and took look-only screenshots: the tab bar reads Read, Plan, Notes, Ask beside the search button; the Plan tab with no plan shows "Plan" and "No reading plan"; edge swipes from Read's right edge reach Plan and then Notes and the left edge goes back. Nothing was tapped, no plan was made, and the simulator's store holds none.
- **The controller looked at pictures, not at the apps.** It opened renders in Tasks 7 to 11 and the fix wave (week 63 on the plan window, the change-date form, the band's columns at 1100 pt, every flag in the review, the Plan tab anchored on week 63, the phone's review of 86 weeks, the editor after the wave) and ruled on what they showed: the band's column minimum, the gap between readings, and the date field's text crowding its right edge (put to the live look).
- **Offscreen renders only,** the implementers' temporary tests (an offscreen hosting view written to a PNG, or a test window's layer), each picture opened and the test removed: the plan window, the band, the popover, the review with every flag and its phone version, the Plan tab, in light, dark and Sepia (the popover in two), at the largest standard and one accessibility text size on the phone (macOS ignores Dynamic Type offscreen). A render cannot show focus, a key, a toolbar, a popover's anchor, a file panel, a drag, a sheet, the tab bar's glass or a swipe, and a system button in the phone's bar blanks the render, so the phone's editor was drawn without its bar.
- **By no controller:** everything else, below, but what Matt looked at himself. The Release apps are untouched and not built.

### Not seen by anyone

By surface; the live look's order is under "For Matt".

- **The Mac's editor:** a late field commit then Save or Cancel (the Critical finding's cure); Remove Week and Remove Reading with the keyboard in the removed row or a later one; typing in a long draft (measured at 9 ms hosted, never felt); To check taking the keyboard in a far line; a dragged reading (no flash, the field keeping the keyboard); New Plan from the not-a-plan alert really presenting the sheet (if it is dropped, three toolbar items stay dimmed); the Paste button; the Starts in stepper; the date field's text against its right edge (AppKit's date field drawn in a window that is never key). **From the fix wave:** focus through the compared row views, and Return between lines; whether a field's typing undo interleaves with the sheet's undo of a remove or move; whether the Mac sheet's undo manager is its own; the "Could not save" alert inside the sheet.
- **The Mac's plan window:** ⌥⌘P, View › Reading Plan and ⌘K really opening it; the sidebar taking the keyboard as it opens; ↑ and ↓ and the beep at either end; Tab reaching the passages, Space on a circle, Return on a passage; the plans menu's checkmark; Change Meeting Date…'s popover and its anchor; Set Dates and Change taking the accent once the window is key; the toolbar; the confirmation dialog and Edit › Undo and Redo; the last sidebar row cut by about 12 pt with week 86 this week (maybe an offscreen artefact); week 14 in view but not centred in a render; a PDF dropped on the window; the file panel; the window following midnight.
- **The Mac's main window:** Tab order with the band; the contents taking the keyboard as the page opens and after ⇧⌘H (and, a behaviour change, after a Library view is closed from the pane's icon); Space on a circle and Return on a passage; the reader's button dimmed on the front page; its popover's anchor and its closing on a passage, on The whole plan and on Esc; the popover in Sepia; whether the main window gives up the plan's undo manager on every screen switch; two "Could not save" alerts on one chain (the window in front says it); the band at a larger text size.
- **The phone (simulator or device):** the Plan tab scrolling to this week each time it is shown again, and when another plan is followed or the day changes; whether the first swipe from Read into a large plan stalls (the Plan tab is warmed now); a circle under a thumb; a passage bringing Read forward; the context menu on a week and the `ellipsis` menu; the date sheet's bar buttons; Delete Plan… and a shake; the editor's sheet in Sepia and dark (its background is on the stack, not the sheet), Save dimmed in the bar (never seen), the keyboard over the last line, the number pad then Save, the file picker, the Paste button, swiping a line away, whether a reading can be dragged at all (a long press on a line begins text selection), swiping the sheet down; the anchor form's buttons inside the list; the two weeks' date chips drawing in different forms and places in one render; the accessibility text sizes and VoiceOver on a reading and a week; any real device.
- **Across devices and time:** a tick on one device reaching the other; a plan made on one arriving and being followed on the other; the day after a meeting with the app left open overnight; and what happens to a tick in flight when an older build is run on a store the new build has used (the rehearsal showed the plans and ticks stripped and restored from iCloud, but only the stand-in's, at rest).
- **By nobody:** whether anything behaves differently on the Release build.

### The whole-project review and its re-review

Verdict **ready with fixes**, by reading only; the review ran nothing. **C1:** the editor's fields wrote by position into a draft Save and Cancel had set to nothing (a possible trap at Save, Cancel or Remove, and a typed week number lost). **I1:** a failed save closed the editor and discarded the draft. **I2:** two devices each restoring one backup left two plan records with one identity, and same-identity tick twins could each be deleted by both devices. **I3:** a keystroke in the 86-week editor cost about 104 ms. **I4:** choosing a week cost 25 ms against 16. **I5:** the older-build rehearsal was owed when the review was written, a gate and not a defect (it has since run and passed, with a finding; see "The rehearsal" above). The review found the storage exactly what Matt approved (two kinds of record with the spec's attributes, one synced key, everything defaulted, nothing unique, no relationship, and nothing else stored), a plan from a newer build never written over, records out of step handled by construction, and the UI rules holding on every new view. It triaged every deferred line of the ledger (fix, backlog, drop, or the live list); the backlog ones are in `docs/BACKLOG.md`. Its three owner's items and the Task 10 gap are Matt's, below. The re-review found every one of the 37 items addressed, and no new Critical or Important finding.

### For Matt

Nothing here is ticked on his behalf. This is the spec's section 11 list with its last item rewritten for his answer, **with what this session could not check beside each item,** then the live look in the order the whole-project review gave it, then the choices that are his.

- [ ] Import the Gen 1 PDF; the review shows 67 weeks and nothing to check; week 63 is Psalms 71 · Esther 1–3, Psalms 73 · Esther 4–6, Psalms 84 · Esther 7–8, Psalms 90 · Esther 9–10, Psalms 92 · Ezra 1–3. *Could not check:* anyone using Import… live (the file panel, the progress, the drop). The real file was read by the opt-in test only: 67 weeks of five, 335 readings, no flags, week 63 as listed, in 0.21 s. The review's look is a render.
- [ ] Say week 63 meets Tuesday 17 November; the band shows it; the day after, it shows week 64. *Could not check:* the anchor form and the band live (renders only); the day moving on by test (`thisWeekAndTheButtonFollowTheDay`, `theDayAndTheTimeZoneChangingMoveToday`), not left open overnight. Since 17 November has passed, anchoring it now shows week 64, meeting Tuesday 24 November.
- [ ] Tick a reading on the Mac; it is ticked on the iPhone, and the other way round. *Could not check:* a tick on any device. The merge is by test; the crossing of plans and ticks through iCloud was Task 4's (one stand-in plan and two ticks reached fresh stores and an older build's store within 5 seconds); no one has ticked a real reading on one device and seen it on another.
- [ ] Open a passage from the band and from the Plan tab. *Could not check:* Read coming forward live on either app (read in the code and tested as a reading move, not a lookup).
- [ ] Move one week's date for a break and see the later weeks follow. *Could not check:* the popover and the phone's sheet live (renders); the rule by test.
- [ ] **Import the Gen 2 PDF: it starts 15 September 2026 with nothing to check; stepping Starts in to 2025 flags Feb 29.** *Could not check:* the stepper never driven live; the real file by test, both ways.
- [ ] The band, the plan window and the review on the Mac, and the Plan tab and the review on the iPhone, in light, dark and Sepia. *Could not check:* anything live; every picture is a render, the popover in two appearances only.

**The live look, in order.** The whole-project review's list, with the fix wave's four added at the end; it is the longest list in this milestone and the first seven items, the Mac's editor, are where the highest risk is.

**Before anything: nothing is owed from the rehearsal.** It has run and passed (above); its store and builds were deleted, and the Debug apps are both on this code, so a plan may be made in `.dev`. What stays: no Release build until Matt says, and no older build is ever run on a store this build has opened. The looks below are made in the Debug apps, with a plan of his own made there (or the rehearsal identity built again as the plan's "The rehearsal identity" says, if he wants a stand-in plan, `-planProbe large`, and he knows the App ID and container are there).

**The Mac's editor (the highest risk: the late field commit and the typing cost lived here)**

1. Import… a text file: the review opens. Change a week's number and click Save without leaving the field. The number is saved, nothing reopens, nothing crashes.
2. The same with Cancel, with Remove Week on the last week while a field in it has the keyboard, and with Remove Reading on a line with the keyboard in it and in a later line.
3. Type in a line of an 86-week draft: no hitch per key.
4. A To check line for a far week: it scrolls there and the line takes the keyboard.
5. Drag a reading within its week: no flash, the field keeps the keyboard.
6. A PDF that is not a plan: the alert, and New Plan from it opens the sheet (if it does not, three toolbar items stay dimmed).
7. A PDF dropped on the window; the Paste button in a new plan; the Starts in stepper; the date field's text against its right edge.

**The Mac's plan window**

8. ⌥⌘P, View › Reading Plan and ⌘K each open it, on this week, in the middle of the sidebar, the sidebar holding the keyboard.
9. ↑ and ↓ through the weeks, held down: smooth, with a beep at either end; with week 86 this week, the last row whole.
10. Tab reaches the passages; Space on a circle; Return on a passage brings the main window forward at that chapter.
11. The plans menu's checkmark; Change Meeting Date…'s popover and its anchor; Set Dates and Change in the accent.
12. Delete Plan…, the dialog, then Edit › Undo and Redo. Again straight after closing the editor. Again after clicking the main window and coming back.

**The Mac's main window**

13. The band: five readings in one row at the usual width, wrapping at 820 pt; the two rules at its foot; a tick; a passage opened; The whole plan.
14. Tab order with the band; the contents holding the keyboard as the page opens and after ⇧⌘H; closing a Library view from the pane's icon.
15. The reader's button: dimmed on the front page; its popover's anchor; closing on a passage, on The whole plan and on Esc; a tick there showing in the open plan window. The popover in Sepia, which no render shows.
16. Light, dark and Sepia across all of it; the band at a larger text size.

**The phone (the simulator's Debug app, or a rehearsal app built again, then the device)**

17. The bar: Read, Plan, Notes, Ask and search. The Plan tab opens with this week at its head, and again each time it is shown. Whether five readings at about 640 pt is too tall.
18. The edge swipes Read, Plan, Notes; whether the first swipe into a large plan stalls.
19. A circle ticks under a thumb; a passage goes to the Read tab.
20. A week opens in place; its context menu; the `ellipsis` menu, its plan picker, Change Meeting Date… and its sheet's bar buttons.
21. Delete Plan…, then a shake.
22. The editor's sheet: Sepia and dark behind it; Save dimmed in the bar; the keyboard over the last line; a week number typed on the number pad and then Save; the two date chips' form and place; swiping a line away; whether a reading can be dragged at all; swiping the sheet down.
23. The anchor form inside the list: its picker, its date and Set Dates each answering their own tap.
24. The accessibility text sizes; VoiceOver on a reading (its action and its passages' actions) and on a week row.

**Across devices and time**

25. A tick on the Mac shows on the phone and the other way; a plan made on one arrives and is followed on the other.
26. The day after a meeting, with the app left open overnight: the band, the button, the window and the tab have moved on.

**Added by the fix wave's re-review (the editor's new plumbing, which a render cannot show)**

27. Focus through the editor's row views, and Return between lines: each line keeps the keyboard as rows are redrawn.
28. Whether a field's typing undo interleaves with the sheet's undo of a remove or a move (⌘Z after typing in one line and removing another).
29. Whether the Mac sheet's undo manager is its own, or the window's (⌘Z in the sheet must not undo a Delete Plan in the window behind, and the reverse).
30. The "Could not save" alert inside the sheet: a save the store refuses (for example, a plan made unreadable by a newer build) keeps the sheet and the draft and says so once there.

**Choices that are his to make** (none answered, but the three answers of 2026-11-19 below):

- **Answered 2026-11-19:** the rehearsal build (approved, built, run and passed); the year (Gen 2 starts 15 September 2026, nothing flagged); dates in the region's order.
- **The eight departures** (above), most likely to matter: the empty circle in `ink.secondary` and the ticked one in the accent; no hairlines between a week's readings in the plan window; dates in the system's order.
- **Ticked passages are `ink.tertiary`,** which the spec asks for and which is under 4.5:1 by the spec's own choice (`DESIGN.md` reserves that ink for text that is "never the only channel"). They still open. Say if they should read more strongly.
- **The band closes with two rules,** the plan's progress line on its track and then the hairline, a few points apart (with nothing ticked they read as a double rule). Both are the spec's. Keep both, or drop one.
- **The word "tick" in the Restore sentence** ("Restored 1 reading plan and 2 ticks."): it is the spec's word and appears nowhere else in the app, which says "Mark as read". Say if it should.
- **On the phone, a reading's passages one to a line with a wide gap between readings** (this week's five readings take about 640 pt, nearly the screen), **or on one line where they fit** ("Psalms 71 · Esther 1–3", each still 44 pt high, half the height). The review would have chosen the second and left it to him at the live look.
- **Where Delete Plan… lives:** last in the plans menu on the Mac and last in the phone's `ellipsis` menu.
- **Whether "Everything else looks good" and a passed rehearsal call project 5 done:** not yet asked. **When to update the Release apps** (together, never an older build run on a store this one has opened), and whether a build should refuse such a store first (`docs/BACKLOG.md`).

