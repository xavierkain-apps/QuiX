# QuiX

Imports GoPro clips onto a Mac and separates the **highlighted** takes from the rest.
Replaces the one function of Quik Desktop that was still useful, after GoPro dropped it in late 2024.

Plug the camera in over USB-C, or the card into a reader, and you get:

```
~/<your folder>/2026-09-07/
├── Highlights/     takes carrying at least one HiLight tag
└── Clips/          everything else
```

No editing, no trimming, no cloud. The day we add that, we have rebuilt Quik.

## How it works

The HiLight tags you press while filming are written into the MP4 itself, in the
`moov/udta/HMMT` atom. QuiX reads that atom — **three seeks and about 34 KB** per clip, whatever
its size — and knows where a file belongs before copying a single byte of it. Nothing is ever
sorted after the fact.

This holds for **both** sources, and it is what took the most care:

- **the card in a reader** — an ordinary volume, three seeks;
- **the camera over USB-C** — which exposes no disk at all. It brings up a network interface and
  answers HTTP on `172.2X.1YZ.51:8080`. The three seeks become three `Range` requests, measured on
  a HERO12: `206 Partial Content`, `Accept-Ranges: bytes`. So sorting stays free over the cable
  too — a clip is only pulled down to be imported, never to find out where it goes.

The format in detail, the measurements taken on a real HERO12 and the two traps they exposed are
in **[docs/HILIGHT.md](docs/HILIGHT.md)**.

## What the product guarantees

- **Nothing is ever erased on its own.** The app can empty the camera, but only from a button,
  after confirmation, and only once it has found **every** clip the camera holds on the Mac, at
  the right size. One missing file and the button is not offered.
- **A take is never split in two.** The chapters of a long take share a file number; if a single
  one carries a tag, they all follow into `Highlights/`.
- **Every copy is verified** — a checksum computed while writing, then read back from the written
  file — before it counts as imported.
- **Plugging the card in again copies only what is new**, through a `name + size + date` index
  kept at the root of the library.
- **An interrupted transfer resumes where it stopped**, without losing what already went through
  and without weakening the verification — see [docs/USB.md](docs/USB.md).

## Layout

| | |
|---|---|
| `Core/` | The engine, plain Swift on Foundation alone. Builds and tests on Linux. |
| `App/` | The SwiftUI window. Builds on macOS only. |
| `docs/` | The HiLight format as measured on the camera, and the decisions. |

The split is not cosmetic: all the value lives in `Core`, and that is what lets continuous
integration prove it without an Apple machine.

## The engine on the command line

```sh
swift build --package-path Core --product quix

quix hilight clip.MP4                      # the tagged moments of one clip
quix scan /Volumes/GOPRO                   # a card's takes, and which ones are tagged
quix camera                                # the GoPro over USB: its takes, copying nothing
quix import /Volumes/GOPRO ~/Movies/GoPro --dry-run   # the plan, without writing a byte
quix import /Volumes/GOPRO ~/Movies/GoPro             # for real
```

## Building on the Mac

Requirements: **Xcode 16 or later** (the project uses `objectVersion 77`) and **macOS 15 or later**
(deployment target).

### The short way: take the notarized bundle

Continuous integration produces a universal bundle on every push — Developer ID signed, notarized
and stapled. Nothing to compile:

```sh
gh run download --repo xavierkain-apps/QuiX --name QuiX
ditto -x -k QuiX.zip /Applications/
open /Applications/QuiX.app
```

`ditto` rather than `unzip`: it preserves the bundle's extended attributes, and therefore its
signature. Gatekeeper should say nothing at all — not even on first launch.

### Building it yourself

```sh
# The engine: 109 tests, no Apple machine required
swift test --package-path Core

# The command-line tool, to watch the parser at work
swift build --package-path Core --product quix
"$(swift build --package-path Core --product quix --show-bin-path)/quix" \
  hilight Core/Tests/QuiXCoreTests/Fixtures/hero12-un-highlight.mp4
# -> hero12-un-highlight.mp4 : 1 moment(s) — 3.436 s

# The app
xcodebuild build -project QuiX.xcodeproj -scheme QuiX -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=
cp -R build/Build/Products/Release/QuiX.app /Applications/
```

Those last three settings sign ad hoc. That is enough to try the app, but **not to live with it**:
an ad-hoc signature changes on every build, and security software — Bitdefender, Little Snitch —
has nothing stable to remember. They ask for permission again after every rebuild, explaining that
"the process contains different signature information".

If you have a Developer ID certificate, sign with this instead:

```sh
xcodebuild build -project QuiX.xcodeproj -scheme QuiX -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual \
  "CODE_SIGN_IDENTITY=Developer ID Application: <your name> (<team>)" \
  DEVELOPMENT_TEAM=<team> OTHER_CODE_SIGN_FLAGS=--timestamp \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO

# Sparkle ships nested executables that Xcode does not re-sign. Apple refuses the whole bundle
# over them — see docs/UPDATES.md.
Support/sign-sparkle.sh build/Build/Products/Release/QuiX.app "<your signing identity>"
```

The identity then stays stable from one build to the next, and a permission granted once holds.
`CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` strips the debugging entitlement Apple refuses to
notarize — see [SIGNING.md](SIGNING.md).

`security find-identity -v -p codesigning` lists the available identities.

**Worth knowing before you try:** the two full GoPro clips are not in the repository, only the two
34 KB `moov` atoms the tests rely on. An end-to-end run needs a real card, or a hand-made
`DCIM/100GOPRO/` folder with `.MP4` files in it.

## Using the app

QuiX lives in the **menu bar**. One click opens a popover that says where the import stands, and
nothing more: no card, reading, importing, done. A window opens from there, with three tabs —
**Transfer** (⌘1), the detailed view of an import in progress; **Library** (⌘2), to find tagged
takes again; **Settings** (⌘3, or ⌘,).

On first launch, three screens introduce the app, ask where the clips should go, and announce the
permissions macOS will request. After that, plugging in is enough — the camera over USB-C or the
card in a reader. A checkbox asks for confirmation before each import.

If both are present, **the card wins**: it is faster, and it is the one you deliberately put in
the reader.

The Transfer window opens by itself when an import starts. That is a deliberate departure from the
design handoff, which had it open from the popover: a popover cannot be shown programmatically, so
an import triggered by plugging in would have had no surface to show itself on.

### The two permissions, and their symptoms

macOS asks for one per source, and **both fail the same misleading way**: the app sees the hardware
and finds nothing on it, exactly as it would in front of an empty card.

| Source | Permission | Where to grant it |
|---|---|---|
| Card in a reader | **Removable Volumes** | Privacy & Security → Files and Folders |
| Camera over USB-C | **Local Network** | Privacy & Security → Local Network |

The local network one is surprising, and rightly so: plugged in over USB-C, the camera *is* a
network device as far as macOS is concerned. When it is missing, the app says so explicitly and
opens the right panel — it does not simply sit there empty.

### Opening QuiX when you plug in

A checkbox in Settings. When it is ticked, plugging the GoPro in brings QuiX **to the front** and
the import starts — subject to "Ask before importing", which keeps you in control if you only
plugged in to charge.

QuiX is not running in the meantime: there is no resident process. `launchd` wakes it when the USB
device appears, and nothing exists until the camera is plugged in. macOS will report an added
"background item", listed in System Settings → General → Login Items & Extensions.

The match only recognises the **HERO12 Black**: the details, and how to read another model's
identifier, are in [docs/USB.md](docs/USB.md).

### The library

Three columns: sessions on the left, the grid of takes in the middle, the inspector on the right.
The inspector shows a take's **moments** on a track scaled to its duration — it is the only view
that uses the exact tag timestamps, reduced everywhere else to "tagged or not".

Thumbnails are extracted from the clip itself, **at the first tagged moment** when there is one:
it is the frame that says why the take is in `Highlights/`.

### Erasing the camera after an import

The import report shows a comparison: how many clips the camera holds, how many were found on this
Mac. The erase button appears only when the two numbers match — and the count is rebuilt from
**disk**, not from the index, so that a folder emptied by hand holds the erase back.

It is the only irreversible operation in the app, and the only one that asks for confirmation.

### A card is recognised, never guessed

A volume is only handled if it carries a `DCIM/###GOPRO` folder, never because of its name: another
device's card is left alone, even if it happens to be called "GOPRO".

## Updates

QuiX is distributed outside the App Store and updates itself through Sparkle. Two independent
signatures protect that path, and they do not say the same thing: Apple's Developer ID lets
Gatekeeper open the app, while Sparkle's EdDSA signature tells the **already installed** app that
the archive it just downloaded really came from us. See [docs/UPDATES.md](docs/UPDATES.md).

## Signing

The macOS job produces a universal bundle on every push, downloadable as an artifact. It is
Developer ID signed and notarized as soon as the five `xavierkain-apps` organisation secrets exist
— see [SIGNING.md](SIGNING.md) — and ad-hoc signed otherwise.

## Tests

```sh
swift test --package-path Core
```

The tests rely on `Core/Tests/QuiXCoreTests/Fixtures/`, which holds the real `moov` atoms of two
HERO12 clips — one tagged, one without. The second matters most: see its
[README](Core/Tests/QuiXCoreTests/Fixtures/README.md).

What the tests cannot prove is in [VERIFICATION.md](VERIFICATION.md), to be checked on the Mac with
a real card.

## One limitation worth knowing

Highlights added **afterwards** in the Quik mobile app stay inside that app: GoPro does not write
them back into the MP4. Only the ones pressed while filming — button or voice command — can be
recovered. That is not a QuiX bug, and the app says so in its own window.
