---
title: Reading plans
lede: A table of weeks and their readings, for a group that meets weekly.
---

A reading plan is a table of weeks, each with its readings, for a group that meets weekly. A week usually holds a Wisdom chapter and an Old or New Testament passage. The app keeps any number of plans and follows one of them.

Before you make the first plan, build the same version of the app for every device you use. An older build that opens your notes removes the plans it does not know (see [Sync and backups]({{ '/guide/sync-and-backups/' | url }})).

## The Reading Plan window

On the Mac, plans live in the Reading Plan window. Open it with View › Reading Plan (<kbd>⌥</kbd><kbd>⌘</kbd><kbd>P</kbd>), with "Reading Plan" in <kbd>⌘</kbd><kbd>K</kbd>, or with The whole plan on Home.

{% shot "reading-plan", "The Reading Plan window with five weeks listed down the side and Week 2 chosen, showing its three readings with one ticked", "lazy", "(min-width: 65rem) 43rem, 100vw" %}

It lists every week down the side with its date and how many of its readings are ticked, and shows the chosen week's readings beside them. Its toolbar holds, from the left, the plans menu (with the plan you follow checked and Delete Plan… under the plans), Import…, New Plan, Edit Plan… and Change Meeting Date… for the chosen week. Delete Plan… asks first, and Edit › Undo brings the plan back with its ticks.

## Bring a plan in

To type a plan, choose New Plan in the Reading Plan window's toolbar. To bring one in, choose Import… there and pick a text file or a PDF, or drop a PDF on the window.

A text file, or text pasted into a new plan, starts each week with a line such as `Week 12`, with a date and a label after it if there are any. Each reading is then one line:

```text
Week 12
Psalms 84; Esther 7-8
```

The app reads only the two PDF table layouts it was made for. It rebuilds the table on the device, with no network, from where each word sits on the page. A PDF it cannot read, or one with no text in it, is reported, and the app offers New Plan so that you can type or paste the plan instead.

## The review

Nothing is saved until you accept the review, which is also the editor. New Plan and Edit Plan… open the same screen.

At the top are the title and the year the dates start in. A PDF gives each date as a month and a day, so the app picks the year in which every date exists and all fall on the same weekday. The stepper changes the year.

Under that is To check: a book the app does not know, a chapter the book does not have, a date that does not exist or is out of order, or a week numbered out of sequence. Click a line to go to the place.

Each week shows its number, date and label, and its readings as text you can edit. You can add, remove and drag readings, and add and remove weeks. Save is off while a line cannot be read or a book is unknown.

Editing a plan that is in use keeps what you ticked. A tick goes only when its reading is removed.

## This week

This week is the first week whose meeting date is today or later. The day after the meeting, the next week takes over. After the last week's date, the plan is finished.

A plan with no dates asks which week the group is on and when it next meets, and dates every week a week apart from that. Change Meeting Date… moves one week's date, and every later week moves by the same number of days. A week's label, such as "Retreat" or "No meeting", can be changed too.

## Read this week

On the Mac, while a plan is followed and not finished, a band at the top of Home shows the week. Its readings sit side by side, each with a tick circle and the passages. Click a passage to open it for reading. The band also shows the plan's progress as a thin line, and a link, The whole plan, that opens the Reading Plan window.

In the reader, the This Week button in the toolbar (a calendar) shows the same in a popover.

## Ticks

A circle ticks and unticks a reading. The app does not tick a reading for you or count you as behind: a week that passed with nothing ticked looks like any other.

## On the iPhone

The Plan tab sits between Read and Notes. It shows this week at the head, and the weeks before and after in one list. A week opens in place to its readings. The ••• menu has the plans, Import…, New Plan, Edit Plan…, Change Meeting Date… and Delete Plan…, and Import… is also offered when there is no plan yet. A shake undoes a delete.

{% shot "phone-plan", "The Plan tab on the iPhone, with this week's three readings, one ticked, above the weeks that follow", "lazy", "(min-width: 900px) 16rem, 50vw", "shot-phone" %}

## Where plans live

A plan syncs through iCloud as a whole, and each tick syncs on its own. Ticks made on two devices both stay, and the same reading ticked twice is one tick. Which plan you follow syncs too. If a plan is edited on two devices at once, the later edit wins.

The daily backup carries plans and ticks, and Restore… brings back the ones that are missing.
