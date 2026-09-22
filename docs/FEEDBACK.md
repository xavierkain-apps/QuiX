# Receiving feedback from users

Two buttons, in Settings and in the Help menu: **Report a bug** and **Suggest a feature**. Each
opens, in the browser, the form at
[quix.xavier-kain.fr/retour](https://quix.xavier-kain.fr/retour), with the technical context
already filled in.

## Why a web page

**Not a form inside the app**: it would carry text through QuiX that the user had not seen leave,
and it would force the app to hold a privacy policy. The page shows what will be sent before they
press anything. Nothing leaves the Mac without a click of theirs.

**Not GitHub either**, even though the repository is public and issues would file themselves. A
GitHub account is a wall for someone who came from Instagram to sort their clips. The server can
open the issue on their behalf.

## What the app puts in the URL

```
?type=bug&version=0.1.0+(1)&os=26.6.2&mac=Mac16,6&lang=fr_FR&camera=HERO12+Black
```

Versions and models, nothing else. **Never a path, never a file name, never an address**:
whatever goes through a URL ends up in the server's logs.

Each of those fields earns its place:

- **the QuiX version**, without which we fix a bug that is already fixed;
- **the macOS version**, because permissions and notifications change behaviour from one release
  to the next — [NOTIFICATIONS.md](NOTIFICATIONS.md) is a demonstration of exactly that;
- **the Mac model**, because a USB copy fault can come down to the controller. Hundreds of
  thousands of Macs carry the same identifier: it identifies nobody;
- **the camera model**, the most important of all. The HiLight format has only ever been measured
  on a HERO12 Black — see [HILIGHT.md](HILIGHT.md). A report without the model leads nowhere.

The Settings screen shows those lines exactly as they will be sent: one should be able to read
what one is sending before sending it.

## What is left to build on the server

The form does not exist yet: the link leads to a missing page. It needs a free-text field, an
**optional** email field — to be able to reply, not to build a mailing list — and a way to attach
a screenshot. Behind it, a GitHub issue opened by the server, labelled `bug` or `enhancement`
according to `type`.
