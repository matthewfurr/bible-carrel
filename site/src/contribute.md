---
layout: layouts/page.njk
title: Contribute
eyebrow: Help shape it
lede: Ideas, corrections and code are welcome.
description: "How to help with Bible Carrel: suggest an idea, report a fault, or change the code and send a pull request."
permalink: /contribute/
---

Bible Carrel is a small project with one maintainer. If you read with it and something is missing, awkward or wrong, say so. A short note is enough.

## Suggest an idea

{% if site.repoUrl %}[Open an issue]({{ site.repoUrl }}/issues/new) on GitHub{% else %}Open an issue in the project's repository on GitHub{% endif %} and say what you were reading or doing, and what you wished the app did. You do not need a design or a plan.

The [Roadmap]({{ '/roadmap/' | url }}) lists what is planned next{% if site.repoUrl %}, and [the backlog]({{ site.repoUrl }}/blob/main/docs/BACKLOG.md) lists what has been set aside and why{% endif %}.

## Report a fault

Open an issue and include:

- **Where:** Mac or iPhone, and the version of macOS or iOS.
- **Which build:** The commit you built from. `git rev-parse --short HEAD` prints it.
- **What happened:** The steps you took, what you expected and what you saw.

A mistake in the [guide]({{ '/guide/first-chapter/' | url }}) or on this site counts too.

## Change the code

1. Build the app by the steps on the [Build page]({{ '/build/' | url }}).
2. For anything larger than a small fix, open an issue first, so the idea can be talked through before you write it.
3. Run the tests: `swift test --package-path Packages/ScriptureKit`.
4. Send a pull request against `main`. Say what it changes and how you checked it.

Two documents at the top of the repository, `PRODUCT.md` and `DESIGN.md`, describe who the app is for and how its screens are made. Read them before you change a screen.

Your contribution is licensed under the GNU General Public License, version 3, like the rest of the code. Please do not put copyrighted Bible text in an issue, a picture or a pull request.

## What to expect

One person maintains the app, so a reply can take a while. Not every idea will be built.
