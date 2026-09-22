# Updates

QuiX is distributed outside the App Store. With no update mechanism, a broken version stays
installed on everyone's machine until each of them goes back to the site of their own accord —
which is to say, never. **Sparkle 2** handles it: the app checks once a day, announces what the
version brings, downloads and installs.

## The signature, which is the whole subject

An automatic update is a way to run code on someone else's machine. Two independent signatures
protect that path, and they do not say the same thing:

- **Developer ID + notarization**, from Apple: Gatekeeper agrees to open the app.
- **EdDSA, from Sparkle**: the *already installed* app checks that the archive it just downloaded
  really came from us. `SUPublicEDKey` is written into the `Info.plist`; any archive signed with
  another key is refused, whatever it claims to be.

The practical consequence: **someone who took over the server could not make their own binary be
installed.** At worst, they could prevent updates.

## Where the keys live

| | Where | Who touches it |
|---|---|---|
| EdDSA private key | Xavier's keychain, and the repository's `SPARKLE_PRIVATE_KEY` secret | nobody else |
| EdDSA public key | `Support/Info.plist`, in plain sight | everyone, that is the point |
| Developer ID certificate | the `MACOS_CERT_P12` secrets and friends | see [SIGNING.md](../SIGNING.md) |

The private key was produced by Sparkle's `generate_keys` and **was never displayed**. To export
it in order to feed the secret:

```sh
build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -x private-key.txt
gh secret set SPARKLE_PRIVATE_KEY --repo xavierkain-apps/QuiX < private-key.txt
rm private-key.txt
```

Losing that key cannot be fixed remotely: installed apps would refuse any update signed with a new
key, and everyone would have to reinstall by hand.

## The nested-signature trap

Xcode signs the Sparkle framework it embeds, **but not what is inside it**. Sparkle carries an
updater app, an installer tool and two XPC services, all signed by the Sparkle project and without
a secure timestamp. Apple refuses the whole bundle, with a message that does not say where the
problem comes from:

```
The binary is not signed with a valid Developer ID certificate.
The signature does not include a secure timestamp.
```

[Support/sign-sparkle.sh](../Support/sign-sparkle.sh) re-signs them from the inside out, keeping
their entitlements — the XPC services have some, and losing them would stop them starting.
`codesign --deep` does not do the job: it does not replay each component's entitlements.

CI runs it after the build, then **verifies** that no nested executable carries a foreign
signature any more. Learning it there costs a second; learning it from the notarization service
costs two minutes.

## Publishing a version

```sh
# 1. The number, in the two places that matter
#    MARKETING_VERSION        → what the user reads
#    CURRENT_PROJECT_VERSION  → what Sparkle compares, to increment every time
# 2. The notes users will read in the update window
#    release-notes/1.0.0.en.md   (required — the release job fails without it)
#    release-notes/1.0.0.fr.md   (optional — French users fall back to English)
# 3. A tag
git tag v1.0.0 && git push origin v1.0.0
```

CI builds, signs, notarizes, staples, **signs the update**, writes `appcast.xml` with the notes
embedded, and publishes the release with both files. The same notes become the body of the GitHub
release. How to write them: [release-notes/README.md](../release-notes/README.md).

## How the feed reaches the app

`SUFeedURL` is `https://quix.xavier-kain.fr/appcast.xml`. The site's `.htaccess` redirects that
address to the `appcast.xml` attached to the latest GitHub release, so publishing a version never
requires redeploying the site. Requests for it give the number of active installs and the spread
of versions, without a line of tracking in the app.

The update window shows the notes from the feed itself — one `<description>` per language, in
Markdown, which Sparkle renders natively and picks according to the language the app is shown in.
It used to show `sparkle:releaseNotesLink`, a GitHub page loaded in a web view; that link is gone.

## When the update window says "An error occurred in retrieving update information"

Sparkle gives the same message for every failure. Two causes have produced it here:

- **A feed that is not well-formed XML.** `sign_update` prints `length="…"` next to the signature,
  and the enclosure wrote its own: a duplicate attribute. The job now strips it and runs
  `xmllint` before publishing. A broken feed can be repaired in place with
  `gh release upload <tag> appcast.xml --clobber` — the signature covers the ZIP, not the feed.
- **An invalid HTTPS certificate on the feed's address.** Sparkle verifies it strictly.

Check both with `curl -sSL https://quix.xavier-kain.fr/appcast.xml | xmllint --noout -` — no
`-k`, so the certificate is checked too.
