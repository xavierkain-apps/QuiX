# The interface

Follows the `design_handoff_quix` handoff, blocks `#2a` (popover), `#2b` (Transfer), `#2c`
(Library) and `#4c` (icon). This file does not repeat the values — they live in
[`App/Theme.swift`](../App/Theme.swift), in a single copy — but records what the implementation
forced us to decide.

## One place for the tokens

The mockups are CSS, with colours in `oklch` that SwiftUI does not read. `Theme.swift` carries the
sRGB equivalents **named by their role** — `Ink.blue`, `Ink.raised`, `Ink.tertiary` — never by
their hue. Changing the accent one day happens there, not across fifteen views.

The handoff's type scale is in half points (13.5 · 12.5 · 11.5) and matches no native style: we
take it as it is rather than approximating with `.callout` and drifting screen by screen.

## The theme is dark by choice

`NSApp.appearance = .darkAqua` at startup. Without it, title bars and system controls stay light
in the middle of ink-coloured windows — a flaw that shows immediately in a screenshot, and never
in the code.

## One window, three tabs

The handoff drew Transfer and Library as two windows. They are two tabs of one: "Open highlights"
no longer makes a second window appear over the first, it switches tab — you stay where you are.

The current tab lives in `AppRouter`, outside the views, because three places change it: the
popover, the menu bar, and the Transfer button. It travels down to deep views through the
environment rather than hand to hand.

Transfer loses the 860 pt width the handoff gave it: it now shares the window and stretches. Its
table fills the available height, and the footer stays anchored at the bottom.

The tab bar is centred, and the "import in progress" indicator is laid **over** it rather than
placed beside it: in an `HStack`, the indicator appearing shifted the tabs out from under the
cursor.

## Settings are a tab

They first left the foot of the popover — you open that to find out where the import stands, not
to tick boxes — for a `Settings` window, and therefore ⌘, as everywhere on macOS. That was not the
first place anyone looks: in an app that already has tabs, you look in the tabs. So they are a
third one, and ⌘, goes there instead of opening a separate window.

Settings also show the **state of the permissions**, which no other screen does. The two QuiX asks
for fail the same misleading way — the app sees the hardware and finds nothing. With no API to
query the "Local Network" permission, the state is inferred from what the camera answers:
"missing" is only asserted when a camera is plugged in and refuses, "asked when needed" otherwise.

The panel follows the window's width up to 860 pt, and its scroll bar is the thin one that
withdraws when unused. macOS set to "Automatic" brings out the old, permanent bar as soon as a
mouse is connected; SwiftUI does not expose that setting, so we reach for the `NSScrollView` that
carries the view.

## The menus

SwiftUI adds menus by default that correspond to nothing here: the app creates no document, prints
nothing, has no toolbar. They are removed rather than left greyed out, which makes an app look
unfinished. What remains is the tabs, on ⌘1, ⌘2 and ⌘3, and Help — which was empty, though it is
exactly where you look for "how do I tell them this is broken".

## Every state has a place in the window

The Transfer tab only showed the three states that display a table — ready, running, finished —
and otherwise fell back on "No transfer in progress". The first import from a real card ran
straight into it: the app was waiting to be given a folder, said so only in the popover, and the
window showed that nothing was happening. You hunt for a fault while the app waits for an answer.

Every state is there now, each with its reason and something to act on: reading the card with its
progress bar, the missing folder with the button that chooses it, the network permission, the
failure. And the window opens for **any** state that is waiting for something, not only for those
with a table to show.

The rule that comes out of it: a state the popover can state and the window keeps quiet about is
an invisible state. A popover is consulted; a window is looked at.

## What the popover cannot do

A `MenuBarExtra` **cannot** be opened programmatically. That is harmless as long as the user
clicks, but the app also wakes on its own when the camera is plugged in: in that case the popover
stays shut and nothing is shown.

So the window opens by itself, on the Transfer tab, when the state turns to `ready` or `importing`.
The trigger sits on the menu-bar item's view, the only one alive at all times — putting it in the
window would only have opened it when it was open already.

The same view opens the window **at launch**. That seems obvious; it was not. An app that lives in
the menu bar opens no window at startup: you clicked its Dock icon, it bounced, and you had to go
find it in the menu at the top. It cannot live in the `AppDelegate` either —
`applicationDidFinishLaunching` runs before any view exists, and its notification would have had
nobody listening.

## One queue, two displays

The popover and the Transfer table show the same files. `ImportModel.queue` computes them from the
plan and the progress; both views subscribe to it. Drawing the same thing twice would have ended
in two truths.

The per-file state is derived from `ImportProgress.fileIndex` — before it, verified; at it, in
progress; after it, pending — without changing anything in `Core`. Moving from one file to the next
therefore matters as much as the percentage in the progress reporting: without it, the queue would
show the first file as "in progress" throughout an import of small clips.

The plan is published as soon as it exists, not only when copying starts: the table shows the queue
"pending" before Import has been clicked.

## Thumbnails

Extracted on the fly by `AVAssetImageGenerator`, **at the first tagged moment** when there is one —
the frame that says why the take is in `Highlights/`. Failing that, one second in rather than at
zero: the first frame of a GoPro clip is often black.

The frame imposes 16:9 and the image is cropped into it, through a `GeometryReader`. Without it the
image dictates its own size, and a take filmed vertically stretches the thumbnail over the whole
height of the grid.

Two defects lived in that grid, and both refused clicks. The tile was the only button in the file
without a `contentShape`: only the pixels actually drawn answered, so the gap between the thumbnail
and the name, and the space between the name and the duration, swallowed the click. And
`Thumbnails.image(for:)` was called from `body` and mutated observed state there — a read that
writes during layout restarts it, and while thumbnails keep arriving the grid rebuilds under the
cursor. The request now comes from a `.task`.

## Moments

The inspector's track places each tag in proportion to the clip's duration, capped at 98%. A file
whose duration is not loaded yet spreads its moments evenly rather than stacking them all on the
left.

## Notifications vanished every other time

macOS suppresses the banner when the app posting it is frontmost: it assumes you are already
looking. But QuiX comes to the front precisely to show the import. The notification therefore only
appeared when you had clicked elsewhere in the meantime — hence the feeling of randomness.

A `UNUserNotificationCenterDelegate` answering `[.banner, .list, .sound]` to `willPresent` lifts
the suppression. The delegate is installed at startup, before any banner, and that is also where
authorization is requested: asked at posting time, the first notification was lost while the system
prompt waited for an answer.

## Coming to the front, really

`NSApp.activate(ignoringOtherApps:)` at startup is not enough when the window does not exist yet at
that moment — the normal case here, since it opens in reaction to a state change. Activation is
therefore claimed a second time when the window opens, and a third in its `onAppear`. Three nets
for a simple thing, but the order of appearance is not controlled from one place.

## The icon in notifications

A notification shows a generic glyph instead of the icon. Neither the bundle nor the catalogue is
at fault, and neither is the cache — that was a wrong conclusion, held for a while. The identifier
carries the fault. The whole investigation, and the seven dead ends it went through, are in
[NOTIFICATIONS.md](NOTIFICATIONS.md).

## A layout trap

`Color.clear.frame(width: 24)` only constrains the width. A `Color` being expandable, the height
stayed free: the table header stretched over the whole window and pushed the rows down, with its
labels floating in the middle of the void. The defect shows neither at compile time nor on reading
the code — only on screen.

## The icon

Redrawn in Core Graphics from `#4c` — the generator is in
[`tools/AppIcon.swift`](../tools/AppIcon.swift) — rather than exported from a tool: the handoff's
proportions are given in 168ths, so they compute directly at every size.

A trap along the way: a Core Graphics gradient paints **nothing** beyond its axis without
`.drawsBeforeStartLocation` / `.drawsAfterEndLocation`. The two opposite corners of the squircle
stayed transparent, which only shows to the eye.

The menu-bar glyph is drawn in code rather than imported: it is a ten-line shape, and one more
image would be one more image to regenerate at the first change of proportion.

## Two languages, and two folder names that do not change

The interface is a string catalogue (`App/Localizable.xcstrings`), source language **English**,
French translation. macOS picks by the system language; a Mac set to a third language falls back to
English. `App/InfoPlist.xcstrings` does the same for the two permission texts macOS shows in its
own alerts. A setting lets the language be forced to one or the other, which writes `AppleLanguages`
in QuiX's domain alone and asks to restart — macOS only reads it at launch.

Two strings are not in there, and must never be: **`Highlights`** and **`Clips`**. They are folder
names written to disk, defined in `ImportPlan`. Translating them would split in two the library of
anyone who changes their Mac's language: half the takes in `Highlights/`, the rest in
`Temps forts/`, and a second scan that finds nothing any more. The filter's label does get
translated — it names no folder.

Two traps met along the way:

- **A concatenation is not a key.** `Text("one " + "two")` compiles without complaint, but the
  argument is no longer a literal: Swift picks the `String` initialiser, and the string escapes
  translation in silence. Long texts therefore sit on a single line, however long.
- **Two meanings, two keys.** "Import" titles a section and "Import" labels a button: the same word
  in English, "Import" and "Importer" in French. The section carries an explicit key,
  `settings.section.import`, without which the title became "IMPORTER".

What is not translated is written `Text(verbatim:)`: file names, paths, sizes, durations. Without
that marking, every clip name ended up as a key in the catalogue.

## The first launch

Three screens, once: what the app does, where the clips go, and the permissions.

The two permissions QuiX asks for — **Local Network** and **Removable Volumes** — fail the same
misleading way: the app sees the hardware and finds nothing on it. A card that looks empty, a
plugged-in camera showing no clips. Announcing them before the first connection costs one screen;
letting them be discovered costs an hour hunting a fault that does not exist.

The last screen says "Plug in **and turn on** your GoPro": switched off, it wakes nothing.

The import folder is **required** to go further: without it the next screen has nothing to offer,
and the first connection would land back on the same question.

An installation that already has an import folder has never seen these screens and will not: it
comes from an earlier version, and subjecting it to an introduction would be a step backwards. A
button in Settings replays them for anyone who wants to see them again.

Two things found while building it:

- **A button style greys out nothing on its own.** `.disabled()` cut the click while leaving
  "Continue" a confident blue: you read an active button that did not answer. `FilledBlue` and
  `OutlinedDark` now read `\.isEnabled`.
- **The step is addressable at launch**, `--args -quixOnboardingStep 2`, so that each one can be
  photographed. Driving the interface by clicking at computed coordinates does not work: the window
  moves between the measurement and the click, and the click lands somewhere else — once on another
  app entirely.
