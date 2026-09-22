#!/bin/bash
# Publishes site/ to the web host over SSH.
#
#   Support/deploy-site.sh <user@host> <remote path>
#
# rsync with --delete, so the remote directory ends up as an exact copy of site/. Three paths are
# excluded on purpose: the registers written by the PHP endpoints live one level above the web
# root, but if anyone ever moves them down, --delete must not wipe them; and .well-known holds the
# Let's Encrypt challenge, which the host writes into the document root. A deploy landing in the
# middle of a certificate issuance must not delete it.
#
# The download file itself is never uploaded: it lives on the GitHub releases, and the page only
# links to it.
set -euo pipefail

TARGET="${1:?usage: deploy-site.sh <user@host> <remote path>}"
REMOTE="${2:?usage: deploy-site.sh <user@host> <remote path>}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

[ -f "$HERE/site/index.html" ] || { echo "site/index.html missing — wrong directory?"; exit 1; }

echo "Publishing $HERE/site/ to $TARGET:$REMOTE"
rsync -az --delete --human-readable \
  --exclude ".DS_Store" \
  --exclude "*.jsonl" \
  --exclude ".well-known" \
  --chmod=D755,F644 \
  "$HERE/site/" "$TARGET:$REMOTE/"

# The PHP endpoints write one level above the web root. Create it once, and keep it unreadable
# from the web whatever the server's default umask says.
ssh "$TARGET" "cd '$REMOTE/..' && touch quix-inscriptions.jsonl quix-retours.jsonl && chmod 600 quix-inscriptions.jsonl quix-retours.jsonl"

echo "Done. Check https://quix.xavier-kain.fr/"
