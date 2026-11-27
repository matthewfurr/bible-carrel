# Milestone 12 ledger: the site

Plan: `docs/superpowers/plans/2026-11-26-milestone-12-site.md`. Spec: `docs/superpowers/specs/2026-11-26-milestone-12-site-design.md` (approved by Matt, 2026-11-26). Branch `milestone-12-site`, cut from `main` at `84f3909`. Built on 2026-11-26 in one sitting: implementers and task reviewers on Sonnet, the stand-in build and the pictures on Opus, the whole-branch review on Opus. Nothing was pushed or published.

## What was built

| Task | What | Commits |
|---|---|---|
| 1 | The scaffold, the tokens and the checks (`npm --prefix site run check`: links at two prefixes, HTML, contrast in three palettes, the appearance tests) | `98596c5`, `f670e0c` |
| 2 | The Sources page, `site/src/_data/credits.json`, the licence texts under `/licences/`, and `CreditsTests.theSitesCreditsAreTheApps` | `3cfb8f3`, `6836a6c` |
| 3 | The guide's layout, sidebar data, the check that sidebar and files agree, and five pages | `c7d01d5`, `b02743d`, `9957296`, `255710e` |
| 4 | Seven guide pages: marking and studying | `9a99679` |
| 5 | Five guide pages: keeping, the iPhone, reference; the check now needs all 17 | `1eb44b1` |
| 6 | The roadmap page | `52973d8`, `1853cc4` |
| 7 | The stand-in build (its own bundle identifier, no iCloud) and the Build page | `b86e0e9`, `7a72b44` |
| 8 | The pictures: 6 from the iPhone simulator, 15 from the Mac | `ec742f0`, `4fe31a0` |
| 9 | The front page; the pictures placed there and on 11 guide pages | `0044256`, `65a3aae`, `91c010a`, `c2ad6d2`, `b4e194c` |
| 10 | `.github/workflows/site.yml`; `CLAUDE.md`, `README.md` and the backlog | `3561547`, `515f3b4`, `fe16515` |
| 11 | The whole site checked in a browser (below) | |
| Final | The whole-branch review's one fix wave (27 items) | `20ae2eb`, `95353a5`, `3e02fa3` |

Every task was reviewed against its brief and the spec before the next built on it. The fix rounds: Task 3, one (a name and an unsupported sentence, both settled from the code); Task 6, one (the page had said the NLT is bundled today; only the ESV is); Task 7, one (the Build page had presented its commands as run exactly as shown); Task 9, two (a second filled button and two overstated sentences; then two picture placements and two overflow defects); Task 10, one (two action majors a release behind).

## Verified

- `npm ci` from the lockfile and `npm run check`, clean, in the worktree: links resolve at `/` and at `/bible-carrel/`, the HTML validates, every text and surface pairing meets its minimum in light, Sepia and dark, 7 of 7 appearance tests pass.
- A picture the front page names, when missing, fails the build by name. A guide file not in the sidebar, a title that differs, or a sidebar page with no file fails the build.
- `swift test --package-path Packages/ScriptureKit` passes; `theSitesCreditsAreTheApps` failed when one notice in the JSON was altered and passed when it was restored.
- In a browser, on the built site: the four Literata files load; no request leaves the site's origin (front page and a guide page); one `h1` a page, one filled button on the front page; the appearance control sets each of the four choices, the choice survives a move to another page, and with no choice stored the page follows the system's dark setting; no page scrolls sideways at 320 or 375 px at normal text size, nor at 375 px at twice the text size; tab order, the skip link and the focus ring are right.
- Every picture was looked at one by one by a reviewer: the wording is the World English Bible's as the database has it, the marks are invented, nothing of the desktop shows, the map keeps Apple's attribution, and the assistant's reply is labelled On-device.
- The stand-in build was checked while it ran (its open files were only its own `Local/` store; its log said sync off) and the Debug identity's store and defaults were unchanged afterwards.

## Not verified

- **The workflow has never run**: the repository has no remote. It was read against the actions' own release pages.
- **Lighthouse was not run.** The measured checks above stand in for it.
- **The fonts were seen in a Chromium browser only.** They were made by a small converter written for the purpose (`site/tools/ttf-to-woff2.mjs`); open the site in Safari once before publishing.
- **A build from a fresh clone.** The clean install and check ran in the worktree.
- **The Build page's commands as written.** The builds that ran used another bundle identifier, a link scheme of their own, another derived data folder and the simulator named by id; the page says so. The downloads in `Scripts/build-bible.sh` were not exercised: the files were cached.
- At 320 px wide and twice the text size together, the Build page still scrolls sideways (four unbreakable names in list items).

## Left out, and waiting

- The first pass left out `cross-references.png`, removed the dark hero and left ten Mac pictures with an inactive window's faded toolbar. All three were settled by the retake below.
- Publishing: the spec's section 10. The code is GPL-3.0; the public repository starts from a fresh history. The repository itself now exists (below).

## Rulings made while building (each Matt's to overturn)

1. The build began without his review of the plan, on his "start working on that now" and his approval of the spec.
2. Breakpoints inside `@media` conditions are literals in `site.css` (custom properties cannot be used there).
3. The fonts' WOFF2 files come from a converter written for the purpose and kept in `site/tools`, since no packaged converter could be fetched.
4. Sepia keeps the app's accent, and the accent never carries text on a panel surface (it would fall to 4.08:1 in Sepia).
5. Guide prose never uses a symbol's internal name; a button is named by what it does.
6. The window is "the Notes window"; "Notes Browser" names only its command and button.
7. The stand-in is addressed only by process id or full path; it goes on screen only after five minutes idle; the Debug identity's store and defaults must be unchanged, and the Release app's own syncing is not the stand-in's doing.
8. The front page was built before the pictures existed, then made to require them.
9. The two-pictures-a-page limit, the plan's own, was lifted for the Library page.
10. The dark hero was removed rather than shipped with a toolbar that looks broken.
11. The mixed window chrome across the pictures was left as it is: true and safe, and a retake needs the screen.
12. Lighthouse was not run.
13. The whole-branch review ran on Opus.
14. The guide's reading-plans page uses invented week labels and names no group; the front page says nothing of PDFs.
15. `SITE_URL` was removed: nothing used the site's full address.

## After the handover, the same day

Matt read the handover and asked for three things: "Try the picture retake again. And create a bible-carrel repo on my GitHub", then, on seeing the site, "Also fix the website light and dark mode. No need for sepia and this should not be a dropdown. It should be an icon that toggles between them."

| What | Commits |
|---|---|
| The retake (Opus): ten Mac pictures taken again with the stand-in as the active window, `reader-hero-dark.png` back as the hero's dark pair, `cross-references.png` new on the Verse panels page; `site/README.md` says how | `2976c4d` |
| The appearance control (Sonnet): one icon button that switches between light and dark, following the system until pressed; the site's Sepia palette removed; 22 tests | `7e3301f` |
| The records: this section, the spec amended (section 4.4 carries Matt's words), the backlog's retake line removed, `site/README.md` cleared of details of the Mac the pictures were taken on | this commit |

- **The repository** `matthewfurr/bible-carrel` was created on GitHub, private and empty. No remote was added to this checkout, on purpose: the public repository starts from a fresh history, and with no remote the full history cannot be pushed there by mistake. Nothing was pushed.
- **The retake, checked.** A reviewer (Sonnet) opened all sixteen Mac pictures: every toolbar is active, the dark hero's toolbar is dark and its framing matches the light one, the Cross-References panel is whole with its OpenBible.info credit, and the visible verses match the database's World English Bible word for word (John 1, Psalms 1 and 23, and the six cross-referenced verses). The `.dev` identity's store listing and defaults were identical before and after; the stand-in opened nothing under `Sync/` and logged sync off. Two wording findings in `site/README.md` were fixed in this commit.
- **What the retake changed besides chrome:** the assistant's reply is a new on-device answer (five numbered themes, no verse links); the contents page shows the focus ring an active window draws around the chosen book; the two assistant conversations in the stand-in's store were deleted so the Notes window shows its five items.
- **The screen during the retake:** the stand-in's windows were in front for about 13 minutes and focus went back to the window that had it. No key was posted unless the stand-in was frontmost.
- **The appearance control, checked in a browser:** with nothing stored the page follows the system, light or dark, and the button's name says what a press does; a press switches at once, the hero's picture follows, and the choice holds on another page; the button is 44 px square; no sideways scroll at 320 or 375 px. **Not verified:** that the button's name follows a change of the system's setting while the page is open (the preview's emulation fires no change event; a press still does the right thing, since it reads the setting when pressed).
- Still not verified, as above: the workflow, Lighthouse, the fonts in Safari, a fresh-clone build.

Rulings made here (each Matt's to overturn):

16. The repository was made private, since he did not say which; nothing is exposed until he makes it public. On a free GitHub plan Pages serves only a public repository.
17. Rulings 4, 10 and 11 above are overtaken: the site has no Sepia, the dark hero is back, and the pictures share one window chrome.
18. With no choice stored the control follows the system and has two states, not three: there is no way back to "follow the system" short of clearing the site's storage. A third state would make it a menu again.
19. The link-on-panel rule (panel links use the primary ink) stays as built, though Sepia was its reason.
20. The four pictures taken active in the first pass were not retaken: their chrome matches the new set. They are region captures, so their corners are square and their window buttons sit a little nearer the edge than in the rest.

## The critique and its fixes, the same day

Matt, on being asked what to do with the branch: "Don't merge yet. Run the design and wording through /impeccable and report back." The critique ran as three isolated reviewers: a design review of the rendered site in light and dark (Opus), Impeccable's detector on the built pages and five live pages (Sonnet), and an editor reading the wording of all 21 pages against the code (Opus). It scored 27 of 40. Its record is in `.impeccable/critique/` (not committed).

What it found, in short: three wrong statements (the Debug build's `bible-dev://` links against the guide's `bible://`; the Roadmap saying the NLT and NTV come with the build; the Notes window's Mac sort choices given the iPhone's labels); a front page whose one filled button led to the guide when the only thing a visitor can do is build; a Build page with commands running past the column, no clone line and four separate "not tried" notes; pictures too small to read and light in the dark appearance; one thing under several names and the same paragraph on several pages; and prose in British spelling where the app and Matt write American.

Matt's answer: "Yes to all the ones that are my call", and to do what the critique recommended. His four calls: Build is the filled button; the documented build is made to match the guide (not the guide footnoted); American spelling; fixes now, and mockups of a front page with more of the Printed page in it for him to choose from.

| What | Commits |
|---|---|
| Design (Opus, the design reviewer continued as implementer): Build as the filled action at the top and the close; a current state in the header nav; a wider picture column and every picture a link to its full size; one h2 style, the app's italic section heading in primary ink; a sticky guide sidebar; the measure kept between 701 and 900px; touch-size links at phone width; key chords drawn as one cap by a build-time transform; shortcut tables aligned; the front page's lines reworded to say what the documented build gives | `8c4c0cd` |
| Wording (Opus, the wording reviewer continued as implementer): all forty findings but those on the front page; the Build page rebuilt (what it costs, `PASSAGE_URL_SCHEME=bible`, commands one setting to a line, a clone line when the address is set, "If the build fails", one "What was checked" paragraph, a link on to the guide); American spelling and `/licenses/`; one name per thing; repeats replaced by a sentence and a link; a "Choose a translation" section; each guide page's meta description | `db33e83`, `c88a8cf` |
| Pictures (Opus): a new hero pair that opens on the book's title, and a dark twin for every picture but the Sepia one (13 Mac, 6 iPhone) | `547b19f`, `3653bd5` |
| A review of the fixes (Sonnet) found nothing critical and four smaller faults, all fixed | `6fc4c7d` |
| Three front-page mockups for Matt to choose from, kept in `docs/superpowers/specs/milestone-12-mockups/front-page-directions/` (A, a page of the book; B, the contents page; C, the page and its margin) | this commit |

Checked: `npm --prefix site run check` passes on the result (links at both prefixes, HTML, contrast in both palettes, 22 tests). The reviewer checked every changed statement about the app against the code, all 1,071 internal links and picture sources in the built site, the chord transform, and that nothing under `site/` carries a private path, address or identifier. The dark front page, the phone-width guide and the Build page were looked at in a browser. The pictures were each opened by the agent that took them; the `.dev` identity's store listing and defaults were identical before and after, and the stand-in and the simulator were shut down.

Not verified: the Build page's commands with `PASSAGE_URL_SCHEME=bible` were not run (a build that registers `bible` would compete with the copy already on this Mac); the setting was checked with `xcodebuild -showBuildSettings` for both schemes, and the page says so. The dark pictures were not opened by a second reader.

Rulings made here (each Matt's to overturn):

21. The critique's reviewers were continued as the implementers of their own findings, and a fresh reviewer checked the result.
22. The spec's "one filled button" becomes "the one filled action is Build, at the top and at the close".
23. The front page keeps its rows and labels until Matt chooses among the mockups; the site is published with the corrected page meanwhile.
24. `reader-lectern-sepia` has no dark twin: it is a picture of the Sepia paper.
25. The site's spec quoted the private commit email that the fresh history exists to keep out of the public repository; the address was removed from the spec.


## Published, the same day

Matt, asked why the repository was private: "I asked for it so we could publish a public repo and GitHub pages people could actually see". So publishing was done in the same sitting, once the fixes above passed their checks: the repository made public, Pages' source set to GitHub Actions, and one commit holding this tree pushed to `main` by address, made with his public name and GitHub's no-reply address for his account. This checkout still has no remote, and the working history, with `refs/notes/ai`, stays on this Mac. The tree was searched for addresses and device identifiers before the commit; the mild items the audit listed stay, as he decided. `site/README.md`, "Publishing", has the commands for the next publication. The first deploy ran once and passed (build 22 s, deploy 10 s: `npm ci`, the build, the link, HTML and contrast checks, the tests, then Pages). The live site at `https://matthewfurr.github.io/bible-carrel/` was opened: the four Literata faces load, the hero shows, the header carries the GitHub link, the Build page shows the clone line, a license file answers, and nothing is requested from another host. The repository's homepage is set to the site. So "the workflow has never run" above no longer holds; Lighthouse and Safari are still not done.

26. The repository's privacy on creation (ruling 16) was read by Matt as holding back; he had asked for the repository in order to publish it. Claude read those words as his go-ahead to publish, and said so before starting, with the offer to stop before the push if he wanted to look first.
27. The public commit's address is GitHub's no-reply address, since he named none; it is one commit and can be made again with another.
