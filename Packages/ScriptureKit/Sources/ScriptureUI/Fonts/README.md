# Bundled fonts

Static TrueType instances, registered at launch by `PageFace.registerBundledFonts()`. Both families are licensed under the SIL Open Font License 1.1 (`OFL-Literata.txt`, `OFL-SourceSerif4.txt`).

## Literata

- Release: googlefonts/literata `3.103`
- Download: https://github.com/googlefonts/literata/releases/download/3.103/3.103.zip (`fonts/ttf/`)
- Files: `Literata-Light`, `Literata-Regular`, `Literata-Italic`, `Literata-Medium`, `Literata-SemiBold`, `Literata-SemiBoldItalic`
- SemiBold and SemiBold Italic set the matched words in search rows (`PageFace.matchFont`); the page's own semibold asks (titles, headings, the running head, the contents page's book names) stay on Medium.
- Optical size: the unsuffixed statics, which are the text-size instances (12 pt). The release also ships 7pt, 36pt and 72pt display sets; none is bundled.

## Source Serif 4

- Release: adobe-fonts/source-serif `4.005R`
- Download: https://github.com/adobe-fonts/source-serif/releases/download/4.005R/source-serif-4.005_Desktop.zip (`TTF/`)
- Files: `SourceSerif4-Regular`, `SourceSerif4-Italic` (the release's `SourceSerif4-It.ttf`, PostScript name `SourceSerif4-It`), `SourceSerif4-Semibold`
