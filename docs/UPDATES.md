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
# 2. A tag, and that is all
git tag v1.0.0 && git push origin v1.0.0
```

CI builds, signs, notarizes, staples, **signs the update**, writes `appcast.xml` and publishes the
release with both files.

## What is left to connect

`SUFeedURL` points at `https://quix.xavier-kain.fr/appcast.xml`, which does not exist yet. CI, for
its part, publishes the appcast as a file of the GitHub release. The site has to serve that file —
the simplest way is a redirect to the latest release's URL, which avoids redeploying the site for
every version.

Until then, a manual update check fails with "An error occurred while retrieving update
information". That is expected, not a bug.

As a bonus, requests for that file give the **number of active installs and the spread of
versions**, without a line of tracking in the app.
