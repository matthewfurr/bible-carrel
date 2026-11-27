# Contributing to Bible Carrel

Ideas, corrections and code are welcome. Bible Carrel is a small project with one maintainer, so a reply can take a while, and not every idea will be built.

The site's [Contribute page](https://matthewfurr.github.io/bible-carrel/contribute/) says the same in more words.

## Suggest an idea

Open an issue and say what you were reading or doing, and what you wished the app did. You do not need a design or a plan. `docs/BACKLOG.md` lists what has been set aside and why.

## Report a fault

Open an issue and include:

- **Where:** Mac or iPhone, and the version of macOS or iOS.
- **Which build:** The commit you built from. `git rev-parse --short HEAD` prints it.
- **What happened:** The steps you took, what you expected and what you saw.

## Change the code

1. Build the app by the steps in `README.md` or on the site's [Build page](https://matthewfurr.github.io/bible-carrel/build/).
2. For anything larger than a small fix, open an issue first, so the idea can be talked through before you write it.
3. Run the tests: `swift test --package-path Packages/ScriptureKit`.
4. Send a pull request against `main`. Say what it changes and how you checked it.

`PRODUCT.md` and `DESIGN.md` describe who the app is for and how its screens are made. Read them before you change a screen.

Your contribution is licensed under the GNU General Public License, version 3, like the rest of the code. Please do not put copyrighted Bible text in an issue, a picture or a pull request.
