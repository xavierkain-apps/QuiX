#!/usr/bin/env python3
"""The Instagram stories as video — English, 1080 × 1920, 30 fps, 6 s each.

Same content and layout as the still stories (render.py), with motion added by motion.css. The
animations are not recorded in real time: every animation is paused and set to the exact time of
each frame, which is then captured. The result is perfectly smooth whatever the machine's load,
and identical on every run. ffmpeg assembles the frames into H.264.

    python3 marketing/instagram-stories/render_video.py

writes out/quix-story-en-<0…5>.mp4, one per story — 0 is the poll, posted on its own first — then
out/quix-stories-en.mp4, the five app stories joined, and out/quix-stories-en-x2.mp4, the same at
double speed.
"""
import pathlib, re, shutil, subprocess, tempfile
from playwright.sync_api import sync_playwright
import render

HERE = render.HERE
OUT = render.OUT
FPS, SECONDS = 30, 6
LANG = "en"


def with_motion(i, html):
    """Hooks for motion.css: classes and per-element delays on the still markup."""
    html = html.replace('<section class="story">', f'<section class="story s{i}">', 1)

    if i == 0:  # the crowd arrives one voter at a time, while the count climbs
        n = 0
        def bubble(m):
            nonlocal n
            d = 1.5 + n * 0.035
            n += 1
            return f'<i style="animation-delay:{d:.3f}s;{m.group(1)}"></i>'
        html = re.sub(r'<i style="([^"]*background-image[^"]*)"></i>', bubble, html)
        assert n == 41, f"story 0: {n} voters hooked instead of 41"

    if i == 2:  # the grid fills in order; the three moments light up one after another
        n, lit = 0, 0
        def tile(m):
            nonlocal n, lit
            d = 0.8 + n * 0.06
            n += 1
            if "hot" in m.group(1):
                l = 2.3 + lit * 0.5
                lit += 1
                return f'<div class="tile{m.group(1)}" style="animation-delay:{d:.2f}s,{l:.2f}s;--l:{l}s;'
            return f'<div class="tile{m.group(1)}" style="animation-delay:{d:.2f}s;'
        grid = re.search(r'<div class="grid">.*?</div></div>\n', html, re.S)
        if grid:
            part = re.sub(r'<div class="tile([^"]*)" style="', tile, grid.group(0))
            part = re.sub(r'(style="animation-delay:[\d.]+s,([\d.]+)s;--l:[\d.]+s;[^"]*">)<b class="badge">',
                          lambda m: f'{m.group(1)}<b class="badge" style="animation-delay:{float(m.group(2)) + .15:.2f}s">', part)
            html = html.replace(grid.group(0), part)

    if i == 3:  # the camera: playhead, press, marker
        html = html.replace('<rect x="120" y="620" width="300" height="22" rx="11" fill="#00A3E4"/>',
                            '<rect class="played" x="120" y="620" width="520" height="22" rx="11" fill="#00A3E4"/>')
        html = html.replace('<circle cx="652" cy="262" r="76" fill="url(#halo)"/>',
                            '<g class="halo"><circle cx="652" cy="262" r="76" fill="url(#halo)"/>')
        html = html.replace('<circle cx="652" cy="262" r="48" fill="none" stroke="#00A3E4" stroke-width="3" stroke-opacity=".6"/>',
                            '<circle cx="652" cy="262" r="48" fill="none" stroke="#00A3E4" stroke-width="3" stroke-opacity=".6"/></g>')
        html = html.replace('<rect x="634" y="222" width="34" height="80" rx="14" fill="#00A3E4"/>',
                            '<rect class="button" x="634" y="222" width="34" height="80" rx="14" fill="#00A3E4"/>')
        html = html.replace('<circle cx="198" cy="232" r="10" fill="#FF4B3E"/>', '<circle class="rec" cx="198" cy="232" r="10" fill="#FF4B3E"/>')
        html = re.sub(r'(<path d="M404 668[^>]*/>\s*<text x="420" y="700"[^>]*>[^<]*</text>)', r'<g class="marker">\1</g>', html)
        for hook in ('class="played"', 'class="halo"', 'class="button"', 'class="marker"'):
            assert hook in html, f"story 3: the {hook} hook did not match the diagram"

    if i == 5:  # the fan opens from a stack
        html = re.sub(r'transform:rotate\((-?\d+)deg\)', r'--a:\1deg', html)
        assert html.count("--a:") == 5, "story 5: the fan cards were not hooked"
    return html


def page(i, html):
    return f'''<!DOCTYPE html><html lang="{LANG}"><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Archivo:wdth,wght@62..125,400..900&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
<link rel="stylesheet" href="stories.css"><link rel="stylesheet" href="motion.css">
<style>body{{background:#101017}}</style></head><body>
{html}
<script>
// Everything that is not a CSS animation: the timecode runs on, the popover counts up.
const base = (3 * 60 + 27) * 30 + 14 + ({i} - 1) * {SECONDS} * 30;
window.setTime = (t) => {{
  document.getAnimations().forEach(a => {{ a.pause(); a.currentTime = t * 1000; }});
  const f = base + Math.round(t * 30), p = (n) => String(n).padStart(2, "0");
  const tc = document.querySelector(".hud .tc");
  if (tc) tc.textContent = "00:" + p(Math.floor(f / 1800) % 60) + ":" + p(Math.floor(f / 30) % 60) + ":" + p(f % 30);
  const count = document.querySelector(".count");
  if (count) {{
    const k = Math.min(1, Math.max(0, (t - 0.5) / 1.4));
    count.textContent = String(Math.round(41 * (1 - Math.pow(1 - k, 3))));
  }}
  document.querySelectorAll(".pop .n b").forEach(b => {{
    b.textContent = String(Math.max(0, Math.min(3, Math.floor((t - 2.6) / 0.2) + 1)));
  }});
}};
</script></body></html>'''


def main():
    OUT.mkdir(exist_ok=True)
    c = render.COPY[LANG]
    builders = [render.s0, render.s1, render.s2, render.s3, render.s4, render.s5]
    clips = []
    with sync_playwright() as p:
        browser = p.chromium.launch(args=["--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu"])
        for i, build in enumerate(builders, 0):
            path = HERE / f"stories-video-{i}.html"
            path.write_text(page(i, with_motion(i, build(c))), encoding="utf-8")
            tab = browser.new_page(viewport={"width": 1080, "height": 1920}, device_scale_factor=1)
            tab.goto(path.as_uri(), wait_until="networkidle")
            tab.evaluate("document.fonts.ready")
            tab.wait_for_timeout(500)
            frames = pathlib.Path(tempfile.mkdtemp(prefix=f"quix-story-{i}-"))
            for f in range(FPS * SECONDS):
                tab.evaluate(f"window.setTime({f / FPS})")
                tab.screenshot(path=str(frames / f"{f:04d}.jpg"), type="jpeg", quality=94)
            tab.close()
            path.unlink()
            clip = OUT / f"quix-story-{LANG}-{i}.mp4"
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", str(FPS), "-i", str(frames / "%04d.jpg"),
                            # The frames are full-range JPEGs; without the conversion ffmpeg keeps them
                            # full range (yuvj420p), which some players — Instagram's among them — show
                            # with crushed blacks. Video range, yuv420p, plays the same everywhere.
                            "-vf", "scale=in_range=full:out_range=tv,format=yuv420p", "-color_range", "tv",
                            "-c:v", "libx264", "-preset", "slow", "-crf", "18",
                            "-movflags", "+faststart", str(clip)], check=True)
            shutil.rmtree(frames)
            clips.append(clip)
            print(f"story {i}: {clip.name} ({clip.stat().st_size / 1e6:.1f} MB)")
        browser.close()

    # The joined video holds the five app stories only: the poll (story 0) is posted on its own,
    # before them. It also comes at double speed, which is how it reads best on Instagram.
    listing = OUT / "concat.txt"
    listing.write_text("".join(f"file '{c.name}'\n" for c in clips if not c.name.endswith("-0.mp4")))
    joined = OUT / f"quix-stories-{LANG}.mp4"
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", str(listing),
                    "-c", "copy", "-movflags", "+faststart", str(joined)], check=True, cwd=OUT)
    listing.unlink()
    fast = OUT / f"quix-stories-{LANG}-x2.mp4"
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(joined), "-filter:v", "setpts=0.5*PTS",
                    "-r", str(FPS), "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p",
                    "-color_range", "tv", "-movflags", "+faststart", str(fast)], check=True)
    print(f"the five app stories: {joined.name}, and at double speed {fast.name} ({fast.stat().st_size / 1e6:.1f} MB)")

if __name__ == "__main__":
    main()
