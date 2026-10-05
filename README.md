# Crawler's Companion for KOReader

*Who is this?* Long-press a name in a **Dungeon Crawler Carl** book, tap **Crawler's
Companion**, and get the entry: who or what it is, and what has happened so far — sealed past
the chapter the book is open at.

It is the [Crawler's Companion](https://dcc.dev.innovativstud.io) site, offline, with one
difference: the site has to be told where you are, and your e-reader already knows.

## Install

1. Download `crawlerscompanion.koplugin.zip` from the latest release and unzip it.
2. Copy the `crawlerscompanion.koplugin` folder into KOReader's `plugins` directory:

   | device | path |
   |---|---|
   | Kobo | `.adds/koreader/plugins/` |
   | Kindle | `koreader/plugins/` |
   | PocketBook | `applications/koreader/plugins/` |
   | Android | `koreader/plugins/` on internal storage |
   | macOS / Linux | `~/Library/Application Support/koreader/plugins/` or `~/.config/koreader/plugins/` |

3. Restart KOReader.

## Use

Open a Dungeon Crawler Carl book. Long-press a word — *Donut*, *Mordecai*, *Larracos* — and
tap **Crawler's Companion** in the dictionary popup that opens. Select two words for a longer
name (*Princess Donut*, *Over City*); the button is in that selection menu too.

You get the **recap**: who or what this is in a line, then a short paragraph for each book you
have finished, then this book so far — one line per thing that has happened, up to the chapter
before the one you are on — and a line saying how much is still sealed and when the next part
opens. Nothing from the chapter you are reading is told; it only says how many entries it holds.

One button, **The whole crawl for Carl so far**, opens the full entry: the System's own
description where there is one, every reached entry in the character's own voice with its
chapter, and **Connections** — everyone and everything this entry is tied to that you have met,
with the stamp of when. Tap a connection and you are reading that entry's recap.

A name the book has not yet introduced and a word that is not a name get the same answer,
`*** No record ***`. The plugin never confirms a name exists.

Under **Tools → Crawler's Companion** you can also type a name to look up, see the position
the plugin has read off the book, and set one by hand.

## How it knows where you are

- **Which book** comes from the document's title.
- **Which chapter** comes from the table-of-contents entry you are inside. An interlude
  between chapters counts as the next chapter; the epilogue and anything after it count as
  the book finished.
- **Which edition**: chapter numbers follow the Ace/Penguin edition, the one the site uses.
  Book 5 has 77 chapters in the original self-published edition and 75 there; the plugin
  counts the chapters in your copy and renumbers if it has to.

The gate sits at the chapter you are on, not the one before, so a fact from a few pages ahead
in the same chapter can already answer. That is the trade for "who is this?" working on the
name you have just met.

If your copy has an unusual table of contents, use **Set position…** in the menu: `7:12`, or
`7:end` for a finished book. It is remembered per book.

## What it never does

- Go online. The data ships in the plugin; nothing on the device talks to anything.
- Show a sealed fact. Everything compares one number: your chapter against the chapter a
  fact is tagged with, the same arithmetic the site uses.

The data is in plain JSON under `crawlerscompanion.koplugin/data/`, so the whole crawl is on
your device. Nothing shows it to you early; a text editor would.

## Developing

```sh
# unit tests, with KOReader's own LuaJIT (or any Lua 5.1+)
luajit tests/run.lua

# the real thing, on a desktop build: open a book, look up a name, and log which buttons
# the dictionary popup ended up with — the one check the stubs cannot make
CRAWLERS_COMPANION_SELFTEST=Donut KO_HOME=~/Library/Application\ Support/koreader \
  ./luajit reader.lua path/to/book.epub   # from the KOReader directory

# refresh the data from the site's repo (expects ../dcc-companion)
scripts/sync-data.sh

# a release zip
scripts/package.sh
```

The data is exported, never edited here: `npm run export:koreader` in the
[dcc-companion](https://github.com/danspy/dcc-companion) repo writes it, and this repo
commits the result.

`cc_position.lua` and `cc_gate.lua` are plain Lua with no KOReader in them, which is why the
tests run on a laptop, against the real tables of contents of the real books
(`tests/fixtures/`). `main.lua` is only the wiring.

## License

MIT for the code. The data is a reader's companion to Matt Dinniman's books, written for the
site above. `cc_json.lua` is [rxi/json.lua](https://github.com/rxi/json.lua), MIT.
