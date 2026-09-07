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

## L'app

Ouvrir `QuiX.xcodeproj` dans Xcode, choisir l'équipe de développement dans **Signing &
Capabilities**, compiler.

Au premier lancement, l'app demande où ranger les clips. Ensuite, brancher la carte suffit : elle
est reconnue par la présence d'un dossier `DCIM/###GOPRO`, jamais par le nom du volume. Une case
permet de demander confirmation avant chaque import.

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
