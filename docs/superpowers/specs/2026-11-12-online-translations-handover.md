# Online translations: handover

Status: parked on 2026-11-12, to be picked up after the reader project (page styles, book-long scrolling, headings). This note holds what was learned and decided so the brainstorm can resume without redoing the research. It is not a design; the next session brainstorms the open questions below with Matt and then writes one.

## Why this exists

While designing the new reader (book titles, subtitles and section headings on the page, `DESIGN.md` section 3, Page Styles), it turned out that the bundled text from bobuk/holybooks has no headings or book titles for any translation. Matt reads the ESV, wants the NLT nearly as much, would like the NIV and KJV, and would like Spanish as well as English. Most of that can only come from publishers' APIs, which is a project of its own: fetching, keys, caching within each publisher's terms, offline behavior. On 2026-11-12 Matt agreed to split it off: the reader ships first with headings from bundled sources, and this project adds the online translations and their own headings.

## What the reader project leaves for this one

The reader project will build a per-translation headings layer: book title, subtitle and section headings keyed by verse, which the page styles draw wherever a translation provides them. It ships with only bundled sources:

- the app's own table of the 66 book titles and subtitles, in English (a Spanish table belongs with the Spanish translations, in this project),
- the KJV's own book titles from eBible.org's USFM ("The Gospel According to St. John"),
- the BSB's section headings (public domain) as an optional fallback for translations without their own, labelled as BSB headings.

This project fills the same layer from the publishers' APIs, so the reader needs no change to show them. Check the reader's spec and plan (in `docs/superpowers/`) for the layer's actual shape before designing against it.

## Research findings (2026-11-11)

Checked against official docs and terms pages, plus live calls to the NLT API. The tyndale.com and biblica.com permissions pages blocked fetching, so their terms come from search results. Prior art: michaelshimeles/bible (bible-rs) `TRANSLATIONS.md`, October 2026, which does most of this for a Rust Mac app and was a useful cross-check.

| Translation | Route | Headings | Book titles | Key, limits, storage | Cost |
|---|---|---|---|---|---|
| **ESV** | Crossway's ESV API, api.esv.org | Yes: `include-headings` (default on); `include-subheadings` adds psalm titles, the Psalm 119 acrostic letters and the Song of Songs speakers | `include-book-titles` (default off) gives the book's name, probably only "John" (not verified) | Token required. 5,000 requests a day, 1,000 an hour, 60 a minute. At most "500 verses or one-half of any book (whichever is less)" stored. No separate clause for headings, so assume they count as stored text. | Free, non-commercial only |
| **NLT** | Tyndale's NLT API, api.nlt.to `/api/passages?ref=&version=NLT` | Yes, verified: `<h3 class="subhead">Prologue: Christ, the Eternal Word</h3>` over John 1:1; `h4.subhead` then `p.psa-title` in Psalms. Each verse comes wrapped in `<verse_export orig="john_1_1" bk="john" ch="1" vn="1">` | No: only a "John 1" chapter label | No key: 50 verses a request, 500 requests a day. Free key: 500 verses a request, 5,000 a day. The API states no storage terms; the NLT copyright notice allows quoting 500 verses, never a whole book, under 25% of the work | Free, non-commercial |
| **NTV** (the NLT's Spanish counterpart) | The same NLT API, `version=NTV`, Spanish book names in the reference (`Mateo.5.1-4`) | Yes, in Spanish, verified (`El Sermón del monte`) | The reference only ("Mateo 5:1-4, NTV") | As for the NLT | Free, non-commercial |
| **NIV** | No free sanctioned route. API.Bible lists it under a "Unique License" (a direct agreement with Biblica, through support@api.bible). YouVersion Platform (free, has a Swift SDK) carries NIV as version 111 behind a separate licence accepted on platform.youversion.com; caching terms not found. Biblica directly: a permission form, about 4 to 6 weeks, proof of a legal entity. Accordance and Logos sell it only inside their own apps. | YouVersion has `include_headings`; otherwise not checked | Not checked | Unknown | Free on YouVersion if granted; otherwise negotiated |
| **KJV** | Already bundled (holybooks); eBible.org `eng-kjv_usfm` for titles | None: the KJV has no section headings (eBible's 44 `\s1` lines are the Psalm 119 letters and the Pauline subscriptions); 116 `\d` psalm titles | Yes: `\mt1` "THE GOSPEL ACCORDING TO ST. MATTHEW", "The First Book of Moses, called Genesis" | Public domain (except under the UK's Crown patent) | Free |
| **BSB** (heading source for any translation) | eBible.org `engbsb_usfm` | 3,017 `\s1`, 80 `\s2`, 1,324 `\r` parallel-passage lines, 117 `\d` psalm titles | Short only (`\mt1 John`) | Dedicated to the public domain 2023-04-30. The dedication names the texts, not headings explicitly, but eBible's edition includes the headings and is marked Public Domain throughout (an inference). | Free |
| **Reina-Valera 1909** | eBible.org USFM | None | Yes ("Génesis") | Public domain, bundle freely | Free |
| Versión Biblia Libre | eBible.org USFM | None | Yes | CC BY-SA 4.0: attribution and share-alike | Free |
| **RVR1960** | No sanctioned route: not in API.Bible's current catalogue; needs a licence from the American Bible Society | — | — | 500-verse quotation limit | Licence |
| NVI, LBLA, NBLA, NTV | API.Bible | Yes (`include-titles`) | Yes | Starter plan: 5,000 calls a month, non-commercial, up to three copyrighted Bibles; cache under 500 consecutive verses and refreshed within 14 to 30 days; citation and link required. API.Bible's help pages disagree on whether Starter unlocks these. | Free on Starter, uncertain |

Things to know about the headings:

- BSB headings are a different editor's outline. In John 1 the BSB has "The Beginning" at 1:1, "The Witness of John" at 1:6 and "The Word Became Flesh" at 1:14; the NLT has "Prologue: Christ, the Eternal Word" at 1:1. Shown over the ESV or NLT they would disagree with that translation's own, which is why the reader labels them and the publisher's own headings should replace them where available.
- The NLT API's KJV (`version=KJV`) carries Tyndale's NLT headings, presumably Tyndale's copyright, not public domain. Don't use it as a source of "KJV headings".

## Decided so far

- Split from the reader project; the reader goes first (Matt, 2026-11-12).
- Priority: ESV and NLT first, then NIV and KJV, and Spanish.
- Recommended starting set (Claude's recommendation, not yet discussed in detail): NLT and NTV through Tyndale's API (one integration gives both, with headings, English and Spanish); ESV headings through Crossway's API; Reina-Valera 1909 bundled for offline Spanish; NIV parked until YouVersion's terms are known.

## Open questions for Matt

1. **ESV headings and storage.** Matt already bundles the full ESV text from holybooks for personal use. Either follow the ESV API's storage limit strictly (fetch a chapter's headings as it's read, keep at most 500 verses' worth, so a chapter read for the first time needs the network), or fetch the headings once and keep them, as with the text. The first keeps an App Store release possible; the second is simpler and works offline. This was asked on 2026-11-12 and not yet answered.
2. **NLT and NTV text.** Fetched and cached chapter by chapter within the 500-verse rule, like bible-rs, or something else? What does the reader show offline for a chapter it hasn't kept?
3. **Spanish and English together.** Reading a Spanish translation on its own, or side by side with English (parallel columns, or a compare view of one verse)? The latter overlaps with the parallel-translations idea from the bible-rs comparison.
4. **NIV.** Is it worth applying to the YouVersion Platform as an individual developer? Their approval process and caching terms are unknown.
5. **API keys.** The free NLT and ESV keys can live beside the LLM keys (synchronizable Keychain items, `SecretStore`). Who gets the keys: does Matt want to paste his own in Settings, as with the LLM providers?
6. **Highlights on fetched text.** Phrase highlights store character offsets and a quote. Storing a quote of NLT text in the synced store may count as storing text under Tyndale's terms (bible-rs widens NLT highlights to whole verses for this reason). Decide how highlights behave on an online translation.

## Sources

- api.esv.org (passage-html and passage-text docs), crossway.org/rights-and-permissions/esv
- api.nlt.to and api.nlt.to/Documentation, plus live calls with `key=TEST`
- care.api.bible/article/394, care.api.bible/article/378-comparing-api-bible-plans, care.api.bible/article/382-which-bible-versions-are-available, docs.api.bible/common-questions, api.bible/terms-and-conditions
- platform.youversion.com
- berean.bible/terms.htm
- ebible.org (eng-kjv, engbsb, spaRV1909, spavbl, spablm), github.com/bobuk/holybooks
- lockman.org permissions, bibles.com American Bible Society rights and permissions
- github.com/michaelshimeles/bible `TRANSLATIONS.md`
