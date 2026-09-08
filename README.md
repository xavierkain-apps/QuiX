# QuiX

Importe les clips d'une GoPro sur un Mac et sépare les prises **highlightées** du reste.
Remplace la seule fonction de Quik Desktop qui servait encore, après son abandon par GoPro fin 2024.

Branchez la caméra en USB-C, ou la carte dans un lecteur, et vous obtenez :

```
~/<votre dossier>/2026-09-07/
├── Highlights/     les prises portant au moins un tag HiLight
└── Clips/          tout le reste
```

Pas de montage, pas de trim, pas de cloud. Le jour où on ajoute ça, on a refait Quik.

## Comment ça marche

Les tags HiLight posés pendant le tournage sont écrits dans le MP4 lui-même, dans l'atome
`moov/udta/HMMT`. On lit cet atome — **trois `seek` et environ 34 Ko** par clip, quelle que soit sa
taille — et on sait où va le fichier avant d'en copier le premier octet. Il n'y a jamais de tri
après coup.

Cela vaut par les **deux** sources, et c'est ce qui a demandé le plus de soin :

- **la carte dans un lecteur** — un volume ordinaire, trois `seek` ;
- **la caméra branchée en USB-C** — qui n'expose aucun disque. Elle monte un réseau et répond en
  HTTP sur `172.2X.1YZ.51:8080`. Les trois `seek` deviennent trois requêtes `Range`, mesurées sur
  une HERO12 : `206 Partial Content`, `Accept-Ranges: bytes`. Le tri reste donc gratuit par le
  câble aussi — on ne rapatrie un clip que pour l'importer, jamais pour savoir où il va.

Le détail du format, les mesures faites sur une vraie HERO12 et les deux pièges qu'elles ont
révélés sont dans **[docs/HILIGHT.md](docs/HILIGHT.md)**.

## Ce que le produit garantit

- **Rien ne s'efface tout seul.** L'app peut vider la caméra, mais seulement sur un bouton, après
  confirmation, et seulement si elle a retrouvé sur le Mac **chacun** des clips qu'elle porte, à la
  bonne taille. Un seul manquant, et le bouton n'est pas proposé.
- **Une prise ne se coupe pas en deux.** Les chapitres d'une longue prise partagent un numéro de
  fichier ; si un seul porte un tag, tous suivent dans `Highlights/`.
- **Chaque copie est vérifiée** — empreinte calculée pendant l'écriture, puis relue sur le fichier
  écrit — avant d'être considérée comme importée.
- **Rebrancher la carte ne recopie que le neuf**, via un index `nom + taille + date` rangé à la
  racine de la bibliothèque.
- **Un transfert coupé reprend où il s'était arrêté**, sans perdre ce qui était déjà passé ni
  affaiblir la vérification — voir [docs/USB.md](docs/USB.md).

## Disposition

| | |
|---|---|
| `Core/` | Le moteur, en Swift pur sur Foundation seule. Se compile et se teste sur Linux. |
| `App/` | La fenêtre SwiftUI. Ne se compile que sur macOS. |
| `docs/` | Le format HiLight relevé sur la caméra, et les décisions. |

La séparation n'est pas cosmétique : toute la valeur est dans `Core`, et c'est ce qui permet à
l'intégration continue de la prouver sans machine Apple.

## Le moteur en ligne de commande

```sh
swift build --package-path Core --product quix

quix hilight clip.MP4                      # les instants tagués d'un clip
quix scan /Volumes/GOPRO                   # les prises d'une carte, et lesquelles sont taguées
quix camera                                # la GoPro branchée en USB : ses prises, sans rien copier
quix import /Volumes/GOPRO ~/Films/GoPro --dry-run   # le plan, sans écrire un octet
quix import /Volumes/GOPRO ~/Films/GoPro             # pour de vrai
```

## Construire sur le Mac

Prérequis : **Xcode 16 ou plus** (le projet est au format `objectVersion 77`) et **macOS 15 ou
plus** (cible de déploiement).

### Le plus court : prendre le bundle déjà notarisé

L'intégration continue produit à chaque push un bundle universel, signé Developer ID, notarisé et
agrafé. Rien à compiler :

```sh
gh run download --repo xavierkain-apps/QuiX --name QuiX
ditto -x -k QuiX.zip /Applications/
open /Applications/QuiX.app
```

`ditto` plutôt qu'`unzip` : il préserve les attributs étendus du bundle, donc la signature.
Gatekeeper ne doit rien dire du tout — pas même au premier lancement.

### Compiler soi-même

```sh
# Le moteur : 109 tests, aucune machine Apple requise
swift test --package-path Core

# L'outil en ligne de commande, pour voir le parseur à l'œuvre
swift build --package-path Core --product quix
"$(swift build --package-path Core --product quix --show-bin-path)/quix"   hilight Core/Tests/QuiXCoreTests/Fixtures/hero12-un-highlight.mp4
# -> hero12-un-highlight.mp4 : 1 moment(s) — 3.436 s

# L'app
xcodebuild build -project QuiX.xcodeproj -scheme QuiX -configuration Release   -destination 'generic/platform=macOS' -derivedDataPath build ONLY_ACTIVE_ARCH=NO   CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=
cp -R build/Build/Products/Release/QuiX.app /Applications/
```

Les trois derniers réglages signent en ad hoc. Ça suffit pour essayer, mais **pas pour vivre avec** :
une signature ad hoc change à chaque compilation, et les logiciels de sécurité — Bitdefender, Little
Snitch — n'ont rien de stable à retenir. Ils redemandent l'autorisation après chaque reconstruction,
en expliquant que « le processus contient des informations de signature différentes ».

Si vous avez un certificat Developer ID, signez plutôt avec :

```sh
xcodebuild build -project QuiX.xcodeproj -scheme QuiX -configuration Release   -destination 'generic/platform=macOS' -derivedDataPath build ONLY_ACTIVE_ARCH=NO   CODE_SIGN_STYLE=Manual   "CODE_SIGN_IDENTITY=Developer ID Application: <votre nom> (<équipe>)"   DEVELOPMENT_TEAM=<équipe> OTHER_CODE_SIGN_FLAGS=--timestamp   CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO
```

L'identité devient stable d'une compilation à l'autre, et une autorisation donnée une fois le reste.
`CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` retire l'entitlement de débogage qu'Apple refuse de
notariser — voir [SIGNING.md](SIGNING.md).

`security find-identity -v -p codesigning` liste les identités disponibles.

**À savoir avant d'essayer :** les deux clips GoPro complets ne sont pas dans le dépôt, seulement
les deux `moov` de 34 Ko qui servent aux tests. Un essai bout en bout demande une vraie carte, ou
un dossier `DCIM/100GOPRO/` fabriqué à la main avec des `.MP4` dedans.

## Utiliser l'app

Au premier lancement, elle demande où ranger les clips. Ensuite, brancher suffit — la caméra en
USB-C ou la carte dans un lecteur. Une case permet de demander confirmation avant chaque import.

Si les deux sont présents, **la carte l'emporte** : elle est plus rapide, et c'est celle que vous
avez délibérément mise dans le lecteur.

### Les deux autorisations, et leurs symptômes

macOS en demande une par source, et **les deux échouent de la même façon trompeuse** : l'app voit le
matériel et ne trouve rien, exactement comme devant une carte vide.

| Source | Autorisation | Où la donner |
|---|---|---|
| Carte dans un lecteur | **Volumes amovibles** | Confidentialité et sécurité → Fichiers et dossiers |
| Caméra en USB-C | **Réseau local** | Confidentialité et sécurité → Réseau local |

Celle du réseau local surprend, et c'est normal : branchée en USB-C, la caméra *est* un
périphérique réseau pour macOS. Quand elle manque, l'app le dit explicitement et ouvre le bon
panneau — elle ne se contente pas de rester vide.

### Ouvrir QuiX au branchement

Une case dans la fenêtre. Quand elle est cochée, brancher la GoPro ouvre QuiX et l'import démarre —
sous réserve de « Demander confirmation », qui garde la main si vous branchez seulement pour
recharger.

QuiX ne tourne pas en attendant : il n'y a pas de processus résident, pas d'icône dans la barre des
menus. C'est `launchd` qui le réveille à l'apparition du périphérique USB, et rien n'existe tant
que la caméra n'est pas branchée. macOS signalera un « élément en arrière-plan » ajouté, listé dans
Réglages Système → Général → Ouverture et extensions.

L'appariement ne reconnaît que la **HERO12 Black** : les détails, et comment relever l'identifiant
d'un autre modèle, sont dans [docs/USB.md](docs/USB.md).

### Effacer la caméra après import

Le compte rendu d'import affiche un comparatif : combien de clips la caméra porte, combien ont été
retrouvés sur ce Mac. Le bouton d'effacement n'apparaît que lorsque les deux nombres coïncident —
et le décompte se refait à partir du **disque**, pas de l'index, pour qu'un dossier vidé à la main
retienne l'effacement.

C'est la seule opération irréversible de l'app, et la seule qui demande une confirmation.

### Une carte reconnue, jamais devinée

Un volume n'est traité que s'il porte un dossier `DCIM/###GOPRO`, jamais d'après son nom : la carte
d'un autre appareil n'est pas touchée, même si elle s'appelle « GOPRO ».

## Signature

Le job macOS produit un bundle universel à chaque push, téléchargeable en artefact. Il est signé
Developer ID et notarisé dès que les cinq secrets de l'organisation `xavierkain-apps` existent —
voir [SIGNING.md](SIGNING.md) — et signé ad hoc sinon.

## Tests

```sh
swift test --package-path Core
```

Les tests s'appuient sur `Core/Tests/QuiXCoreTests/Fixtures/`, qui contient les `moov` réels de deux
clips d'une HERO12 — un tagué, un sans tag. Le second est le plus important : voir son
[README](Core/Tests/QuiXCoreTests/Fixtures/README.md).

Ce que les tests ne peuvent pas prouver est dans [VERIFICATION.md](VERIFICATION.md), à cocher sur le
Mac avec une vraie carte.

## Une limite à connaître

Les highlights ajoutés **après coup** dans l'app mobile Quik restent dans l'app : GoPro ne les
réécrit pas dans le MP4. Seuls ceux posés pendant le tournage — bouton ou commande vocale — sont
récupérables. Ce n'est pas un bug de QuiX, et l'app le dit dans sa fenêtre.
