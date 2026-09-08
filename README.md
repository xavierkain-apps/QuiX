# QuiX

Importe les clips d'une GoPro sur un Mac et sépare les prises **highlightées** du reste.
Remplace la seule fonction de Quik Desktop qui servait encore, après son abandon par GoPro fin 2024.

Branchez la carte, et vous obtenez :

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

Le détail du format, les mesures faites sur une vraie HERO12 et les deux pièges qu'elles ont
révélés sont dans **[docs/HILIGHT.md](docs/HILIGHT.md)**.

## Ce que le produit garantit

- **La carte n'est jamais modifiée.** L'effacement reste une action manuelle, dans la caméra.
- **Une prise ne se coupe pas en deux.** Les chapitres d'une longue prise partagent un numéro de
  fichier ; si un seul porte un tag, tous suivent dans `Highlights/`.
- **Chaque copie est vérifiée** — empreinte calculée pendant l'écriture, puis relue sur le fichier
  écrit — avant d'être considérée comme importée.
- **Rebrancher la carte ne recopie que le neuf**, via un index `nom + taille + date` rangé à la
  racine de la bibliothèque.

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
# Le moteur : 85 tests, aucune machine Apple requise
swift test --package-path Core

# L'outil en ligne de commande, pour voir le parseur à l'œuvre
swift build --package-path Core --product quix
"$(swift build --package-path Core --product quix --show-bin-path)/quix"   hilight Core/Tests/QuiXCoreTests/Fixtures/hero12-un-highlight.mp4
# -> hero12-un-highlight.mp4 : 1 moment(s) — 3.436 s

# L'app
xcodebuild build -project QuiX.xcodeproj -scheme QuiX -configuration Release   -destination 'generic/platform=macOS' -derivedDataPath build ONLY_ACTIVE_ARCH=NO   CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=
cp -R build/Build/Products/Release/QuiX.app /Applications/
```

Les trois derniers réglages signent en ad hoc, ce qui suffit pour essayer en local. Pour une vraie
signature, ouvrir `QuiX.xcodeproj` et choisir l'équipe dans **Signing & Capabilities** — Xcode
inscrit alors `DEVELOPMENT_TEAM` dans le projet, à committer.

**À savoir avant d'essayer :** les deux clips GoPro complets ne sont pas dans le dépôt, seulement
les deux `moov` de 34 Ko qui servent aux tests. Un essai bout en bout demande une vraie carte, ou
un dossier `DCIM/100GOPRO/` fabriqué à la main avec des `.MP4` dedans.

## Utiliser l'app

Au premier lancement, elle demande où ranger les clips. Ensuite, brancher la carte suffit : elle
est reconnue par la présence d'un dossier `DCIM/###GOPRO`, jamais par le nom du volume. Une case
permet de demander confirmation avant chaque import.

macOS demandera l'accès aux **volumes amovibles** au premier branchement. Sans cette autorisation,
l'app voit le volume monter et ne trouve aucun fichier — le symptôme ressemble exactement à une
carte vide.

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
