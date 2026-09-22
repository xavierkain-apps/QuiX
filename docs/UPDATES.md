# Les mises à jour

QuiX se distribue hors de l'App Store. Sans mécanisme de mise à jour, une version défectueuse
reste installée chez tout le monde jusqu'à ce que chacun repasse sur le site de son plein gré
— c'est-à-dire jamais. C'est **Sparkle 2** qui s'en charge : l'app vérifie une fois par jour,
annonce ce que la version apporte, télécharge et installe.

## La signature, qui est tout le sujet

Une mise à jour automatique est un moyen d'exécuter du code sur la machine de quelqu'un. Deux
signatures indépendantes protègent ce chemin, et elles ne disent pas la même chose :

- **Developer ID + notarisation**, d'Apple : Gatekeeper accepte d'ouvrir l'app.
- **EdDSA, de Sparkle** : l'app *déjà installée* vérifie que l'archive qu'elle vient de
  télécharger vient bien de nous. `SUPublicEDKey` est inscrite dans l'`Info.plist` ; toute
  archive signée d'une autre clé est refusée, quoi qu'elle prétende être.

La conséquence pratique : **quelqu'un qui prendrait le contrôle du serveur ne pourrait pas
faire installer son propre binaire.** Il pourrait au pire empêcher les mises à jour.

## Où vivent les clés

| | Où | Qui y touche |
|---|---|---|
| Clé privée EdDSA | trousseau de Xavier, et le secret `SPARKLE_PRIVATE_KEY` du dépôt | personne d'autre |
| Clé publique EdDSA | `Support/Info.plist`, en clair | tout le monde, c'est le but |
| Certificat Developer ID | secrets `MACOS_CERT_P12` et compagnie | voir [SIGNING.md](../SIGNING.md) |

La clé privée a été produite par `generate_keys` de Sparkle et **n'a jamais été affichée**.
Pour l'exporter afin d'alimenter le secret :

```sh
build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -x cle-privee.txt
gh secret set SPARKLE_PRIVATE_KEY --repo xavierkain-apps/QuiX < cle-privee.txt
rm cle-privee.txt
```

Perdre cette clé n'est pas rattrapable à distance : les apps installées refuseraient toute
mise à jour signée d'une nouvelle clé, et il faudrait que chacun réinstalle à la main.

## Le piège de la signature imbriquée

Xcode signe le framework Sparkle qu'il embarque, **mais pas ce qu'il y a dedans**. Sparkle
porte une app d'interface, un outil d'installation et deux services XPC, tous signés par le
projet Sparkle et sans horodatage sécurisé. Apple refuse le bundle entier, avec un message qui
ne dit pas d'où vient le problème :

```
The binary is not signed with a valid Developer ID certificate.
The signature does not include a secure timestamp.
```

[Support/sign-sparkle.sh](../Support/sign-sparkle.sh) les resigne du plus profond vers le
plus extérieur, en conservant leurs droits — les services XPC en ont, et les perdre les
empêcherait de démarrer. `codesign --deep` ne fait pas l'affaire : il ne rejoue pas les droits
de chaque composant.

La CI le lance après la compilation, puis **vérifie** que plus aucun exécutable imbriqué ne
porte une autre signature. L'apprendre là coûte une seconde ; l'apprendre du service de
notarisation coûte deux minutes.

## Publier une version

```sh
# 1. Le numéro, aux deux endroits qui comptent
#    MARKETING_VERSION  → ce que l'utilisateur lit
#    CURRENT_PROJECT_VERSION → ce que Sparkle compare, à incrémenter à chaque fois
# 2. Un tag, et c'est tout
git tag v1.0.0 && git push origin v1.0.0
```

L'intégration continue compile, signe, notarise, agrafe, **signe la mise à jour**, écrit
`appcast.xml` et publie la release avec les deux fichiers.

## Ce qui reste à brancher

`SUFeedURL` pointe sur `https://quix.xavier-kain.fr/appcast.xml`, qui n'existe pas encore. La
CI, elle, publie l'appcast comme fichier de la release GitHub. Il faut que le site serve ce
fichier — le plus simple est une redirection vers l'URL de la dernière release, ce qui évite
d'avoir à redéployer le site à chaque version.

En prime, les requêtes sur ce fichier donnent le **nombre d'installations actives et la
répartition des versions**, sans une ligne de traçage dans l'app.
