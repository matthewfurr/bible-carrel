# Bible Carrel

Bible Carrel (the app's name since 2026-11-16; the repo, targets, bundles and identifiers keep `ReadingThroughScripture`): a native macOS and iOS app for reading through the Bible with highlights, notes, bookmarks and a study assistant. See README.md for building and running.

## Design Context

Before writing or changing any SwiftUI, read `PRODUCT.md` (who it is for, register, principles, anti-references) and `DESIGN.md` (Color Sets, type ladder, spacing scale, materials, components, do's and don'ts). The `/impeccable-swift` skill loads both; use it for any UI work (`craft`, `critique`, `polish`, `audit`, and the rest).

North star: **The Study Carrel**. The page is the product and chrome recedes.

The three rules most often broken here:

1. No fixed-point fonts in chrome: `.font(.system(size:))` is only allowed where DESIGN.md names an exception. Use semantic text styles; use `@ScaledMetric` for sizes tied to text.
2. No inline colors: `Color(red:green:blue:)`, `Color(hex:)`, `.opacity()` tints on `.primary`, `.foregroundStyle(.secondary)`, and system palette colors (`.blue`, `.gray`) are not tokens. Use the palette in `ScriptureUI/Palette.swift` (`Color.inkSecondary`, `Palette.accent.platformColor`) and add any new pairing to `PaletteTests`. Spacing and radii come from `AppSpacing` and `AppRadius` in `Metrics.swift`.
3. No card by reflex: the gray-fill-plus-hairline container is banned. A note in the column is a row with rhythm, not a card; selection is the `accent.wash` tint, not a border.

## The site

`site/` is the public site (Eleventy). Its design rule is section 4.6 of `docs/superpowers/specs/2026-11-26-milestone-12-site-design.md` and `site/src/css/tokens.css`, which mirror DESIGN.md's tokens: no colour, size or gap is typed in a page. Run `npm --prefix site run check` before committing a change to it.

Every picture on it is the real app, in the World English Bible, with invented marks, taken from the stand-in build described in `site/README.md`; nothing is drawn or retouched. The Sources page's data (`site/src/_data/credits.json`) is held equal to `Credits.swift` by `CreditsTests.theSitesCreditsAreTheApps`, so change both together. When the app's behaviour changes, the guide page that describes it changes in the same commit.

## Later work

`docs/BACKLOG.md` lists what has been set aside and why. Read it before planning new work. When a spec leaves something out as "later", add a line there in the same commit; when an item is built or dropped, delete its line. When a wanted item is built or dropped, its entry also leaves `site/src/roadmap.md` in the same commit as its backlog line.

## Undo

Deletes are undoable through the window's `UndoManager` (`MarkupStore.delete(_:)` and `restore(_:)`), so the reader never asks for confirmation.
