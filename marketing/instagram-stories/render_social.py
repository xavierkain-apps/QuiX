#!/usr/bin/env python3
"""The same visuals, cut for an Instagram post: a Reel and a carousel. English.

    python3 marketing/instagram-stories/render_social.py

writes
    out/quix-reel-en.mp4          1080 × 1920, 30 fps, 15 s — the Reel
    out/quix-reel-cover-en.png    1080 × 1920 — its cover
    out/quix-carousel-en-<1…5>.png  1080 × 1350 — the carousel, in order

Nothing is re-laid out by hand. Each story is scaled as a whole into the part of the frame the
format leaves free:

- A Reel is covered on the right by the like / comment / share buttons and at the bottom by the
  caption and the audio line. Each story is drawn at 80 % in the top-left, which keeps it inside
  x 40…904 and clear of both.
- A carousel slide is 4:5. The readable band of a story (y 200…1580) is scaled to fill its height.

The Reel follows the stories in their own order — the line "skip the rushes, keep the moments"
first, then the problem, the gesture, the result, the call — at double speed, rendered natively at
that speed rather than accelerated afterwards.
"""
import pathlib, shutil, subprocess, tempfile
from playwright.sync_api import sync_playwright
import render, render_video

HERE, OUT = render.HERE, render.OUT
FPS = 30
C = dict(render.COPY["en"])
C["link_hint"] = "Link in bio"          # links in a Reel caption are not clickable

REEL = {"w": 1080, "h": 1920, "scale": 0.8, "x": 40, "y": 110}
POST = {"w": 1080, "h": 1350, "scale": 1350 / 1380, "x": 12, "y": round(-200 * 1350 / 1380)}

# Story number → builder. The Reel order: line, problem, gesture, result, call.
BUILD = {1: render.s1, 2: render.s2, 3: render.s3, 4: render.s4, 5: render.s5}
# Story 1 starts once its headline is whole: the first frame is what a scrolling feed shows, and
# before 2 s the wall of clips is still on its own, with no words over it.
REEL_ORDER = [(1, 2.0), (2, 0.0), (3, 0.0), (4, 0.0), (5, 0.0)]   # (story, start offset in s)
REEL_SPEED, SCENE = 2.0, 6.0


def framed(section, fmt):
    return (f'<style>html,body{{margin:0;width:{fmt["w"]}px;height:{fmt["h"]}px;overflow:hidden;'
            f'background:radial-gradient(900px 700px at 45% 40%, rgba(0,163,228,.18), transparent 65%), #101017}}'
            f'.story{{background:transparent!important}}</style>'
            f'<div style="position:absolute;left:{fmt["x"]}px;top:{fmt["y"]}px;width:1080px;height:1920px;'
            f'transform:scale({fmt["scale"]});transform-origin:0 0">{section}</div>')


def still_page(section, fmt):
    return f'''<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Archivo:wdth,wght@62..125,400..900&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
<link rel="stylesheet" href="stories.css"></head><body>{framed(section, fmt)}</body></html>'''


def shoot_still(browser, html, fmt, path):
    tmp = HERE / "social-tmp.html"
    tmp.write_text(html, encoding="utf-8")
    tab = browser.new_page(viewport={"width": fmt["w"], "height": fmt["h"]})
    tab.goto(tmp.as_uri(), wait_until="networkidle")
    tab.evaluate("document.fonts.ready")
    tab.wait_for_timeout(500)
    tab.screenshot(path=str(path))
    tab.close()
    tmp.unlink()


def main():
    OUT.mkdir(exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(args=["--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu"])

        # Carousel: the five stories, cover first.
        for n in range(1, 6):
            shoot_still(browser, still_page(BUILD[n](C), POST), POST, OUT / f"quix-carousel-en-{n}.png")
        print("carousel: 5 slides")

        # Reel cover: the line, with the wall.
        shoot_still(browser, still_page(BUILD[1](C), REEL), REEL, OUT / "quix-reel-cover-en.png")

        # Reel: every scene rendered at double speed, frame by frame, into one sequence.
        frames = pathlib.Path(tempfile.mkdtemp(prefix="quix-reel-"))
        k = 0
        for story, start in REEL_ORDER:
            section = render_video.with_motion(story, BUILD[story](C))
            tmp = HERE / "social-tmp.html"
            tmp.write_text(render_video.page(story, framed(section, REEL)), encoding="utf-8")
            tab = browser.new_page(viewport={"width": REEL["w"], "height": REEL["h"]})
            tab.goto(tmp.as_uri(), wait_until="networkidle")
            tab.evaluate("document.fonts.ready")
            tab.wait_for_timeout(400)
            n = round((SCENE - start) / REEL_SPEED * FPS)
            for f in range(n):
                tab.evaluate(f"window.setTime({start + f * REEL_SPEED / FPS})")
                tab.screenshot(path=str(frames / f"{k:05d}.jpg"), type="jpeg", quality=94)
                k += 1
            tab.close()
            tmp.unlink()
        browser.close()

    reel = OUT / "quix-reel-en.mp4"
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", str(FPS), "-i", str(frames / "%05d.jpg"),
                    "-vf", "scale=in_range=full:out_range=tv,format=yuv420p", "-color_range", "tv",
                    "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-movflags", "+faststart", str(reel)], check=True)
    shutil.rmtree(frames)
    print(f"reel: {reel.name}, {k / FPS:.1f} s ({reel.stat().st_size / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
