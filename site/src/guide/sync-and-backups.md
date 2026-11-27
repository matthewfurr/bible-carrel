---
title: Sync and backups
lede: What iCloud carries between your devices, and the copy kept for you each day.
---

Everything you make is kept on the device. In a build signed with an iCloud container, it is also mirrored to your private iCloud database: sign in to the same iCloud account on each Mac and iPhone and they share it. The Bible text never syncs, because each app carries its own. The build described on the [Build]({{ '/build/' | url }}) page has sync off and keeps everything on the Mac.

## What syncs

- Highlights, notes and bookmarks.
- Assistant conversations and their messages.
- Your prompts and your highlight colors.
- Reading plans and the ticks in them.
- The kept versions of notes, and the record that a note was deleted.

Each item keeps its own identity across devices. When two devices change the same item, the later change wins. A note's text is the exception: the text that lost is kept as a version. See [The Notes window]({{ '/guide/notes-window/' | url }}).

Some settings sync too:

- your place, and the reading plan you follow
- the default translation, and the translations Compare Translations shows
- whether highlights without notes show in the notes column, and which key finishes a note
- who answers in the assistant, its model names and custom endpoint
- whether the Library shows dates
- the reader's page style, font, layout, verse numbers, section headings and justification

API keys travel through iCloud Keychain, not iCloud itself.

A place from another device moves your reader only at certain times; [Your place]({{ '/guide/your-place/' | url }}) says when.

## What stays on each device

- Text size, line spacing, column width and appearance.
- Whether the notes column shows, the Notes window's sort and filters, your export choices and the Settings tab you last used.
- The Recent list in <kbd>⌘</kbd><kbd>K</kbd>.
- The width of the chapter pane on Home.

## The iCloud line

Settings › General has an iCloud line. It reads "Synced just now", then "Synced 2 minutes ago" and so on, or "Syncing…", or "Waiting for iCloud." If iCloud is full, offline, unavailable or signed out, it says so in a sentence, with Open iCloud Settings. In a build without iCloud it says that sync is off.

The reading window shows nothing about sync until sync has failed for a day for a reason other than being offline, such as a full iCloud. Then an iCloud button appears at the head of the toolbar's right-hand group. It opens Settings › General, and its help tag names the day sync last worked.

## A new device, and no account

A second device joins by installing the app, signing in to the same iCloud account and waiting for the first import. A new device waits for that import, or fifteen seconds, before it adds the default colors and prompts, so it takes what iCloud has. If both devices made defaults anyway, they merge after each import and keep your changes.

Without an iCloud account the app opens as usual, keeps what you make on this device and says so in Settings.

Signing out of iCloud removes the synced notes from that device. That is how Apple's sync works, and the app cannot change it. Your notes come back when the same account signs in again, but anything that had not yet uploaded is lost.

## Daily backups

Once a day, at launch or when the app comes to the front, the app takes a backup if today's is missing. It keeps the newest seven. A backup carries your highlights, notes, bookmarks, conversations, prompts, colors, reading plans and ticks. A backup is taken only once you have at least one highlight or note, so plans alone are not backed up.

In Settings › General, under Backups:

- The line shows when the last backup was taken.
- **Show in Finder** selects the newest backup.
- **Restore…** asks you to choose a backup, then brings back every item in it that the app no longer has, kept versions included. It changes nothing else. It never edits or deletes, so it asks for no confirmation, and what it restores then syncs. It says what came back, such as "Restored 2 notes.", or "Nothing was missing."

Restore does not bring back the record that a note was deleted. Copying an old backup file over the live one does not work, because iCloud replays its deletions onto it.

## Two rules

**Never copy the app's data between Macs.** Let iCloud bring your notes to the new one.

**Never run an older version of the app after a newer one has opened your notes.** If you build from source, that means not checking out an older commit and running it after a newer build. The older app strips out whatever it does not know, such as reading plans or kept versions. What had already reached iCloud returns when the newer app next opens, and nothing else does, except from a backup. Build the same version for every device before you use a new feature, and do not go back.

## On the iPhone

Settings › General has Your Data after Backups, with Export All Data… and Import Data… in it. See [Export and import]({{ '/guide/export-and-import/' | url }}).
