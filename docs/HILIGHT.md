# The HiLight format — measured on Xavier's camera

Measured on 2026-09-07 against two real clips, one tagged and one not.
It clears the brief's reservation about recent models: **classic HMMT works**.

| | |
|---|---|
| Camera | **HERO12 Black** (`GPMF/MINF`) |
| Firmware | `H23.01.02.32.00` (`udta/FIRM`) |
| Lens | `LSU3121202401859` (`udta/LENS`) |
| Serial number | `C3501325811702` (`GPMF/CASN`) |

## Where the information lives

```
ftyp        @0           20 B
free        @20           8 B
mdat        @28       ~90 MB      <- the video
moov        @89,793,449 34 KB     <- everything else, AT THE END OF THE FILE
  mvhd                            timescale + duration
  udta
    FIRM LENS CAME SETT MUID
    HMMT                 332 B    <- the highlights
    BCID GUMI
    GPMF                  25 KB   <- telemetry, including an HLMT stream
```

## Trap 1 — `moov` is at the end, not the beginning

The brief says "only the header is read". That is the right idea with the wrong word: in GoPro
files `mdat` comes first and `moov` closes the file. Reading the first few kilobytes gives
nothing.

It costs no more for all that. The top-level boxes are walked by reading only their 8-byte
headers and skipping `mdat` by its size: **three seeks, then about 34 KB read**. Scanning a whole
card stays a matter of seconds. Sorting before copying still holds.

To handle: `size == 1` (a 64-bit size in 8 further bytes, the case of an `mdat` over 4 GB) and
`size == 0` (the box runs to the end of the file — an `mdat` shaped that way would hide `moov`,
and must be treated as a file with no highlights, not as an error).

## Trap 2 — HMMT is always 332 bytes, tagged or not

This is the trap that costs the entire app.

```
HMMT, 324-byte payload, invariant:
  [0..3]     uint32 BE   number of moments
  [4..323]   uint32 BE × 80   slots, filled with zeros
```

GoPro **preallocates 80 slots**. The clip with no highlight at all carries the same 332-byte atom
as the tagged one; only the count differs.

Therefore:

- **Never infer the number of moments from the size of the atom.** `(size - 8 - 4) / 4` would
  give 80 on *every* clip, everything would go to `Highlights/`, and the app would lose its only
  reason to exist — without raising a single error. That is exactly what the untagged clip made
  visible.
- **The presence of HMMT does not mean "highlighted clip".** The criterion is
  `number of moments > 0`.
- Clamp the count read to the number of slots actually available in the atom before looping: an
  absurd count must not make the reader run past the end.
- A complete absence of HMMT (another camera, a remuxed file) reads as "no highlights", never as
  an error.

## Measurements

| File | Duration | HMMT count | Moments |
|---|---|---|---|
| `GX013097.MP4` | 6.17 s (`mvhd` 370370/60000) | 0 | — |
| `GX013129.MP4` | 7.26 s (`mvhd` 435435/60000) | 1 | 3436 ms |

## Cross-check: the GPMF/HLMT stream

`udta/GPMF` contains an `HLMT` stream in GoPro's own KLV format, described by its own `RMRK`:

```
struct: Time (ms), in (ms), out (ms), Location XYZ (deg,deg,m), Type, Confidence (%) Score
```

On the tagged clip it carries `00 00 0d 6c` three times — 3436 as time, in and out.
**It confirms HMMT exactly.**

It is not used: reading HLMT would need a full KLV parser for information already obtained in
thirty lines. Worth remembering if some model ever stops writing HMMT.

## What stays out of reach

Highlights added afterwards in the Quik mobile app are not written back into the MP4 — neither
into HMMT nor into HLMT. A limitation to show in the interface, not a bug to fix.

## Test fixtures

`Core/Tests/QuiXCoreTests/Fixtures/` holds the two real `moov` atoms, reassembled behind an empty
`mdat` to keep the "moov last" geometry. 34 KB each instead of 90 MB, and the same bytes the
camera wrote.
