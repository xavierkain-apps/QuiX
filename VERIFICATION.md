# Hardware checklist

What continuous integration cannot prove. To be ticked off on the Mac, with the real GoPro and a
card reader.

The automated part lives elsewhere: `swift test --package-path Core` covers HMMT decoding against
the two real `moov` atoms, grouping into takes, the import plan, idempotence and verified
copying; CI builds the app on macOS. Nothing below can be automated without hardware.

## Setup, once

- [ ] Open `QuiX.xcodeproj`, **Signing & Capabilities**, pick the development team. Xcode writes
      `DEVELOPMENT_TEAM` into the project — commit it.
- [ ] Build, launch, walk through the three welcome screens and choose the import folder.
- [ ] **Grant access to removable volumes** when macOS asks, on the first card. Without that
      permission the app watches the volume mount and finds no files in it — the symptom looks
      exactly like an empty card.
      CI checks that `NSRemovableVolumesUsageDescription` is in the `Info.plist`; what is left to
      see by hand is that macOS actually asks the question.
- [ ] **Grant local network access** when macOS asks, on the first camera over USB-C. Same
      misleading failure: the camera is seen, and nothing is found on it.
- [ ] **Answer the notification prompt.** A prompt dismissed without an answer counts as a
      refusal, and it never comes back — see [docs/NOTIFICATIONS.md](docs/NOTIFICATIONS.md).

## Everyday behaviour

- [ ] **1.** GoPro card in the reader: the window reacts on its own and the import starts.
- [ ] **2.** **The highlights are the right ones.** Take a clip you remember tagging, check it is
      in `Highlights/` — and that an untagged take is in `Clips/`. This is the only point that
      validates the product; all the rest is plumbing.
- [ ] **3.** **A long take with several chapters.** Film more than 4 GB in one go, tag a single
      chapter, check that **all** the chapters land together in `Highlights/`. That case produces
      an `mdat` over 4 GB, and therefore a 64-bit size header: it is also the only way to exercise
      for real the code path covered by `testSixtyFourBitSizeIsUnderstood`.
- [ ] **4.** **The card is untouched.** After a full import, compare the number of files in
      `DCIM/` before and after. Nothing should have moved.
- [ ] **5.** **Plugging the same card in again copies nothing.** The second import must report
      "already imported" across the whole card and create no empty dated folder.
- [ ] **6.** **Unplug the card mid-import.** The app must stop cleanly, and no `.quix-partiel`
      and no truncated `.MP4` may be left in the destination folder.
- [ ] **7.** **A card that is not a GoPro** — a USB stick, a camera card, an external disk. The
      app must do nothing at all, even if the volume happens to be called "GOPRO".
- [ ] **8.** "Ask before importing" ticked: plugging the card in shows the summary and waits for
      the click. Unticked: the import starts on its own.
- [ ] **9.** "Open highlights" switches to the Library tab on the right session.
- [ ] **10.** **Timing on a full card.** Time the scan of a well-filled card: it must be counted
      in seconds, not minutes. If it is slow, something is reading the videos instead of their
      headers, and the whole design collapses.

## The camera over USB-C

- [ ] **11.** Plug the camera in **and switch it on**. Switched off it exposes nothing, and
      nothing will happen — which is not a bug.
- [ ] **12.** With both a card in the reader and the camera plugged in, **the card wins**.
- [ ] **13.** Import from the camera, then check the erase button: it only appears once every
      clip on the camera has been found on the Mac at the right size.

## What is already known not to work

- [ ] **Highlights added afterwards in the Quik mobile app** are not in the MP4 and will never be
      seen. Check that the window says so clearly.

## Before distributing

`codesign --verify`, the universality of the binary, the hardened runtime and the signature of
Sparkle's nested executables are all checked by CI on every push — see [SIGNING.md](SIGNING.md)
and [docs/UPDATES.md](docs/UPDATES.md). What is left needs a real machine:

- [ ] Download the CI `QuiX` artifact onto a Mac that has never built the project, and launch it.
      It is Developer ID signed, notarized and stapled: **Gatekeeper must say nothing at all**,
      not even on first launch. If it warns, the ticket did not follow.
- [ ] Launch the app from a user account that has never seen it, to hit the removable-volumes
      prompt cold.
- [ ] **Check for updates** from the menu, against a published appcast, and let an update install
      itself end to end. An update path that has never been walked is not a feature.
