# The Bible Carrel site

A static site built with Eleventy 3. It needs no JavaScript to read; the one script it carries adds the appearance control. Everything is served from the site itself: no font service, tracker or remote image.

## Preview, build, check

Run from the repository root (Node 22 or later):

```sh
npm --prefix site ci            # once
npm --prefix site run dev       # serves http://localhost:8080/ and rebuilds as you edit
npm --prefix site run build     # builds to site/_site/
npm --prefix site run check     # the whole gate, below
```

The site works under any base path. The build reads two environment variables:

| Variable | Default | Meaning |
| --- | --- | --- |
| `SITE_PATH_PREFIX` | `/` | the path the site is served from, for example `/bible-carrel/` |
| `SITE_REPO_URL` | empty | the repository's address; while empty the header has no GitHub link |

`check` runs, in order: the build at prefix `/`, `scripts/check-links.mjs` on it, the build at prefix `/bible-carrel/`, `check-links` on that, `html-validate` over every built page, `scripts/contrast.mjs`, and `node --test scripts/*.test.mjs`.

- `check-links.mjs <dir> <prefix>` lists every `href`, `src`, `srcset` entry and CSS `url()` that does not resolve to a file under `<dir>` once the prefix is stripped. An internal link that does not begin with the prefix is an error. An `http(s):` address is allowed only in `<a href>`.
- `contrast.mjs` reads the two palettes out of `src/css/tokens.css` and the pairs in `scripts/contrast-pairs.json`, prints each ratio and fails below its minimum.

## Where things are

- `src/css/tokens.css` holds every color, size and gap as a custom property; `src/css/site.css` uses them and names no value of its own (the only literals are `0`, `1px` hairlines, percentages, font weights and the breakpoints below).
- The tokens are `DESIGN.md` section 2's, by name with a hyphen for the dot: `--paper-page`, `--paper-panel`, `--paper-overlay`, `--ink-primary`, `--ink-secondary`, `--ink-tertiary`, `--ink-rule`, `--ink-verse`, `--accent`, `--accent-wash`. The values are the light and dark sets of that section. `--on-accent` is the text on the filled button. Then the ladders: `--space-1` to `--space-8` (4 to 64 px, `AppSpacing`'s), `--text-label` to `--text-display` in `rem`, `--measure`, `--radius-sm`, `--radius-lg`, `--serif`, `--sans`, `--mono`.
- Links inside panel surfaces use the primary ink, and the accent never carries text on the panel surface. So `contrast-pairs.json` has accent on the page and the overlay only. The front page's highlights (`mark-*`, the app's five default colors) are checked under the primary ink and under the bronze verse figures.
- Appearance: `prefers-color-scheme` chooses light or dark until the visitor presses the header's icon button; a `data-appearance` attribute on `<html>` (`light` or `dark`) then overrides it, and the choice is kept in `localStorage` under `appearance`. The button shows the appearance a press switches to (the moon while the page is light, the sun while it is dark), decided in CSS by the same selectors as the dark picture, and is revealed by the script, so with scripting off the page simply follows the system. The pure functions that read, work out and apply the choice live in `scripts/appearance-core.mjs` (tested by `scripts/appearance.test.mjs`); `src/js/appearance.js` wires them to the page; the build inlines both in every page's `<head>`, so a chosen appearance applies before the first paint.
- Breakpoints (literals in `@media`, since custom properties cannot be used there): 700 px, where the header's links wrap onto a second line and a two-column list stacks; 900 px, where the guide's sidebar becomes a "Guide contents" disclosure above the article; 800 px is named by the page that uses it.
- Screenshots go in `src/img/shots/<name>.png` (and `<name>-dark.png` for a dark twin) and are placed with `{% shot "name", "Alt text" %}`. A missing file or empty alt text fails the build.

## The icon

`src/img/icon-256.png` (the header), `icon-32.png` (favicon) and `icon-180.png` (touch icon) were made from the built Debug app's `AppIcon.icns`:

```sh
sips -s format png -z 256 256 <Build>/Products/Debug/ReadingThroughScripture.app/Contents/Resources/AppIcon.icns --out site/src/img/icon-256.png
sips -s format png -z 32 32 …AppIcon.icns --out site/src/img/icon-32.png
sips -s format png -z 180 180 …AppIcon.icns --out site/src/img/icon-180.png
```

## The stand-in build

The Build page (`src/build.md`) and the screenshots come from a stand-in build of the app, made by build settings on the command line with no change to the project: no team, signed ad hoc, no iCloud entitlement (so `SyncConfiguration` finds no container and sync is off), and its own bundle identifier, so its defaults are its own. Built on 2026-11-26 with Xcode 27.2 on macOS 26.7, from the repository root, after copying a schema-6 `Build/bible.sqlite` into place (`bash Scripts/build-bible.sh` also works): The check commands shown here are written from the checks that were run, and were not run verbatim as shown.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/SiteDerivedData PRODUCT_BUNDLE_IDENTIFIER=com.matthewfurr.ReadingThroughScripture.site PASSAGE_URL_SCHEME=bible-site CLOUDKIT_CONTAINER= CODE_SIGN_ENTITLEMENTS= CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture-iOS -configuration Debug -destination 'platform=iOS Simulator,id=<udid>' -derivedDataPath Build/SiteDerivedData PRODUCT_BUNDLE_IDENTIFIER=com.matthewfurr.ReadingThroughScripture.site PASSAGE_URL_SCHEME=bible-site CLOUDKIT_CONTAINER= CODE_SIGN_ENTITLEMENTS= CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= build
```

- The apps: `Build/SiteDerivedData/Build/Products/Debug/ReadingThroughScripture.app` and `…/Debug-iphonesimulator/ReadingThroughScripture.app`, bundle identifier `com.matthewfurr.ReadingThroughScripture.site`. `codesign -dvv` shows `Signature=adhoc`, `TeamIdentifier=not set`; the only entitlement is `get-task-allow`.
- Mac: `open -g -n <full path to the .app> --args -storeName Site`; quit with `kill <pid>` of that process. Its process is named `ReadingThroughScripture`, like the owner's Debug and Release apps, so find it with `pgrep -f Build/SiteDerivedData` and never address it by name. Its store is `~/Library/Application Support/ReadingThroughScripture/Local/Site.store` (with `Backups-Site/` and `LastTexts-Site/`), its defaults `com.matthewfurr.ReadingThroughScripture.site`; it has no sandbox container. The `sync` log line reads `store …/Local/Site.store, sync off`.
- iPhone simulator: a device other than the owner's, booted by UDID (`xcrun simctl boot <udid>`), then `xcrun simctl install <udid> <app>` and `xcrun simctl launch <udid> com.matthewfurr.ReadingThroughScripture.site -storeName Site`. Its store is in the app's data container on that device, under `Library/Application Support/ReadingThroughScripture/Local/Site.store`, and its log says `sync off`.
- Links: the app reads only the `bible` and `bible-dev` schemes, so this build ignores `bible-site://` links and its Copy Link writes `bible://`, which the owner's Release app answers. That is fine for a build used only for pictures; do not open or click a passage link from it. `bible-site` is set only so that it does not compete with the Debug app for `bible-dev` links.
- The check run around each launch: while it runs, `lsof -p <pid>` names no path under `ReadingThroughScripture/Sync/` and nothing in another identity's container; the `.dev` Sync directory listing and `defaults read com.matthewfurr.ReadingThroughScripture.dev` are the same before and after. A change in either is a hard stop. The commands, with `$S` a scratch folder outside the repository:

  ```sh
  ioreg -c IOHIDSystem | grep HIDIdleTime | head -1   # nanoseconds; at least 300 s before a window goes on screen
  find "$HOME/Library/Application Support/ReadingThroughScripture/Sync/iCloud.com.matthewfurr.ReadingThroughScripture.dev-Development" -exec /usr/bin/stat -f '%m %z %N' {} \; | sort -k3 > "$S/dev-sync-before.txt"
  defaults read com.matthewfurr.ReadingThroughScripture.dev > "$S/dev-defaults-before.txt"
  open -g -n "$PWD/Build/SiteDerivedData/Build/Products/Debug/ReadingThroughScripture.app" --args -storeName Site
  pgrep -f Build/SiteDerivedData/Build/Products/Debug/   # the pid
  lsof -p <pid> | grep -E '/Sync/|Containers'            # expected: nothing
  /usr/bin/log show --last 2m --predicate 'processID == <pid> AND category == "sync"' --style compact   # expected: store …/Local/Site.store, sync off
  kill <pid>
  # then the same find and defaults read into *-after.txt, and diff each pair: expected no output
  ```

  The app logs under the subsystem `com.matthewfurr.ReadingThroughScripture` whatever its bundle identifier, so the log is filtered by pid. In the simulator: `xcrun simctl spawn <udid> log show --last 2m --predicate 'subsystem == "com.matthewfurr.ReadingThroughScripture" AND category == "sync"' --style compact`.

## The pictures

`src/img/shots/` holds the pictures, taken on 2026-11-26 from the stand-in build above (Mac and iPhone simulator), never from the owner's apps. The rules, in brief:

- Every picture is the real app: nothing drawn, composited or retouched. Downscaling (Mac to 1600 px wide, iPhone to 800 px wide) and cropping to the window are the only edits.
- The World English Bible in every picture; Compare Translations shows KJV, ASV and WEB only. The marks, notes and plan are invented and live only in the stand-in's store. The one assistant reply was given by Apple's on-device model in that run.
- The Mac may be in use for other work while pictures are taken: the stand-in is never addressed by name (the app's Debug and Release builds are processes of the same name, `ReadingThroughScripture`), only by pid. Every Mac picture shows the stand-in as the active, frontmost window, sized through Accessibility on the pid (under a tiling window manager, make the window floating first) and taken while the Mac was not otherwise in use. Before every key posted, the frontmost app's pid was checked to be the stand-in's.
- A window that is not active draws a faded toolbar, and in Dark its toolbar capsules stay light, so a picture taken from a background window is not kept.

**The invented data** is `screenshots/stand-in-data.json`, an Export All Data file (`bible-carrel-data`, version 1): highlights on John 1:4 ("the life was the light of men", yellow) and John 1:14 ("full of grace and truth", blue), each with a short note; a bookmark on John 1:12; a highlight on Psalm 1:3 ("like a tree planted by the streams of water", green); a chapter note on Genesis 1; and "A stand-in plan", five weeks from 22 November 2026 (Psalms 1 to 5, Genesis in pairs of chapters, John 1 to 5), with week 1 and the first reading of week 2 ticked. Every quoted phrase was read from `Build/bible.sqlite` (WEB) and its offsets counted there. It was brought into each store, with the app not running, by a throwaway SwiftPM tool (kept outside the repository) that depends on `Packages/ScriptureKit` and calls `DataImport.apply` on `StoreLocation.resolve(sync: nil, storeName: "Site", applicationSupport: …)`: the Mac's Application Support folder, and the simulator app's data container (`xcrun simctl get_app_container <udid> com.matthewfurr.ReadingThroughScripture.site data`, then `Library/Application Support`). File › Import Data… in the app does the same.

**Mac settings**, written before launch with `defaults write com.matthewfurr.ReadingThroughScripture.site`: `defaultTranslationID WEB`, `readingPosition.translationID WEB`, `compareTranslationIDs "KJV,ASV,WEB"`, `readerPageStyle printed`, `readerAppearance light`, `readerFontSize -float 18`, `showNotesColumn -bool true`, `followedPlanID 51E00000-0000-4000-8000-000000000401`, `showDates -bool true`, `datesNoticeAnswered -bool true`, `settingsTab general`, and `readingPosition -data <hex>` of `{"book":"JHN","chapter":1,"firstVisibleVerse":1,"translationID":"WEB"}` (sorted keys, no spaces), so it opens on John 1. The running app follows `readerAppearance` and `readerPageStyle` written while it runs. Launch: `open -g -n <app> --args -storeName Site`. The window was 1280 by 800 pt (2560 by 1600 px), set through Accessibility on the pid; for Cross-References alone it was 1280 by 990 pt.

**Driving it.** Accessibility actions addressed by pid (`AXUIElementCreateApplication(pid)`) press toolbar buttons (Home, Notes Column, Assistant), books, chapters, the People, Places and About icons, menu items (View › Reading Plan, View › Notes Browser), and set a scroll bar's value to scroll. They work on a background window too. Avoid System Events: its process references resolve by name. Keys posted with `CGEvent.postToPid` reach the app once it is frontmost; clicks posted that way do not reach the reader's text. The pointer is never in a picture: `screencapture` leaves it out unless asked.

**Window or region.** A picture of the window alone is `screencapture -x -o -l <window id>` (no shadow), downscaled to 1600 px wide. A popover is a window of its own and `-l` leaves it out, so a picture with one is a region capture of the window's rectangle, `screencapture -x -R<x>,<y>,<w>,<h>`, with 16 px cropped from each edge so the window's rounded corners hold nothing behind it, then downscaled to 1600 px wide.

**iPhone.** The simulator device is the stand-in's own (not the owner's), with `xcrun simctl status_bar <udid> override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3` and light appearance. The app's preferences on the simulator are given as launch arguments (the argument domain): `-storeName Site -defaultTranslationID WEB -readingPosition.translationID WEB -compareTranslationIDs KJV,ASV,WEB -readerPageStyle printed -readerAppearance light -followedPlanID 51E00000-0000-4000-8000-000000000401 -readingPosition '<hex>'`. (`xcrun simctl spawn <udid> defaults write` writes the device's own domain, which the app does not read.) Taps were made by a throwaway XCUITest bundle outside the repository that drives the installed app with `XCUIApplication(bundleIdentifier:)`, relaunching it for each picture, and saves `XCUIScreen.main.screenshot()`; `phone-reader` is `xcrun simctl io <udid> screenshot`.

| File | On screen | How it was set up |
| --- | --- | --- |
| `reader-hero.png` | John 1 from the top, Printed, light, 18 pt: the title page ("John", "The Gospel According to John", Chapter 1), verses 1 to 11, the 1:4 highlight, the notes column with the two notes | Launched on John 1; reader at the top (scroll bar 0); window capture |
| `reader-hero-dark.png` | The same in Dark, toolbar capsules dark to match | `readerAppearance dark` written while running; window capture. The `shot` shortcode serves it as the hero's dark pair |
| `reader-lectern-sepia.png` | Psalm 23, Lectern, Sepia: the drop numeral and the lines of poetry; notes column hidden | Home, Psalms, Chapter 23; `readerPageStyle lectern`, `readerAppearance sepia`; Notes Column toggled off; window capture after the book thumb faded (4 s) |
| `text-and-layout.png` | The Text & Layout popover over John 1 | Toolbar Text & Layout pressed; region capture and edge crop |
| `markup-menu.png` | The markup menu under John 1:5, selected | One real click on the words of verse 5; region capture and edge crop |
| `notes-column.png` | The John 1:14 note selected in the notes column, its highlight outlined on the page | The note's row pressed by Accessibility; reader scroll bar set to 0.215; window capture |
| `home.png` | The contents page, the John pane with its ringed chapter 1, dots on marked books, this week's plan band; John carries the focus ring an active window draws | Toolbar Home pressed; window capture |
| `people.png` | People in Genesis, Jacob's page at his drawn family tree | Genesis chosen, People, Jacob; the page's scroll bar set to 0.27; window capture |
| `places.png` | Places in Acts: Apple's map with its pins and attribution (Maps, Legal), the list by Most named | Acts chosen, Places; 8 s for the tiles; window capture |
| `about-timeline.png` | About Genesis: the timeline's chart and its first rows | Genesis chosen, About; scroll bar set to 0.105; window capture |
| `search.png` | ⌘K with "light shines" typed, Scripture results in WEB | ⌘K and the text as keys posted to the pid; region capture and edge crop |
| `reading-plan.png` | The plan window: "A stand-in plan", week 2 chosen, one of three ticked | View › Reading Plan pressed by Accessibility; the plan window floating and focused, 780 by 560 pt; window capture, not downscaled |
| `assistant.png` | The assistant on Psalm 1, "Name the key themes" and the on-device reply | Home, Psalms, Chapter 1; toolbar Assistant; "Psalm 1" for where you are; the prompt's tile pressed; about 70 s for the reply to finish; window capture. Each run saves a conversation, deleted afterwards so the Notes window keeps its five items |
| `compare.png` | Compare Translations on John 1:1: WEB (reading), ASV, KJV | J selects verse 1, C opens the panel; region capture and edge crop |
| `cross-references.png` | Cross-References on John 1:1: six verses it points to, Show all (36), verses that point here (50), Ask About These and the OpenBible.info credit, the whole panel inside the picture | Window 1280 by 990 pt; J selects verse 1, R opens the panel; region capture and edge crop (1600 by 1233 px) |
| `notes-window.png` | The Notes window, all five items by day | View › Notes Browser pressed; window 1100 by 680 pt, floating and focused; the filter set to Notes and back to All to clear a selection; window capture |
| `phone-reader.png` | John 1 on the iPhone, the 1:4 highlight and its note mark | Launch with the arguments above; `simctl io screenshot` |
| `phone-library.png` | The Library sheet on John, its chapters and the People, Places and About icons | Library tapped |
| `phone-plan.png` | The Plan tab: this week (week 2), the weeks either side | Plan tapped |
| `phone-search.png` | Search with "light shines", WEB results, keyboard put away | Search tapped, text typed, the keyboard's first-use tip's Continue tapped, the list dragged down |
| `phone-pen.png` | The pen on: the tab bar as a row of the five colors | Highlighter tapped |
| `phone-switcher.png` | Psalm 1's end with the chapter card for Psalm 2 | Launched on Psalm 1; two slow drags up from the lower quarter to the upper quarter |
| `<name>-dark.png` (about-timeline, assistant, compare, cross-references, home, markup-menu, notes-column, notes-window, people, places, reading-plan, search, text-and-layout) | The light picture's twin in Dark: same window, size, state and framing | `readerAppearance dark` written while running, then set up as its light picture. Differences: About's scroll bar 0.1032; Search's selected row comes from the resting pointer; Cross-References taken with the window at x 40; Text & Layout shows Dark chosen; the assistant's reply is a new on-device answer, its conversation deleted afterwards. `reader-lectern-sepia` has no twin on purpose: it is a picture of the Sepia paper |
| `phone-<name>-dark.png` (reader, library, plan, search, pen, switcher) | The light iPhone picture's twin in Dark | The simulator's appearance set to dark (`xcrun simctl ui <udid> appearance dark`) and `-readerAppearance dark` among the launch arguments; otherwise as the light picture |

## The fonts

`src/fonts/` holds Literata Light, Regular, Italic and Medium as WOFF2, with `OFL-Literata.txt`. The source files are the app's own TTFs in `Packages/ScriptureKit/Sources/ScriptureUI/Fonts/`. They were converted once (a one-off), with the dependency-free converter in `site/tools/ttf-to-woff2.mjs` (Node's built-in Brotli; it is not part of the build and not a dependency):

```sh
node site/tools/ttf-to-woff2.mjs Packages/ScriptureKit/Sources/ScriptureUI/Fonts/Literata-Light.ttf site/src/fonts/Literata-Light.woff2
node site/tools/ttf-to-woff2.mjs Packages/ScriptureKit/Sources/ScriptureUI/Fonts/Literata-Regular.ttf site/src/fonts/Literata-Regular.woff2
node site/tools/ttf-to-woff2.mjs Packages/ScriptureKit/Sources/ScriptureUI/Fonts/Literata-Italic.ttf site/src/fonts/Literata-Italic.woff2
node site/tools/ttf-to-woff2.mjs Packages/ScriptureKit/Sources/ScriptureUI/Fonts/Literata-Medium.ttf site/src/fonts/Literata-Medium.woff2
```

## Contrast, as `contrast.mjs` prints it

```text
palette  text on surface                          ratio  min
light    ink-primary on paper-page                 15.29  4.5  ok
light    ink-primary on paper-panel                14.46  4.5  ok
light    ink-primary on paper-overlay              15.97  4.5  ok
light    ink-secondary on paper-page                5.58  4.5  ok
light    ink-secondary on paper-panel               5.28  4.5  ok
light    ink-secondary on paper-overlay             5.83  4.5  ok
light    ink-verse on paper-page                    6.34  4.5  ok
light    ink-verse on paper-panel                   5.99  4.5  ok
light    ink-verse on paper-overlay                 6.62  4.5  ok
light    accent on paper-page                       4.89  4.5  ok
light    accent on paper-overlay                    5.10  4.5  ok
light    ink-primary on accent-wash                13.54  4.5  ok
light    on-accent on accent                        5.25  4.5  ok
light    ink-primary on paper-page                 15.29  3    ok
light    ink-primary on mark-yellow                12.61  4.5  ok
light    ink-primary on mark-green                 12.96  4.5  ok
light    ink-primary on mark-blue                  12.53  4.5  ok
light    ink-primary on mark-rose                  12.00  4.5  ok
light    ink-primary on mark-orange                11.57  4.5  ok
light    ink-verse on mark-yellow                   5.23  4.5  ok
light    ink-verse on mark-green                    5.37  4.5  ok
light    ink-verse on mark-blue                     5.19  4.5  ok
light    ink-verse on mark-rose                     4.97  4.5  ok
light    ink-verse on mark-orange                   4.79  4.5  ok
dark     ink-primary on paper-page                 15.05  4.5  ok
dark     ink-primary on paper-panel                13.78  4.5  ok
dark     ink-primary on paper-overlay              12.24  4.5  ok
dark     ink-secondary on paper-page                7.46  4.5  ok
dark     ink-secondary on paper-panel               6.83  4.5  ok
dark     ink-secondary on paper-overlay             6.06  4.5  ok
dark     ink-verse on paper-page                    9.77  4.5  ok
dark     ink-verse on paper-panel                   8.94  4.5  ok
dark     ink-verse on paper-overlay                 7.95  4.5  ok
dark     accent on paper-page                       8.94  4.5  ok
dark     accent on paper-overlay                    7.27  4.5  ok
dark     ink-primary on accent-wash                11.65  4.5  ok
dark     on-accent on accent                        8.94  4.5  ok
dark     ink-primary on paper-page                 15.05  3    ok
dark     ink-primary on mark-yellow                 7.46  4.5  ok
dark     ink-primary on mark-green                  7.23  4.5  ok
dark     ink-primary on mark-blue                   7.38  4.5  ok
dark     ink-primary on mark-rose                   7.84  4.5  ok
dark     ink-primary on mark-orange                 7.67  4.5  ok
dark     ink-verse on mark-yellow                   4.85  4.5  ok
dark     ink-verse on mark-green                    4.69  4.5  ok
dark     ink-verse on mark-blue                     4.79  4.5  ok
dark     ink-verse on mark-rose                     5.09  4.5  ok
dark     ink-verse on mark-orange                   4.98  4.5  ok
contrast: every pair meets its minimum in both palettes
```

## Publishing

The public repository, `github.com/matthewfurr/bible-carrel`, does not carry this project's working history. Each publication is one new commit there whose tree is the tree being published. The working repository has no remote to it, so the working history cannot be pushed there by mistake, and nothing but the one commit is ever sent.

Before publishing, search the tree for anything that should stay private (an email address, a device identifier), and run `npm --prefix site run check`. Then, with `<ref>` the commit to publish and the public name and GitHub's no-reply address for the account in `GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_NAME` and `GIT_COMMITTER_EMAIL`:

```sh
URL=https://github.com/matthewfurr/bible-carrel.git
git fetch "$URL" main
COMMIT=$(git commit-tree "<ref>^{tree}" -p FETCH_HEAD -m "<what changed>")
git push "$URL" "${COMMIT}:refs/heads/main"
```

The first publication had no `-p FETCH_HEAD`. A push that changes anything under `site/` runs `.github/workflows/site.yml`, which builds, checks and deploys the site to GitHub Pages.

