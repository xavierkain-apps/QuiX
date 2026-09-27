#!/usr/bin/env python3
"""Turn the designer's export (a .dc.html file) into the production site.

The export runs inside the design tool's runtime: a React wrapper (support.js), image
placeholders (image-slot.js), template bindings such as onClick="{{ press }}", conditional
<sc-if> blocks and style-hover attributes. None of that can be served as is. The motion itself
is plain DOM and requestAnimationFrame code, so this script keeps it untouched and only replaces
the wrapper:

  markup   -> site/index.html   bindings become data-action attributes, <sc-if> becomes data-if,
                                <image-slot> becomes a plain div with its image, style-hover and
                                style-focus become CSS rules
  logic    -> site/assets/site.js   the Component class, detached from React, mounted on #top
  styles   -> site/assets/site.css  the design's base styles plus the generated hover rules

Three behaviours are changed on purpose, all marked in site.js: the download form really submits
to telechargement.php (the design only played its animation), it carries the page language, and
English is the default. The design is written in French and translated to English at runtime;
the build writes the page in English instead and inverts the dictionary, so French is what gets
applied at runtime — only for browsers set to French. Visitors, search engines and link previews
all get English first, with no flash of French.

Usage: tools/build-site-from-design.py "QuiX site motion design/QuiX Site v2.dc.html"
Re-run it whenever the designer delivers a new version.
"""
import html, json, pathlib, re, sys

src = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
root = pathlib.Path(__file__).resolve().parent.parent
out = root / "site"

head = re.search(r"<helmet>(.*?)</helmet>", src, re.S).group(1)
markup = re.search(r"</helmet>(.*?)</x-dc>", src, re.S).group(1)
logic = re.search(r'<script type="text/x-dc"[^>]*>(.*?)</script>', src, re.S).group(1)

# ── Head ──────────────────────────────────────────────────────────────────────
base_css = re.search(r"<style>(.*?)</style>", head, re.S).group(1).strip()
fonts = re.search(r'<link href="(https://fonts.googleapis.com/css2[^"]+)"', head).group(1)
title = re.search(r"<title>(.*?)</title>", head).group(1)

# ── Markup ────────────────────────────────────────────────────────────────────
m = markup
m = m.replace('ref="{{ rootRef }}" ', "")
m = re.sub(r'onClick="\{\{ (\w+) \}\}"', r'data-action="\1"', m)
m = re.sub(r'onSubmit="\{\{ (\w+) \}\}"', r'data-action-submit="\1" id="gate"', m)
m = re.sub(r'defaultChecked="\{\{ true \}\}"', "checked", m)
m = re.sub(r'required="\{\{ true \}\}"', "required", m)
# JSX attribute spellings. HTML is case-insensitive about them, but checked is not an alias.
m = m.replace("autoComplete=", "autocomplete=").replace("maxLength=", "maxlength=").replace("tabIndex=", "tabindex=")

# <sc-if>: the HUD is always on; the two form states are toggled by site.js.
m = re.sub(r'<sc-if value="\{\{ showHud \}\}"[^>]*>(.*?)</sc-if>', r"\1", m, flags=re.S)
m = re.sub(r'<sc-if value="\{\{ notSent \}\}"[^>]*>(.*?)</sc-if>', r'<span data-if="notSent">\1</span>', m, flags=re.S)
m = re.sub(r'<sc-if value="\{\{ sent \}\}"[^>]*>(.*?)</sc-if>', r'<span data-if="sent" hidden>\1</span>', m, flags=re.S)

# <image-slot> -> a div carrying its picture.
def slot(match):
    attrs = match.group(1)
    sid = re.search(r'id="([^"]+)"', attrs).group(1)
    img = re.search(r'src="([^"]+)"', attrs).group(1)
    style = re.search(r'style="([^"]*)"', attrs).group(1)
    return (f'<div id="{sid}" role="img" style="{style} background:#1C1B21 center/cover no-repeat '
            f'url(\'{img}\');"></div>')
m = re.sub(r"<image-slot([^>]*)>.*?</image-slot>", slot, m, flags=re.S)

# style-hover / style-focus -> generated classes. Inline styles outrank any class rule, so every
# declaration is marked !important.
rules = []
def interactive(match, kind):
    decls = [d.strip() for d in html.unescape(match.group(1)).split(";") if d.strip()]
    cls = f"{kind[0]}x{len(rules)}"
    body = "; ".join(d if "!important" in d else d + " !important" for d in decls)
    rules.append(f".{cls}:{'hover' if kind == 'hover' else 'focus'} {{ {body}; }}")
    return f'data-cls="{cls}"'
m = re.sub(r'style-hover="([^"]*)"', lambda x: interactive(x, "hover"), m)
m = re.sub(r'style-focus="([^"]*)"', lambda x: interactive(x, "focus"), m)
# Merge the generated class into the element's class attribute, or add one.
def merge(tag):
    t = tag.group(0)
    cls = re.findall(r'data-cls="([^"]+)"', t)
    if not cls:
        return t
    t = re.sub(r'\s*data-cls="[^"]+"', "", t)
    if ' class="' in t:
        return t.replace(' class="', ' class="' + " ".join(cls) + " ", 1)
    return re.sub(r"^<([\w-]+)", lambda x: f'<{x.group(1)} class="{" ".join(cls)}"', t)
m = re.sub(r"<[\w-]+\b[^>]*data-cls=[^>]*>", merge, m)

m = m.replace("site/assets/", "assets/")

# ── English by default ────────────────────────────────────────────────────────
DICT_RE = r"_dict\(\) \{\s*return (\{.*?\});\s*\}"
fr_to_en = json.loads(re.search(DICT_RE, logic, re.S).group(1))
en_to_fr = {en: fr for fr, en in fr_to_en.items()}
if len(en_to_fr) != len(fr_to_en):
    sys.exit("two French strings share one English translation: the dictionary cannot be inverted")
# Text the motion code rewrites on every frame through _t(), so absent from the dictionary. Only
# its first, static state has to be English.
STATIC_ONLY = {"vérifié": "verified"}

translated = 0
def to_english(match):
    global translated
    raw = match.group(1)
    text = html.unescape(raw)
    key = text.strip()
    en = fr_to_en.get(key) or STATIC_ONLY.get(key)
    if not en:
        return match.group(0)
    translated += 1
    return ">" + html.escape(text.replace(key, en), quote=False) + "<"
m = re.sub(r">([^<]+)<", to_english, m)
french_left = sorted(set(t.strip() for t in re.findall(r">([^<]+)<", m)
                         if re.search(r"[éèàùçêôœ]", html.unescape(t))))
if french_left:
    sys.exit(f"French text left in the English page: {french_left[:8]}")

leftover = re.findall(r"\{\{[^}]*\}\}|<sc-if|<image-slot|style-hover|style-focus", m)
if leftover:
    sys.exit(f"unconverted design-tool syntax left in the markup: {sorted(set(leftover))}")

page = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>QuiX — free GoPro importer for Mac that sorts your highlights</title>
<meta name="description" content="Press the button on your GoPro when something good happens. QuiX finds those moments and puts the clips in their own folder, automatically. Free, for Mac.">
<link rel="icon" href="assets/favicon.png">
<meta property="og:title" content="QuiX — skip the rushes, keep the moments">
<meta property="og:description" content="Press the button while you film. QuiX does the rest. Free, for Mac.">
<meta property="og:image" content="https://quix.xavier-kain.fr/assets/icon-1024.png">
<meta property="og:type" content="website">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="{fonts}" rel="stylesheet">
<link rel="stylesheet" href="assets/site.css">
<!-- Plausible: cookieless visit counts, no personal data. See docs/STATS.md. -->
<script defer data-domain="quix.xavier-kain.fr" src="https://plausible.io/js/script.js"></script>
<script>window.plausible=window.plausible||function(){{(window.plausible.q=window.plausible.q||[]).push(arguments)}}</script>
</head>
<body>
<!-- Generated by tools/build-site-from-design.py from the designer's export. Edit the design and
     re-run the script rather than editing this file by hand. -->
{m.strip()}
<script src="assets/site.js"></script>
</body>
</html>
"""
(out / "index.html").write_text(page, encoding="utf-8")

css = ("/* Generated by tools/build-site-from-design.py. */\n\n" + base_css +
       "\n\n/* Hover and focus states, from the design's style-hover / style-focus attributes. */\n" +
       "\n".join(rules) + "\n\n[hidden] { display: none !important; }\n")
(out / "assets" / "site.css").write_text(css, encoding="utf-8")

# ── Logic ─────────────────────────────────────────────────────────────────────
js = logic.strip()
js = js.replace("class Component extends DCLogic {", "class QuixSite {", 1)
js = js.replace("  rootRef = React.createRef();\n", "", 1)
js = js.replace("site/assets/", "assets/")
# The page is English now: the dictionary maps English to French, and translating happens when the
# visitor is French rather than English. (The variable keeps the design's name `fr`; it now holds
# the English original.)
js = re.sub(DICT_RE, lambda x: "_dict() {\n    return " + json.dumps(en_to_fr, ensure_ascii=False, indent=6)[:-1] + "    };\n  }", js, count=1, flags=re.S)
APPLY = "const k = fr.trim(), v = en ? fr.replace(k, d[k]) : fr;"
if APPLY not in js:
    sys.exit("the design's _applyLang changed: update the English-by-default patch")
js = js.replace(APPLY, "const k = fr.trim(), v = en ? fr : fr.replace(k, d[k]);  // page is English; translate for French")
FALLBACK = "(navigator.language || 'fr')"
if FALLBACK not in js:
    sys.exit("the design's language fallback changed: update the English-by-default patch")
js = js.replace(FALLBACK, "(navigator.language || 'en')")
if "React." in js or "DCLogic" in js:
    sys.exit("the logic still references the design runtime")

bootstrap = r"""
// ── Runtime ───────────────────────────────────────────────────────────────────
// What the design tool used to provide around the class above: a root element, default props,
// setState, and event wiring for the data-action attributes the build script left in the markup.
QuixSite.prototype.setState = function (patch) {
  Object.assign(this.state, patch);
  document.querySelectorAll("[data-if]").forEach((el) => {
    el.hidden = !this.renderVals()[el.getAttribute("data-if")];
  });
};

(function mount() {
  const root = document.getElementById("top");
  if (!root) return;
  const site = new QuixSite();
  site.rootRef = { current: root };
  site.props = { showHud: true, intensity: 1, autoHighlight: true };
  site.componentDidMount();

  const actions = site.renderVals();
  document.querySelectorAll("[data-action]").forEach((el) => {
    const fn = actions[el.getAttribute("data-action")];
    if (fn) el.addEventListener("click", fn);
  });

  // The design only played its animation on submit. Here the form really goes out: the page
  // language rides along so the confirmation and the email answer in it, the animation plays,
  // and the form is posted to telechargement.php — which records the sign-up, sends the link by
  // email and starts the download. Without JavaScript the form posts on its own, unchanged.
  const form = document.getElementById("gate");
  if (form) {
    form.addEventListener("submit", (ev) => {
      ev.preventDefault();
      if (!form.reportValidity()) return;
      let lang = form.querySelector('input[name="langue"]');
      if (!lang) {
        lang = document.createElement("input");
        lang.type = "hidden";
        lang.name = "langue";
        form.appendChild(lang);
      }
      lang.value = site.lang;
      site._burst();
      site.setState({ sent: true });
      setTimeout(() => form.submit(), site.reduced ? 0 : 650);
    });
  }
})();
"""
header = """// Generated by tools/build-site-from-design.py from the designer's export.
// The class below is the design's own motion code, unchanged apart from being detached from the
// design tool's React wrapper. The runtime at the bottom replaces that wrapper.
"use strict";
"""
(out / "assets" / "site.js").write_text(header + js + "\n" + bootstrap, encoding="utf-8")

print(f"index.html  {len(page):>7} bytes")
print(f"site.js     {len(header + js + bootstrap):>7} bytes")
print(f"site.css    {len(css):>7} bytes, {len(rules)} hover/focus rules")
print(f"English     {translated} text nodes translated at build time, {len(en_to_fr)} French strings for runtime")
