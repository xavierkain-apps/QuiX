# QuiX — importeur GoPro pour macOS

## Le problème

GoPro a retiré Quik Desktop du Mac App Store fin 2024 et ne le maintient plus.
Xavier s'en servait uniquement pour **importer** ses clips, jamais pour monter.
Les alternatives citées partout (iMovie, UniConverter, HitPaw) sont des monteurs :
elles ne répondent pas au besoin, qui est un transfert fiable et trié.

## Ce que l'app doit faire

Une seule chose, bien :

1. Détecter que la GoPro (ou sa carte SD) vient d'être branchée.
2. Copier les clips dans le dossier habituel de Xavier, dans un **nouveau dossier daté**.
3. À l'intérieur, deux sous-dossiers : `Highlights/` et `Clips/`.
4. Permettre de voir tout de suite les clips highlightés.

Pas de montage, pas de trim, pas de cloud, pas d'export réseaux sociaux. Le jour
où on ajoute ça, on a refait Quik et perdu la raison d'être du produit.

## Le fait technique qui rend tout ça possible

Les tags HiLight sont écrits **dans le fichier MP4 lui-même**, dans l'atome
`moov` → `udta` → `HMMT` : un `uint32` big-endian donnant le nombre de moments,
puis un `uint32` par moment (timestamp en millisecondes depuis le début du clip).

Conséquences pratiques, toutes bonnes :

- Lisible en Swift pur, sans dépendance et sans AVFoundation.
- On ne lit que l'en-tête, pas la vidéo : scanner une carte entière prend
  quelques secondes même à travers un lecteur de carte.
- Le tri se décide **avant** la copie, donc on écrit directement au bon endroit
  au lieu de copier puis déplacer.

Deux réserves à lever tôt :

- Les modèles récents (Hero 11/12/13) pourraient s'écarter du HMMT classique.
  **À vérifier sur un vrai clip de la caméra de Xavier avant d'écrire l'app.**
- Les highlights ajoutés *après coup dans l'app mobile Quik* restent dans l'app
  et ne sont pas réécrits dans le MP4. Seuls ceux posés pendant le tournage
  (bouton, commande vocale) sont récupérables. Ce n'est pas un bug à corriger,
  c'est une limite à documenter dans l'interface.

## Ce qu'il faut savoir sur les fichiers GoPro

- Nommage `GX010123.MP4` : `GX` = encodage, `01` = numéro de chapitre,
  `0123` = numéro de prise. Une longue prise est découpée en chapitres qui
  partagent le numéro de prise.
  → **Si un chapitre porte un highlight, toute la prise part dans `Highlights/`.**
  Séparer les chapitres d'une même prise rendrait le dossier inutilisable.
- `.LRV` (proxy basse résolution) et `.THM` (vignette) : ignorés par défaut.
- Les fichiers vivent dans `DCIM/100GOPRO/`, `101GOPRO/`, etc.

## Branchement de la caméra

En USB, la GoPro se présente en MTP — pénible à piloter. Avec la carte dans un
lecteur, c'est un volume normal monté sous `/Volumes/`, et le transfert est
nettement plus rapide. **Cibler le volume monté en premier** ; le MTP est une
extension éventuelle, pas le chemin nominal.

Détection : `NSWorkspace.shared.notificationCenter`, `didMountNotification`.
On confirme que c'est bien une carte GoPro par la présence de `DCIM/1xxGOPRO/`
(et non par le nom du volume, que l'utilisateur peut avoir renommé).

## Architecture

App **SwiftUI pour macOS**. Xavier a déjà un compte Apple Developer, donc
signature et notarisation sont possibles — l'app peut être installée
durablement, et distribuée si le produit prend.

Séparer dès le départ :

- **Le moteur** (parsing HMMT, planification de l'import, copie vérifiée) en
  Swift pur, sans UI, testable en ligne de commande. C'est là qu'est la valeur
  et c'est là que les bugs coûtent cher.
- **L'interface** par-dessus : une fenêtre, une liste, une barre de progression.

Règles non négociables du moteur :

- **Ne jamais supprimer sur la carte.** L'effacement reste une action manuelle
  de l'utilisateur, dans la caméra. Une erreur d'import est rattrapable, une
  carte effacée ne l'est pas.
- **Import idempotent** : un index (nom + taille + date) des fichiers déjà
  importés, pour que rebrancher la carte ne recopie que le nouveau.
- **Copie vérifiée** avant de considérer un fichier importé.

## Ordre de construction

1. **Valider le parseur HiLight sur un vrai clip taggé de la GoPro de Xavier.**
   Bloquant : tout le reste en dépend. Ne rien construire avant.
2. Moteur d'import en Swift, piloté en ligne de commande, testé sur une copie
   de carte.
3. App SwiftUI : fenêtre, détection automatique du volume, progression.
4. Signature + notarisation.

## Questions ouvertes

- Modèle exact de la GoPro.
- Chemin du « dossier habituel » d'import.
- Format du nom de dossier daté (`2026-09-07` ? avec un libellé de sortie ?).
- Import auto dès le branchement, ou proposition à confirmer ? (l'auto sans
  confirmation surprend la première fois qu'on branche une carte d'un autre appareil)
- Affichage des highlights : Finder suffit-il, ou faut-il une galerie dans l'app
  avec une vignette extraite à chaque instant taggé ?

## Contrainte serveur (importante)

Ce serveur Linux est saturé : ~650 Mo de RAM libre, swap à 99 %, earlyoom tue
régulièrement des processus. **L'app macOS se compile sur le Mac, jamais ici.**
Ce dossier ne sert qu'à écrire le code et les décisions. Vérifier `free -m`
avant de lancer quoi que ce soit de permanent.

## Méthode

Xavier travaille avec flowkit (`/flowkit-mvp:brief`, `/flowkit-mvp:plan`,
`/flowkit-mvp:ship`). Passer par là plutôt que d'improviser un découpage.
