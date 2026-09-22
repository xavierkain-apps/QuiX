# The site — quix.xavier-kain.fr

Everything the site needs is in [`site/`](../site). It is a static page plus two PHP endpoints:
no framework, no build step, no tracker. The only external request is Google Fonts.

| | |
|---|---|
| `index.html` | the landing page |
| `assets/` | stylesheet, the two scripts, the icon |
| `shots/en/`, `shots/fr/` | **real captures of the real app**, one set per language |
| `telechargement.php` | the download gate: first name, email, then the link |
| `retour/index.php` | the feedback form the app opens from Settings and the Help menu |
| `.htaccess` | HTTPS, security headers, and the Sparkle appcast redirect |

## The screenshots follow the language

Showing an English interface under French copy makes the app look half-translated. There are two
sets, and the language switch changes both text and images.

They are produced by running the app with `-AppleLanguages` **and** `-AppleLocale`: the language
alone leaves the number formatting on the system locale, and "720,2 MB" mixes two conventions in
one line.

The library tab is not on the page. The test card's clips carry no video track, so its thumbnails
come out as empty placeholders — true, but not worth showing. The menu-bar popover takes that
slot instead.

## What the two endpoints do, and do not do

**Nothing personal travels in a URL.** The app passes four fields to the feedback form — QuiX
version, macOS version, Mac model, camera model — and the form refuses any character outside
`A-Za-z0-9 ._()+,:-` in them rather than escaping HTML that has no business being there. See
[FEEDBACK.md](FEEDBACK.md).

**The registers live outside the web root**, one directory above, and `.htaccess` denies `.jsonl`
as a second belt in case anyone ever moves them down.

**The download file is never served from here.** It stays on the GitHub releases, which handle
the bandwidth and the versioning. The page only links to
`releases/latest/download/QuiX.zip`, an address that does not change from one version to the next.

Both forms carry a hidden field that only a robot fills in.

## Publishing

```sh
Support/deploy-site.sh user@host /path/to/public_html
```

`rsync --delete`, so the remote directory becomes an exact copy of `site/`. CI does the same on
every push to `main`, as soon as four secrets exist: `SITE_SSH_KEY`, `SITE_SSH_TARGET`,
`SITE_SSH_PATH` and `SITE_KNOWN_HOSTS`. Until then the job reports that it skipped, rather than
failing a build over a site.

The host key is pinned through `SITE_KNOWN_HOSTS` instead of being trusted on first use: a deploy
that silently accepts a new key is a deploy that can be pointed somewhere else.

## What is missing before it can go live

1. **A DNS record for `quix.xavier-kain.fr`.** The name does not resolve at all today. The parent
   domain answers on 109.234.164.181.
2. **An account on that host.** The SSH config on the Mac reaches a different hosting account,
   for the `xavierkain.fr` domain — not this one.

Both of those are Xavier's to do; neither can be worked around from here. Everything else is
ready and tested locally against a PHP server: the form validations, the honeypot, the registers,
and both languages.
