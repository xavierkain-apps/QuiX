# Handoff : redesign QuiX (macOS)

## Vue d'ensemble

QuiX importe les clips d'une carte GoPro sur un Mac et sépare les prises portant au moins un tag
HiLight (`moov/udta/HMMT`) du reste. Le moteur existe déjà (`Core/`, Swift pur) ; ce handoff ne
concerne que l'interface (`App/`, SwiftUI) et l'icône d'app.

Le redesign remplace la fenêtre unique actuelle (`App/ContentView.swift`) par :

1. un **popover de barre de menus** — le lieu par défaut de l'app, quatre états ;
2. une **fenêtre Transfert** — ouverte depuis le popover pendant un import ;
3. une **fenêtre Bibliothèque** — ouverte après coup, pour retrouver les highlights ;
4. une **icône d'app** : objectif + flèche d'import + perforations de pellicule.

## À propos des fichiers de design

`QuiX Redesign.dc.html` (avec `support.js` à côté, ouvrir le `.html` dans un navigateur) est une
**référence de design en HTML**, pas du code à porter. Il montre l'apparence et la structure
voulues. Le travail consiste à **recréer ces écrans en SwiftUI** dans le projet existant, avec ses
conventions (`@Observable`, `ImportModel.Stage`, `Preferences`), pas à embarquer du HTML.

Le fichier contient l'historique complet des explorations, en sections empilées, la plus récente en
haut. **Seuls les blocs suivants font foi :**

| Bloc dans le HTML | Écran à implémenter |
|---|---|
| `#4c` | Icône d'app (**retenue**) |
| `#2a` | Popover barre de menus, 4 états |
| `#2b` | Fenêtre Transfert |
| `#2c` | Fenêtre Bibliothèque |

Tout le reste (`#1a`, `#1b`, `#1c`, `#3a`, `#3b`, `#3c`, `#4a`, `#4b`) est abandonné : ne pas
l'implémenter.

## Fidélité

**Hi-fi.** Couleurs, tailles, graisses et espacements sont définitifs et listés plus bas. Les
vignettes vidéo sont des placeholders rayés : elles doivent être remplacées par de vraies images
extraites du premier frame (ou du frame du premier moment tagué).

Les maquettes sont dessinées en CSS avec la famille système ; en SwiftUI, utiliser les styles
natifs (`.title2`, `.callout`…) quand ils tombent juste, et les valeurs exactes sinon.

---

## Design tokens

### Couleurs

| Rôle | Valeur | Usage |
|---|---|---|
| Encre / fond fenêtre | `#1A191D` | fond des fenêtres Transfert et Bibliothèque |
| Fond popover | `rgba(24,23,26,.94)` + flou d'arrière-plan | popover barre de menus |
| Fond barre de titre | `#232228` | barre de titre des fenêtres |
| Fond panneau secondaire | `#1F1E23` | inspecteur, en-tête de liste |
| Fond sidebar | `#201F25` | colonne de gauche de la Bibliothèque |
| Surface surélevée | `rgba(255,255,255,.05)` | cartes source/destination, ligne sélectionnée |
| Survol | `rgba(255,255,255,.06)` | lignes de liste |
| Filet | `rgba(255,255,255,.08)` | séparateurs (0,5 pt) |
| Filet marqué | `rgba(255,255,255,.12)` | bordures de cartes, pistes de progression |
| Texte primaire | `#F2F0EC` | |
| Texte secondaire | `rgba(242,240,236,.55)` | |
| Texte tertiaire | `rgba(242,240,236,.4)` | légendes, chemins, en-têtes de colonnes |
| **Bleu GoPro** | `oklch(0.68 0.15 233)` ≈ `#00A3E4` | accent : progression, boutons, marqueurs |
| Bleu clair | `oklch(0.86 0.07 233)` ≈ `#A9DCF5` | flèche de l'icône, texte sur bleu foncé |
| Bleu badge | `oklch(0.74 0.13 233)` ≈ `#3FB2E8` | pastille « nombre de tags » |
| Bleu texte | `oklch(0.78 0.13 233)` ≈ `#5BBDEE` | mentions « 3 taguées », pourcentages |
| Feux de circulation | `#EC6A5E` `#F4BF4F` `#61C554` | fournis par macOS, ne pas redessiner |

Le texte sur le bleu plein est **blanc** ; sur les pastilles bleu clair, il est en encre `#17161A`.

### Typographie

- Interface : police système (SF Pro Text / `-apple-system`).
- Valeurs numériques et noms de fichiers : **monospace** (SF Mono ; les maquettes utilisent IBM Plex
  Mono, remplacer par SF Mono).
- Échelle : titre de section 15 pt / semibold 590 · corps 13,5 pt · secondaire 12,5 pt · légende
  11,5 pt · en-têtes de colonnes 10,5 pt mono, majuscules, interlettrage 0,12 em.
- Chiffres de bilan : 22 pt semibold.

### Espacement, rayons, ombres

- Grille de 4 pt. Marges de panneau : 18-20 pt. Gouttières de grille : 14 pt.
- Rayons : fenêtre 14 · popover 16 · carte 12 · bouton 8-9 · pastille 4-5 · vignette 8.
- Ombre de fenêtre : `0 30px 70px -22px rgba(0,0,0,.6)` + liseré `0 0 0 .5px rgba(255,255,255,.13)`.
- Séparateurs à 0,5 pt (`Divider()` suffit).

---

## Écran 1 — Popover barre de menus (`#2a`)

**Rôle.** Le siège de l'app. Item de barre de menus toujours présent ; un clic ouvre le popover.
Largeur fixe **300 pt**, hauteur selon le contenu.

L'item de barre de menus affiche l'icône monochrome (glyphe template) ; pendant un import il montre
une pastille bleue à côté.

Le popover suit `ImportModel.Stage`, un état par cas :

### 1. Au repos (`.waiting`)
Padding 22/18/16. Titre « Aucune carte » (15 pt, 590). Sous-titre « Branchez la carte, l'import
démarre tout seul. » (12,5 pt, secondaire). Séparateur. Deux lignes clé/valeur :
« Dernier import » → date ISO en mono ; « Dossier » → `~/Films/GoPro` en mono, tronqué par la tête.

Si `preferences.library == nil`, remplacer la seconde ligne par un bouton « Choisir le dossier
d'import… ».

### 2. Lecture de la carte (`.scanning`)
Titre « Lecture de la carte » précédé d'une pastille bleue de 7 pt qui pulse (opacité 0,35 → 1,
1,6 s, aller-retour). En dessous, une rangée de 14 barres verticales de hauteurs inégales
(9-26 pt, largeur égale, gap 3 pt, `rgba(255,255,255,.16)`) — décoratif, pas une vraie forme
d'onde ; peut aussi servir de jauge en colorant en bleu les barres déjà lues.
Ligne « 9 clips sur 14 » / « en-têtes seuls » (12,5 pt secondaire).
Légende « Aucune vidéo n'est copiée à ce stade. » (11,5 pt tertiaire).

### 3. Import (`.importing`)
En-tête : « Import » (15 pt 590) + « 7,4 / 11,9 Go » en mono 11,5 pt à droite.
Barre de progression : hauteur 3 pt, rayon 2, piste `rgba(255,255,255,.12)`, remplissage bleu.
Puis la file des fichiers, une ligne par copie (padding 7/10, rayon 8, survol
`rgba(255,255,255,.06)`) : nom en mono 12,5 pt · pastille bleue avec le nombre de tags si la prise
est taguée (toujours réserver la cellule, même vide) · taille alignée à droite, 44 pt de large.
Pied : bouton « Arrêter » pleine largeur, contour `rgba(255,255,255,.18)`.

### 4. Terminé (`.finished`)
« Import terminé » + « 14 fichiers — 11,9 Go — vérifiés ».
Deux tuiles côte à côte (rayon 10, fond `rgba(255,255,255,.06)`, padding 12) : nombre 22 pt — le
chiffre des Highlights en bleu clair — et libellé 11,5 pt.
Bouton plein bleu « Ouvrir les highlights » (texte blanc, rayon 9, hauteur ~32 pt).
Légende « La carte n'a pas été modifiée. »

En cas d'échec (`.failed`), même gabarit : titre « Échec », raison en secondaire, pas de bouton
bleu.

---

## Écran 2 — Fenêtre Transfert (`#2b`)

**Rôle.** Vue détaillée d'un import en cours, ouverte depuis le popover. Largeur **860 pt**,
hauteur selon le contenu. Barre de titre standard, titre « Transfert ».

**Bandeau source → destination.** Grille `1fr / auto / 1fr`, padding 28, gap 20.
Chaque carte : bordure `rgba(255,255,255,.12)`, rayon 12, padding 18/20, fond
`rgba(255,255,255,.05)`, et quatre lignes :
en-tête de colonne (10,5 mono majuscules tertiaire) · nom 17 pt 590 · résumé 13 pt secondaire ·
chemin 11,5 pt mono tertiaire.
- Source : « GOPRO » · « 14 prises — 11,9 Go — **3 taguées** » (la mention taguée en bleu texte) ·
  `/Volumes/GOPRO/DCIM/100GOPRO`.
- Destination : « 2026-09-09 » (nom du dossier daté) · « Highlights / — Clips / » · `~/Films/GoPro`.

Entre les deux, un disque bleu de 34 pt avec une flèche blanche « → ».

**Progression.** Barre de 6 pt à deux tons : bleu plein pour les octets écrits, bleu pâle
(`oklch(0.88 0.05 233)`) pour la portion en cours de vérification. À droite, « 7,4 Go sur 11,9 Go »
puis une estimation en mono tertiaire.

**Table des fichiers.** Colonnes fixes `24 / 1fr / 90 / 70 / 100` pt, gap 12, padding horizontal 28.
En-tête 10,5 mono majuscules : (vide) · Fichier · Taille · Tags · Vérification (aligné à droite).
Une ligne par fichier, hauteur ~40 pt, séparateur 0,5 pt, survol `rgba(255,255,255,.06)` :
pastille d'état de 7 pt · nom en mono 12,5 · taille · pastille de tags (cellule **toujours
présente**, vide si aucune) · état en 12 pt tertiaire, valeurs « vérifié », « en cours »,
« en attente ».

La pastille d'état de gauche doit refléter l'état : bleu plein = vérifié, bleu qui pulse = en cours,
`rgba(255,255,255,.22)` = en attente. En cas d'échec de copie, la ligne passe en orange système et
l'état porte la raison.

**Pied.** Légende « Empreinte calculée pendant l'écriture puis relue sur le fichier écrit. La carte
n'est jamais modifiée. » à gauche ; boutons « Arrêter » (contour) et « Ouvrir les highlights »
(bleu plein, texte blanc) à droite.

---

## Écran 3 — Fenêtre Bibliothèque (`#2c`)

**Rôle.** Retrouver les prises taguées après l'import. Largeur **1120 pt**, hauteur mini **620 pt**,
trois colonnes : `214 / 1fr / 268` pt.

**Sidebar (214 pt, fond `#201F25`).**
Deux entrées globales avec pastille et compteur : « Tous les highlights » (pastille bleue, en gras
quand sélectionnée, fond `rgba(255,255,255,.09)`) et « Tous les clips » (pastille grise).
En-tête de groupe « Sessions » (10,5 mono majuscules tertiaire).
La session en cours d'import est surélevée (fond `rgba(255,255,255,.05)`, liseré) et affiche son
pourcentage en bleu avec une pastille qui pulse. Les autres sessions : date ISO en mono 12,5 pt à
gauche, nombre de prises à droite.
Pied de sidebar : « Dossier d'import » + chemin en mono, cliquable pour changer.

**Colonne centrale.**
Barre d'en-tête de 46 pt : date de la session en 13,5 pt 590 + « 14 prises — 3 taguées » en
secondaire à gauche ; à droite un segmented control « Highlights / Clips / Tout » (fond
`rgba(255,255,255,.08)`, segment actif surélevé).
Grille de 3 colonnes, gap 14, padding 18/20 :
vignette 16:9, rayon 8, liseré `rgba(255,255,255,.1)` ; pastille du nombre de tags en haut à gauche
(bleu `oklch(0.74 0.13 233)`, texte encre, 10 pt 590) ; sous la vignette, nom en mono 12 pt à
gauche et durée en tertiaire à droite.
Sélection : liseré bleu de 2 pt autour de la vignette.

**Inspecteur (268 pt, fond `#1F1E23`).**
En-tête « Inspecteur » de 46 pt.
Aperçu 16:9 rayon 8. Nom du fichier en mono 14 pt, puis « 8:04 — 3,4 Go — 5,3K 60 i/s » en 12,5
secondaire.
Groupe « 4 moments » : une piste de 26 pt de haut en rayures fines représentant la durée du clip,
avec un trait bleu de 2 pt par moment HiLight, positionné au prorata du timestamp ; puis la liste
des moments, un par ligne (barre bleue de 3 pt, timestamp en mono, mention « tournage » à droite).
Cliquer un moment lance la lecture à cet instant (ou ouvre QuickLook à ce timecode).
Bouton bleu plein « Révéler dans le Finder ».
Légende « Les highlights ajoutés après coup dans l'app Quik restent dans l'app. »

---

## Icône d'app (`#4c`, retenue)

Squircle macOS standard, dégradé d'encre `#22212A` → `#101017` (160°), liseré interne blanc à 14 %.

Au centre, un anneau bleu `oklch(0.68 0.15 233)` — diamètre 90/168 du côté, épaisseur 11/168 — qui
contient une flèche d'import bleu clair `oklch(0.86 0.07 233)` pointant vers le bas : hampe
10 × 22 (angles hauts arrondis à 5) surmontant une tête triangulaire de 26 de large × 14 de haut.

De part et d'autre de l'anneau, deux colonnes de trois perforations de pellicule : carrés de 10 pt,
rayon 3, `rgba(255,255,255,.22)`, gap 8, à 10 pt de l'anneau.

Déclinaisons (déjà dessinées dans le HTML) :
- **512 / 256 / 128 px** : la composition complète.
- **64 px** : mêmes proportions, perforations réduites à 4 pt.
- **32 px et en dessous** : supprimer les perforations, ne garder que l'anneau et la flèche.
- **Barre de menus** : version template monochrome, anneau + flèche uniquement, 18 × 18 pt.

À redessiner en vectoriel (les maquettes sont des formes CSS) puis exporter en `.icns` /
Asset Catalog.

---

## Comportement et états

Le modèle existant (`ImportModel.Stage`) couvre déjà les états ; le redesign en ajoute deux au
niveau des fenêtres :

- `waiting` → popover « Aucune carte ».
- `scanning(done, total)` → popover « Lecture de la carte ».
- `needsLibrary(result)` → popover au repos avec le bouton de choix de dossier.
- `ready(result, plan)` → popover avec le récapitulatif et un bouton « Importer » (n'apparaît que si
  `askBeforeImporting`).
- `importing(progress)` → popover état 3 ; la fenêtre Transfert, si elle est ouverte, suit la même
  source.
- `finished(report)` → popover état 4 ; la Bibliothèque se rafraîchit avec la nouvelle session.
- `failed(reason)` → popover en échec.

Détails :
- La table de Transfert et la file du popover partagent la même source de vérité : la liste des
  copies planifiées, chacune avec son état (en attente / en cours / vérifié / échoué).
- La progression n'est remontée qu'au changement de pourcentage (déjà le cas dans `ImportModel`).
- Animation de la pastille de scan : opacité 0,35 ↔ 1, 1,6 s, `easeInOut`, en boucle. Aucune autre
  animation n'est requise.
- Survol : uniquement le fond des lignes de liste, sans transition.
- Fenêtres non redimensionnables sous les largeurs indiquées ; au-delà, seule la grille de vignettes
  de la Bibliothèque s'étire (colonnes de 220 pt minimum).

## Contenu

Toutes les chaînes affichées dans les maquettes sont en français et à reprendre telles quelles, en
particulier la mise en garde du pied de Bibliothèque et celle du pied de Transfert, qui existent
déjà dans `ContentView.swift`.

## Assets

Aucune image fournie. Les vignettes et l'aperçu de l'inspecteur sont des placeholders rayés : côté
app, extraire une image du clip (premier frame, ou frame du premier moment tagué) et la mettre en
cache dans la bibliothèque. L'icône est à redessiner en vectoriel d'après `#4c`.

## Fichiers

- `QuiX Redesign.dc.html` — toutes les maquettes ; blocs retenus `#2a`, `#2b`, `#2c`, `#4c`.
- `support.js` — runtime nécessaire pour ouvrir le HTML dans un navigateur.

Côté dépôt `xavierkain-apps/QuiX`, les fichiers à modifier sont `App/ContentView.swift`,
`App/QuiXApp.swift` (passage en `MenuBarExtra` + fenêtres), `App/ImportModel.swift` (états de copie
par fichier) et l'Asset Catalog de l'icône. `Core/` n'a pas à changer.
