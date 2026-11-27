# Handover: milestone 9 (done: merged and released)

First written 2026-11-13 after Matt's device rounds on the reader; rewritten 2026-11-16, when the rest of milestone 9 was built and Matt checked it, then merged and released the same day. It supersedes `2026-11-13-single-chapter-handover.md`.

**In one line:** milestone 9 is done. Everything planned is built, Matt checked it on his Mac and iPhone, it is merged into `main`, and his Release apps on both run it.

## Where things are

- **Repo:** `/Users/matt/Code/reading-through-scripture`. A native macOS and iOS Bible reader built with Swift 6.2, SwiftUI, UIKit/AppKit, TextKit 2, GRDB, SwiftData + CloudKit and Swift Testing, for macOS 26 and iOS 26.
- **The app is named Bible Carrel** (Matt, 2026-11-16). It serves a two-year "Reading Through Scripture" group. Only the name people see changed. The repo, targets, `.app` bundles, executables, module names, and bundle and iCloud identifiers all keep `ReadingThroughScripture`. See "The name" below.
- **Merged into `main`** on 2026-11-16 as `47e5895` (a `--no-ff` merge of `milestone-9-reader`, with no conflicts). Nothing has been pushed.
  - `main`'s old uncommitted draft of `DESIGN.md` and `DESIGN.json` (Page Styles "not yet built") was stashed before the merge. Matt dropped the stash once he saw everything in it was on `main` in finished form.
- **The worktrees are gone.** `milestone-8-iphone` and `milestone-9-reader` were removed after their merges, along with a stray `milestone-2-reader` folder of Xcode state. Their branches remain as a record. Work now happens in the main checkout, `/Users/matt/Code/reading-through-scripture`. The next piece of work starts on a new branch.
- **Release apps installed from `main` on 2026-11-16:** `/Applications/ReadingThroughScripture.app` (shown as Bible Carrel) and the Release app on Matt's iPhone (`Scripts/install-phone.sh release --go-live`), both on his real notes. The stored note format did not change in milestone 9, only new read queries in `MarkupStore`, so no iCloud schema change was needed.
- **Debug apps:** the Mac Debug app is built from the main checkout's `Build/DerivedData` and running. The iPhone `.dev` app is from `270a05b`; later commits change only tests and docs.
- **Tests at this file's commit:** package 942 (736 ScriptureUI, 111, 52, 26, 17); iOS `ScriptureUITests` 704. Both Debug builds succeed.

## Read these first

1. `CLAUDE.md`, `PRODUCT.md`, `DESIGN.md` in the repository root. `DESIGN.md` is current and is the authority on how everything looks and behaves. The relevant parts:
   - section 4: the loupe
   - section 5: the reader, the Library reference icons, and Rows › References in notes
   - section 7: the iPhone, including Library, Edge swipes and The note sheet
2. `docs/superpowers/specs/2026-11-12-single-chapter-reader-and-quick-hops-design.md`. Its section 8 records each of Matt's review rounds on the reader.
3. `docs/superpowers/specs/2026-11-12-phone-notes-swipes-library-design.md`. Its section 8, "As built", records what was built and every **(call)** Claude made.
4. `docs/superpowers/specs/2026-10-26-reading-through-scripture-design.md`: the main spec. Milestone 9's verification list is fully ticked.
5. `README.md`: building and running.

## What milestone 9 contains

- **Page styles and the page** (the original plan, `docs/superpowers/plans/2026-11-12-milestone-9-reader.md`):
  - four page styles: Printed, Lectern, Study, Classic
  - the bundled faces, book titles and section headings
  - Sepia, Settings › Reading, and Lectern's drop numeral
- **One chapter at a time**, with Previous/Next links at the foot. The book-long scroll was dropped because TextKit 2 drifted.
- **Book thumb and loupe** (both apps): a ruler of chapters at the right edge, and a clear-glass loupe holding the chapter number.
  - The bend is a Metal Core Image kernel.
  - The glass is drawn off the main actor.
  - A press lands only after it has left the chapter it came down on (`BookThumb.Press`), so a bare click on the Mac ruler does nothing.
- **Chapter switcher** (iPhone): a stack of chapter cards past the page's ends that runs on through the books beyond.
- **Edge swipes** (iPhone): Ask ↔ Notes ↔ Read ↔ Library (`PhoneEdgeSwipes`).
  - The swipe moves pictures of the screens; the live tabs never move.
  - It measures movement from where the touch came down.
  - At either end of the chain, the edge holds the drag so nothing underneath moves.
  - A copy of Notes is built out of sight after launch, so the first swipe there is quicker.
- **Library:**
  - Library is the screen to the left of Read and slides in from the left.
  - Every book has four reference icons: BibleProject, People, Places, About. BibleProject opens the book's overview video; the other three are placeholders for later.
  - A book of one chapter opens like any other and shows a single "1".
  - The Mac shelf shows the same icon row.
- **Notes that read** (both apps): a note is shown rendered, with any typed reference as a link (`NoteBodyText`, `ReferenceLinker`'s note rules).
  - On the iPhone a tapped note opens to read first; Edit/Done switch to and from the editor, and the mark's actions sit at the foot.
  - On the Mac a link shows the verses in a popover.
- **The name:** Bible Carrel, on the home screen, the menu bar, About/Quit, the window title and exported notes.
- **Parked items cleared:**
  - the Mac's top inset now follows the running head's height
  - the phone's room above a later chapter grows with large text
  - the bar title is centred under VoiceOver
  - `headlineSize` is out of the layout hash
  - stale comments fixed
  - a test that Ask About This Chapter follows the reader

## What Matt has confirmed (2026-11-16)

- All six live checks in the verification list (spec, milestone 9): "All look good."
- The loupe, the chapter cards and the Library icons in the other page styles, and light and dark: good.
- The swipe fixes (headers keeping their margin, Ask not moving) and the one-chapter books: "FIXED".
- The icons evenly spaced and rounder: "FIXED".
- The motions he alone can judge (the fast-flick trigger for the cards, their entrance, the title card's tap): "Good for now".
- **Accepted as they are:**
  - the glass bar buttons vanishing for the moment of a swipe
  - a reference to verses the translation lacks opening nothing
  - the note sheet's calls: paper background, no Add Color in its colour menu, delete alone on a chapter note

## Not checked by anyone

- **The Mac's verse popover on a click.** The links render in Matt's own Debug notes (seen in his Notes window). The step from a click to the popover was not seen:
  - SwiftUI builds no accessibility tree in a test window.
  - Synthetic `NSEvent` clicks don't reach SwiftUI there.
  - AeroSpace kept the Notes window out of reach of System Events.

  Ask Matt to click one reference if this matters.
- **Undo after deleting from the phone's note sheet** is tested (`theNoteSheetsDeleteIsUndoneWithItsNote`), not shaken on a device.
- **Landscape, Reduce Motion, Reduce Transparency and VoiceOver** on the newest pieces (the swipes, the note sheet) have not been seen.

## Known limits

- **Glass bar buttons during a swipe.** The swipe moves pictures, and neither `snapshotView` nor `drawHierarchy` includes Liquid Glass. Keeping the buttons would mean moving the live screens again, which lost the Notes and Ask titles' margins. Matt accepted it.
- **The first swipe into Notes** still waits about 217 ms in a Debug build in the simulator, while SwiftUI builds the tab. It was 742 ms before the warm-up.
- **Markdown headings in Notes browser rows** show at heading size. That predates this week.
- **Plan files:** their checkboxes were never ticked, so they are not a record of what is done.

## What comes next

1. **Done 2026-11-16:** merged into `main`, worktrees removed, Release apps installed on both devices.
2. **Release builds from now on:** only Matt decides when his real apps move to new code (`Scripts/install-app.sh`, `Scripts/install-phone.sh release --go-live`). Never run either without his go-ahead.
3. **The next project, online translations** (NLT, NTV, ESV, NIV, Spanish), is parked in `2026-11-12-online-translations-handover.md`. It needs a brainstorm with Matt before any design.
4. **Later, not scheduled:** reading plans, audio, the People/Places/About content behind the Library's placeholder icons, App Store and licensing.

## Numbers Matt may ask to tune

Describe these to Matt by what they do, never by name. He said he does not know what the names mean.

| What it does | Where | Now |
|---|---|---|
| How far to pull past an end to open the cards | `ChapterSwitcher.pullThreshold` | 56 pt |
| Pull or flick needed from a page already at an end | `restPull`, `restFlick` | 20 pt, 300 pt/s |
| Speed at which a coast opens the cards | `arrivalSpeed` | 5,000 pt/s |
| How far a flick must go to move one card | `flickTravel` | 40 pt |
| The page's spring as the cards open | `PhoneChapterTextController.switcherSpring` | 0.55 s, damping 0.7 |
| How light the patch behind the loupe's number is | `LoupeLens.pool` | 0.64 |
| How blurred the text in that patch is | `LoupeLens.centreBlur` | 2.2 pt |
| How far from the centre the patch reaches | `LoupeLens.poolReach` | 0.62 of the radius |
| Blur and veil over the rest of the glass | `LoupeLens.blur`, `veil` | 0.8 pt, 15% |
| Where the rim's bend begins, and how far it reaches | `LoupeLens.flat`, `reach` | 0.58, 0.5 |
| Strength of each chapter tap on the thumb | `ThumbHaptics.detentIntensity` | 0.8 |
| How long the Mac ruler stays | `ThumbRevealTracker.linger` | 2.5 s |
| How wide a strip at each edge starts a swipe between screens | `PhoneEdgeSwipes.edgeZone` | 24 pt |
| How far a swipe must go to settle on the next screen; or a flick this fast | `EdgeSwipe.settleFraction`, `flickSpeed` | half the width, 300 pt/s |
| How far in a swipe changes screens under Reduce Motion | `EdgeSwipe.cutTravel` | 60 pt |
| How fast a swipe settles | `PhoneEdgeSwipes.settleAnimation` | 0.35 s |
| How long after launch Notes is built ahead | `PhoneRootView`'s warm-up task | 1.5 s |

## How to see the UI without stalling

Matt was sent broken visuals twice by sessions that never looked. Look before you report. None of these methods prompts for anything.

- **iPhone, in a test:**
  - Host the view in a `TestWindow`, render `window.layer` with `layer.render(in:)` to a PNG in the session scratchpad, and open it with Read. `drawHierarchy` returns blank there, and system glass does not draw.
  - `layer.render` ignores a transform on `UITabBarController`'s transition view, so a swipe caught halfway cannot be pictured this way.
  - Remove the temporary test before committing.
- **iPhone, the real app in the simulator** (the iOS Simulator control tool): launch `Build/DerivedData/Build/Products/Debug-iphonesimulator/ReadingThroughScripture.app`, wait about 8 s, then tap, swipe, type and screenshot.
  - For a frame in the middle of a gesture, start `(sleep N; xcrun simctl io booted screenshot out.png) &` before a slow `touch_path`.
  - The tool's injected touches never begin a `UIScreenEdgePanGestureRecognizer`; plain pans work.
  - Typing goes in only once a field has focus, so wait a second after opening an editor.
- **Mac:**
  - Find the Debug app's window id with a small `swift` script over `CGWindowListCopyWindowInfo`, filtered by its pid. Pick the large window, not the 33 pt menu-bar strips.
  - Run `screencapture -x -o -l<id> out.png` in the background and kill it after a few seconds.
  - The front page (the shelf) is ⇧⌘H through System Events.
  - To hold the loupe open for a picture, use the debug default `DebugThumbChapter` (see the memory file).
  - AeroSpace may keep a window off the current workspace; System Events cannot reach it then. Do not move Matt's windows to get at it.
- **Probes:** a temporary `Logger(subsystem: "EdgeSwipeProbe", …)` with `notice` lines, read with `xcrun simctl spawn booted log show --predicate 'subsystem == "…"'`, found two of the swipe bugs. Remove the probes before committing.
- The memory file `env-headless-ui-snapshots.md` has these recipes.

## Things that cost time

- **`CIDisplacementDistortion` does not displace by its map's values.** Use a warp kernel.
- **`flat` is a reserved word in Core Image's old kernel language.** The Metal kernel's parameter is `inner`.
- **Metal Core Image kernels** need `-fcikernel` to compile and `-cikernel` to link, which SwiftPM cannot pass. They are built by `Scripts/build-kernels.sh` and checked in, one per platform (macOS, iOS, iOS simulator).
- **Loading the kernel library:** `Bundle.module.url(forResource:withExtension:subdirectory:)` returned nil for it. Build the path from `Bundle.module.resourceURL`.
- **A toolbar's principal slot is not centred** on the screen or between the bar's items.
- **`.overlay { }` wraps its content in an implicit stack**, which swallows alignment guides. Use `.position`.
- **A named coordinate space attached after `.ignoresSafeArea()` starts at the safe area.**
- **The system drops haptic impacts fired too fast.** Keep them 0.05 s apart.
- **A pan's `translation(in:)` reads zero when it asks to begin a slow drag.** Measure from where the touch came down (`shouldReceive`).
- **On iOS 26 the window's root view is not a direct subview of the window**, so inserting a view below it needs its top-level ancestor.
- **A static func on a SwiftUI `View` is main-actor isolated.** Calling it off the main actor traps at run time (signal 5) under Swift 6. Mark pure helpers `nonisolated`.
- **SwiftUI's menus ignore a checkmark in a `Button`'s label.** Use a `Picker` for a checked choice.
- **`.containerBackground(.clear, for: .navigation)`** lets the page below show through a pushed page, and the note's foot showed through. Use an opaque paper colour.
- **Xcode's generated Info.plist always takes `CFBundleName` from `PRODUCT_NAME`:**
  - neither an `INFOPLIST_FILE` key nor `INFOPLIST_KEY_CFBundleName` overrides it
  - a run-script PlistBuddy edit broke the code signature
  - what worked: set `PRODUCT_NAME`, with `WRAPPER_NAME`, `EXECUTABLE_NAME` and `PRODUCT_MODULE_NAME` pinned to the old name
- **`rtk` shortens or mangles command output,** including `find`. Use `rtk proxy <command>` when you need all of it.
- **Swift Testing's `#expect` cannot contain a mutating call.** Do the mutation on the line before.

## Rules that bind every session here

- **Git:**
  - Use `/usr/bin/git`, one git command per Bash call, with no `cd … &&`, loops or shell variables. In a worktree, a guard refuses compound commands.
  - Start new work on a branch of its own, not on `main`. Never push or merge without Matt's say.
  - End commit messages with the attribution line the harness gives.
- **Matt's real data:** never touch his Release app, `Scripts/install-app.sh`, `~/Library/Application Support/ReadingThroughScripture`, or its keychain item. Debug (`.dev`) is separate and safe, but it syncs to the Development iCloud container shared with his phone's Debug app. Don't create notes in it to test with.
- **Screen Recording:** never block on a prompt. The methods above do not prompt.
- **Mac Debug app:**
  - Build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture -configuration Debug -derivedDataPath Build/DerivedData -allowProvisioningUpdates build`
  - Quit: `pkill -f "Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app"`. Never `pkill -x`, which also quits his Release app.
  - Then `open` the Debug app.
- **iPhone:** `Scripts/install-phone.sh debug`. The phone must be unlocked and ProtonVPN off. Never toggle the VPN. The simulator is "iPhone 18 Pro Max".
- **Tests:**
  - Package: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path Packages/ScriptureKit`
  - iOS: `xcodebuild test -workspace ReadingThroughScripture.xcworkspace -scheme ReadingThroughScripture-iOS -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath Build/DerivedData -only-testing:ScriptureUITests`
  - Run builds one after another; they share `DerivedData`.
  - `PhoneReaderScreenTests` need `Build/bible.sqlite`.
- **TextKit 2 only:** never touch `textView.layoutManager`.
- **UI rules (CLAUDE.md):**
  - no fixed-point fonts in chrome
  - Palette tokens only
  - `AppSpacing` and `AppRadius` (now with `xxl`, 14, for the Library icons)
  - no card by reflex
  - deletes are undoable
  - The app applies `.glassEffect()` nowhere. `DESIGN.md` names the exceptions: the switcher's card hairline and the loupe's one soft shadow.

## Working with Matt

- **Do what he literally asked.** Do not substitute a reading of your own for his words.
- **Say plainly what you did not check.** He tests on real devices and finds whatever was guessed at.
- **Plain words, not code names.** Describe a value by what it does to what he sees.
- **Mockups before a visual choice.** He picks; he usually picks the fuller option.
- **Decisive and short.** One line per step while working.
- **Never stall.** Do not end a turn waiting on something that is not his decision.
