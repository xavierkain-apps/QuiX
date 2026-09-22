# The camera over the cable

Measured on Xavier's HERO12 Black (serial `C350132581xxxx`, firmware `H23.01.02.32.00`),
macOS 26.6, September 2026. Everything below is measured, not inferred from documentation.

## What the camera is not

**It exposes no mass storage.** That is the starting point, and there is no setting to change it:
the HERO12 has no "USB mass storage" option. Plugged in and switched on, it publishes three USB
interfaces:

| Interface | Class | |
|---|---|---|
| CDC Network Control Model | 2 / 13 | networking, the useful road |
| CDC Network Data | 10 | |
| MTP | 6 / 1 | camera protocol |
| *(none)* | **8** | **mass storage — absent** |

The direct consequence: `/Volumes/` will never show the camera, and
`NSWorkspace.didMountNotification` will never fire for it. Looking for a `DCIM/###GOPRO` folder on
a mounted volume — the correct path for a card in a reader — cannot structurally yield anything
here.

**MTP is a decoy.** It is there, and Image Capture does see the camera — but it publishes only two
service files, `leinfo.sav` and `Get_started_with_GoPro.url`. No clips. Going through
ImageCaptureCore would lead to a dead end after a great deal of work.

## What it is

An **HTTP server**, reachable over the network the CDC NCM interface brings up. That is the road
Quik took, and the only one that gives access to the clips.

The address derives from the serial number, in the shape `172.2X.1YZ.51`. We do not reproduce that
calculation — it would require knowing the serial *before* talking to the camera. We start from
the machine's own interfaces instead: it receives an address in the same `/24`, and the camera
always sits at `.51`.

```
GET /gopro/camera/info                    model, serial, firmware
GET /gopro/camera/control/wired_usb?p=1   switch to wired control
GET /gopro/media/list                     the catalogue: folder, name, size, date
GET /videos/DCIM/<folder>/<name>          the file
```

## The point everything hinges on

**The server honours `Range`.** Measured on a 48.7 MB clip:

```
Range: bytes=48664916-48699731/48699732
→ HTTP/1.1 206 Partial Content
  Accept-Ranges: bytes
  Content-Length: 34816
```

This is what saves the app's whole principle. `FileByteReader`'s three seeks become three `Range`
requests, and the `moov` at the end of the file is reached without pulling the clip down. Sorting
stays free over the cable exactly as it is on a card — see `HTTPRangeByteReader`.

If a future firmware stopped honouring it, every clip would have to be downloaded **before**
knowing where it goes, which rule 1 of the project forbids. `CameraScanner` therefore checks
`Range` once per session and reports the failure instead of quietly working around it.

The 34 KB of tail brought back by `Range` do contain the expected chain:

```
moov at +3512      udta at +3628      HMMT at +3797, 332 bytes
```

And the two control clips confirm the trap documented in [HILIGHT.md](HILIGHT.md): an **identical**
332-byte atom on both, with only the counter separating the tagged clip (1) from the untagged one
(0).

## The permission nobody guesses

macOS classifies the camera as a network device. Every request therefore falls under the **"Local
Network"** permission — not "Files and Folders", which only concerns the mounted card.

A refusal is particularly bad to diagnose: `URLSession` returns `-1009`, *"The Internet connection
appears to be offline"*, when neither the Internet nor an outage is involved. The only mark of the
refusal is in the `userInfo`:

```
_NSURLErrorNWPathKey = unsatisfied (Local network prohibited), interface: en10
```

Without special handling, a plugged-in camera with a refused permission is indistinguishable from
no camera at all: the app appears to see nothing. `CameraWatcher` therefore tells the two apart
explicitly, and the app offers to open the right Settings panel.

`curl` works while the app fails — Terminal already has the permission. That detail costs time:
never conclude from a `curl` that succeeds that the code will succeed.

## One connection at a time

The camera's server holds only one, and it does not show immediately. With `URLSession.shared`,
scanning left an idle but open connection behind it; the first download that followed asked for a
second, which the camera refused.

The symptom was disorienting because it did not point at the culprit: **the first clip failed and
the following ones went through**, and re-running the import always succeeded — the idle connection
having timed out in the meantime. The file was blamed, when only its rank mattered.

Every request therefore goes through sessions with `httpMaximumConnectionsPerHost = 1`. And since a
USB link can drop for other reasons, `ImportRunner` retries three times with a short delay — which
costs almost nothing, because resuming starts from the bytes already received.

## Being woken when the camera is plugged in

There is nothing to watch while the app is not running: `launchd` wakes QuiX, through an agent
dropped in `~/Library/LaunchAgents` and matched to the appearance of the USB device. Until the
camera is plugged in, no process exists.

The agent launches **the app's executable**, not `open`. That is counter-intuitive, because `open`
handled the already-running case for free — but it cannot *consume* the event.

This is the most expensive trap on the whole path. As long as a `launchd` event stays pending, the
job is considered unfinished and **relaunched every few tens of seconds**: quitting QuiX with the
camera plugged in reopened it ten seconds later, indefinitely. Measured at four launches in 35
seconds, with or without `IOMatchLaunchStream` — removing the key changes nothing.

Only a program that calls `xpc_set_event_stream_handler("com.apple.iokit.matching", …)` ends the
cycle. Measured: `runs = 1` instead of 4, and no relaunching at all. That program therefore has to
be the app itself.

The price is the second copy, which `open` avoided without being asked: `launchd` starts the binary
without going through LaunchServices, and therefore without its single-instance rule. The newcomer
consumes the event, brings the existing window forward, then withdraws — in that order, because
leaving before delivery would restart the loop.

Finally, the app has to activate itself **imperatively**. Since macOS 14 activation is
"cooperative": `NSApp.activate()` can be refused by the frontmost app, and a process born from
`launchd` has nothing to make it yield. `activate(ignoringOtherApps:)` is deprecated and remains
the only one that works here — plugging in a camera is an explicit intent, and it outranks
politeness between apps.

Three details of the matching were found by trial, and none of them is guessable — **an agent that
matches nothing does not complain**, it simply never fires, and `launchctl print` displays it
exactly as though it worked:

| | What works | What does not |
|---|---|---|
| Event name | `com.apple.device-attach` | any free-form name — accepted, displayed, inert |
| `IOProviderClass` | `IOUSBDevice` | `IOUSBHostDevice`, which is the node's real class |
| Identifiers | `idVendor` **and** `idProduct` | `idVendor` alone |

Measured by reloading the agent with the camera plugged in: IOKit matching also fires for a device
that is already present, which makes it possible to test without unplugging (`runs = 1` in
`launchctl print`, and the app opens).

The third point costs something: the agent only recognises the model that was measured, the HERO12
Black (`idProduct` 89). Another GoPro would need its own identifier:

```sh
ioreg -p IOUSB -l | grep -A20 GoPro
```

## Two implementation traps

**Detection cannot be event-driven.** There is no notification for the appearance of a network
device as there is for a mounted volume. `CameraWatcher` polls every 3 seconds; when nothing is
plugged in, no request is sent at all, the candidate list being empty.

**`URLSession` holds on to its delegate beyond the call.** `finishTasksAndInvalidate()` returns
before it has released anything. A delegate holding non-escaping closures keeps them alive past
their scope, and Swift traps — the app crashed after the first imported clip, while all 85 tests
of the time passed. `RemoteVerifiedCopy` therefore releases its closures as soon as the transfer
ends, and `RemoteCopyTests` stands up a real HTTP server to prove it.
