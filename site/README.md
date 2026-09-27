# The site — quix.xavier-kain.fr

## What is generated and what is not

`index.html`, `assets/site.js` and `assets/site.css` are **generated** from the designer's export
by [`tools/build-site-from-design.py`](../tools/build-site-from-design.py). Do not edit them by
hand: change the design, then run

```sh
python3 tools/build-site-from-design.py "QuiX site motion design/QuiX Site v2.dc.html"
```

The export runs inside the design tool (a React wrapper, image placeholders, template bindings,
`style-hover` attributes). The script keeps the design's motion code untouched and replaces only
that wrapper. It also changes two behaviours on purpose, both commented in `site.js`: the download
form really posts to `telechargement.php` — the design only played its animation — and it carries
the page language.

The page is written in French in the design; English comes from the dictionary in `site.js`
(`_dict`), applied to the text nodes when the visitor picks EN or when the browser is not in French.

Everything else is written by hand:

| File | Role |
|---|---|
| `telechargement.php` | the download form: validates, records the sign-up, emails the link, starts the download |
| `retour/index.php` | the feedback form the app opens |
| `_mail.php` | readable notification emails, shared by the two forms |
| `.htaccess` | HTTPS, the Sparkle feed redirect, security headers, the Let's Encrypt exception |
| `assets/style.css` | styles of the two PHP pages |
| `assets/thumbs/` | stills from real sessions, used by the hero wall, the library and the download fan |

## Deploying

A push to `main` publishes `site/` over FTPS — see the `site` job in
[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) and
[`Support/deploy-site-ftps.sh`](../Support/deploy-site-ftps.sh).
