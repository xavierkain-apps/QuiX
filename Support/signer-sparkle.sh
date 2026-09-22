#!/bin/bash
# Resigne les exécutables imbriqués de Sparkle avec notre identité Developer ID.
#
#   Support/signer-sparkle.sh <QuiX.app> <identité de signature>
#
# Xcode signe le framework qu'il embarque, mais **pas ce qu'il y a dedans** : Sparkle porte une
# app d'interface (Updater.app), un outil d'installation (Autoupdate) et deux services XPC, tous
# signés par le projet Sparkle et sans horodatage sécurisé. Apple refuse de notariser un bundle
# qui contient un exécutable signé par quelqu'un d'autre, avec exactement ce message :
#
#   The binary is not signed with a valid Developer ID certificate.
#   The signature does not include a secure timestamp.
#
# `codesign --deep` ne suffit pas et n'est pas recommandé : il ne rejoue pas les droits de chaque
# composant. On signe donc du plus profond vers le plus extérieur, en conservant les droits déjà
# déclarés — les services XPC de Sparkle en ont, et les perdre les empêcherait de démarrer.
set -euo pipefail

APP="$1"
IDENTITY="$2"
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"

if [ ! -d "$FRAMEWORK" ]; then
  echo "Pas de Sparkle dans $APP — rien à resigner."
  exit 0
fi

sign() {
  [ -e "$1" ] || return 0
  codesign --force --options runtime --timestamp \
    --preserve-metadata=entitlements \
    --sign "$IDENTITY" "$1"
  echo "  signé  ${1#"$APP/"}"
}

VERSIONS="$FRAMEWORK/Versions/Current"
echo "Resignature de Sparkle :"
sign "$VERSIONS/XPCServices/Downloader.xpc"
sign "$VERSIONS/XPCServices/Installer.xpc"
sign "$VERSIONS/Autoupdate"
sign "$VERSIONS/Updater.app"
sign "$FRAMEWORK"
# L'app elle-même en dernier : sa signature scelle le contenu, qui vient de changer.
codesign --force --options runtime --timestamp \
  --preserve-metadata=entitlements --sign "$IDENTITY" "$APP"
echo "  signé  $(basename "$APP")"
