# Décisions

Répond aux « Questions ouvertes » du [BRIEF.md](../BRIEF.md). Une décision par
section : ce qui est tranché, et pourquoi.

## 2026-09-07 — Validation du parseur HiLight

Xavier dépose un clip GoPro **taggé** à la racine du projet (`sample.MP4`, non
versionné). On lit l'en-tête réel avant d'écrire le parseur, et on en extrait un
**fixture de quelques kilo-octets** (l'atome `moov` seul, pas la vidéo) qui, lui,
part dans les tests.

Pourquoi : la réserve du brief sur les Hero 11/12/13 ne se lève que sur un vrai
fichier. Coder défensivement « au cas où » reviendrait à écrire deux parseurs
dont un jamais exécuté.

**Bloquant : rien du moteur ne s'écrit avant.**

## 2026-09-07 — Dossier d'import

Choisi par l'utilisateur **au premier lancement**, mémorisé dans les préférences.
Pas de chemin en dur.

À l'intérieur, un dossier par import, nommé en **date ISO** (`2026-09-07/`), puis
`Highlights/` et `Clips/`. Format triable chronologiquement dans le Finder.

Hypothèse à confirmer : pas de libellé de sortie dans le nom du dossier en V1.
Deux imports le même jour se retrouvent dans le même dossier daté — l'idempotence
fait que le second n'ajoute que le neuf, ce qui est le comportement voulu.

Pourquoi le choix au premier lancement plutôt qu'un défaut : le « dossier
habituel » de Xavier n'est pas dans le brief, et le sandbox macOS a de toute façon
besoin d'une autorisation explicite sur le dossier de destination.

## 2026-09-07 — Déclenchement de l'import

**Automatique dès le branchement**, avec une case « demander confirmation avant
d'importer » dans les préférences.

Pourquoi l'auto par défaut : c'est le geste que Quik Desktop rendait, et le brief
demande une app qui fait une chose sans qu'on la pilote.

Pourquoi le réglage malgré tout : brancher la carte d'un autre appareil ne doit
pas déclencher une copie surprise. La garde principale reste la détection par
`DCIM/1xxGOPRO/` — une carte non-GoPro n'est jamais touchée, réglage ou pas.

## 2026-09-07 — Affichage des highlights

**Le Finder.** L'import terminé, l'app révèle `Highlights/`.

Pas de galerie, pas d'extraction de vignette, donc pas d'AVFoundation en V1. Une
galerie avec un instant par tag est le premier pas vers un visualiseur, c'est-à-dire
vers Quik — ce que le brief interdit explicitement. À rouvrir seulement si
l'usage montre que le Finder ne suffit pas.

## 2026-09-07 — Disposition du dépôt

`Core/` (SwiftPM, Foundation pur) + `App/` (SwiftUI, `.xcodeproj`), et non le
`src/` annoncé dans le CLAUDE.md.

Pourquoi : c'est la disposition de DisplayX, et elle applique littéralement la
règle d'architecture du brief — le moteur se teste sur Linux en intégration
continue, l'app ne se compile que sur macOS. Un `src/` unique laisserait AppKit
fuiter dans le moteur sans que rien ne le signale.

## 2026-09-07 — Réserve sur les modèles récents : levée

La caméra est une **HERO12 Black** (firmware `H23.01.02.32.00`) et elle écrit le
`HMMT` classique. Le parseur en Swift pur, sans AVFoundation, est confirmé
possible. Relevé complet dans [HILIGHT.md](HILIGHT.md).

Deux corrections au brief au passage : `moov` est en **fin** de fichier chez
GoPro (et non au début), et `HMMT` fait **332 octets quel que soit le nombre de
highlights** — 80 emplacements préalloués. Le point n°1 du CLAUDE.md a été
corrigé en conséquence.

Le source retenu est `udta/HMMT` seul. Le flux `GPMF/HLMT` le confirme au
milliseconde près mais demanderait un parseur KLV complet pour rien.

## 2026-09-07 — Choix pris pendant la construction du moteur

**L'index vit dans la bibliothèque**, pas dans les données de l'application
(`<bibliothèque>/.quix-index.json`). Supprimer le dossier importé doit suffire à
pouvoir tout réimporter ; un index caché ailleurs ferait croire à l'app que les
clips sont déjà là alors qu'ils ont disparu. Et un index illisible ne bloque
jamais un import — au pire on recopie.

**L'idempotence se vérifie sur le disque**, pas seulement dans l'index : un
fichier n'est écarté que si l'index le connaît *et* que la copie est réellement
présente, à la bonne taille.

**La vérification de copie est un CRC-32**, calculé sur la source pendant
l'écriture puis recalculé en relisant le fichier écrit. Il s'agit de détecter une
copie abîmée, pas de résister à quelqu'un qui chercherait à tromper la
vérification : une empreinte cryptographique coûterait plus cher sans rien
apporter ici. Foundation seule n'expose de toute façon pas CryptoKit sur Linux.

**On écrit dans un `.quix-partiel` renommé à la fin.** Une copie interrompue doit
laisser une trace évidente, pas un `.MP4` de bonne taille apparente que le Finder
afficherait comme un clip valide.

**La date de modification est reportée sur la copie**, sinon tous les clips
importés porteraient la date de l'import et le tri par date dans le Finder ne
dirait plus rien.

**Une collision de noms désambiguïse au lieu d'écraser.** Deux dossiers DCIM
peuvent porter le même nom de fichier après un tour de compteur de la caméra ;
le second devient `GX010001-101GOPRO.MP4`.

**Le flux GPMF/HLMT n'est pas lu.** Il confirme HMMT à la milliseconde mais
demanderait un parseur KLV complet pour une information déjà obtenue en trente
lignes. Noté comme filet de secours dans [HILIGHT.md](HILIGHT.md) si un modèle
cessait un jour d'écrire HMMT.
