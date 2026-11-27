# Milestone 12: the site

Status: **Approved by Matt, 2026-11-26** ("4. Approved."), as its second draft: a roadmap page and an appearance switch were added at his word the same day, and he chose the licence, the fresh history and settled the icon (section 10). **Amended the same day, after he saw the built site:** the appearance control is an icon that switches between light and dark, and the site has no Sepia (section 4.4; his words are there). Branch `milestone-12-site`, cut from `main` at `84f3909`, in the worktree `.claude/worktrees/milestone-12-site`. No app code changes except one test (section 7.2).

## 1. Intent

Matt, 2026-11-26: "instead for Milestone Twelve what I'd like is a GitHub pages like about this repo style site. it should have like a marketing slash like features page of like what the app is, what it does, screenshots, features, info about where the sources are, that kind of stuff. And then maybe like a documentation type page or pages as well that talks about how to use it." On the look: "The design should be similar to the app, in terms of like fonts and stuff. I think my favorite of the page styles is Printed or lectern", and, corrected the same day, "**Loosely** based on those designs." On who it is for: "Nobody else can get the app, but they can build it for themselves when we do publish the repo."

So the site is for someone who finds the repository and wants to know what Bible Carrel is, see it, learn how it is used and build it for themselves. It is not a storefront: there is nothing to download.

Today (main at `84f3909`):

- The repository has **no git remote**; nothing is on GitHub. There is no `LICENSE` file.
- Everything a guide would say is in `README.md` (313 lines), written for the developer: behaviour mixed with `UserDefaults` keys, launch arguments, store paths and rehearsal notes.
- Every outside source is listed once, in `Packages/ScriptureKit/Sources/ScriptureUI/Credits.swift` (17 credits in three sections), and Settings › About shows that list.
- There are no screenshots of the app anywhere in the repository.
- `docs/` holds the specs, plans, ledgers and `BACKLOG.md`, so it cannot be the site's folder.
- The earlier milestone 12 (read-only when a newer version has opened the store; Matt, 2026-11-20) is displaced, not dropped. This spec's commit renames its backlog heading (section 9).

## 2. Goals, non-goals, anti-goals

**Goals**

- A front page that says what the app is in one screen, shows it in real screenshots, walks through its features, names its sources and points to the guide and to building it.
- A guide: how to use the app, page by page, written for a reader and not for a developer.
- A Build page that a stranger with Xcode can follow, honest about what is theirs to change.
- A Sources page with every credit the app shows, kept in step with the app by a test.
- The look of the Printed page, loosely: Literata, the slate paper, bronze labels, verdigris for the site's own controls. Light and dark, each designed, following the visitor's system unless they choose (Matt, 2026-11-26: "Users should be able to change the light or dark setting.").
- A roadmap page: what is planned next, in plain words (Matt, 2026-11-26: "Add a roadmap page. Plans to move to the API for ESV, etc.").
- Ready to go live the day the repository is published, with nothing left to build then.

**Non-goals**

- Publishing. Creating the GitHub repository, pushing, making it public and turning Pages on are Matt's, on his word (section 10). Nothing in this milestone pushes anything.
- A download, the App Store, TestFlight, a notarised build.
- Changes to the app, the README's structure (it gains one link to the site), or `Credits.swift`.
- A custom domain, a blog, a changelog, release notes.
- Search inside the guide (backlog, section 9).
- API documentation (DocC), video, localisation, analytics of any kind.

**Anti-goals** (the site fails if any of these is true, even if it builds)

- It reads as a SaaS landing page: gradients, card grids, stat tiles, badges, testimonials, emoji, "Get started free". `PRODUCT.md`'s anti-references apply to the site as they do to the app.
- A screenshot is drawn, mocked or retouched. Every picture is the app.
- A picture or a line of prose shows copyrighted Bible text (ESV, NASB, AMP, ERV), Matt's own notes, or the church's reading plans.
- It says something about the app that the README or the code does not support, or presents something not built as if it were. The roadmap page is the one place planned work is named, and it is named as a plan, with no dates.
- It loads anything from another origin: no font service, no script, no tracker, no embed.
- It suggests the app can be downloaded.

## 3. Approaches

**The look.** Three directions were shown as mockups (`docs/superpowers/specs/milestone-12-mockups/site-directions.html`, kept as shown; open it in a browser):

- **A · Printed.** A features page in the usual shape (a title, one large screenshot, then each feature with a picture), set as the Printed page sets a chapter. Shows the most of the app at a glance.
- **B · Lectern.** One narrow column on warm paper, small-capital title, drop numerals, screenshots as captioned plates. Quieter and more unusual, less to scan; Iowan Old Style cannot be served, so only Apple devices would see the real face.
- **C · Contents page.** The app's own home page as the site's front: contents on the left, a pane on the right. The most like the app; a visitor must click to see each feature.

**Matt chose A** (2026-11-26, "A"). The mockup's fourth tab, a guide page, goes with it.

**How it is built** (Claude's call; Matt was told and did not object):

- **Eleventy, with the guide in Markdown.** Node is already on Matt's Mac (v26), so the site previews locally; the guide's pages are Markdown files a person can edit; one layout carries the navigation. **Chosen.**
- **Jekyll, built by GitHub.** Nothing to install in the repository, but the Mac's Ruby is 2.6 and Jekyll is not installed, so there would be no local preview without new tooling.
- **Hand-written HTML.** No toolchain at all, but about twenty pages would each repeat the navigation, and the guide would be HTML to edit by hand.

## 4. What is built

### 4.1 Where it lives

- `site/` at the repository root: `package.json` and its lockfile, the Eleventy configuration, `src/` (layouts, pages, guide Markdown, styles, fonts, images, data) and `README.md` (how to preview, build and retake the screenshots). The built output (`site/_site/`) and `site/node_modules/` are git-ignored.
- `.github/workflows/site.yml`: on a push to `main` that touches `site/**` (and on manual dispatch), install with `npm ci`, build, and deploy with GitHub's Pages actions. It cannot run until the repository is on GitHub; it is written and linted, not exercised (section 8).
- The site must work under any base path, since a project site is served from `/<repository>/` and the repository's public name is not settled: every internal link and asset goes through Eleventy's path prefix (the HTML base plugin or the `url` filter), and the prefix and the site's full address come from the Pages action's outputs at build time, never a hard-coded string. Locally the prefix is `/`.
- Dependencies are few and pinned by the lockfile: Eleventy and what it needs for images and Markdown. No CSS framework, no client-side framework, no bundler. The site needs **no JavaScript to read**; a script may add a convenience (section 4.3) and nothing may depend on one.

### 4.2 Pages

One front page, the guide, and three standing pages. Titles below are final unless the writing shows a better word; the grouping is the guide's sidebar.

| Group | Page | Covers (from the README section of the same subject) |
|---|---|---|
| | **Front page** | Section 4.4 |
| | **Build it** | Section 6 |
| | **Sources** | Section 7 |
| | **Roadmap** | Section 4.5 |
| Start | Your first chapter | Opening the app, the home page, choosing a book and chapter, the reader at a glance, where the guide goes next |
| Reading | The reader | One chapter at a time, the running head and progress line, Previous and Next, the book thumb, how a chapter is set |
| | Page styles and text | The four styles, font, size, spacing, width, layout, verse numbers, headings, appearance; ⌘T; what syncs |
| | Your place | Where the app reopens, reading against looking up, Back and Home, Read From Here |
| | Reading plans | Bringing a plan in, the review, this week, ticks, meeting dates |
| Marking | Highlights and bookmarks | The markup menu, colours (yours to name and add), bookmarks, the reader's keys, undo |
| | Notes | Notes on a phrase and on a chapter, the notes column, editing, Markdown, links in notes |
| | The Notes window | Every mark across the Bible, filters, search, sort, exporting notes as Markdown, kept versions |
| Studying | The Library | The home page's contents, rings, People and the family tree, Places, About and the timeline, dates |
| | Search and ⌘K | The palette, the five search forms (the README's table), scopes, "did you mean", Recent |
| | Verse panels | Compare Translations and Cross-References |
| | The study assistant | The three ways in, prompts, who answers (on-device first, a key for the rest), Add as Note, conversations |
| Keeping | Sync and backups | What syncs and what stays on a device, the daily backup, Restore, signing out of iCloud, never copy a store between Macs |
| | Export and import | Export All Data, Import Data and what it never does |
| The iPhone | The iPhone app | What is the phone's own: the tabs, the pen, the chapter switcher, the thumb, swipes, Search |
| Reference | Every shortcut | All keyboard shortcuts in tables, grouped as the app's own shortcuts sheet groups them |
| | Passage links | The `bible://` form |

Every other guide page covers the Mac first and gives the iPhone's way under an "On the iPhone" heading where it differs.

### 4.3 The parts every page shares

- **Header:** the app's icon and "Bible Carrel" at the left (to the front page), then Features, Guide, Sources, Roadmap, Build it, and GitHub (the repository's address, from one configuration value; until it is set the link is left out entirely, not shown dead). Below about 700 px the links wrap onto a second line; no hamburger menu.
- **Footer:** one line: the app's name, a link to the Sources page, and "© 2026 Matthew Furr. The code is under the GNU General Public License, version 3." with the licence linked to the site's own copy of `LICENSE` (copied at build time, as the other licence texts are). The texts, data and typefaces keep their own licences, which the Sources page gives.
- **The icon** in the header and as the favicon is the app's own, taken from a built app's icon (its `.icns`) or exported from `AppIcon.icon`; the repository has no flat image of it.
- **Guide layout:** the sidebar of the table above (the current page on `accent.wash`), the article at the reader's measure, Previous and Next at the foot in the guide's order. Below about 900 px the sidebar becomes a `<details>` "Guide contents" above the article.
- **A skip link**, landmarks (`header`, `nav`, `main`, `footer`), one `h1` a page, headings in order.
- **Appearance,** at the header's trailing edge: one icon button that switches between light and dark. It shows the appearance a press would switch to (a moon while the page is light, a sun while it is dark) and its accessible name says so. With nothing chosen the page follows the system; a press switches to the other appearance and keeps that choice in the browser (`localStorage`), applied before the first paint by a few lines in the page's head, so a chosen appearance never flashes the other. Reachable and operable by keyboard. As first built it was a labelled menu of System, Light, Sepia and Dark, Sepia being Claude's addition; Matt, on seeing it (2026-11-26): "No need for sepia and this should not be a dropdown. It should be an icon that toggles between them."
- **Script:** the appearance control is the one thing that needs a script. With scripting off the control is not shown, the site follows the system's light or dark, and every page is complete. Nothing else may depend on a script.

### 4.4 The front page

**As rebuilt on 2026-11-26 after the critique: "the page and its margin" (Matt chose mockup C of three, `milestone-12-mockups/front-page-directions/c.html`).** The front page is laid out as the app's reader is: a column of text with a notes column on the panel surface beside it. Top to bottom:

1. **Title.** The bronze label "For Mac and iPhone", "Bible Carrel" in Literata Light, one italic line saying what it is, then two ways on: **Build it from source** (the page's filled button; Matt, 2026-11-26, after the critique: building is the one thing a visitor can do) and **Read the guide** (a link). Under them, one small line that says plainly it is not in the App Store and is built from source.
2. **The page.** Eight passages down the text column, in this order: The page · Marks and notes · The Library · Search and ⌘K · Reading plans · The study assistant · On the iPhone · Keeping what you make. Each has an italic heading in the app's section-heading style, one paragraph whose sentences are numbered like verses (the numbers run on from passage to passage, as verses do through a chapter), one phrase in it highlighted in one of the app's five default highlight colors, and its picture below, linked to its full size. The last passage has no picture.
3. **The margin.** A notes column beside the text, headed "Notes" with its count. Each passage has one note there, level with it: a dot in the highlight's color and the passage's name, the highlighted phrase in italic, one plain sentence, and the link to that part of the guide. Below 900px there is no column, and each note follows its paragraph as a row between hairlines.
4. **The sources,** as an aligned two-column list (what, then whose and under what license), with a link to the full Sources page.
5. **Build it,** two or three sentences and the same filled button to the Build page.

**Pictures on the front page (Matt, 2026-11-26): "Don't use any sepia screenshots unless it is specific to showing that sepia is an option. But it is not what I want the leading screenshot to be."** The first picture is the Printed reader (`reader-hero`, with its dark twin). `reader-lectern-sepia` is not on the front page; it stays in the guide's Page styles page, beside the sentence that names Sepia as an appearance.

The first build's front page, mockup A of the first three, was rows of words beside pictures on alternating sides, each under a bronze label. The critique found that structure generic, and its pictures too small to read.

### 4.5 The roadmap page

A short page, set like a guide page without the sidebar: one opening sentence saying these are plans and not promises, then each planned piece as a heading and two or three sentences on what it is and why. No dates, no version numbers, no percentages. Its content comes from `docs/BACKLOG.md`, and only from items marked **(wanted)** or already promised in `PRODUCT.md`:

1. **Translations from their publishers.** The ESV and NLT (and the NTV in Spanish) fetched from the publishers' own services with the reader's own key, within each publisher's terms, with their own section headings, in place of bundled copies of copyrighted texts (`2026-11-12-online-translations-handover.md`). The page says what this changes for someone building the app: fewer texts under copyright arrive with the build. It names the NIV only as "if a route opens".
2. **An older version meets a newer store:** read-only until updated, so nothing is lost.
3. **Built-in reading plans:** a year through the Bible and the like, beside imported ones.
4. **Paul's journeys** and other routes on the Places map.
5. **The iPad.**

The page ends with one line pointing to the backlog file in the repository for everything else set aside (a link shown only once the repository's address is set). When an item is built or dropped, its entry leaves the page in the same commit as its backlog line: `CLAUDE.md`'s "Later work" section gains that rule.

That the copyrighted texts will stop being bundled is Claude's reading of "move to the API for ESV"; Matt approved the spec with that reading stated.

### 4.6 The look

The rule is `DESIGN.md`'s, carried to the web: nothing arbitrary. Every colour, size and gap is a named custom property in one stylesheet; no value typed by feel in a page.

- **Colour.** The tokens of `DESIGN.md` section 2 by name, light and dark. `prefers-color-scheme` chooses between them until the visitor chooses, and a `data-appearance` attribute on the root element overrides it: `paper.page` `#F5F7F9` / `#101418`, `paper.panel` `#EDF1F4` / `#191D22`, `paper.overlay` `#FAFCFE` / `#22272D`, `ink.primary` `#192028` / `#E5E8EC`, `ink.secondary` `#5D646C` / `#A0A5AB`, `ink.tertiary` `#8D9399` / `#6D7277`, `ink.rule` `#D3D8DC` / `#292E34`, `ink.verse` `#7A5320` / `#DDB683`, `accent` `#247966` / `#73C3AE`, `accent.wash` `#D1F0E6` / `#0A3028`. The page is `paper.page`; the guide's sidebar and code blocks sit on `paper.panel`; keycaps on `paper.overlay` with an `ink.rule` edge.
- **Where each goes.** Bronze (`ink.verse`) for the spaced labels and the raised feature numbers, as the Printed page uses it. Verdigris for links, the one filled button and the current page's wash, as the app keeps it for chrome. `ink.tertiary` never carries text a visitor must read. The plum and the mark colours do not appear in the site's own design; they are seen only inside screenshots.
- **Type, two voices as in the app.** Literata for titles, headings and running prose (Light for the largest titles, Regular for text, Italic for the lede and the guide's section headings, Medium where a serif needs weight). The system sans (`-apple-system, system-ui, sans-serif`) for navigation, labels, buttons, captions, tables' key columns and keycaps. Literata is served from the site itself as WOFF2, at most four files, `font-display: swap`, with its licence text beside the fonts; the source files are the app's own TTFs in `Packages/ScriptureKit/Sources/ScriptureUI/Fonts/`, converted to WOFF2 once and committed (the conversion and its tool are recorded in `site/README.md`).
- **Sizes** in `rem` on a short named ladder (title, heading, lede, body, small, label) so the visitor's text size setting scales everything; body text in the guide about 17 to 18 px at the default, line height about 1.6, measure no wider than about 38 em. Labels are uppercase, semibold, tracked about 0.2 em, as the chapter label is.
- **Space** on a 4 px scale that mirrors `AppSpacing`.
- **No cards.** Nothing sits in a bordered, filled box by reflex. The exceptions, each named: a screenshot has a 1 px `ink.rule` edge, rounded corners and the soft shadow of mockup A (it is a picture of a window); a code block and a keycap have a surface because they are a different kind of text. Tables are rows with a hairline under each.
- **Motion:** none beyond the browser's own. No scroll effects.

## 5. Screenshots

### 5.1 Rules

- Real, from a Debug build of the app at this branch's commit, with nothing drawn on or edited after capture beyond cropping to the window.
- **Translation: the World English Bible** in every picture. Where a picture shows more than one translation (Compare Translations), the compare set is public-domain texts only (KJV, ASV, WEB).
- **A stand-in store made for the purpose.** A handful of invented highlights, notes and bookmarks (John 1, Psalm 1 or 23, Genesis 1) and one invented reading plan. Never Matt's notes, never the church's plans.
- **The capture must not touch anything of Matt's.** Never the Release app, its store, its defaults or its keychain item. Never the `.dev` identity's synced store or its iCloud key-value store either: a `-storeName` store of the Debug app shares the `.dev` iCloud database, and synced preferences (the default translation among them) travel to Matt's Debug apps. Use a Debug build made for the purpose by build settings on the command line, with no change to the project: its own bundle identifier (for example `com.matthewfurr.ReadingThroughScripture.site`, so its defaults are its own), **no iCloud entitlement** (`SyncConfiguration` then finds no container, the store is `Local/…` and sync is off) and a named store (`-storeName Site`). Say in `site/README.md` exactly how it was built. The rehearsal identity is not used: it is built only on Matt's word. If such a build cannot be made to work without changing the app, stop and ask.
- No assistant reply is shown unless it came from the on-device model or a provider in that run; no API key is shown; the Settings pictures avoid the Assistant pane's key fields.
- The Places picture shows Apple's map with its own attribution in view, uncropped.
- iPhone pictures come from the simulator, as plain screenshots with rounded corners and a hairline: no drawn device frame.

### 5.2 How

`site/README.md` records, for each picture, what was on screen and how it was set up (launch arguments, the stand-in store, window size), so that a picture can be retaken when the app changes. A script for the repeatable parts is welcome; full automation is not required. Mac windows are captured one at a time by window id at a fixed size (about 1280 by 800 pt, 2×); Matt's window manager (AeroSpace) resizes windows on launch, so the size is set and checked before each capture. Do not capture while Matt is using the Mac; check idle time first, and never wait on a permission prompt.

### 5.3 The pictures

Mac, light appearance unless said:

1. **Hero:** the reader, John 1, Printed, the notes column open with two notes and two highlights. Also captured in Dark, served to visitors in dark mode through `<picture>`.
2. **The page:** the reader in Lectern and Sepia on a psalm (the drop numeral, hanging poetry).
3. **The page, second:** the Text & Layout popover (⌘T) open over the reader.
4. **Marks:** the markup menu open on a selected phrase.
5. **Notes:** a note being read in the notes column beside its highlight (may be the hero's crop if it reads well).
6. **The Library:** the home page, contents and pane, with rings on marked chapters and this week's plan band.
7. **People:** a person's page with the drawn family tree (Jacob or David).
8. **Places:** the map and list for Acts.
9. **About:** Genesis's timeline with its chart.
10. **Search:** ⌘K with a search's results.
11. **Reading plans:** the plan window with the invented plan.
12. **The assistant:** the panel with a short reply on a passage.
13. **Verse panels:** Compare Translations (public-domain set) and Cross-References.
14. **The Notes window.**

iPhone (simulator): the reader; the pen with its colours; the Library's book list; the Plan tab; Search; the chapter switcher's cards.

The front page uses 1, 2, 4, 6 or 7, 10, 11, 12, one iPhone pair and 14 or none for "Yours to keep"; the guide uses the rest where a page is clearer with one. A picture that cannot be captured within these rules is left out and listed in the handover, never faked.

Every picture has alt text that says what it shows, an explicit width and height, and loads lazily below the first screen. Sources are kept as PNG in `site/src/img/`; the build may produce smaller formats and sizes from them.

## 6. The Build page

What a stranger needs, in order, each step checked by doing it on this branch:

1. What is needed: macOS 26, Xcode 26; Apple Intelligence for the on-device assistant (optional). What an Apple account is needed for is stated only as far as step 3 found it out.
2. Clone, then `bash Scripts/build-bible.sh`. Say plainly what it downloads and from where: the texts from bobuk/holybooks, pinned to one commit (the script checks no digest for them); headings from eBible.org, cross-references from OpenBible.info and the Library's data from Theographic, each checked against a pinned SHA-256 digest. And that **four of the eight translations are under copyright and belong to their publishers**: the build fetches them for the builder's own use, and the Sources page names each holder.
3. Signing. The project is set to Matt's team and identifiers, and this Mac has that team, so a plain build here proves nothing about a stranger's. **The stranger's build is stood in for by one build on this branch with the team cleared, signed to run locally (ad hoc) and with no iCloud entitlement, all by build settings on the command line** (the same kind of build section 5.1 uses), for the Mac and for the iPhone simulator. The page states what that build needed and what was seen in it (sync off, everything else as usual, or whatever is in fact seen). What was not tried is said to be untried, in one plain sentence: a real iPhone, a free Apple ID, sync under someone else's team and container. If the stand-in build needs a change to the project itself, the page documents the manual steps and a backlog line records the change; the project is not altered in this milestone.
4. Run it, on the Mac and in the iPhone simulator, with the README's commands.
   - **The link scheme (2026-11-26, after the critique).** A Debug build copies and answers `bible-dev://`, and the guide describes `bible://`. The page's commands pass `PASSAGE_URL_SCHEME=bible` so the build a reader makes matches the guide. This was checked with `xcodebuild -showBuildSettings` only: a build registering `bible` was not made or run on this Mac, where Matt's own copy answers those links, and the page says so.
   - The page also opens with what the build costs, keeps one paragraph on what was and was not checked, has a short section on a failed build that says only what the repository supports, and ends with a link into the guide.
5. A short "What is where" (the README's Layout section) and a link to the README for everything a developer needs beyond this.

## 7. The Sources page

### 7.1 Content

Every credit in `Credits.swift`, under its three sections (Scripture; Study data; Typefaces, icon, videos and software), each with its name, what the app uses it for, its notice in full, its licence and its link. Where the app shows a licence text (the two typefaces' OFL texts, GRDB's and holybooks' licences), the site serves its own copy of that text, copied at build time from the package's files (`ScriptureUI/Fonts/OFL-*.txt`, `ScriptureUI/Licenses/`), and the page links to it; nothing on this page depends on the repository's GitHub address. The Theographic entry keeps its statement that the data was changed, and its notice's own links.

### 7.2 Kept in step

The site reads the credits from one data file (`site/src/_data/credits.json`). A test in `CreditsTests.swift` (which already reads `README.md` from `#filePath`) reads that file and fails when its entries differ from `Credits.swift` in **any field the page shows**: id, section, name, use, notice, licence, link, the licence's link, the licence file's name, and the Theographic notice's inline links (`LibraryCredit.linked`). That is the milestone's only change inside `Packages/`. A list kept in step by hand is not acceptable.

## 8. Writing

- Voice from `PRODUCT.md`: plain, short, second person, no exclamation marks, no coaching. The site names the thing and stops. No sentence sells.
- The guide is rewritten from the README for a reader: what to do and what happens. It leaves out `UserDefaults` keys, launch arguments, probes, schema versions, rehearsal history and store paths, except where a reader needs one (where backups are, never copy a store between Macs, never run an older build on a store a newer one has used).
- Every statement about the app's behaviour is checked against the README, and against the code where the README is unclear. A doubt is resolved by looking, or the sentence is left out.
- Any Bible text quoted in prose is from the World English Bible or the KJV.
- Keys are written as keycaps (`<kbd>`), menu paths with the app's own "›".
- American spelling, as the app's own strings and Matt write (Matt, 2026-11-26, after the critique; the first build was in British spelling, Claude's doing). The records in `docs/superpowers/` keep the spelling they were written in.

## 9. Bookkeeping, in this spec's commit and the build's

- **With this spec:** `docs/BACKLOG.md`'s heading "Milestone 12: an older build meets a newer store (wanted)" becomes "An older build meets a newer store (wanted; was to be milestone 12)" with a line giving Matt's change of 2026-11-26; the main spec (`2026-10-26-reading-through-scripture-design.md`) gains a milestone 12 entry pointing here; the mockups are kept in `milestone-12-mockups/`.
- **With the build:** new backlog lines for what this spec leaves out (search in the guide; a custom domain; whatever the Build page finds a stranger must change by hand); `CLAUDE.md` gains a short section naming `site/` and section 4.6 as its design rule; the README gains one link to the site's folder and the preview command; `.gitignore` gains the two site folders; a ledger in `docs/superpowers/ledgers/milestone-12/`.

## 10. Before the repository goes public (Matt's, not built here)

The site is finished when it builds and reads right locally. Going live needs, in order, each on Matt's word:

1. **The licence: GPL-3.0** (Matt, 2026-11-26, so that someone else cannot put the app on the App Store closed, while he as its owner still can). `LICENSE` at the root holds the text, version 3; the README's Licence section names the holder (Matthew Furr, 2026) and the parts that keep their own licences. The site's footer and Build page say so (section 4.3).
2. **How the history is published.** The history and the tree were audited on 2026-11-26 at Matt's word (693 commits on `main`, every path ever committed, every change scanned for keys, tokens, addresses and identifiers; the docs read by a second reader). Found clean: no key or token; no `bible.sqlite` or other database; no screenshot; no church PDF and no church name; no text of a real note; test fixtures are KJV, WEB and BSB only, and the only ESV words are a few phrases of Matthew 5 in tests and examples. Found, and Matt's to decide:
   - **The commit email**, a private address, is on every commit and becomes public with the history.
   - **The iPhone's identifier** was in `plans/2026-11-09-milestone-8-iphone.md`; it is removed from the file as of this commit and remains in earlier commits.
   - **`refs/notes/ai`** (683 notes written by the git-ai tool: which session wrote which lines, the model's name, the same email; no prompts) is a separate ref that a plain push of `main` does not send. `.git/ai/` (743 MB) is local and never pushed.
   - **Mild, in `docs/superpowers/`:** two of Matt's reading places (Zechariah 12, Ezra 4), the shape of the church's plans (week counts, a start date, labels such as "Leader Dinner"), `/Users/matt/…` paths, the Team ID, and the record of how the app was built with Claude. `README.md` itself, not only `docs/superpowers/`, names the church's two plan layouts and the Team ID; the site's own pages name neither.
   - The other branches are all merged into `main`; only `main` need be pushed.
   The identifier and the email can leave the history only by rewriting it, which changes every commit hash the ledgers cite. **Matt chose a fresh history** (2026-11-26, "fresh start from the cleaned tree"): the public repository starts from one commit of the tree as it stands when published, made with the name and email he wants public, and the full history stays on this Mac and is never pushed there. The mild items above stay in the tree as they are unless he says otherwise.
3. **The icon's licence.** Checked at the source on 2026-11-26: 3dicons' site and its repository's licence file say CC0 1.0, free for personal and commercial use with no credit required; "clay" and "premium" are styles of that free library. Its online editor has a paid tier (Pro), and nothing states a licence for what the editor exports. The two images in `AppIcon.icon` are 2,400 px square, larger than the free editor exports (800 px), so they came from the library's own download or from Pro. **Matt, 2026-11-26: "Library's download."** So the artwork is CC0 and nothing is owed; the backlog's line is closed. The site uses the icon in its header and as its favicon.
4. The GitHub repository `matthewfurr/bible-carrel` (created on Matt's word, 2026-11-26) was published the same day, on his word that the repository and its Pages site were asked for so that people could see them: made public, Pages' source set to GitHub Actions before the first push, then one commit holding this tree pushed to `main` by address, with no remote added to this checkout. The commit is made with his public name and GitHub's no-reply address for his account. Later publications add one commit each the same way; `site/README.md`, "Publishing", has the commands. The workflow takes the repository's address from GitHub itself.
5. The Theographic share-alike item in the backlog is unchanged by publishing source: the converted tables are still not given to anyone.

A backlog line records this list so it is not lost.

Waiting before or after publishing, what this milestone leaves:

- Lighthouse was not run.
- The fonts were checked in a Chromium browser only; open the site in Safari once before publishing.
- The workflow has never run.

## 11. Verification

- `npm ci` and the build run clean from a fresh clone of the branch, with no warnings left unexplained.
- Every internal link and asset resolves, checked by a link checker over the built output, **once with the prefix `/` and once with a prefix such as `/bible-carrel/`**.
- The built HTML validates; no page has more than one `h1` or a skipped heading level; every image has alt text.
- Contrast: each text and surface pairing the stylesheet uses holds 4.5:1 (3:1 for the large titles) in light and dark, computed from the tokens, not judged by eye. The pairings and ratios are listed in `site/README.md`.
- No request leaves the site's origin (the network log of a full front-page and guide-page load).
- Seen in a browser at 375, 768 and 1280 px wide, light and dark: the front page, one guide page with a table, the Build page, the Sources page, the roadmap. No sideways scroll at 375.
- The appearance control: a press takes effect at once, the choice survives a reload and a move to another page with no flash of the other appearance, and with nothing chosen the page follows the system when it changes. With `localStorage` unavailable the control still works for the page in view and nothing throws.
- The front page with scripting off is complete, follows the system's light or dark, and shows no appearance control.
- Keyboard: Tab reaches every link in order with a visible focus ring; the skip link works.
- Lighthouse on the built front page and one guide page: accessibility 100, performance and best practices 95 or better, or each shortfall explained.
- `swift test --package-path Packages/ScriptureKit` passes with the new credits test, and the test fails when one credit in the JSON is altered (shown once, then restored).
- The workflow file is read against GitHub's current Pages documentation (`actionlint` is not installed on this Mac; it is not installed for this). **It cannot be run before the repository is on GitHub; the handover says so.**
- Every picture checked against section 5.1 by looking at it: translation, no real notes, no key.

## 12. Left to the builder

The Eleventy configuration and plugins; file names and URL slugs; the exact ladder of sizes and the breakpoints; how images are sized and which formats are served; the link checker, validator and contrast script; the wording of every page within section 8; which pictures a guide page needs; the split of work into tasks. Build with an appropriate model: the plan and the final whole-branch review on the session's model, implementers on Sonnet (Opus for the screenshot work that drives the app).
