# Instagram stories

Six stories, French and English, 1080 × 1920:

0. the poll — *41 of you said yes*: Xavier's own poll story, the 98 % result, and a crowd of 41
   voters whose avatars are blurred beyond recognition. Posted first.
1. the hook — the wall of session stills, *Skip the rushes. Keep the moments.*
2. the problem — hours of footage, three moments that matter
3. the gesture — a short press on the HERO12's side button writes a HighLight into the clip
4. the result — plug in, the Highlights folder and the menu bar popover
5. the call — free, for Mac, with room left empty for the link sticker

```sh
python3 marketing/instagram-stories/render.py
```

writes `out/quix-story-<fr|en>-<0…5>.png`. The text lives in `COPY` at the top of `render.py`; the
French version speaks *tu*, as Instagram does, where the site says *vous*.

Everything that must be read sits between y = 240 and y = 1560: Instagram covers the top (progress
bar, profile) and the bottom (reply bar). Story 5 leaves the band under "Get it here ↓" empty for
the link sticker.

## Video

```sh
python3 marketing/instagram-stories/render_video.py
```

writes the same five stories in English as video — 1080 × 1920, 30 fps, H.264, 6 s each
(`out/quix-story-en-<1…5>.mp4`) — plus `out/quix-stories-en.mp4`, the five joined into one 30 s
clip. The motion lives in `motion.css`; the renderer pauses every animation and sets it to the time
of each frame before capturing it, so the result is smooth and identical on every run, whatever
the machine's load. Takes about three minutes.

## Story 0 needs local assets

`assets/poll.jpg` (the poll story, cropped from a screenshot) and `assets/crowd-*.png` (the voters'
avatars, blurred) are **not in the repository**: the voters did not agree to appear in public, and
even blurred, their pictures have no business in a public repo. Without them story 0 renders
without its card and its crowd.

The voters stay anonymous on purpose: Instagram shows the voter list to the poster alone. Name
someone only with their agreement.

## Reel and carousel

```sh
python3 marketing/instagram-stories/render_social.py
```

writes the Reel (`out/quix-reel-en.mp4`, 1080 × 1920, ~14 s, and its cover) and the carousel
(`out/quix-carousel-en-<1…5>.png`, 1080 × 1350). Same visuals, scaled as a whole into the part of
each format Instagram leaves free — see the docstring. The Reel opens on the problem and starts
once the first headline is whole, because its first frame is what a scrolling feed shows.
