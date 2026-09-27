# LinkedIn post

A post to share the work rather than to recruit users: the text tells why the app exists and what
was interesting to solve, and the video shows the site scrolling.

- `POST.fr.md`, `POST.en.md` — the text. The link goes in the first comment, not in the post.
- `render_site_video.py` — films the site from `../../site`, served locally, frame by frame:
  `out/quix-site-linkedin.mp4`, 1080 × 1350 (4:5, the tallest format the feed shows whole).
  `--probe` writes a few stills instead, to tune the scroll script (`KEYS`).

The viewport is 960 px wide: the desktop layout, but large enough to read on a phone.
