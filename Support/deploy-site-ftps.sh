#!/bin/bash
# Publishes site/ to the web host over FTPS. This is the path the CI uses.
#
# Why not SSH, like Support/deploy-site.sh does from a workstation: the host firewalls port 22
# against cloud address ranges. A GitHub runner reaches port 21 and nothing else — measured, not
# assumed. FTPS is therefore the only way in from CI.
#
# The connection goes to the *server* name rather than the account name, because that is what the
# FTP certificate is issued for. That keeps certificate verification on instead of turning it off.
#
# Credentials come from the environment:
#   SITE_FTP_HOST      the server, e.g. bretelle.o2switch.net
#   SITE_FTP_USER      the FTP account, scoped to the site's document root
#   SITE_FTP_PASSWORD
set -euo pipefail

: "${SITE_FTP_HOST:?SITE_FTP_HOST is required}"
: "${SITE_FTP_USER:?SITE_FTP_USER is required}"
: "${SITE_FTP_PASSWORD:?SITE_FTP_PASSWORD is required}"

HERE="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$HERE/site/index.html" ] || { echo "site/index.html missing — wrong directory?"; exit 1; }

echo "Publishing $HERE/site/ to $SITE_FTP_HOST"

# The account is chrooted to the document root, so the remote target is simply /.
#
# Three exclusions. `.well-known` holds the Let's Encrypt challenge, written by the host: deleting
# it mid-issuance would fail the certificate. `.ftpquota` belongs to the FTP server. The `.jsonl`
# registers live above the document root and are out of reach from here, but the rule costs
# nothing and survives someone moving them down.
lftp <<LFTP
set ftp:ssl-force true
set ftp:ssl-protect-data true
set ssl:verify-certificate true
set ftp:passive-mode true
set net:max-retries 3
set net:timeout 20
open -u "$SITE_FTP_USER","$SITE_FTP_PASSWORD" "$SITE_FTP_HOST"
mirror --reverse --delete --parallel=4 --verbose \
  --exclude-glob .DS_Store \
  --exclude-glob *.jsonl \
  --exclude-glob .ftpquota \
  --exclude '^\.well-known/' \
  "$HERE/site/" /
bye
LFTP

echo "Done. Check https://quix.xavier-kain.fr/"
