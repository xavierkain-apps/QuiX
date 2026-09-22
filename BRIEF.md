# QuiX — a GoPro importer for macOS

> The original brief, kept as written. Where reality turned out differently, a note says so and
> points at the document that measured it.

## The problem

GoPro pulled Quik Desktop from the Mac App Store in late 2024 and no longer maintains it.
Xavier only ever used it to **import** his clips, never to edit. The alternatives everyone
recommends (iMovie, UniConverter, HitPaw) are editors: they do not answer the need, which is a
reliable, sorted transfer.

## What the app must do

One thing, well:

1. Notice that the GoPro (or its SD card) has just been plugged in.
2. Copy the clips into Xavier's usual folder, in a **new dated folder**.
3. Inside it, two subfolders: `Highlights/` and `Clips/`.
4. Let him see the highlighted clips straight away.

No editing, no trimming, no cloud, no social export. The day we add that, we have rebuilt Quik
and lost the reason the product exists.

## The technical fact that makes it possible

HiLight tags are written **into the MP4 file itself**, in the `moov` → `udta` → `HMMT` atom: a
big-endian `uint32` giving the number of moments, then one `uint32` per moment (a timestamp in
milliseconds from the start of the clip).

The practical consequences are all good ones:

- Readable in plain Swift, with no dependency and no AVFoundation.
- Only the header is read, never the video: scanning a whole card takes seconds, even through a
  card reader.
- Sorting is decided **before** the copy, so each file is written straight to the right place
  instead of being copied and then moved.

Two reservations to clear early:

- Recent models (Hero 11/12/13) might depart from the classic HMMT layout.
  **To be checked against a real clip from Xavier's camera before writing the app.**
  → Measured on a HERO12 Black, with two traps found: see [docs/HILIGHT.md](docs/HILIGHT.md).
- Highlights added *afterwards in the Quik mobile app* stay inside that app and are not written
  back into the MP4. Only the ones pressed while filming (button, voice command) can be
  recovered. That is not a bug to fix, it is a limitation to state in the interface.

## What to know about GoPro files

- Naming, `GX010123.MP4`: `GX` = encoding, `01` = chapter number, `0123` = take number. A long
  take is cut into chapters that share the take number.
  → **If one chapter carries a highlight, the whole take goes to `Highlights/`.** Splitting the
  chapters of one take would make the folder useless.
- `.LRV` (low-resolution proxy) and `.THM` (thumbnail): ignored by default.
- Files live in `DCIM/100GOPRO/`, `101GOPRO/`, and so on.

## Connecting the camera

Over USB the GoPro presents itself as MTP — painful to drive. With the card in a reader it is an
ordinary volume mounted under `/Volumes/`, and the transfer is markedly faster. **Target the
mounted volume first**; MTP is a possible extension, not the nominal path.

> This turned out to be wrong, and it is the most important correction in the project. Over
> USB-C the HERO12 exposes **no mass storage at all**. It brings up a network interface and
> answers HTTP, and it honours `Range` requests — which is what keeps sorting free over the
> cable. See [docs/USB.md](docs/USB.md).

Detection: `NSWorkspace.shared.notificationCenter`, `didMountNotification`. A card is confirmed
to be a GoPro card by the presence of `DCIM/1xxGOPRO/` — never by the volume name, which the
user may have changed.

## Architecture

A **SwiftUI app for macOS**. Xavier already has an Apple Developer account, so signing and
notarization are possible — the app can be installed for good, and distributed if the product
catches on.

Separate from the start:

- **The engine** (HMMT parsing, import planning, verified copying) in plain Swift, with no UI,
  testable from the command line. That is where the value is, and where bugs are expensive.
- **The interface** on top: a window, a list, a progress bar.

Non-negotiable rules for the engine:

- **Never delete anything on the card.** Erasing stays a manual action by the user, in the
  camera. A failed import can be recovered from; an erased card cannot.
  → Softened deliberately later: there is now a button that erases the camera, held by three
  independent locks. Nothing automatic ever triggers it.
- **Idempotent import**: an index (name + size + date) of the files already imported, so that
  plugging the card in again only copies what is new.
- **Verified copy** before a file counts as imported.

## Order of construction

1. **Validate the HiLight parser against a real tagged clip from Xavier's GoPro.**
   Blocking: everything else depends on it. Build nothing before that.
2. The import engine in Swift, driven from the command line, tested on a copy of a card.
3. The SwiftUI app: window, automatic volume detection, progress.
4. Signing and notarization.

## Open questions

All of them have since been answered by the app as it stands; they are kept because they show
what was undecided at the start.

- The exact GoPro model. → HERO12 Black.
- The path of the "usual folder". → Chosen by the user on first launch; nothing is guessed.
- The format of the dated folder name. → `2026-09-07`.
- Automatic import on connection, or a prompt to confirm? → Automatic by default, with a
  setting; the guard that matters is elsewhere, since a card with no `DCIM/###GOPRO` folder is
  never touched either way.
- Showing the highlights: is the Finder enough, or is a gallery needed inside the app, with a
  thumbnail extracted at each tagged moment? → A library tab, with the thumbnail taken at the
  first tagged moment.

## Where the work happens

Two machines, and the instructions differ:

- **On Xavier's Linux server**, where the project was written: code and decisions are written,
  nothing is compiled. The machine is saturated (a few hundred MB of free RAM, swap at the
  ceiling) and Swift is not even installed there. Continuous integration compiles and tests —
  see [.github/workflows/ci.yml](.github/workflows/ci.yml).
- **On the Mac**: compile, run, try against a real card. The exact commands are in the
  [README](README.md), and what has to be checked by hand is in
  [VERIFICATION.md](VERIFICATION.md).
