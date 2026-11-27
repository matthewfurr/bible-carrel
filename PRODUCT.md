# Product

## Name

**Bible Carrel** (Matt, 2026-11-16). A carrel is a study desk in a library, the design's north star. The app serves a two-year "Reading Through Scripture" group. The repository, the targets, the `.app` bundles and the bundle and iCloud identifiers keep the old name `ReadingThroughScripture`; only the name people see changed.

## Register

product

## Users

One reader, Matt, reading through the Bible in a year on a Mac and on his iPhone, with an iPad version later. The app is personal: no accounts, no sharing, no store listing until licensing is settled.

The scene that the design serves first is the study session: a desk, physical books open beside the Mac, a long sit with both hands on the keyboard, cross-checking references, highlighting phrases and writing notes as the reading goes. Daylight from a window most of the time; the evening version of the same desk under a lamp, in Dark Mode. Shorter reads happen too, one chapter between other work, and the app must reopen exactly where the last one ended.

The job: read today's chapters without friction, mark what matters in the reader's own colors, keep notes beside the text, find any mark again later, and, in a later milestone, ask a study assistant about a passage without leaving the page.

## Product Purpose

A fast, quiet reader for eight bundled English translations (ESV default) that behaves like a printed Bible plus a notebook. Phrase-level highlights in user-named colors, markdown notes anchored to those highlights, whole-verse bookmarks, a notes column beside the chapter, a whole-Bible notes browser, and a ⌘K palette for references, books, translations and commands. An on-device study assistant with cloud providers behind a key arrives in milestone 5. iCloud sync and the iPhone app are built; iPad comes later.

Success looks like this: the app opens and the reader is reading within a second, the chapter reads like a page rather than a web view, marks and notes feel like pencil in a margin, and nothing on screen asks for attention that the text did not earn. A user fluent in Reeder, Things and Craft sits down and trusts every control.

## Brand Personality

**Settled, exact, and hushed.** Like a good reading lamp: present, warm enough, never the thing you look at.

Voice: plain, short, in the second person, no exclamation marks, no coaching. Copy names the thing ("Delete Highlight", "Next: Matthew 6") and stops. Empty states say what to do in one line.

Emotional goals: calm on open, confidence that nothing will be lost, pleasure in the typography, the sense that the marks on the page belong to the reader and the app merely keeps them.

References, and what to take from each:

- **Reeder and NetNewsWire**: a three-pane Mac reading app whose sidebar is quiet, whose article view is typographic, and whose chrome never decorates.
- **Things**: whitespace with a pulse, one owned hue used with discipline, tactile rows, small details that reward attention without demanding it.
- **Craft and Bear**: notes that feel designed, markdown that renders as a document and not as a text dump.

## Anti-references

Not a web page in a window: no flat white sheet, no hyperlink feel, no HTML-like text flow, no sense that the chapter is a scrolling div. The reader has a measure, margins, a baseline rhythm and a page tone.

Not a SaaS dashboard: no gradient accents, no card grids, no stat tiles, no material slapped on surfaces for depth, no hero metrics.

Not the current default look, which is the generic SwiftUI tutorial: the gray-fill-plus-hairline card (`Color.primary.opacity(0.04)` over `opacity(0.08)` stroke) on every note and row; an editor bordered inside a bordered card (nested cards); fixed-point font sizes (`.system(size: 28)`, `15`, `17`, `18`) in chrome that should scale; the stock pastel five as highlight defaults; no Color Sets, no app icon, no accent, no spacing scale; `padding(10)`, `12`, `14` chosen by feel.

Not a consumer Bible app and not a scholar's workbench: no promo cards, badges or social features, and no tabs-and-panels on every edge.

## Design Principles

1. **The page is the product.** The chapter column sets the measure, the margins and the rhythm; every other surface takes its scale from the page and recedes. When a decision trades chrome for text, text wins.
2. **Earned familiarity.** System controls, Mac idioms, standard navigation. The test for any custom control is whether a Reeder or Things user would pause at it. Invention needs a reason that can be written down.
3. **Marks are the reader's voice.** Highlight colors belong to the reader and are the only saturated color on the page. The app's own accent lives in chrome, selection and the icon, and never competes with a highlight.
4. **Built for the long sit.** Contrast, spacing and type are tuned for an hour at a desk, in daylight and under a lamp. Everything reachable from the keyboard. No motion that does not report a state change.
5. **Nothing arbitrary.** Every color is a named Color Set with light and dark values, every size a Dynamic Type style or a scaled metric, every gap a step on the spacing scale. A number typed by feel is a bug.

## Accessibility & Inclusion

Apple baseline plus low vision.

- Dynamic Type everywhere in chrome: semantic text styles only, `@ScaledMetric` for any spacing or glyph tied to text. The reader's own font size setting (14 to 24 pt today) extends into the accessibility sizes without breaking the measure.
- Dark Mode is designed, not inverted: separate Dark Appearance values for every Color Set, depth by surface lightness rather than shadow.
- Highlight fills keep primary ink at 4.5:1 or better in both appearances, so a marked phrase stays as readable as an unmarked one. Highlight colors never carry meaning alone; the notes column and browser always show the reference and text.
- Increase Contrast gets explicit high-contrast variants for rules, secondary ink and the accent. Reduce Motion turns scroll-to-card and selection animations into cuts.
- Every control has a label and a help tag; the reader, notes column and browser work end to end with VoiceOver and the keyboard.
- English only for now. No hard-coded widths that would break under longer strings, so localization later costs layout nothing.
