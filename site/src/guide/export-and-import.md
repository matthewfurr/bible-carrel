---
title: Export and import
lede: Take everything you have made out in one file, and bring it back in without disturbing what is there.
---

There are two ways out. Export Notes writes what you have marked as Markdown, to read or keep elsewhere. Export All Data writes everything you have made to one file that Import Data can read back.

## Export Notes

File › Export Notes… (<kbd>⇧</kbd><kbd>⌘</kbd><kbd>E</kbd>) saves everything you have marked as Markdown. The Export button in the Notes window saves what its list shows, so filter to Bookmarks, say, or search, first to export only those.

The save panel asks for the layout: One file, or One file per book. One file per book makes a folder with a `README.md` and a file for each book, and replaces a folder of that name already there. The panel also asks whether to include conversations.

Either way the items run in canon order, under a heading for each book and each chapter. A note or highlight quotes its words as a blockquote, the way Copy with Reference does, then gives the note's text as written and a line naming its kind, color and date. A bookmark quotes its verse in the translation you are reading. A conversation gives each turn under its speaker.

## Export All Data

File › Export All Data… writes one file, named like `Bible Carrel Data 2026-11-19.json`. It holds your colors, highlights, notes, kept versions, bookmarks, prompts, reading plans, ticks and assistant conversations.

On the Mac, turn off Include conversations in the save panel to leave them out. The iPhone always includes them.

The file leaves out your API keys, which stay in the Keychain. It also leaves out your settings, the records of deleted notes and the daily backups.

## Import Data

File › Import Data… adds what the file has and this device does not. It never edits or deletes anything.

- A second import of the same file adds nothing.
- Anything you deleted since the export comes back, because the file still has it.
- A note whose text differs from the file's keeps the file's text as a kept version. You can discard it. See [The Notes window]({{ '/guide/notes-window/' | url }}).
- A file that is damaged, is not this app's, or comes from a newer version changes nothing and says why.

When it finishes, one sentence says what happened, such as "Added 12 notes and 3 highlights. 2 notes have another version kept. 40 were already here."

Import Data… is offered when Restore… is: with sync off, or once your iCloud account is available and its first import has finished. With a great many notes, the app may pause for a moment while it runs.

For the copies the app takes each day, see [Sync and backups]({{ '/guide/sync-and-backups/' | url }}).

## On the iPhone

Settings › General has Your Data after Backups. Export All Data… opens the share sheet, and Import Data… opens the file picker. To export notes as Markdown, use the ••• menu in the Notes tab; it exports what is listed, through the share sheet.
