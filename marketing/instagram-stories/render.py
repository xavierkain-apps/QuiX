#!/usr/bin/env python3
"""Instagram stories for QuiX: five frames, French and English, 1080 × 1920 PNG.

Written as HTML so the site's look — dark ink, GoPro blue, the headline marked like a HighLight,
the real session stills, the HERO12 diagram — carries over as is, and so the text can change
without redrawing anything. Run it from anywhere:

    python3 marketing/instagram-stories/render.py

The PNGs land in marketing/instagram-stories/out/, which is not committed.
"""
import pathlib
from playwright.sync_api import sync_playwright

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE / "out"
THUMBS = "../../site/assets/thumbs/"
ICON = "../../site/assets/icon-1024.png"

COPY = {
    "fr": {
        "s0_kicker": "Il y a quelques jours, je vous ai demandé",
        "s0_h1": '<span class="count">41</span> d\'entre vous<br><span class="hl">ont dit oui.</span>',
        "s0_yes": "Yes please !!", "s0_no": "Not really …", "s0_yes_n": "41 votes", "s0_no_n": "1 vote",
        "s0_lede": "Alors je l'ai fait. C'est gratuit, et c'est pour vous.",
        "s0_size": 116,
        "s1_h1": 'Tes meilleurs shots,<br><span class="hl">déjà triés.</span>',
        "s1_lede": "L'app gratuite qui trie tes rushs GoPro, toute seule, sur ton Mac.",
        "s2_kicker": "Le vrai problème",
        "s2_h1": '3 heures de rushs.<br><span class="hl">3 moments</span><br>qui comptent.',
        "s2_lede": "Les retrouver, c'est ça qui prend du temps. Pas de les filmer.",
        "s3_kicker": "Pendant que tu filmes",
        "s3_h1": 'Un appui.<br><span class="hl">Un highlight.</span>',
        "s3_lede": "Un appui court sur le bouton du côté, et l'instant est écrit dans la vidéo. Ou dis « GoPro, HighLight ».",
        "gp_shutter": "Déclencheur", "gp_shutter2": "lance l'enregistrement",
        "gp_side": "Power / Mode", "gp_side2": "appui court", "gp_side3": "= HighLight",
        "gp_clip": "Ta vidéo", "gp_mark": "HighLight",
        "s4_kicker": "De retour à la maison",
        "s4_h1": 'Tu branches.<br><span class="hl">C\'est trié.</span>',
        "win_title": "Highlights", "win_path": "Vidéos › GoPro › 2026-09-27 › Highlights",
        "pop_t": "Import terminé", "pop_m": "6 clips — 720 Mo — tous vérifiés",
        "pop_hl": "Highlights", "pop_cl": "Clips", "pop_go": "Ouvrir les highlights",
        "s5_h1": 'Gratuit.<br><span class="hl">Pour Mac.</span>',
        "s5_lede": "Pour GoPro, en USB-C ou avec la carte dans un lecteur.",
        "chips": ["<b>0 €</b>", "Sans compte", "Sans pub", "Sans abonnement"],
        "link_hint": "Télécharge-le ici", "tc": "00:03:27:14",
        "s1_size": 112, "s3_size": 124,
    },
    "en": {
        "s0_kicker": "A few days ago, I asked you",
        "s0_h1": '<span class="count">41</span> of you<br><span class="hl">said yes.</span>',
        "s0_yes": "Yes please !!", "s0_no": "Not really …", "s0_yes_n": "41 votes", "s0_no_n": "1 vote",
        "s0_lede": "So I built it. It's free, and it's yours.",
        "s0_size": 128,
        "s1_h1": 'Skip the rushes.<br><span class="hl">Keep the moments.</span>',
        "s1_lede": "The free app that sorts your GoPro footage on your Mac, all by itself.",
        "s2_kicker": "The real problem",
        "s2_h1": '3 hours of footage.<br><span class="hl">3 moments</span><br>that matter.',
        "s2_lede": "Finding them is what takes time. Not filming them.",
        "s3_kicker": "While you film",
        "s3_h1": 'One press.<br><span class="hl">One highlight.</span>',
        "s3_lede": "A short press on the side button, and the moment is written into the video. Or say “GoPro, HighLight”.",
        "gp_shutter": "Shutter", "gp_shutter2": "starts recording",
        "gp_side": "Power / Mode", "gp_side2": "short press", "gp_side3": "= HighLight",
        "gp_clip": "Your clip", "gp_mark": "HighLight",
        "s4_kicker": "Back home",
        "s4_h1": 'Plug in.<br><span class="hl">It\'s sorted.</span>',
        "win_title": "Highlights", "win_path": "Movies › GoPro › 2026-09-27 › Highlights",
        "pop_t": "Import finished", "pop_m": "6 clips — 720 MB — all checked",
        "pop_hl": "Highlights", "pop_cl": "Clips", "pop_go": "Open highlights",
        "s5_h1": 'Free.<br><span class="hl">For Mac.</span>',
        "s5_lede": "For GoPro, over USB-C or with the card in a reader.",
        "chips": ["<b>Free</b>", "No account", "No ads", "No subscription"],
        "link_hint": "Get it here", "tc": "00:03:27:14",
        # The English headlines run longer; one size smaller keeps each on its intended lines.
        "s1_size": 92, "s3_size": 108,
    },
}

def tile(img, cls="", badge=False, style=""):
    b = '<b class="badge">★ 1</b>' if badge else ""
    return f'<div class="tile {cls}" style="background-image:url({THUMBS}{img}.jpg);{style}">{b}</div>'

HUD = lambda c: f'''<div class="vf"><i class="tl"></i><i class="tr"></i><i class="bl"></i><i class="br"></i></div>
<div class="hud"><span class="rec">REC</span><span class="tc">{c["tc"]}</span></div>'''

CROWD = "assets/crowd-{:02d}.png"


def s0(c):
    """The opening story: the poll Xavier ran before building the app.

    The voters stay anonymous. Their avatars are blurred beyond recognition — colour only, no face,
    no name — because Instagram shows the voter list to the poster alone, and none of them agreed
    to appear in a promotion. The poll itself is Xavier's own story.
    """
    avatars = sorted(pathlib.Path(HERE / "assets").glob("crowd-*.png"))
    order = [(i * 7) % len(avatars) for i in range(41)] if avatars else []
    crowd = "".join(f'<i style="background-image:url(assets/{avatars[k].name})"></i>' for k in order)
    return f'''<section class="story">{HUD(c)}
<div class="content" style="top:330px">
  <div class="kicker">{c["s0_kicker"]}</div>
  <h1 style="font-size:{c["s0_size"]}px">{c["s0_h1"]}</h1>
</div>
<div class="poll"><img src="assets/poll.jpg" alt=""></div>
<div class="bars">
  <div class="bar yes"><span class="fill"></span><b>{c["s0_yes"]}</b><em>98%</em><small>{c["s0_yes_n"]}</small></div>
  <div class="bar no"><span class="fill"></span><b>{c["s0_no"]}</b><em>2%</em><small>{c["s0_no_n"]}</small></div>
</div>
<div class="crowd">{crowd}</div>
<div class="content" style="top:1420px"><p class="lede" style="margin:0; font-size:38px; max-width:26ch">{c["s0_lede"]}</p></div>
</section>'''


def s1(c):
    rows = [["k-sea","h11","wing","h7","para"], ["h4","h1","k-beach","h9","k-water"], ["h5","flare","h10","k-jump","h3"], ["h8","h2","k-sea","wing","h11"]]
    hot = {"h1", "k-jump", "h2"}
    wall = "".join('<div class="row" style="margin-left:%dpx">%s</div>' % (i * -120, "".join(tile(x, "hot" if x in hot else "", x in hot) for x in r)) for i, r in enumerate(rows))
    return f'''<section class="story">
<div class="wall">{wall}</div><div class="fade"></div>{HUD(c)}
<div class="content" style="top:800px; text-align:center">
  <img class="appicon" src="{ICON}" alt="" style="margin:0 auto 40px; display:block">
  <h1 style="font-size:{c["s1_size"]}px">{c["s1_h1"]}</h1>
  <p class="lede" style="margin:36px auto 0; font-size:38px">{c["s1_lede"]}</p>
</div></section>'''

def s2(c):
    pool = ["h4","k-water","h8","h5","h10","h7","h6","k-beach","h9","h3","flare","h11","para","k-sea","h1","wing","h2","k-jump","h8","h4"]
    hot = {1: "k-jump", 6: "h1", 10: "h2"}
    cells = []
    for i in range(12):
        if i in hot: cells.append(tile(hot[i], "hot", True))
        else: cells.append(tile(pool[i], "dim"))
    return f'''<section class="story">{HUD(c)}
<div class="content" style="top:380px">
  <div class="kicker">{c["s2_kicker"]}</div>
  <h1 style="font-size:100px">{c["s2_h1"]}</h1>
</div>
<div class="grid">{"".join(cells)}</div>
<div class="content" style="top:1330px"><p class="lede" style="margin:0; font-size:36px">{c["s2_lede"]}</p></div>
</section>'''

def gopro(c):
    return f'''<svg viewBox="0 0 960 700">
  <defs><radialGradient id="halo"><stop offset="0" stop-color="#00A3E4" stop-opacity=".55"/><stop offset="1" stop-color="#00A3E4" stop-opacity="0"/></radialGradient></defs>
  <text x="380" y="40" fill="#F2F0EC" font-size="36" font-weight="700" text-anchor="middle" font-family="Archivo">{c["gp_shutter"]}</text>
  <text x="380" y="82" fill="rgba(242,240,236,.55)" font-size="26" text-anchor="middle" font-family="JetBrains Mono">{c["gp_shutter2"]}</text>
  <path d="M380 96 V140" stroke="rgba(255,255,255,.35)" stroke-width="3" stroke-dasharray="6 8"/>
  <rect x="330" y="132" width="100" height="26" rx="10" fill="#2B2B31" stroke="rgba(255,255,255,.2)" stroke-width="2"/>
  <rect x="356" y="126" width="48" height="14" rx="7" fill="#E8453C"/>
  <rect x="120" y="150" width="520" height="380" rx="52" fill="#1D1D22" stroke="rgba(255,255,255,.18)" stroke-width="3"/>
  <circle cx="652" cy="262" r="76" fill="url(#halo)"/>
  <circle cx="652" cy="262" r="48" fill="none" stroke="#00A3E4" stroke-width="3" stroke-opacity=".6"/>
  <rect x="634" y="222" width="34" height="80" rx="14" fill="#00A3E4"/>
  <path d="M704 262 H750" stroke="rgba(255,255,255,.35)" stroke-width="3" stroke-dasharray="6 8"/>
  <text x="760" y="250" fill="#F2F0EC" font-size="34" font-weight="700" font-family="Archivo">{c["gp_side"]}</text>
  <text x="760" y="290" fill="#5BBDEE" font-size="27" font-family="JetBrains Mono">{c["gp_side2"]}</text>
  <text x="760" y="326" fill="#5BBDEE" font-size="27" font-family="JetBrains Mono">{c["gp_side3"]}</text>
  <rect x="164" y="194" width="186" height="156" rx="18" fill="#0B0C10" stroke="rgba(255,255,255,.1)"/>
  <circle cx="198" cy="232" r="10" fill="#FF4B3E"/>
  <text x="218" y="242" fill="#FF6B60" font-size="26" font-weight="700" font-family="JetBrains Mono">REC</text>
  <text x="257" y="310" fill="rgba(242,240,236,.9)" font-size="40" text-anchor="middle" font-family="JetBrains Mono">00:42</text>
  <circle cx="176" cy="490" r="7" fill="#FF4B3E"/>
  <text x="200" y="499" fill="rgba(242,240,236,.3)" font-size="28" font-weight="700" font-family="Archivo">GoPro</text>
  <rect x="384" y="186" width="220" height="220" rx="36" fill="#121216" stroke="rgba(255,255,255,.1)" stroke-width="2"/>
  <circle cx="494" cy="296" r="80" fill="#0B0C10" stroke="rgba(255,255,255,.14)" stroke-width="3"/>
  <circle cx="494" cy="296" r="54" fill="#04060B" stroke="rgba(0,163,228,.5)" stroke-width="3"/>
  <circle cx="474" cy="276" r="14" fill="rgba(169,220,245,.35)"/>
  <text x="120" y="600" fill="rgba(242,240,236,.5)" font-size="26" font-family="JetBrains Mono">{c["gp_clip"]}</text>
  <rect x="120" y="620" width="520" height="22" rx="11" fill="rgba(255,255,255,.1)"/>
  <rect x="120" y="620" width="300" height="22" rx="11" fill="#00A3E4"/>
  <path d="M404 668 l16 -22 l16 22 z" fill="#00A3E4"/>
  <text x="420" y="700" fill="#5BBDEE" font-size="27" text-anchor="middle" font-family="JetBrains Mono">★ {c["gp_mark"]}</text>
</svg>'''

def s3(c):
    return f'''<section class="story">{HUD(c)}
<div class="content" style="top:380px">
  <div class="kicker">{c["s3_kicker"]}</div>
  <h1 style="font-size:{c["s3_size"]}px">{c["s3_h1"]}</h1>
</div>
<div class="gp">{gopro(c)}</div>
<div class="content" style="top:1390px"><p class="lede" style="margin:0; font-size:33px; max-width:36ch">{c["s3_lede"]}</p></div>
</section>'''

def s4(c):
    files = [("h1", "GX010042.MP4"), ("k-jump", "GX010044.MP4"), ("h2", "GX010046.MP4")]
    body = "".join(f'<div class="file">{tile(i, badge=True)}{n}</div>' for i, n in files)
    return f'''<section class="story">{HUD(c)}
<div class="content" style="top:380px">
  <div class="kicker">{c["s4_kicker"]}</div>
  <h1 style="font-size:124px">{c["s4_h1"]}</h1>
</div>
<div class="win"><div class="bar"><i style="background:#FF5F57"></i><i style="background:#FEBC2E"></i><i style="background:#28C840"></i><b>{c["win_title"]}</b></div>
  <div class="body">{body}</div><div class="path">{c["win_path"]}</div></div>
<div class="pop"><div class="t">{c["pop_t"]}</div><div class="m">{c["pop_m"]}</div>
  <div class="tiles"><div class="n blue"><b>3</b>{c["pop_hl"]}</div><div class="n"><b>3</b>{c["pop_cl"]}</div></div>
  <div class="go">{c["pop_go"]}</div></div>
</section>'''

def s5(c):
    fan = [("wing", -24), ("h2", -12), ("h1", 0), ("k-jump", 12), ("para", 24)]
    cards = "".join(tile(i, style=f"transform:rotate({a}deg)") for i, a in fan)
    chips = " · ".join(c["chips"])
    return f'''<section class="story">{HUD(c)}
<div class="fan">{cards}</div>
<div class="content" style="top:650px; text-align:center">
  <img class="appicon" src="{ICON}" alt="" style="margin:0 auto 34px; display:block; position:relative">
  <h1 style="font-size:132px">{c["s5_h1"]}</h1>
  <p class="lede" style="margin:30px auto 0; font-size:36px">{c["s5_lede"]}</p>
  <p class="chipline">{chips}</p>
</div>
<div class="link"><div class="hint">{c["link_hint"]} <span class="arrow">↓</span></div><div class="url">quix.xavier-kain.fr</div></div>
</section>'''

def page(lang):
    c = COPY[lang]
    return f'''<!DOCTYPE html><html lang="{lang}"><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Archivo:wdth,wght@62..125,400..900&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
<link rel="stylesheet" href="stories.css"></head><body>
{s0(c)}{s1(c)}{s2(c)}{s3(c)}{s4(c)}{s5(c)}
</body></html>'''

def main():
    OUT.mkdir(exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(args=["--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu"])
        for lang in COPY:
            path = HERE / f"stories-{lang}.html"
            path.write_text(page(lang), encoding="utf-8")
            tab = browser.new_page(viewport={"width": 1080, "height": 1920}, device_scale_factor=1)
            tab.goto(path.as_uri(), wait_until="networkidle")
            tab.evaluate("document.fonts.ready")
            tab.wait_for_timeout(600)
            # Story 0 is the poll that opens the series; 1 to 5 follow.
            for i, story in enumerate(tab.locator(".story").all(), 0):
                story.screenshot(path=str(OUT / f"quix-story-{lang}-{i}.png"))
            tab.close()
            print(f"{lang}: 6 stories → {OUT.relative_to(HERE.parent.parent)}/")
        browser.close()


if __name__ == "__main__":
    main()
