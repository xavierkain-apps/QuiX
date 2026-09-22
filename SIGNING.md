# Signing and notarization

CI signs and notarizes the app **as soon as the five secrets exist**. Without them it still
produces a bundle, ad-hoc signed: it launches, but Gatekeeper warns on first start on any machine
that did not build it.

QuiX lives in the **`xavierkain-apps`** organisation, alongside FCP CleanX. The goal is for the
secrets to be set there **once and for all**, at organisation level, so that each new app is
signed without copying anything around.

## Producing the five values

To be done on the Mac. Nothing to redo if FCP CleanX's `.p12` was kept: the same certificate signs
every app distributed outside the App Store.

**1. The certificate.** Xcode ▸ Settings ▸ Accounts ▸ the Apple ID ▸ **Manage Certificates…** ▸
**+** ▸ **Developer ID Application**. Then Keychain Access ▸ "My Certificates" ▸ right-click
"Developer ID Application: …" ▸ **Export…** ▸ `.p12` format ▸ choose a password.

**2. Encode it**, because a GitHub secret only takes text:

```sh
base64 -i certificate.p12 | pbcopy
```

CI also accepts hexadecimal (`xxd -p certificate.p12 | pbcopy`): the same bytes either way, and it
recognises which of the two it received. What it cannot guess is a `.cer` downloaded from the Apple
portal — that one does not contain the private key.

**3. The app-specific password.** https://account.apple.com ▸ Sign-In and Security ▸
**App-Specific Passwords** ▸ create one, name it "CI macOS apps". This is **not** the Apple ID
password.

**4. The team identifier.** https://developer.apple.com/account ▸ Membership details, ten
characters.

| Secret | Contents |
|---|---|
| `MACOS_CERT_P12` | The `.p12`, base64 encoded (step 2) |
| `MACOS_CERT_PASSWORD` | The password chosen at export |
| `APPLE_ID` | The Apple ID, in plain text |
| `APPLE_APP_PASSWORD` | The app-specific password (step 3) |
| `APPLE_TEAM_ID` | The team identifier (step 4) |

A sixth secret lives on the repository itself rather than the organisation, because it is specific
to this app: `SPARKLE_PRIVATE_KEY`, which signs updates. See [docs/UPDATES.md](docs/UPDATES.md).

## Where to put them — at organisation level

https://github.com/organizations/xavierkain-apps/settings/secrets/actions ▸ **New organization
secret**, five times.

For each one, **Repository access: Public repositories**.

It is the only choice available: the organisation is on the **Free** plan, where GitHub states
plainly that "Organization secrets cannot be used by private repositories with your plan". That is
why QuiX is a **public** repository. The fixtures were audited before it was opened — see below.

From the command line, if you prefer — the token has to be widened first, since `gh` does not ask
for the `admin:org` scope by default:

```sh
gh auth refresh -h github.com -s admin:org

base64 -i certificate.p12 | gh secret set MACOS_CERT_P12 --org xavierkain-apps --visibility all
gh secret set MACOS_CERT_PASSWORD --org xavierkain-apps --visibility all
gh secret set APPLE_ID            --org xavierkain-apps --visibility all
gh secret set APPLE_APP_PASSWORD  --org xavierkain-apps --visibility all
gh secret set APPLE_TEAM_ID       --org xavierkain-apps --visibility all
```

(`--visibility all` means "every repository the plan allows", which here means the public ones.)

## Checking

Push a commit. In the "App — bundle macOS" job, the **Import the Developer ID certificate** and
**Notarize** steps must **appear instead of being skipped**, and the verification step must get
`accepted` from `spctl --assess`. It is an unambiguous signal: either both steps run, or they are
greyed out.

## Three traps met, and settled

**The certificate may arrive in hexadecimal.** `xxd -p certificate.p12` and
`base64 -i certificate.p12` carry the same bytes; CI recognises which it received. What it rightly
refuses is a `.cer` from the Apple portal — no private key in it.

**`xcodebuild build` injects a debugging entitlement.** `com.apple.security.get-task-allow` lets a
debugger attach to the process: normal in development, refused by Apple at notarization.
`CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` strips it, and the verification checks for it before every
submission — one second here rather than a two-minute round trip to Apple for a message that does
not say how to get rid of it.

**Sparkle's nested executables keep their own signature.** Xcode signs the framework it embeds,
but not the updater app, the installer tool or the two XPC services inside it. Apple refuses the
whole bundle over them. [Support/sign-sparkle.sh](Support/sign-sparkle.sh) re-signs them from the
inside out, and CI then verifies that no nested executable carries a foreign signature.

## What a public repository changes

**The certificate stays out of reach.** GitHub withholds secrets from any change proposed by a
fork, and the workflow adds an explicit guard: the signing steps only run on a `push`, never on a
`pull_request`. The token's write permission is narrowed to the single job that publishes a
release.

**Minutes become free.** Standard runners have no quota on a public repository, macOS included.
The organisation's 2,000 monthly minutes no longer apply to QuiX — only to the repositories that
stayed private.

**The fixtures were cleaned.** See
[Core/Tests/QuiXCoreTests/Fixtures/README.md](Core/Tests/QuiXCoreTests/Fixtures/README.md): the
camera and lens serial numbers, and the body's binary fingerprint, were replaced with zeros before
the repository was opened — rewritten git history included. No GPS data was ever present:
telemetry lives in the `mdat`, which is not in the fixtures.

## What the secrets do not do on their own

A new app in the organisation is signed automatically **provided it has the workflow**. The
secrets sign nothing; `.github/workflows/ci.yml` is what uses them. For a next app, copying QuiX's
"App — bundle macOS" job and replacing the project, scheme and bundle names is enough — it is the
only file to carry over.

## For the next app

If it is public, it inherits the five secrets with no effort, and its minutes are free.

If it has to stay private, organisation secrets will not reach it: they will have to be set on its
own repository, as FCP CleanX does today, or the organisation moved to the Team plan.
