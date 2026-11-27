# Milestone 12: The Site — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A static site in `site/` (a front page, a 17-page guide, Build, Sources and Roadmap pages) that looks loosely like the app's Printed page, shows the app in real screenshots, and is ready for GitHub Pages the day the repository is published.

**Architecture:** Eleventy 3 turns Nunjucks layouts and Markdown pages in `site/src/` into `site/_site/`. One stylesheet of named tokens mirrors `DESIGN.md`; one data file of credits is held equal to `Credits.swift` by a Swift test; three small Node scripts (links, contrast, HTML) are the site's test suite, run by `npm run check`. Screenshots come from a stand-in build of the app with its own bundle identifier and no iCloud.

**Tech Stack:** Node 26, Eleventy 3 (`@11ty/eleventy`, its bundled HTML base plugin, `@11ty/eleventy-img`), Nunjucks, Markdown, plain CSS, `html-validate`. Swift Testing for the one package test. No CSS or client framework.

**Spec:** `docs/superpowers/specs/2026-11-26-milestone-12-site-design.md` (approved by Matt, 2026-11-26). Read it whole before any task; section numbers below are its.

## Global Constraints

- **Where:** the worktree `/Users/matt/Code/reading-through-scripture/.claude/worktrees/milestone-12-site`, branch `milestone-12-site`. Never work in the main checkout. Never push; nothing is published in this milestone.
- **Git on this Mac:** call `/usr/bin/git …` directly, one git command per Bash call, no `cd`, no shell variables or loops in a command that names git. Use Write and Edit for files, not heredocs.
- **npm:** always from the root with a prefix, for example `npm --prefix site run build`. Dependencies pinned by `site/package-lock.json`; install with `npm --prefix site ci` once the lockfile exists.
- **Nothing of Matt's is touched:** never the Release app (`/Applications/Bible Carrel.app`), `Scripts/install-app.sh`, `Scripts/install-phone.sh`, anything under `~/Library/Application Support/ReadingThroughScripture/Sync/`, the `.dev` identity's store, defaults or iCloud key-value store, or any keychain item. The only app that may be launched is the stand-in build of Task 7.
- **No other origin:** no font service, script, tracker, embed or remote image anywhere in the built site (spec 2).
- **No copyrighted Bible text** in a picture or in prose: no ESV, NASB, AMP or ERV wording. Bible text quoted in prose is World English Bible or KJV; every picture shows the World English Bible (spec 5.1, 8).
- **Every picture is the app.** Nothing drawn, mocked or retouched; cropping to the window is the only edit (spec 2, 5.1).
- **Say only what is true of the app.** Every statement about behaviour is checked against `README.md`, and the code where the README is unclear; a doubt is resolved by looking or the sentence is left out (spec 8). Planned work is named only on the roadmap page.
- **Voice (`PRODUCT.md`):** plain, short, second person, no exclamation marks, no coaching, no selling. Keys as `<kbd>`; menu paths with "›".
- **Nothing arbitrary (spec 4.6):** every colour, size and gap in a page is a custom property from `tokens.css`. No hex, px or rem literal outside `tokens.css` except `0`, `1px` hairlines and percentages.
- **No cards, no gradients, no motion** beyond the browser's own. The named exceptions are spec 4.6's: screenshots, code blocks, keycaps.
- **The site is complete with scripting off.** The appearance control is the only thing a script adds.
- **Commits:** small, one per step that says "Commit", message in the repository's style (`site: …`, `docs: …`, `test: …`), a sentence that says what is now true.
- **Models:** implementers on Sonnet; Tasks 7 and 8 on Opus.

## Review Focus

1. **The chosen appearance against the system's.** A visitor on a light system chooses Dark: every surface, and the hero picture, must follow the choice. A `<picture>` with a `prefers-color-scheme` source follows the system, not the choice, so the hero cannot use one. Pinned in Task 9 (both images in the page, shown by the same rule that picks the tokens) and tested in Task 1 (`appearance.test.mjs`) and Task 11.
2. **The site under a path prefix.** Fonts named in CSS `url()`, the favicon, the inline head script and deep guide pages must all resolve at `/bible-carrel/`. Pinned in Task 1: `check-links.mjs` follows `url()` in built CSS as well as `href` and `src`, and `npm run check` runs it at both prefixes.
3. **Storage that fails.** `localStorage` throwing (private modes), holding a value that is not one of the four, or absent: the page must render in the system's appearance and the control must still work for the page in view. Pinned in Task 1's `appearance.test.mjs`.
4. **A missing or stray file.** A page that names a screenshot that does not exist, a guide page listed in the sidebar with no file, or a guide file not in the sidebar must fail the build with a message naming it, never ship a broken image or an orphan page. Pinned in Tasks 1 and 3.
5. **Small screens and large text.** At 320 px wide and at 200% text size the header wraps without overlap, the shortcut tables scroll inside themselves and the page never scrolls sideways. Pinned in Task 11's browser pass, with the table wrapper built in Task 3.

---

## File Structure

```
LICENSE                                   (exists)
.github/workflows/site.yml                Task 10
site/
  package.json, package-lock.json         Task 1
  eleventy.config.js                      Task 1 (extended in 2, 3, 9)
  .htmlvalidate.json                      Task 1
  README.md                               Task 1, extended by 7, 8, 11
  scripts/check-links.mjs                 Task 1
  scripts/contrast.mjs, contrast-pairs.json   Task 1
  scripts/appearance-core.mjs, appearance.test.mjs   Task 1
  src/_data/site.js                       Task 1
  src/_data/guide.json                    Task 3
  src/_data/credits.json                  Task 2
  src/_includes/layouts/base.njk          Task 1
  src/_includes/layouts/page.njk          Task 1   (a standing page: Build, Sources, Roadmap)
  src/_includes/layouts/guide.njk         Task 3
  src/_includes/header.njk, footer.njk    Task 1
  src/css/tokens.css                      Task 1   (custom properties only)
  src/css/site.css                        Task 1, extended by 2, 3, 9
  src/js/appearance.js                    Task 1
  src/fonts/Literata-{Light,Regular,Italic,Medium}.woff2, OFL-Literata.txt   Task 1
  src/img/icon-*.png, favicon             Task 1
  src/img/shots/*.png                     Task 8
  src/index.njk                           Task 1 (placeholder), Task 9 (real)
  src/sources.njk                         Task 2
  src/build.md                            Task 7
  src/roadmap.md                          Task 9
  src/guide/*.md                          Tasks 3 to 6
Packages/ScriptureKit/Tests/ScriptureUITests/CreditsTests.swift   Task 2 (one test added)
```

URLs: `/`, `/guide/<slug>/`, `/build/`, `/sources/`, `/roadmap/`, `/licences/<file>.txt`.

---

### Task 1: The scaffold, the look and the checks

**Files:** everything marked Task 1 above; `.gitignore` (add `site/_site/` and `site/node_modules/`).

**Interfaces — Produces:**
- `npm --prefix site run build` builds to `site/_site/`. `npm --prefix site run dev` serves it. `npm --prefix site run check` runs, in order: the build at prefix `/`, `check-links` on it, the build at prefix `/bible-carrel/`, `check-links` on it, `html-validate` over `_site/**/*.html`, `contrast`, `node --test scripts/`.
- Environment read by `eleventy.config.js`: `SITE_PATH_PREFIX` (default `/`), `SITE_URL` (default empty), `SITE_REPO_URL` (default empty). `src/_data/site.js` exports `{ name: "Bible Carrel", url, repoUrl, year: 2026, holder: "Matthew Furr" }`.
- Layouts `layouts/base.njk` (front matter: `title`, optional `description`) and `layouts/page.njk` (base plus a single article column at the reader's measure, with `eyebrow`, `title`, optional `lede`).
- The `shot` shortcode: `{% shot "name", "Alt text", "eager" %}` (third argument optional). Reads `src/img/shots/<name>.png`; emits an `<img>` (through `@11ty/eleventy-img`, widths 800 and 1600, WebP and PNG) with `width`, `height`, `alt`, `loading="lazy"` unless eager, inside `<figure class="shot">`. **Throws, failing the build, when the file is missing or the alt text is empty.** When `<name>-dark.png` exists it emits both images, classed `shot-light` and `shot-dark`; CSS shows one by the same rule that picks the tokens.
- CSS classes later tasks use: `.eyebrow` (bronze spaced label), `.lede`, `.button` (the one filled button), `.keys` (a shortcut table, wrapped in `.table-scroll`), `.aligned` (a `dl` in two aligned columns), `.shot`.
- `scripts/check-links.mjs <dir> <prefix>`: exit 1 listing every `href`, `src`, `srcset` entry and CSS `url()` in the built files that does not resolve to a file under `<dir>` once `<prefix>` is stripped; an internal link that does not begin with the prefix is an error; an `http(s):` link is allowed only in `<a href>`, never in `src`, `srcset`, `link`, `script` or CSS.
- `scripts/contrast.mjs`: parses the three palettes out of `src/css/tokens.css`, reads `contrast-pairs.json` (`[{ "text": "ink-primary", "on": "paper-page", "min": 4.5 }, …]`), prints each ratio per palette and exits 1 below `min`.

**Decisions:**
- `tokens.css` holds three blocks and nothing else: `:root` (light, spec 4.6's values), `@media (prefers-color-scheme: dark) { :root:not([data-appearance]) … }` plus `:root[data-appearance="dark"]` (dark), and `:root[data-appearance="sepia"]` (the seven Sepia values); `[data-appearance="light"]` restores light on a dark system. Names are the tokens' with a hyphen: `--paper-page`, `--paper-panel`, `--paper-overlay`, `--ink-primary`, `--ink-secondary`, `--ink-tertiary`, `--ink-rule`, `--ink-verse`, `--accent`, `--accent-wash`. Then the ladders: `--space-1` to `--space-8` (4, 8, 12, 16, 24, 32, 48, 64 px, `AppSpacing`'s), `--text-label`, `--text-small`, `--text-body`, `--text-lede`, `--text-heading`, `--text-title`, `--text-display` in `rem`, `--measure` (38em), `--radius-sm` (6px), `--radius-lg` (11px), `--serif`, `--sans`.
- `contrast-pairs.json` covers every text-on-surface pair `site.css` uses: primary, secondary, verse and accent on page, panel and overlay at 4.5; primary on wash at 4.5; white on accent (the button) at 4.5 in light and Sepia and the page colour on accent in dark; display titles at 3. `ink-tertiary` appears in no pair because it carries no text.
- `appearance.js` exports nothing and is inlined in `<head>` by `base.njk`; its logic lives in two pure functions also exported from `scripts/appearance-core.mjs` for the test: `readChoice(storage) -> "system" | "light" | "sepia" | "dark"` and `apply(choice, root)` (sets or removes `data-appearance`; `"system"` removes it). The storage key is `appearance`.
- The control is a `<select>` labelled "Appearance" with options System, Light, Sepia, Dark, rendered inside `<div class="appearance" hidden>`; the script removes `hidden`. With scripting off it stays hidden.
- Fonts: convert the four TTFs from `Packages/ScriptureKit/Sources/ScriptureUI/Fonts/` to WOFF2 once with a one-off tool (for example `npx --yes ttf2woff2` or `wawoff2`), commit the WOFF2 files, and record the exact command in `site/README.md`. The converter is not a dependency. Copy `OFL-Literata.txt` beside them. `@font-face` uses `font-display: swap` and a URL that survives the prefix (relative to the stylesheet).
- Icon: the repository has no flat image. Take it from the installed Debug or stand-in app's `AppIcon.icns` if one is built (`Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app/Contents/Resources/AppIcon.icns` in the **main checkout**, read only), with `sips -s format png -z 256 256` for the header (and 512 for 2×) and 32 and 180 for the favicon and touch icon. If no built app is to hand, say so in the report and leave the icon to Task 7, with the header showing the name alone.
- Header and footer exactly as spec 4.3. The GitHub link renders only when `site.repoUrl` is not empty. The footer names the licence in words here; its link to `/licences/gpl-3.0.txt` is added in Task 2, which is where that file starts to exist. The header's Guide, Sources, Roadmap and Build it links are added by the task that creates each page (a link to a page not yet built would fail `check-links`).
- The placeholder `index.njk` is a title and a sentence, enough for the checks to run.

- [ ] **Step 1:** Write `site/package.json` (scripts above, `"type": "module"`, `"private": true`), install Eleventy 3, `@11ty/eleventy-img` and `html-validate` at their current stable versions (`npm view <name> version`), commit the lockfile. Add the two ignore lines.
- [ ] **Step 2: Write the failing tests.** `scripts/appearance.test.mjs` with `node:test`:

```js
test('a stored choice is read', () => assert.equal(readChoice(stub({ appearance: 'sepia' })), 'sepia'))
test('nothing stored is system', () => assert.equal(readChoice(stub({})), 'system'))
test('a value that is not one of the four is system', () => assert.equal(readChoice(stub({ appearance: 'neon' })), 'system'))
test('storage that throws is system', () => assert.equal(readChoice({ getItem() { throw new Error('denied') } }), 'system'))
test('no storage at all is system', () => assert.equal(readChoice(undefined), 'system'))
test('system removes the attribute', () => { const r = root('dark'); apply('system', r); assert.equal(r.dataset.appearance, undefined) })
test('a choice sets the attribute', () => { const r = root(); apply('dark', r); assert.equal(r.dataset.appearance, 'dark') })
```

- [ ] **Step 3:** Run `npm --prefix site run check`; expected: fails (no scripts, no build).
- [ ] **Step 4:** Write `eleventy.config.js`, `site.js`, the layouts, header, footer, `tokens.css`, `site.css`, `appearance.js`, the `shot` shortcode, the fonts and the icon.
- [ ] **Step 5:** Write `check-links.mjs` and prove it: temporarily add `<img src="/nope.png">` and a CSS `url(/nope.woff2)` to the placeholder page; expected: exit 1 naming both; remove them.
- [ ] **Step 6:** Write `contrast.mjs` and `contrast-pairs.json`; prove it by lowering one `min` case (set `--ink-secondary` to `--ink-tertiary`'s value); expected: exit 1 naming the pair and palette; restore.
- [ ] **Step 7:** Prove the `shot` shortcode throws on a missing file and on empty alt text (a scratch page, then removed).
- [ ] **Step 8:** `npm --prefix site run check`; expected: exit 0, both prefixes, every pair printed at or above its minimum in all three palettes.
- [ ] **Step 9:** Write `site/README.md`: preview, build, check, the font conversion command, the token names and where they come from (`DESIGN.md` section 2), the contrast table as printed.
- [ ] **Step 10:** Commit.

### Task 2: The Sources page and the credits kept in step

**Files:** Create `site/src/_data/credits.json`, `site/src/sources.njk`. Modify `site/eleventy.config.js` (licence texts), `site/src/_includes/footer.njk` and `header.njk` (the licence and Sources links), `site/src/css/site.css`, `Packages/ScriptureKit/Tests/ScriptureUITests/CreditsTests.swift`.

**Interfaces:**
- Consumes: `layouts/page.njk`, `.aligned`, the tokens.
- Produces: `credits.json`, an array in `Credits.all`'s order of
  `{ "id", "section", "name", "use", "notice", "license", "link", "licenseLink": string | null, "licenseFile": string | null, "noticeLinks": [{ "phrase", "url" }] }`. `section` is `Credit.Section`'s raw value; `link` and `licenseLink` are absolute strings as `URL.absoluteString` gives them; `licenseFile` is the resource path as `Credits.swift` writes it; `noticeLinks` is empty except for `theographic`, where it is the linked phrases of `LibraryCredit.linked` in order.
- Produces: `/licences/<file>` in the built site: `LICENSE` (as `gpl-3.0.txt`), the two OFL texts and the two files of `ScriptureUI/Licenses/`, copied by Eleventy passthrough from their homes in the repository (paths outside `site/` are allowed as passthrough sources); `/sources/`.

- [ ] **Step 1: Write the failing test** in `CreditsTests.swift`, beside `theReadmeAcknowledgesEverySource` and finding the file the same way (`#filePath`, then `../../site/src/_data/credits.json`):

```swift
@Test func theSitesCreditsAreTheApps() throws {
    let site = try Self.siteCredits()                  // [SiteCredit], Decodable, the shape above
    #expect(site.map(\.id) == Credits.all.map(\.id))   // the same sources in the same order
    for (theirs, ours) in zip(site, Credits.all) {
        #expect(theirs.section == ours.section.rawValue, "\(ours.id): section")
        #expect(theirs.name == ours.name, "\(ours.id): name")
        #expect(theirs.use == ours.use, "\(ours.id): use")
        #expect(theirs.notice == ours.notice, "\(ours.id): notice")
        #expect(theirs.license == ours.license, "\(ours.id): licence")
        #expect(theirs.link == ours.link.absoluteString, "\(ours.id): link")
        #expect(theirs.licenseLink == ours.licenseLink?.absoluteString, "\(ours.id): licence link")
        #expect(theirs.licenseFile == ours.licenseFile, "\(ours.id): licence file")
    }
    let linked = try #require(site.first { $0.id == "theographic" }).noticeLinks
    #expect(linked.map(\.phrase) == Self.linkedPhrases(LibraryCredit.linked))   // from the attributed string's link runs
    #expect(linked.map(\.url) == Self.linkedURLs(LibraryCredit.linked))
}
```

- [ ] **Step 2:** Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit --filter CreditsTests`; expected: `theSitesCreditsAreTheApps` fails (no file).
- [ ] **Step 3:** Write `credits.json` from `Credits.swift` and `LibraryCredit.swift` (17 credits). Run the filter again; expected: pass.
- [ ] **Step 4:** Prove it guards: change one notice in the JSON; expected: the test fails naming that id and "notice"; restore.
- [ ] **Step 5:** Write `sources.njk`: the three sections in order under their names, each credit a row (name, use after a middle dot unless the use is "Bible text", licence), with its notice in full beneath, its link shown without `https://`, the licence as a link to `licenseLink` or to the site's copy under `/licences/` when there is a `licenseFile`. The Theographic notice is rendered with its `noticeLinks` as links. Rows with a hairline between, never cards. Opening sentence: what the page is, in one line; nothing says a text is used by permission (`CreditsTests.noWordSaysUsedByPermission` is the app's rule and the page's).
- [ ] **Step 6:** `npm --prefix site run check`; expected: exit 0 (the licence links resolve at both prefixes).
- [ ] **Step 7:** Commit.

### Task 3: The guide's layout and its first pages

**Files:** Create `site/src/_data/guide.json`, `site/src/_includes/layouts/guide.njk`, `site/src/guide/guide.11tydata.js`, `site/src/guide/first-chapter.md`, `reader.md`, `page-styles.md`, `your-place.md`, `reading-plans.md`. Modify `eleventy.config.js`, `site.css`, `header.njk` (Guide links to the first page).

**Interfaces — Produces:**
- `guide.json`, the whole sidebar now, so later tasks only add files:

```json
[
  { "group": "Start",      "pages": [["first-chapter", "Your first chapter"]] },
  { "group": "Reading",    "pages": [["reader", "The reader"], ["page-styles", "Page styles and text"], ["your-place", "Your place"], ["reading-plans", "Reading plans"]] },
  { "group": "Marking",    "pages": [["highlights", "Highlights and bookmarks"], ["notes", "Notes"], ["notes-window", "The Notes window"]] },
  { "group": "Studying",   "pages": [["library", "The Library"], ["search", "Search and ⌘K"], ["verse-panels", "Verse panels"], ["assistant", "The study assistant"]] },
  { "group": "Keeping",    "pages": [["sync-and-backups", "Sync and backups"], ["export-and-import", "Export and import"]] },
  { "group": "The iPhone", "pages": [["iphone", "The iPhone app"]] },
  { "group": "Reference",  "pages": [["shortcuts", "Every shortcut"], ["passage-links", "Passage links"]] }
]
```

- A guide page is `site/src/guide/<slug>.md` with front matter `title` (must equal the sidebar's) and `lede` (one italic sentence). `guide.11tydata.js` gives every file there `layout: layouts/guide.njk` and `permalink: /guide/<slug>/`; the layout takes the eyebrow (the group) and Previous and Next from `guide.json`.
- **The build fails** (an Eleventy `eleventy.after` or collection check that throws) when a slug in `guide.json` has no file once `GUIDE_COMPLETE=1` is set, and always when a file in `src/guide/` is not in `guide.json` or its title differs. `npm run check` sets `GUIDE_COMPLETE=1` only from Task 5 on (Task 5 turns it on in `package.json`); until then a missing page's sidebar entry renders as plain text, not a link.
- Markdown conventions for Tasks 4 to 6: `<kbd>⌘</kbd><kbd>K</kbd>` for keys; a shortcut table is a Markdown table inside `<div class="table-scroll">`, first column keys; an "On the iPhone" `##` section where the phone differs; `{% shot %}` for pictures, added in Task 9, so no page references a picture yet.

**Content:** each page from the README section of its subject (spec 4.2's table), rewritten for a reader per spec 8. `first-chapter` from "The front page" paragraph and The Library's contents page; `reader` from the chapter and thumb paragraphs; `page-styles` from the styles paragraph and Settings › Reading; `your-place` from the place paragraph and "Coming back"; `reading-plans` from Reading plans (leave out the store-moves-forward warning's history; keep "update every device before making the first plan" as one sentence).

- [ ] **Step 1:** Write `guide.json`, the data file and the check that throws; add a stray `src/guide/stray.md`; run the build; expected: fails naming `stray`. Remove it.
- [ ] **Step 2:** Write `guide.njk` (sidebar on `--paper-panel` with the current page on `--accent-wash`; below 900 px a `<details>` "Guide contents" above the article; article at `--measure`; Previous and Next) and the guide's CSS (`h2` in Literata italic `--ink-secondary`, `.table-scroll { overflow-x: auto }`, `kbd` on `--paper-overlay` with a `--ink-rule` edge).
- [ ] **Step 3:** Write the five pages.
- [ ] **Step 4:** Check every behavioural sentence against the README; list in the report any sentence resolved from code, with the file.
- [ ] **Step 5:** `npm --prefix site run check`; expected: exit 0.
- [ ] **Step 6:** Commit.

### Task 4: The guide — Marking and Studying

**Files:** Create `site/src/guide/highlights.md`, `notes.md`, `notes-window.md`, `library.md`, `search.md`, `verse-panels.md`, `assistant.md`.

**Interfaces — Consumes:** Task 3's front matter and Markdown conventions; nothing else changes.

**Content:** `highlights` from Markup (the menu, colours and the lightness band in one plain sentence, bookmarks, the reader's keys J K 1 to 9 0 N B, undo); `notes` from Markup's notes column paragraph and Links' last sentences; `notes-window` from Notes browser, Exporting notes and Kept versions (what you see and the three choices; none of "How it works" beyond one sentence that both texts are kept); `library` from The Library (contents, rings, People, Places, About, Dates; none of the data-fetching paragraph); `search` from Search, with the README's five-row table as it stands; `verse-panels` from Verse panels (not "The cross-reference data"); `assistant` from Study assistant (three ways in, the command table, who answers and the 3,000-token rule as "longer passages go to a cloud provider if you have added a key", Settings › Prompts in two sentences; no keychain service names).

- [ ] **Step 1:** Write the seven pages.
- [ ] **Step 2:** Check every behavioural sentence against the README; report any resolved from code.
- [ ] **Step 3:** `npm --prefix site run check`; expected: exit 0.
- [ ] **Step 4:** Commit.

### Task 5: The guide — Keeping, the iPhone and Reference

**Files:** Create `site/src/guide/sync-and-backups.md`, `export-and-import.md`, `iphone.md`, `shortcuts.md`, `passage-links.md`. Modify `site/package.json` (set `GUIDE_COMPLETE=1` in the `check` script's builds).

**Content:** `sync-and-backups` from Sync and backups and Settings' iCloud lines (what syncs, what stays on a device, the daily backup and Restore…, signing out empties the store and it returns on sign-in, never copy a store between Macs, never run an older version on a store a newer one has used; no container names, no paths except that backups are found with Settings › General › Backups › Show in Finder); `export-and-import` from Export All Data and Import Data (what is in the file, what is left out, that import never edits or deletes, the one-sentence result; not the format table); `iphone` from iPhone (the tabs, the pen, the chapter switcher, the thumb, Notes, Ask, Search, what stays with each device; no build or install commands); `shortcuts` every shortcut the README names, in tables grouped as the app's shortcuts sheet groups them (read the sheet's source, `grep -rn "Keyboard Shortcuts" Packages/ScriptureKit/Sources`, and follow its groups and order); `passage-links` from Links (the form, examples, Copy Link; not the Debug scheme).

- [ ] **Step 1:** Write the five pages.
- [ ] **Step 2:** Check `shortcuts` against the shortcuts sheet's source, key by key; report the count on each side.
- [ ] **Step 3:** Turn `GUIDE_COMPLETE=1` on; `npm --prefix site run check`; expected: exit 0 with all 17 pages built.
- [ ] **Step 4:** Commit.

### Task 6: The roadmap page

**Files:** Create `site/src/roadmap.md`. Modify `CLAUDE.md` ("Later work" gains: when a wanted item is built or dropped, its entry leaves `site/src/roadmap.md` in the same commit).

**Content:** exactly spec 4.5: the opening sentence (plans, not promises, no dates), the five entries in its order with two or three sentences each from `docs/BACKLOG.md`'s wanted items and `docs/superpowers/specs/2026-11-12-online-translations-handover.md`, and the closing line to the backlog file shown only when `site.repoUrl` is set. The first entry says what changes for someone building the app.

- [ ] **Step 1:** Write the page with `layout: layouts/page.njk`, `permalink: /roadmap/`.
- [ ] **Step 2:** `npm --prefix site run check`; expected: exit 0.
- [ ] **Step 3:** Commit.

### Task 7 (Opus): The stand-in build and the Build page

**Files:** Create `site/src/build.md`. Modify `site/README.md` (the stand-in build, exactly as run), `docs/BACKLOG.md` (only if the build needed a manual change to the project).

**Interfaces — Produces:** a stand-in app at `Build/SiteDerivedData/Build/Products/Debug/ReadingThroughScripture.app` (git-ignored, under the worktree's `Build/`), and the same for the iPhone simulator, both with bundle identifier `com.matthewfurr.ReadingThroughScripture.site`; the exact commands in `site/README.md` under "The stand-in build".

**Decisions:**
- The worktree has no `Build/bible.sqlite`. Copy it from the main checkout (`/Users/matt/Code/reading-through-scripture/Build/bible.sqlite`, read only) into the worktree's `Build/` first so the build phase does not rebuild it; if the copy is refused by the build's schema check, run `bash Scripts/build-bible.sh` in the worktree instead.
- Start from this command and adjust until it builds, recording what was needed:
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/SiteDerivedData PRODUCT_BUNDLE_IDENTIFIER=com.matthewfurr.ReadingThroughScripture.site PASSAGE_URL_SCHEME=bible-site CLOUDKIT_CONTAINER= CODE_SIGN_ENTITLEMENTS= CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build`. No `-allowProvisioningUpdates`. The same for `-scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max'`.
- **Before the first launch,** note the modification times of everything under `~/Library/Application Support/ReadingThroughScripture/Sync/` and the output of `defaults read com.matthewfurr.ReadingThroughScripture.dev` (to a scratch file outside the repository). Launch with `open -n <app> --args -storeName Site`. Confirm from the `sync` log (`/usr/bin/log show --last 2m --predicate 'subsystem == "com.matthewfurr.ReadingThroughScripture.site" OR subsystem == "com.matthewfurr.ReadingThroughScripture"'`, category `sync`) or from the file system that the store opened is `…/Local/Site.store` (or the sandbox container's equivalent) and that sync is off. Quit it. Confirm the `Sync/` modification times and the `.dev` defaults are unchanged. **If either changed, stop and report; do not continue.**
- Do not launch while Matt is using the Mac: read idle time first (`ioreg -c IOHIDSystem`, `HIDIdleTime`); under five minutes idle, wait or report. Match the app by its pid, never by name.

**The page (spec 6):** the five steps in order. Step 2 uses the spec's exact division: holybooks pinned to a commit with no digest check; eBible.org, OpenBible.info and Theographic checked against pinned SHA-256 digests; four of the eight translations under copyright, fetched for the builder's own use. Step 3 states what the stand-in build needed and what was seen in it, and one plain sentence on what was not tried (a real iPhone, a free Apple ID, sync under another team and container). The licence line: the code is GPL-3.0. The page gives the command a stranger runs, with the identifier written as `com.example.BibleCarrel`, not Matt's.

- [ ] **Step 1:** Copy the database; build the Mac stand-in; record the command that worked.
- [ ] **Step 2:** The before-and-after check and first launch, as above.
- [ ] **Step 3:** Build and boot the iPhone simulator stand-in (`xcrun simctl install booted …`, `xcrun simctl launch booted com.matthewfurr.ReadingThroughScripture.site`); confirm it opens.
- [ ] **Step 4:** If Task 1 left the icon out, take it from the stand-in app's `AppIcon.icns` now and add it to the header and favicon.
- [ ] **Step 5:** Write `build.md` (`layout: layouts/page.njk`, `permalink: /build/`) and the README section.
- [ ] **Step 6:** `npm --prefix site run check`; expected: exit 0.
- [ ] **Step 7:** Commit.

### Task 8 (Opus): The screenshots

**Files:** Create `site/src/img/shots/*.png`, `site/screenshots/stand-in-data.json` (the invented data, in the app's own export format), `site/README.md` section "The pictures" (one row per picture: file, what is on screen, how it was set up).

**Interfaces — Consumes:** Task 7's stand-in apps and its safety checks (repeat the before-and-after check around this task). **Produces:** PNGs named for spec 5.3: `reader-hero.png`, `reader-hero-dark.png`, `reader-lectern-sepia.png`, `text-and-layout.png`, `markup-menu.png`, `notes-column.png`, `home.png`, `people.png`, `places.png`, `about-timeline.png`, `search.png`, `reading-plan.png`, `assistant.png`, `compare.png`, `cross-references.png`, `notes-window.png`, and `phone-reader.png`, `phone-pen.png`, `phone-library.png`, `phone-plan.png`, `phone-search.png`, `phone-switcher.png`.

**Decisions:**
- The stand-in's settings are written to its own defaults domain before launch (`defaults write com.matthewfurr.ReadingThroughScripture.site …`): `defaultTranslationID WEB`, `compareTranslationIDs` to KJV, ASV and WEB only (read `ScriptureUI`'s preference code for the stored form), `readerPageStyle`, `readerAppearance`, `readerFontSize 18`. If the app is sandboxed the domain lives in its container; find it rather than guess.
- The invented marks: two highlights with notes and one bookmark in John 1, a highlight in Psalm 1, a chapter note on Genesis 1, one invented reading plan of a few weeks (titles such as "A stand-in plan"; no church's labels), one short conversation only if it was really produced in that run. Write them as a `bible-carrel-data` version 1 file (the README's "Export All Data" format table) and bring them in with File › Import Data…, or make them by keys in the reader (J, K, 1 to 9, N, B) and `-planProbe make`; record which. Every quoted phrase is the World English Bible's wording, read from the database, not typed from memory.
- Mac capture: one window at a time by window id (`screencapture -x -o -l <id> <file>`), at about 1280 by 800 pt. AeroSpace resizes a new window; set the size and read it back before each capture, and if the size cannot be held, capture at the size it gives and record it. Keep the pointer off the window (a resting pointer selects a ⌘K row). Never wait on a permission prompt: if one appears, stop and report.
- iPhone: `xcrun simctl io booted screenshot <file>`; the seed argument `-phoneSeed YES` may be used only if what it puts on screen is checked to be World English Bible wording once the translation is set; otherwise make marks by taps.
- The Places picture keeps Apple's map attribution in view. The assistant picture is taken only if the on-device model answers in this build; otherwise it is left out and listed.
- **Look at every PNG after taking it** (Read the file) and check spec 5.1: the translation, no real note, no key, nothing of Matt's. A picture that cannot be taken within the rules is left out and listed in the report.

- [ ] **Step 1:** Settings, the invented data, the before-and-after check.
- [ ] **Step 2:** The Mac pictures, each looked at.
- [ ] **Step 3:** The iPhone pictures, each looked at.
- [ ] **Step 4:** Quit the stand-in apps; shut the simulator down; repeat the unchanged check.
- [ ] **Step 5:** Write "The pictures" in `site/README.md`; list what was left out and why.
- [ ] **Step 6:** Commit.

### Task 9: The front page, and pictures in the guide

**Files:** Modify `site/src/index.njk` (replace the placeholder), `site/src/css/site.css`, guide pages that gain a picture, `eleventy.config.js` if the shortcode needs the dark pair's markup adjusted.

**Interfaces — Consumes:** `shot`, `.eyebrow`, `.lede`, `.button`, `.aligned`, `credits.json`, `guide.json`, the PNGs Task 8 produced (use only those that exist; a row whose picture was left out is laid out as words alone, full width, not with an empty frame).

**The page (spec 4.4 and mockup A, `docs/superpowers/specs/milestone-12-mockups/site-directions.html`, first tab):**
1. Title block: eyebrow "For Mac and iPhone"; `h1` "Bible Carrel" in Literata Light at `--text-display`; the lede "A quiet desk for reading through the Bible: the page set like print, your highlights and notes in its margin, and a study assistant at your elbow."; **Read the guide** (`.button`, to `/guide/first-chapter/`) and "Build it from source ›" (a link, to `/build/`); the small line "Not in the App Store. It is one reader's app, and the source is here to build with Xcode."
2. The hero, `{% shot "reader-hero", "…", "eager" %}`. **It follows the chosen appearance, not only the system's** (Review Focus 1): `.shot-dark` is shown and `.shot-light` hidden under exactly the selectors that apply the dark tokens in `tokens.css`, and the reverse otherwise. Sepia shows the light picture.
3. Eight feature rows in spec 4.4's order, sides alternating, stacking below 800 px with words first: eyebrow, `h2`, one to three sentences each opening with a small raised bronze figure (`<sup class="verse">`), a link to its guide page. Headings: "It reads like a printed Bible." · "Pencil in the margin." · "People, places and each book's story." · "One field finds anything." · "Your group's plan, week by week." · "Ask beside the page." · "The same desk in your pocket." · "Yours to keep." Sentences are written to spec 8 and true to the README.
4. The sources as a `dl.aligned` of six lines drawn from `credits.json` by section (Bible text, Section headings, Cross-references, People places and events, Typefaces, Software), with a link to `/sources/`.
5. Build it: two or three sentences and the link.

Then place the remaining pictures in the guide where a page is clearer with one (spec 5.3's last paragraph): at most two a page, each with alt text that says what it shows.

- [ ] **Step 1:** Write the page and its CSS.
- [ ] **Step 2:** Add the guide pictures.
- [ ] **Step 3:** `npm --prefix site run check`; expected: exit 0.
- [ ] **Step 4:** Serve it and look, in the browser, at 1280 px in light, Sepia and dark and at 375 px in light: compare against mockup A. Report what differs and why.
- [ ] **Step 5:** Commit.

### Task 10: The workflow and the bookkeeping

**Files:** Create `.github/workflows/site.yml`, `docs/superpowers/ledgers/milestone-12/2026-11-26-milestone-12-site.md`. Modify `CLAUDE.md`, `README.md`, `docs/BACKLOG.md`, `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md`.

**Decisions:**
- The workflow: on `push` to `main` with `paths: ['site/**', '.github/workflows/site.yml', 'LICENSE', 'Packages/ScriptureKit/Sources/ScriptureUI/Fonts/OFL-*.txt', 'Packages/ScriptureKit/Sources/ScriptureUI/Licenses/**']` and on `workflow_dispatch`; permissions `contents: read`, `pages: write`, `id-token: write`; one concurrency group that does not cancel a running deploy; jobs `build` (`actions/checkout`, `actions/setup-node` with `node-version-file` or a pinned major and npm cache keyed on `site/package-lock.json`, `actions/configure-pages`, `npm ci`, the build with `SITE_PATH_PREFIX` from configure-pages' `base_path` output plus a trailing slash, `SITE_URL` from its `base_url`, `SITE_REPO_URL` from `${{ github.server_url }}/${{ github.repository }}`, then `npm run check`'s link, HTML and contrast steps on that build, `actions/upload-pages-artifact` with `path: site/_site`) and `deploy` (`actions/deploy-pages`). Use the current major of each action as GitHub's Pages documentation gives it; read that documentation, do not rely on memory. It cannot be run here; say so in the ledger.
- `CLAUDE.md`: a short "The site" section: `site/` is the public site, its design rule is the spec's section 4.6 and `site/src/css/tokens.css`, `npm --prefix site run check` before committing a change to it, and no picture that is not the app.
- `README.md`: one line under the title linking `site/` and the preview command.
- `docs/BACKLOG.md`: lines for search in the guide; a custom domain; and anything Task 7 found a stranger must change by hand.
- Main spec: tick milestone 12's entry with what was built and what was not verified.
- The ledger: what each task built, the commands that verify it, what was left out (pictures), what is unverified (the workflow).

- [ ] **Step 1:** Write the workflow; read it against GitHub's current Pages documentation; record the page read and its date in the ledger.
- [ ] **Step 2:** The four documents and the ledger.
- [ ] **Step 3:** `npm --prefix site run check` and `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit --filter CreditsTests`; expected: both pass (the README's new lines must not break `theReadmeAcknowledgesEverySource`).
- [ ] **Step 4:** Commit.

### Task 11: The whole site against the spec's verification list

Run by the controller with the browser, not delegated blind. Each line of spec 11 is run and its result written into the ledger; a failure is fixed and re-run.

- [ ] **Step 1:** `rm -rf site/node_modules site/_site`, `npm --prefix site ci`, `npm --prefix site run check`; expected: clean, no unexplained warnings.
- [ ] **Step 2:** The full package tests: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit`; expected: pass.
- [ ] **Step 3:** Serve the build. At 320, 375, 768 and 1280 px, light and dark (Sepia at 1280): the front page, `guide/shortcuts`, `guide/search`, Build, Sources, Roadmap. No sideways scroll; at 200% text size the header does not overlap (Review Focus 5).
- [ ] **Step 4:** The appearance control: each choice at once, across a reload and a move to another page with no flash; System follows a change of the system's setting; the hero picture follows the choice (Review Focus 1). With scripting off: complete, follows the system, no control.
- [ ] **Step 5:** The network log of the front page and one guide page: every request is the site's own origin.
- [ ] **Step 6:** Keyboard: Tab order, visible focus, the skip link, the `<details>` sidebar at 375.
- [ ] **Step 7:** Lighthouse on the front page and one guide page: accessibility 100, performance and best practices 95 or better, or each shortfall explained in the ledger.
- [ ] **Step 8:** Every picture looked at once more against spec 5.1.
- [ ] **Step 9:** Read every page once as a visitor for anything that sells, promises, or is not true of the app; fix.
- [ ] **Step 10:** Commit the fixes and the ledger.
