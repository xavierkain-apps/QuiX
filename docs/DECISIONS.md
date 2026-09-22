# Decisions

Answers the "Open questions" of [BRIEF.md](../BRIEF.md). One decision per section: what was
settled, and why.

Some of these have since been revisited, and where that happened a note says so. The point of
keeping them is to show what was known at the time.

## 2026-09-07 — Validating the HiLight parser

Xavier drops a **tagged** GoPro clip at the root of the project (`sample.MP4`, not committed). The
real header is read before the parser is written, and a **fixture of a few kilobytes** is extracted
from it (the `moov` atom alone, not the video) which does go into the tests.

Why: the brief's reservation about the Hero 11/12/13 can only be cleared against a real file.
Coding defensively "just in case" would mean writing two parsers, one of which is never run.

**Blocking: none of the engine is written before this.**

## 2026-09-07 — The import folder

Chosen by the user **on first launch**, remembered in the preferences. No hard-coded path.

Inside it, one folder per import, named as an **ISO date** (`2026-09-07/`), then `Highlights/` and
`Clips/`. A format that sorts chronologically in the Finder.

An assumption to confirm: no outing label in the folder name in v1. Two imports on the same day
land in the same dated folder — idempotence means the second only adds what is new, which is the
intended behaviour.

Why choose on first launch rather than pick a default: Xavier's "usual folder" is not in the brief,
and the macOS sandbox needs explicit permission on the destination folder anyway.

## 2026-09-07 — Triggering the import

**Automatic on connection**, with an "ask before importing" checkbox in the preferences.

Why automatic by default: that is the gesture Quik Desktop offered, and the brief asks for an app
that does one thing without being driven.

Why the setting all the same: plugging in another device's card must not trigger a surprise copy.
The main guard stays the `DCIM/1xxGOPRO/` detection — a non-GoPro card is never touched, setting or
no setting.

## 2026-09-07 — Showing the highlights

**The Finder.** Once the import finishes, the app reveals `Highlights/`.

No gallery, no thumbnail extraction, and therefore no AVFoundation in v1. A gallery with one frame
per tag is the first step towards a viewer, which is to say towards Quik — which the brief
explicitly forbids. To be reopened only if use shows that the Finder is not enough.

> Reopened, and reversed. There is a Library tab, with a thumbnail taken at the first tagged
> moment. The line held: it shows, it does not play and it does not edit.

## 2026-09-07 — The repository layout

`Core/` (SwiftPM, plain Foundation) + `App/` (SwiftUI, `.xcodeproj`), rather than the `src/`
announced in CLAUDE.md.

Why: it is DisplayX's layout, and it applies the brief's architecture rule literally — the engine
is tested on Linux in continuous integration, the app builds on macOS only. A single `src/` would
let AppKit leak into the engine with nothing to signal it.

## 2026-09-07 — The reservation about recent models: cleared

The camera is a **HERO12 Black** (firmware `H23.01.02.32.00`) and it writes classic `HMMT`. The
parser in plain Swift, without AVFoundation, is confirmed possible. The full measurement is in
[HILIGHT.md](HILIGHT.md).

Two corrections to the brief along the way: `moov` is at the **end** of GoPro files (not the
beginning), and `HMMT` is **332 bytes whatever the number of highlights** — 80 preallocated slots.
Point 1 of CLAUDE.md was corrected accordingly.

The source kept is `udta/HMMT` alone. The `GPMF/HLMT` stream confirms it to the millisecond but
would need a full KLV parser for nothing.

## 2026-09-07 — Choices made while building the engine

**The index lives in the library**, not in the application's data
(`<library>/.quix-index.json`). Deleting the imported folder must be enough to be able to import
everything again; an index hidden elsewhere would make the app believe the clips are still there
after they have gone. And an unreadable index never blocks an import — at worst something is
copied twice.

**Idempotence is checked against disk**, not only against the index: a file is skipped only if the
index knows it *and* the copy is really present, at the right size.

**Copy verification is a CRC-32**, computed on the source while writing and recomputed by reading
the written file back. The point is to catch a damaged copy, not to resist someone trying to fool
the verification: a cryptographic digest would cost more and bring nothing here. Foundation alone
does not expose CryptoKit on Linux in any case.

**Writing goes to a `.quix-partiel`, renamed at the end.** An interrupted copy must leave an
obvious trace, not an `.MP4` of plausible size that the Finder would show as a valid clip.

**The modification date is carried over to the copy**, otherwise every imported clip would bear the
date of the import and sorting by date in the Finder would say nothing any more.

**A name collision disambiguates instead of overwriting.** Two DCIM folders can hold the same file
name after the camera's counter wraps; the second becomes `GX010001-101GOPRO.MP4`.

**The GPMF/HLMT stream is not read.** It confirms HMMT to the millisecond but would need a full KLV
parser for information already obtained in thirty lines. Noted as a fallback in
[HILIGHT.md](HILIGHT.md) should a model ever stop writing HMMT.

## 2026-09-22 — Erasing the camera, deliberately reversed

The brief said "never delete anything on the card", and that rule held for as long as the card in a
reader was the only source. Over USB-C, with the camera answering HTTP, emptying it from the app
became the natural end of an import — and doing it by hand, in the camera's own menus, is exactly
the friction QuiX exists to remove.

It is reversed under three independent locks, and the reasoning behind each is in CLAUDE.md, point
3. The invariant that actually matters was never "never delete": it was **never delete something
that has not been verified as present elsewhere**.

## 2026-09-22 — A new bundle identifier, before any public release

`com.xavierkain.QuiX` became `fr.xavier-kain.quix`. The reason is documented in
[NOTIFICATIONS.md](NOTIFICATIONS.md): the old identifier carries a fault in the notification
system's store on the development Mac, and nothing in the bundle can fix it.

Doing it now costs nothing — there is no installed base. Doing it after a public release would have
cost every user their permissions and their settings. The old preferences domain is read once at
first launch so that an import folder already chosen is not asked for again.
