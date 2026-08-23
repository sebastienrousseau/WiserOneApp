<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->

# User Guide

## Contents

- [What it is](#what-it-is)
- [Running it](#running-it)
- [Using the app](#using-the-app)
- [The corpus](#the-corpus)
- [Where things are written](#where-things-are-written)
- [Troubleshooting](#troubleshooting)

## What it is

A macOS menu-bar app showing one quote a day — the same quote
[wiserone.com](https://wiserone.com) is showing, because both select
from the same pool using the same UTC day number.

## Running it

```sh
make init
swift build
make test
swift run WiserOne
```

The app runs as an accessory: it has a menu-bar icon and no Dock entry
or main window.

| Platform | Build | Test | Run |
|---|---|---|---|
| macOS 13+ | ✅ | ✅ | ✅ |
| Linux | ✅ | ✅ | ❌ |
| WSL2 | ✅ | ✅ | ❌ |

## Using the app

| Action | Result |
|---|---|
| Click the menu-bar icon | Opens the popover with today's quote |
| Click again | Closes it |
| Right-click, or Control-click | Opens the context menu (Quit) |
| Click the logo inside the popover | Opens wiserone.com |

VoiceOver announces the quote and its attribution as one utterance, and
re-announces when the quote changes.

## The corpus

The pool ships inside the app bundle as `quotes.json`:

```json
{
  "quotes": [
    {
      "id": 0,
      "pillar": "elimination",
      "quote_text": "Say no to a hundred good things.",
      "author": "The Wiser One",
      "date_added": "2024-02-17T06:06:06Z",
      "image_url": "https://cloudcdn.pro/stocks/images/example.webp"
    }
  ]
}
```

`id` is the pool position and drives selection. `date_added` records
when a line was written and selects nothing.

Because the corpus is bundled, new quotes reach the app only through a
new build. `make hygiene` checks the bundled pool against the website
and fails if they have diverged.

## Where things are written

| Path | Contents |
|---|---|
| `~/Documents/appLog.txt` | Error log, appended, each entry capped at 8 KB |

Nothing else is written, and the app makes no network requests.

## Troubleshooting

| Symptom | Cause |
|---|---|
| The popover shows "Quote not found" | The corpus did not load — the bundle probe failed, or `quotes.json` is missing |
| The app shows a different quote from the website | The corpus has drifted, or lost its ids. Run `make hygiene` |
| The menu-bar icon is a `⏣` glyph | The logo asset could not be loaded; the app falls back to a text glyph rather than rendering a blank square |
| No menu-bar icon at all | The status bar was not ready; setup retries a bounded number of times, then logs the failure |
| `Corpus has drifted from wiserone.com` in CI | The bundled pool differs from the published one — mirror the website's copy |
