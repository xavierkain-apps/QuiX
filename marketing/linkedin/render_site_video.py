"""
The site, filmed for a LinkedIn post: a scripted scroll through every section, rendered frame by
frame so the motion is smooth whatever the machine's load.

    python3 render_site_video.py            → out/quix-site-linkedin.mp4  (1080 × 1350, 4:5)
    python3 render_site_video.py --probe    → a few stills at chosen times, to tune the script

The page is served locally from ../../site. Time is frozen: Playwright's clock drives
requestAnimationFrame and performance.now, and every Web Animation is paused and stepped by hand,
so each frame is exactly 1/30 s after the last.
"""
import pathlib, subprocess, sys, tempfile, functools, http.server, threading
from playwright.sync_api import sync_playwright

HERE = pathlib.Path(__file__).resolve().parent
SITE = HERE.parent.parent / "site"
OUT = HERE / "out"
FPS = 30
VIEW = {"width": 960, "height": 1200}       # desktop layout, 4:5, large enough to read in a feed

# The scroll script: (seconds, where). "where" is a section's data-screen-label, a pixel offset
# into it, or the page's bottom. Between two keys the scroll eases in and out.
KEYS = [
    (0.0, ("top", 0)), (4.0, ("top", 0)),
    (5.5, ("02", 0)),
    (21.0, ("02", "end")),                  # the sticky story: 620 vh, scrubbed by the scroll
    (24.0, ("03", -80)), (29.0, ("03", -80)),   # the GoPro button, left to play
    (31.5, ("04", -80)), (34.0, ("04", -80)),
    (36.5, ("05", -80)), (39.0, ("05", -80)),
    (41.5, ("06", -80)), (45.0, ("06", -80)),
    (47.5, ("07", -80)), (51.0, ("07", -80)),
]
PROBE = [0.5, 3.5, 7, 12, 17, 20, 26, 28, 33, 38, 44, 50]

def serve():
    h = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(SITE))
    http.server.SimpleHTTPRequestHandler.log_message = lambda *a: None
    s = http.server.ThreadingHTTPServer(("127.0.0.1", 0), h)
    threading.Thread(target=s.serve_forever, daemon=True).start()
    return s

def ease(t):
    return t * t * (3 - 2 * t)

def resolve(page, where):
    label, off = where
    if label == "top":
        return 0
    return page.evaluate("""([label, off]) => {
        const s = [...document.querySelectorAll('section[data-screen-label]')]
                  .find(e => e.dataset.screenLabel.startsWith(label));
        const top = s.getBoundingClientRect().top + scrollY;
        if (off === 'end') return top + s.offsetHeight - innerHeight;
        return Math.min(top + off, document.documentElement.scrollHeight - innerHeight);
    }""", [label, off])

def scroll_at(t, stops):
    for (t0, y0), (t1, y1) in zip(stops, stops[1:]):
        if t0 <= t <= t1:
            return y0 + (y1 - y0) * ease((t - t0) / (t1 - t0)) if t1 > t0 else y1
    return stops[-1][1]

STEP = """dt => { for (const a of document.getAnimations()) {
    if (a.playState === 'finished') continue;
    a.pause(); a.currentTime = (a.currentTime || 0) + dt; } }"""

def main():
    probe = "--probe" in sys.argv
    OUT.mkdir(exist_ok=True)
    srv = serve()
    url = f"http://127.0.0.1:{srv.server_address[1]}/index.html"
    with sync_playwright() as pw, tempfile.TemporaryDirectory() as tmp:
        b = pw.chromium.launch()
        page = b.new_page(viewport=VIEW, device_scale_factor=1)
        page.clock.install()
        page.goto(url, wait_until="networkidle")
        page.evaluate("document.fonts.ready")
        page.clock.run_for(50)
        page.add_style_tag(content="html{scroll-behavior:auto!important} ::-webkit-scrollbar{display:none}")
        stops = [(t, resolve(page, w)) for t, w in KEYS]
        total = KEYS[-1][0]
        wanted = {round(t * FPS) for t in PROBE} if probe else None
        n = round(total * FPS)
        for f in range(n):
            t = f / FPS
            page.evaluate(f"window.scrollTo(0, {scroll_at(t, stops):.1f})")
            page.evaluate(STEP, 1000 / FPS)
            page.clock.run_for(round(1000 / FPS))
            if probe and f not in wanted:
                continue
            path = (OUT / f"probe-{t:05.1f}.png") if probe else pathlib.Path(tmp) / f"{f:05d}.png"
            page.screenshot(path=str(path))
            if not probe and f % 150 == 0:
                print(f"{t:.0f}/{total:.0f} s", flush=True)
        b.close()
        if not probe:
            dst = OUT / "quix-site-linkedin.mp4"
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", str(FPS),
                            "-i", f"{tmp}/%05d.png", "-vf", "scale=1080:1350:flags=lanczos,format=yuv420p",
                            "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-movflags", "+faststart",
                            str(dst)], check=True)
            print(f"{dst.name}: {n / FPS:.1f} s, {dst.stat().st_size / 1e6:.1f} MB")
    srv.shutdown()

if __name__ == "__main__":
    main()
