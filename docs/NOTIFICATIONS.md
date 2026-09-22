# The missing icon in notifications

The end-of-import banner shows up with the right title and the right text, but where the QuiX
icon should be, macOS draws its **empty template** — the pale rounded square with a faint grid.

**Nothing in the bundle causes it.** The bundle identifier carries the fault, in the
notification system's own store on the development Mac.

## The proof

A forty-line probe app — nothing but one notification — signed with the same certificate, put in
`/Applications`, carrying **the same `AppIcon.icns` file as QuiX**:

| Probe's bundle identifier | Icon in the banner |
|---|---|
| `com.xavierkain.SondeNotif` (fresh) | **shown** |
| `com.xavierkain.QuiX` | **missing** |

Same binary, same icon, same signature. Only the identifier changed. The icon is not part of the
question: the identifier is.

## What was ruled out along the way

Every attempt was checked the same way: a real import from a fake GoPro card, then a capture of
the **banner's own window, by its window id** — never a screen capture, which would take whatever
is behind it.

| Attempt | Result |
|---|---|
| Six stale copies of the bundle in LaunchServices, three of them ghosts | unregistered — no effect |
| Icon caches, `usernoted`, `NotificationCenter`, `iconservicesagent` | cleared and restarted — no effect |
| A clean reinstall in `/Applications` | no effect |
| `NSPrincipalClass` missing from `Info.plist` | added — no effect, but kept: it is correct |
| The app's localized name resolving to "?" in `lsregister` | fixed — no effect, but kept |
| Asset catalog (ten sizes, complete `Assets.car`) | the original form — no effect |
| macOS 26 Icon Composer `AppIcon.icon` format | accepted by `actool` — no effect |
| A complete `.icns`, all ten types `ic04`→`ic14`, no catalog | the current form — no effect |
| `tccutil reset All com.xavierkain.QuiX` | no effect: notifications do not live in TCC |
| Purging the app's notification history | no effect |
| Restarting the Mac | no effect |

The system log says this during every banner:

```
iconservicesagent: Failed to find named image for name:<private> … appearanceName:NSAppearanceNameAqua
```

**One dead end is worth recording.** `~/Library/Preferences/com.apple.ncprefs.plist` lists 144
apps allowed to post notifications, and QuiX was not among them — which looked like the smoking
gun. It was not: on macOS 26 that file is no longer written. Its last modification predated all
of the testing. A conclusion drawn from a file nothing updates any more is worth nothing.

## The fix: a new bundle identifier

`com.xavierkain.QuiX` became `fr.xavier-kain.quix`, before any public release and therefore with
nobody to migrate. The old preferences domain is read once at first launch so that an import
folder already chosen is not asked for again, and the launch agent installed under the old label
is unloaded and removed — it pointed at the same binary and would have woken a second copy.

The identifier appears nowhere in the signing chain, so neither the Developer ID certificate nor
notarization is affected.

## If the permission prompt is missed

A new identifier means macOS asks for notification permission again. **A prompt that is dismissed
without an answer is recorded as a refusal**, and `requestAuthorization` never asks twice: it
returns the stored answer in silence, and no banner is ever shown again.

It is recoverable — System Settings → Notifications → QuiX, and turn it back on — but the symptom
looks exactly like the app being broken. Worth remembering before blaming the code.
