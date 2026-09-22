# Release notes

One file per version and per language: `<version>.en.md` and `<version>.fr.md`, where
`<version>` is the tag without its `v` (`0.1.1` for `v0.1.1`).

They are what users read in the update window, so they are written for the person who films,
not for a developer: what changes for them, in a sentence or two. No commit hashes, no class
names.

The CI embeds them in the appcast as `<description sparkle:format="markdown" xml:lang="…">`.
Sparkle picks the language the app is shown in — including the choice made in QuiX's own
settings — and renders the Markdown natively, in light or dark mode. The same text becomes the
body of the GitHub release.

**The English file is required.** A tag without `<version>.en.md` fails the release job: an update
window with nothing to say is worse than a release that waits. The French file is optional;
without it, French users see the English notes.

Keep to what Sparkle's Markdown renders well: bold, italics, links, bullet lists, paragraphs.
