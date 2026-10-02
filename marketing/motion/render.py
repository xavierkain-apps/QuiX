"""Renders the QuiX motion piece.

    python3 render.py [--fmt h|v] --probe 0.5 3.6 ...   stills at those times → probe/<fmt>/
    python3 render.py [--fmt h|v]                         the full video → out/quix-motion-<fmt>.mp4

h is 1920 × 1080 (landscape), v is 1080 × 1920 (Instagram Reel). The composition is captured at
60 fps and every pair of frames is blended into one at 30 fps: a 180° shutter, real motion blur
on every fast move. The soundtrack (music.py) is muxed in if music.wav exists.
"""
import functools, http.server, pathlib, re, shutil, subprocess, sys, threading
from playwright.sync_api import sync_playwright

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(REPO / "marketing" / "instagram-stories"))
import render as stories

DUR, CAP = 15.0, 60
SIZE = {"h": (1920, 1080), "v": (1080, 1920)}

def gopro():
    s = stories.gopro(stories.COPY["en"])
    rep = [
        ('<rect x="120" y="620" width="300" height="22" rx="11" fill="#00A3E4"/>',
         '<rect id="played" x="120" y="620" width="0" height="22" rx="11" fill="#00A3E4"/>'),
        ('<circle cx="652" cy="262" r="76" fill="url(#halo)"/>',
         '<circle id="halo" cx="652" cy="262" r="76" fill="url(#halo)" style="opacity:0; transform-box:fill-box; transform-origin:center"/>'),
        ('<rect x="634" y="222" width="34" height="80" rx="14" fill="#00A3E4"/>',
         '<rect id="button" x="634" y="222" width="34" height="80" rx="14" fill="#00A3E4" style="transform-box:fill-box; transform-origin:center"/>'),
        ('font-family="JetBrains Mono">00:42</text>', 'font-family="JetBrains Mono" id="gptime">00:00</text>'),
    ]
    for a, b in rep:
        assert a in s, a
        s = s.replace(a, b)
    s = re.sub(r'(<path d="M404 668[^>]*/>\s*<text x="420" y="700"[^>]*>[^<]*</text>)',
               r'<g id="marker" style="opacity:0; transform-box:fill-box; transform-origin:center bottom">\1</g>', s)
    assert 'id="marker"' in s
    return s

def build():
    src = (HERE / "compose.src.html").read_text(encoding="utf-8")
    (HERE / "compose.html").write_text(src.replace("__GOPRO__", gopro().replace("`", "\\`")), encoding="utf-8")

def serve():
    h = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(REPO))
    http.server.SimpleHTTPRequestHandler.log_message = lambda *a: None
    s = http.server.ThreadingHTTPServer(("127.0.0.1", 0), h)
    threading.Thread(target=s.serve_forever, daemon=True).start()
    return s

def main():
    args = sys.argv[1:]
    fmt = "h"
    if "--fmt" in args:
        i = args.index("--fmt"); fmt = args[i + 1]; del args[i:i + 2]
    probe = [float(x) for x in args[1:]] if args[:1] == ["--probe"] else None
    W, H = SIZE[fmt]
    build()
    outdir = HERE / ("probe" if probe else "frames") / fmt
    shutil.rmtree(outdir, ignore_errors=True); outdir.mkdir(parents=True)
    srv = serve()
    with sync_playwright() as pw:
        b = pw.chromium.launch(args=["--disable-gpu-vsync"])
        page = b.new_page(viewport={"width": W, "height": H})
        page.on("console", lambda m: m.type == "error" and print("console:", m.text))
        page.on("pageerror", lambda e: print("pageerror:", e))
        page.goto(f"http://127.0.0.1:{srv.server_address[1]}/marketing/motion/compose.html?fmt={fmt}", wait_until="networkidle")
        page.evaluate("window.READY")
        if probe:
            for t in probe:
                page.evaluate(f"R({t})")
                page.screenshot(path=str(outdir / f"t{t:05.2f}.png"))
        else:
            n = round(DUR * CAP)
            for f in range(n):
                page.evaluate(f"R({f / CAP:.5f})")
                page.screenshot(path=str(outdir / f"{f:05d}.png"))
                if f % 120 == 0: print(f"{f / CAP:.0f}/{DUR:.0f} s", flush=True)
        b.close()
    srv.shutdown()
    if probe: return
    OUT = HERE / "out"; OUT.mkdir(exist_ok=True)
    silent = OUT / f"silent-{fmt}.mp4"
    # 60 → 30 fps with a 180° shutter: average each pair of captured frames.
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", str(CAP), "-i", str(outdir / "%05d.png"),
                    "-vf", "tmix=frames=2:weights='1 1',select='not(mod(n\\,2))',setpts=N/30/TB,format=yuv420p",
                    "-r", "30", "-c:v", "libx264", "-preset", "slow", "-crf", "16", str(silent)], check=True)
    dst = OUT / f"quix-motion-{fmt}.mp4"
    wav = HERE / "music.wav"
    if wav.exists():
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(silent), "-i", str(wav), "-c:v", "copy",
                        "-af", "loudnorm=I=-14:TP=-1:LRA=11", "-ar", "48000", "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", str(dst)], check=True)
    else:
        shutil.copy(silent, dst)
    print(dst.name, "written")

if __name__ == "__main__":
    main()
