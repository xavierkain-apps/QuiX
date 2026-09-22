# QuiX

A macOS app that imports GoPro clips and automatically separates the **highlighted** takes from
the rest. Replaces the one function of Quik Desktop that Xavier actually used, after GoPro
dropped it in late 2024.

## Read first

**[BRIEF.md](BRIEF.md)** — the need, the HiLight tag format, the traps in GoPro files, the
architecture and the order of construction. Read it whole before writing code.

**[docs/HILIGHT.md](docs/HILIGHT.md)** — the HiLight format as it is really written by Xavier's
HERO12, measured on two real clips. Two traps are recorded there, one of which breaks the app
silently.

**[docs/USB.md](docs/USB.md)** — what the camera really is when you plug it in: not a disk, but
an HTTP server. Read it before touching the USB path.

**[docs/FEEDBACK.md](docs/FEEDBACK.md)** — what the app attaches to a bug report, and why each of
the four lines is necessary. Read it before adding anything to it.

**[docs/UPDATES.md](docs/UPDATES.md)** — the two signatures that protect the update path, where
the keys live, and how to publish a version.

## Structure

- `Core/` — the pure Swift engine (HMMT parsing + import), testable on Linux
- `App/` — the macOS SwiftUI app, built on the Mac only: a menu-bar popover and one window with
  three tabs. The design tokens (colours, type scale, metrics) live in `App/Theme.swift` and
  nowhere else.
- `Support/` — the `Info.plist`, the icon sources, the signing script
- `docs/` — decisions and notes

## Language

**Everything in this repository is written in English** — documentation, code comments, commit
messages. The repository is public.

The app's interface is bilingual: English is the source language, French is a translation, and
both live in `App/Localizable.xcstrings`. Two strings are deliberately *not* localised —
`Highlights` and `Clips` — because they are folder names on disk. See
[docs/INTERFACE.md](docs/INTERFACE.md).

**Never add an attribution line to a commit** — no `Co-Authored-By`, no mention of the tool that
wrote it. Xavier asked for this explicitly, for all of his projects.

## The four things not to forget

1. **Sorting is free.** HiLight tags live in `moov/udta/HMMT`, and in GoPro files `moov` sits at
   the **end**: three seeks and about 34 KB are enough to know where a clip goes. Do not copy
   and then sort. And never infer the number of highlights from the size of HMMT — see
   [docs/HILIGHT.md](docs/HILIGHT.md).
2. **One take, one folder.** The chapters of a long take share the GoPro file number. If one is
   tagged, they all follow.
3. **Erasing never starts on its own.** There is a button, in the import report, that erases the
   clips from the camera. Three locks hold it: the button only appears if **every** file on the
   camera has been found on the Mac at the right size, an alert asks for confirmation, and
   `CameraCleanup.erase` refuses on its own side any plan that is not verified. Nothing in
   detection or in the end of an import triggers it.
4. **The camera over USB is not a disk.** It exposes no mass storage at all: it brings up a
   network interface and answers HTTP. Sorting stays free there because it honours `Range` —
   measured, not assumed. See [docs/USB.md](docs/USB.md).

## Where the work happens

This repository is worked on from two machines, and the instructions differ:

- **On Xavier's Linux server**, where the project was written: code and decisions are written,
  nothing is compiled. The machine is saturated (~200 MB of free RAM, swap at the ceiling) and
  Swift is not even installed there. Continuous integration compiles and tests — see
  [.github/workflows/ci.yml](.github/workflows/ci.yml).
- **On the Mac**: compile, run, try against a real card. The exact commands are in the
  [README](README.md), under "Building on the Mac", and what has to be checked by hand is in
  [VERIFICATION.md](VERIFICATION.md).
