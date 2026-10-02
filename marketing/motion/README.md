# Motion piece

A 15-second motion-graphics film of QuiX, in two cuts sharing one timeline and one soundtrack:
1920 × 1080 (`h`) and the 1080 × 1920 Instagram Reel (`v`).

    python3 make_assets.py          # the photo collage and the grain tile, from site/assets/thumbs
    python3 music.py                # music.wav — 120 BPM, synthesised, every hit on a picture beat
    python3 render.py --fmt h       # out/quix-motion-h.mp4
    python3 render.py --fmt v       # out/quix-motion-v.mp4
    python3 render.py --fmt v --probe 3.6 9.9   # stills at chosen times, to check a layout

- `compose.src.html` is the whole film: one `R(t)` that sets every property from the time alone.
  The Reel layout is the CSS under `.v`, kept inside Instagram's safe area (top ~220 px, bottom
  ~380 px, the button column on the right).
- `render.py` injects the HERO12 diagram from the Instagram stories, captures at 60 fps and blends
  each pair of frames into one at 30 fps — a 180° shutter, so fast moves get real motion blur.
  The soundtrack is normalised to −14 LUFS when muxed.

| Time | Scene | |
|---|---|---|
| 0 – 3 | 3 hours of footage | the 3 falls from the camera onto the first beat; the footage runs inside the letters |
| 2.5 – 4.5 | the wall | fly-in, brake, scan, three moments light up, dive into the middle one |
| 4.5 – 6.7 | one press, one highlight | the HERO12 turns in, the side button is pressed on the beat, a shockwave |
| 6.5 – 8.6 | plug in, it's sorted | the cable plugs in, six takes copied and verified, each flies to its folder |
| 8.3 – 10.7 | sorting is free | the progress bar becomes a 4 GB file; three seeks, 34 KB read, moov › udta › HMMT |
| 10.3 – 12.7 | go make a coffee | the menu bar, the popover, a click on Open highlights, the folder opens |
| 12.4 – 15 | end card | the three highlights fan out, the icon lands, the line, the address |
