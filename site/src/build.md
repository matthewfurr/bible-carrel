---
layout: layouts/page.njk
title: Build it
eyebrow: From source
lede: Bible Carrel is free software. You can build it yourself, for your Mac and for the iPhone simulator.
description: "How to build Bible Carrel from its source: what you need, what the build downloads, how to sign it without the owner's team, and how to run it."
permalink: /build/
---

You need a Mac with macOS 26 and Xcode 26 or later, and no Apple developer account or team. The first step downloads the Bible texts and study data and builds a database of about 82 MB. Then Xcode builds the app.

The code is under the GNU General Public License, version 3. The Bible texts, study data and typefaces it uses keep their own licenses, listed on the [Sources]({{ '/sources/' | url }}) page.

## 1. What you need

- A Mac with macOS 26 and Xcode 26 or later. The steps on this page were checked with Xcode 27.2 on macOS 26.7.
- Apple Intelligence turned on, if you want the study assistant to answer on the device. It is optional.

The build below signs the app to run on your own Mac and in the simulator only.

## 2. Get the source and build the Bible database

{% if site.repoUrl -%}
Clone the repository and go into its folder:

```sh
git clone {{ site.repoUrl }}
cd {{ site.repoUrl.split("/") | last }}
```

Then run:
{%- else -%}
Clone the repository, then run this from its folder:
{%- endif %}

```sh
bash Scripts/build-bible.sh
```

It downloads what the app is made from, keeps it in `~/Library/Caches/ReadingThroughScripture/`, and writes `Build/bible.sqlite`, about 82 MB. Warnings about Sirach and the stray `NAH` folder are expected.

- The Bible texts come from bobuk/holybooks on GitHub, pinned to one commit. The script checks no digest for them.
- The section headings and the King James Version's book titles come from eBible.org, the cross-references from OpenBible.info, and the people, places and events of the Library from Theographic Bible Metadata. Each file is checked against a pinned SHA-256 digest, and the script stops if one has changed.

Four of the eight translations are under copyright and belong to their publishers: the English Standard Version, the New American Standard Bible (1995), the Amplified Bible, Classic Edition, and the Easy-to-Read Version. The build fetches them for your own use, and this project grants no license to them. The [Sources]({{ '/sources/' | url }}) page names each holder.

If you skip this step, the app's build runs the same script when the database is missing or was made for an older version of the app (`Scripts/ensure-bible.sh`).

## 3. Build the app

The project is set up for its owner's Apple team, bundle identifiers and iCloud containers. The commands below replace those on the command line, with no change to the project: no team, signed to run locally, no iCloud entitlement, and a bundle identifier of your own. Replace `com.example.BibleCarrel` with any identifier you like.

`PASSAGE_URL_SCHEME=bible` makes the app answer and copy `bible://` [passage links]({{ '/guide/passage-links/' | url }}), as the guide describes. Without it, a Debug build uses `bible-dev://`, which lets a development copy sit beside a released one.

For the Mac:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -workspace ReadingThroughScripture.xcworkspace \
  -scheme ReadingThroughScripture \
  -configuration Debug \
  -derivedDataPath Build/DerivedData \
  PRODUCT_BUNDLE_IDENTIFIER=com.example.BibleCarrel \
  PASSAGE_URL_SCHEME=bible \
  CLOUDKIT_CONTAINER= \
  CODE_SIGN_ENTITLEMENTS= \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  build
```

For the iPhone simulator, use the iPhone scheme and name a simulator. In place of `<iPhone>`, put any iPhone that `xcrun simctl list devices available` lists:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -workspace ReadingThroughScripture.xcworkspace \
  -scheme ReadingThroughScripture-iOS \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=<iPhone>' \
  -derivedDataPath Build/DerivedData \
  PRODUCT_BUNDLE_IDENTIFIER=com.example.BibleCarrel \
  PASSAGE_URL_SCHEME=bible \
  CLOUDKIT_CONTAINER= \
  CODE_SIGN_ENTITLEMENTS= \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY=- \
  DEVELOPMENT_TEAM= \
  build
```

## 4. Run it

On the Mac:

```sh
open Build/DerivedData/Build/Products/Debug/ReadingThroughScripture.app
```

In the iPhone simulator, boot the simulator you built for, then install and launch the app. Open the Simulator app to see it.

```sh
xcrun simctl boot "<iPhone>"
APP=Build/DerivedData/Build/Products/Debug-iphonesimulator
xcrun simctl install booted "$APP/ReadingThroughScripture.app"
xcrun simctl launch booted com.example.BibleCarrel
```

What you should see:

- On the Mac the app opens on Home, with every book listed and the book pane beside them, and Settings lists all eight translations. In the simulator it opens on the Read tab.
- Sync is off. Settings › General says "Sync is off in this build. Your notes stay on this Mac." Your highlights, notes and plans are kept in `~/Library/Application Support/ReadingThroughScripture/Local/`, with a backup each day beside them.
- On a Mac with Apple Intelligence, Settings › Assistant shows the on-device model as available.

Once it runs, start with [Your first chapter]({{ '/guide/first-chapter/' | url }}).

## If the build fails

- **"Could not open" when the app starts.** The app says "The Bible text is missing from the app." Run `bash Scripts/build-bible.sh`, then build the app again.
- **The script stops on a digest.** A message such as "eBible changed …; check it and re-pin the digest" means a source changed its file since it was pinned. The script stops rather than use a file it has not checked.
- **"Could not download …".** Check your connection. The script keeps each source once it has downloaded all of it, so running it again skips those and fetches the rest.
- **Warnings about Sirach and the stray `NAH` folder.** These are expected, and the database is still written.
- **`swift` not found, or the wrong toolchain.** The script uses `/Applications/Xcode.app` when `xcode-select` points at the Command Line Tools. Install Xcode there, or set `DEVELOPER_DIR` to your Xcode.

## What was checked

The builds that were run for this page used the commands above with a different bundle identifier, link scheme and derived data folder, and named the simulator by its id. Both built and ran, and showed what is listed under Run it. Not tried: these commands exactly as written, including `PASSAGE_URL_SCHEME=bible`, which was checked only with `xcodebuild -showBuildSettings`; downloading the sources from scratch, because they were already cached; the app's own build making the database when step 2 is skipped; a real iPhone; a free Apple ID; sync under your own team and iCloud container; an assistant reply; and API keys.

## What is where

- `Packages/ScriptureKit` holds all the shared Swift code: reading the Bible database, the notes store, the assistant's providers and the interface.
- `Apps/Mac` and `Apps/iOS` are the two app targets. `Apps/Shared` is the startup and sync code both use. `ReadingThroughScripture.xcworkspace` ties them to the package.
- `Scripts/` holds the download and build scripts.
- `site/` is this site.

The README.md at the top of the repository{% if site.repoUrl %} ([read it]({{ site.repoUrl }}#readme)){% endif %} has everything else a developer needs: the tests, the sync design, the launch arguments for testing and the full feature notes.
