---
title: Passage links
lede: Every passage has a link that opens it in the app.
---

A passage link looks like this:

`bible://<book>[.<chapter>[.<verse>[-<verse>]]][?translation=<ID>]`

The book is the app's three-letter code, in any case. The chapter, the verse, the end of a run of verses and the translation are each optional.

## Examples

<div class="table-scroll">

| Link | Opens |
|---|---|
| `bible://jhn.3.16` | John 3:16 |
| `bible://jhn.3.16-18` | John 3:16 to 18 |
| `bible://rom.8` | Romans 8 |
| `bible://jhn` | John 1 |
| `bible://1co.13.4-7?translation=KJV` | 1 Corinthians 13:4 to 7, in the King James Version |

</div>

A link you write by hand may name the book instead of using its code, but only as a book's whole name, short name or alias: `bible://John%203:16` or `bible://john.3.16`. The beginning of a name, such as `bible://ma`, is not a link. Neither is a name of one or two letters with no chapter.

## Copy Link

Copy Link in the markup menu copies the link to the selected verses, with no translation. On the iPhone it is behind the menu's chevron. Pasted as plain text it is the link. Pasted into an editor that takes rich text it is the reference, carrying the link.

## Opening a link

Both apps answer these links. Opening one shows the passage as a lookup, so Back returns you to your place. A link that cannot be read changes nothing. See [Your place]({{ '/guide/your-place/' | url }}).

A `bible://` link typed or pasted into a note is a link in the rendered note.

