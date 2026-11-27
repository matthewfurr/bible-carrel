# One chapter at a time, with a book thumb and a carry-through drawer

Design agreed with Matt on 2026-11-12, on branch `milestone-9-reader`. It supersedes the book-long scroll in `2026-11-12-reader-page-styles-and-book-scroll-design.md` (sections 3.3 and 4.3, and the parts of 3.2 and 4.4 that follow from them). Everything else in that spec stays: the four page styles, the Lectern drop numeral, the running head, the reading settings, the reader menu and the selection menu.

Lines marked **(call)** are choices Claude made that Matt has not explicitly confirmed. Everything else under "What Matt decided" is his.

## 1. Intent

Milestone 9 put a whole book in one scroll so a reader could move quickly through a handful of chapters. On the Mac that scroll drifted: TextKit 2 discards the layout of paragraphs above the screen as the reader scrolls up and lays the text out again from estimated heights, so the text landed thousands of points from where the running head, the drop numerals and the page height expected it (Psalm 69 drawn under "Psalms · 73"). The same happens in every page style. Re-laying the book out each time costs about 140 ms and recurs every couple of scroll steps. One chapter keeps its layout: Psalm 119 alone kept every line in place through three full upward passes, in Printed and Lectern.

So the reader goes back to one chapter at a time, and two new gestures give back the quick movement the long scroll was for: moving 2 to 5 chapters forward or back.

## 2. Goals, non-goals, anti-goals

**Goals.** The page never drifts. A reader can move a few chapters forward or back quickly: on the iPhone by pulling past a chapter's end or top, on both devices with a book thumb at the right edge. Both gestures feel physical and delightful (Liquid Glass, springs, haptics).

**Non-goals.** A chapter list under the text (Matt: "What I don't want is just a list of chapters at the bottom of the text"). The carry-through drawer on the Mac in this round: the Mac has the footer links and ⌥⌘← / ⌥⌘→ (Matt: "the keyboard shortcuts solve this issue. It is mainly an iOS feature."). Reading plans (still "later" in the main design).

**Anti-goals.** A normal scroll that turns the page: reaching the end of a chapter stops there. A drawer that opens by accident during ordinary reading. A thumb or loupe that shows section headings or other text: it shows the chapter number only.

## 3. What Matt decided

### 3.1 One chapter at a time

- The reader shows one chapter. Its opening is the style's own: chapter 1 with the full title block, later chapters with their label (Lectern: the drop numeral).
- **A normal scroll takes the reader to the end of the chapter, where links go back or forward one chapter.** These are the per-chapter footer links as on `main` ("‹ Psalm 72", "Psalm 74 ›"), restyled to the page style as the milestone 9 end-of-book link was. At a book's last chapter the forward link names the next book, as today.

### 3.2 The carry-through drawer (iPhone)

- **What opens it:**
  - Pulling further at the end of a chapter after the scroll has stopped there, or further at the top.
  - Reaching the end or the top while scrolling very fast. Matt: "It is also triggered by scrolling really quickly at the start or end."
  - From the end it comes up from the bottom; from the top it comes down from the top.
- **Its entrance is Liquid Glass with fluid motion.** The drawer comes out with the speed of the pull, overshoots past its usual edge, then quickly bounces, morphs and settles into its spot. Matt: "the drawer expands past its typical edge from the velocity of pulling it out and then quickly bounces/morphs/settles back into its spot."
- **Its content is a deck of pages (Matt chose option 4 of the drawer mockups).** Small pages stacked, the front one showing a chapter number. Pulling on lifts the front page away and the next number comes forward. Because the gesture is vertical, the deck moves vertically (Matt: "The dial doesn't make sense for someone who is scrolling vertically"): from the bottom drawer, pages lift up and away; from the top drawer, the motion is mirrored.
- **Where it lands:**
  - Forward, at the start of the chosen chapter.
  - Back by one chapter after pulling down at the top: at the **end** of the previous chapter. Matt: "If the user is at the top of the chapter and pull down to get this carry through to display then yes, it should land them at the end of the chapter before it."
  - After a fast scroll, once the reader taps a target page: at the **start** of that chapter.
  - Back by more than one chapter: at the **start** of the chosen chapter.
- **iPhone only in this round**, as above.

### 3.3 The book thumb (iPhone and Mac)

- A thumb along the right edge stands for the whole book, with a faint tick per chapter and the current chapter lit. Dragging it chooses a chapter; letting go lands at that chapter's start.
- **While dragging, the chapter number shows magnified in a Liquid Glass loupe** riding beside the thumb, like the reference image Matt shared (a glass lens bending what it magnifies, with colour fringing at its rim). It should delight.
- **Only the chapter number.** No section heading, no book name. Matt: "No headings should display along with this book thumb. Just the chapter number."

## 4. The how, as far as it was decided

### 4.1 Architecture: narrow milestone 9 to one chapter (call)

Two approaches were considered.

1. **Keep milestone 9's reader and give it a window of exactly one chapter.**
   - The page styles, running head, drop numeral, landing, highlight, selection and markup code are tested and stay.
   - What only existed to grow or hold the book goes:
     - asking for chapters near the edges (`requestChaptersNearEdges`, `onNeedsChapters`)
     - the extension anchor that kept the reader still while text was added above
     - the book-window budget
     - the drop numeral's book-wide placement and near-viewport views (one chapter has one numeral)
     - anything else that exists only because more than one chapter shares the text
   - `BookLayout` may stay as the one-chapter layout type.
2. **Start from `main`'s single-chapter reader and bring milestone 9's features across.** This gives cleaner history, but it redoes and re-tests most of the branch.

Claude recommends 1 and this design assumes it.

### 4.2 Things that follow the chapter again

- The running head names the open chapter. Its progress line runs through that chapter. It still fades in as the opening scrolls under it.
- The window title, the notes column, Notes in This Chapter, Ask About This Chapter and the chapter-note mark all follow the open chapter, as on `main`.
- Back and Forward history works as on `main`: Next, Previous and choosing a chapter push an entry.
  - **(call)** A drawer turn counts as Next or Previous and pushes an entry. It is the same move as the footer link, only faster.
  - A thumb jump pushes an entry, as choosing a chapter in the Library does.
- Lookups (search hits, note links, verse references) behave as on `main`: they show the passage without moving your place until you read on.
- ⌥⌘← and ⌥⌘→ open the previous and next chapter, crossing into the neighbouring book at either end, as on `main`.

### 4.3 The drawer, in detail

- **Glass and motion.**
  - The drawer is Liquid Glass (`glassEffect`), the width of the reading column minus the system margins.
  - **(call)** It is about one and a half deck-pages tall.
  - Its entrance is a spring started with the scroll's own velocity. The overshoot shows as the glass stretching past its resting edge and narrowing slightly, then settling, with a `GlassEffectContainer` morph where the shape changes.
  - Under Reduce Motion it fades in at its spot without overshoot. Under Reduce Transparency it uses the opaque material.
- **Thresholds (call).**
  - A pull counts once the overscroll passes about 80 points past the stopped edge.
  - A fast arrival counts when the scroll hits the edge faster than about 2,500 points per second.
  - Ordinary reading, including a firm scroll that simply stops at the end, must never open it. The builder tunes both numbers on a device.
- **Moving through the deck (call).**
  - Once the drawer is out, continued pulling, or the momentum that brought it, moves through the deck: one page per stretch of travel. Each new front page gives a light selection haptic.
  - At high speed, pages flip faster but each number is shown long enough to read.
  - The deck starts on the next chapter (forward) or the previous one (back) and stops at the book's first or last chapter. **(call)** It does not cross into another book; the footer link does that.
- **Committing and cancelling after a pull (call).**
  - Letting go with the drawer out lands on the front page's chapter.
  - Pushing the deck back to the current chapter's own number, or swiping the drawer back toward its edge, closes it without moving.
- **After a fast scroll (Matt).**
  - The finger is already off the screen, so the drawer opens on the next chapter in the direction of travel and stays open.
  - It stays open until the reader taps a page (which goes to that chapter), swipes it away, or taps anywhere else (both close it without moving). Matt: "It stays open until the reader taps a page or swipes it away or tapping somewhere else dismisses it."
  - It never closes or lands on its own.
  - **(call)** While it is open, a drag on the drawer flips through the deck. Pages visible behind the front one can be tapped too.
- **VoiceOver.** The drawer is not needed: the footer links and the book thumb's adjustable element (4.4) cover it.

### 4.4 The thumb and loupe, in detail

- **Where it sits.**
  - **(call) On the Mac** the thumb sits just inside the vertical scroller, in the margin beyond the text column. The scroller stays at the reader's right edge.
  - With the notes column open, the thumb sits at the reader's right edge, beside the column, not at the window's edge.
- **The iPhone's right edge (call).**
  - The thumb replaces the system scroll indicator, which is hidden. Its long-press scrub would otherwise drag through the chapter, under the same finger.
  - The head's progress line still shows your place in the chapter.
  - A tap on a margin mark (bookmark or note glyph) still acts on the mark. Marks have no long press today, so a long press anywhere in the edge zone opens the thumb.
- **The track.**
  - It is a thin line along the right edge of the reading area, with one tick per chapter and the current chapter's tick in `Palette.accent`.
  - **(call)** It is quiet until used: on the Mac it appears when the pointer is near the right edge or the scroller is in use; on the iPhone it appears with the gesture.
  - In Psalms the ticks are dense, which is acceptable because the loupe carries the precision.
- **The gesture.**
  - **On the iPhone (call)**: a long press within the right edge zone, then a vertical drag. This keeps the right-edge swipe to Notes from the phone fixes design, which is a quick horizontal swipe.
  - **On the Mac (call)**: a drag on the track (the chapter scroller stays as it is, just inside it).
  - The thumb follows the finger or pointer; letting go lands at the chosen chapter's start. Letting go on the current chapter does nothing.
  - On the iPhone, each chapter passed gives a selection haptic. On the Mac, **(call)** each chapter passed gives an alignment haptic on a Force Touch trackpad.
- **The loupe.**
  - It is a circle of Liquid Glass beside the thumb (to the thumb's left) that bends and magnifies the chapter number inside it, with chromatic fringing at the rim.
  - It is built as a SwiftUI layer effect (a small Metal shader for magnification, refraction and fringing) inside a glass rim.
  - **(call)** The number is in the page style's numeral face in `Palette.accent`, at a modest size (Matt: the numbers "do not need to be that big").
  - It springs in when the drag starts and out when it ends.
  - Under Reduce Transparency it is an opaque disc with the number unbent. Under Reduce Motion it appears and disappears without springing.
- **Accessibility (call).**
  - The thumb is one adjustable element: "Chapter 73 of 150"; swipe up or down to change, double-tap to go.
  - It is not a hidden-only path: the footer links and Go to Reference remain.

## 5. What's left to the builder

- How to detect the pull and the fast arrival on the iPhone. The text view's scroll delegate gives the overscroll and the velocity; the drawer is a SwiftUI overlay over the reader. The exact glass and spring parameters are tuned on the device.
- The deck's page size and look within the drawer, kept to tokens (`AppSpacing`, `AppRadius`, Palette). A deck page is a quiet sheet with the numeral, not a card with a shadow.
- The shader, and how it falls back where `layerEffect` is unavailable or costly.
- Which milestone 9 code paths can be deleted outright and which are simplified to one chapter. Deleted code takes its tests with it. Tests that only checked book-wide behaviour (bands across chapters, window growth, near-viewport numeral views, carrying a lookup across chapter labels) are removed or rewritten for one chapter.
- The Lectern numeral keeps its notch and overlay view, now one per page.

## 6. Verification

- **Tests.**
  - One chapter lays out once and keeps every line through repeated upward scrolls (Psalm 119, Printed and Lectern), including the head, the numeral and a highlight.
  - The footer links.
  - Landing rules for the drawer and the thumb (the logic, unit-tested apart from the gesture).
  - History entries for drawer turns and thumb jumps.
  - The thumb's chapter for a given position.
  - The existing landing, highlight, selection and markup tests still pass.
- **On the device (Matt).**
  - The drawer: entrance feel, accidental-open rate, deck readability at speed, the landing rules.
  - The thumb and loupe on both devices.
  - Reduce Motion and Reduce Transparency.
  - VoiceOver on the thumb.
- **Performance.** A scroll frame stays near the 0.65 ms baseline. The loupe's shader holds 120 Hz on the iPhone while dragging.

## 7. Sizing and risks

**(call) Where it lives.** This work stays on `milestone-9-reader`, which is not merged. It gets a plan of its own. The milestone 9 plan's book-scroll tasks and checks are marked superseded by this design, rather than rewritten. Those include the one-second Psalm 119 budget measured across all of Psalms and the five-line lookup rule across a book.

**(call) The phone's edge swipes.** The swipe to Notes from the phone fixes design is not built yet, and it is not part of this work. This work leaves the right edge's quick horizontal swipe free for it. That design's plan, which comes after this one, must keep the thumb's long press working.

This is a project in three parts that can land in order: back to one chapter (deletions and simplifications, with the footer links), the book thumb and loupe (both devices), then the drawer (iPhone).

Risks:

- **The drawer's two triggers** need tuning on a real device so reading never opens it by accident.
- **The loupe's shader** is new ground for this codebase (no Metal yet). SwiftPM packages can carry `.metal` resources, but `swift test` must still build.
- **The phone's right-edge swipe**, when it is built, must keep working beside the thumb's long press.

## 8. Amendments after Matt's device review (2026-11-13)

Matt tried the build on his Mac and iPhone. These replace the parts of this spec named, and DESIGN.md has the detail.

- **3.1, later chapters' labels.** Removed. Chapter 1 keeps its title block; every later chapter opens straight on its text with no label and no air above it, and the running head (the bar's title on the phone) names it from the top. Lectern keeps its drop numeral. The **(call)** that every chapter opens like chapter 1, the head hidden at the top, is overturned.
- **3.2 and 4.3, the carry-through drawer.** Replaced by the chapter switcher (`ChapterSwitcher`):
  - it sits in the page's own scroll past each end and pushes the page rather than covering it;
  - its cards show the chapter's number and its opening words;
  - a pull from any drag opens it once past 56 pt of overscroll, and a flick that only ran on past the end does not;
  - pull distance no longer chooses a chapter and letting go never lands: the cards stay until one is tapped or the page is tapped;
  - a flick on the stack moves through the chapters;
  - the fast-arrival trigger is off (it opened by accident);
  - it is paper, not glass.
  Matt's landing rules stand.
- **4.4, the thumb.**
  - The loupe was misplaced by a layout bug and now rides beside the pointer or finger.
  - On the Mac the track shows on hover and after a landing only, for two and a half seconds, and fades slowly.
  - The phone's haptics are impacts.
  - A press that has been on another chapter lands where it lifts, the chapter it began on included.

### Second round, the same day

- **The fast arrival is back on** (3.2), at 5,000 pt/s as the page meets the end.
- **The cards.** They follow the page style, carry "Chapter" over the number and the opening verses with their verse numbers, and come in like liquid (drawn out of the page's edge, then let go to stretch and settle). A flick anywhere on the page moves them while they are open; a tap anywhere but a card closes them.
- **The loupe** (4.4) is a lens the app draws over the page itself, not system glass: the number unbent, the page behind soft and bent along the rim. The Mac shows the same.
- **The ruler** stays a ruler (Matt turned down the rail and the dots): no line, every fifth tick longer, the ticks swelling under the pointer. On the phone the margin's marks stand aside while it is out, and the press is read at the finger (it had been read a bar's height too low).
- **Printed's running head** drops "chapter": "JOHN · 3".

### Third round, the same day

- **Flicks at the page's end open the cards.** A film of the phone showed flick after flick at the foot of Genesis 14 opening nothing: only a slow pull held past the threshold did. From a page already at an end, a short pull (20 pt) or a flick outward (300 pt/s) now opens them.
- **The lens bends with no step**, evenly soft and evenly veiled: the first lens bent only a ring, whose inner edge showed as a line. Its number is in the page face in every style.
- **The loupe follows the finger** on the phone instead of stepping from tick to tick, and the ticks swell far enough to show from under the finger.
- **The phone's bar title** is centred between the bar's controls, always.
- **The foot's links** stay on one line on a phone by dropping "Previous:" and "Next:" when the full labels do not fit.

### Fourth round, the same day

- **The loupe is a raindrop**: the number clear and unbent, the page behind magnified through its middle, squeezed to its rim and blurred, with a highlight, shading and a soft shadow. The lens of the third round only blurred: the Core Image filter it used does not displace the way it was assumed to.
- **The thumb's taps** are never closer than a twentieth of a second, so a fast drag keeps them.
- **The phone's bar title** is centred on the screen at any length, shrinking to fit.
- **The cards will cross books** (Matt). How a card shows that it opens a new book is being chosen from mockups.

### Fifth round, the same day

- **The loupe is clear glass**: the page clear and unmagnified through its middle, bent only along its rim, with a line of light at the edge. The raindrop blurred and magnified too much.
- **The phone's bar title** is centred between the bar's buttons (the library button, and the highlighter and menu), placed by where those buttons are measured to be. Not on the screen, and not in the bar's own off-centre space.
- **The cards cross books.** The stack ends on a title card for the neighbouring book (Matt's choice of three mockups), arriving with a firmer tap as the cards close up and fan out.

### Sixth round, the same day

- **The stack runs on through the books beyond**, chapter by chapter: it had stopped at the next book's first chapter, and before that reached another book only from a book's own last chapter. Each book's first card is its title card.
- **The loupe is quieter only behind the number**: the words there are lighter and a little more blurred, fading out before the glass begins to curve; the rim is as it was.
- **The title card** has even air above its label.
