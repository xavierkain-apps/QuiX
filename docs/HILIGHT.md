# Format HiLight — relevé sur la caméra de Xavier

Mesuré le 2026-09-07 sur deux clips réels, un tagué et un non tagué.
Lève la réserve du brief sur les modèles récents : **le HMMT classique marche**.

| | |
|---|---|
| Caméra | **HERO12 Black** (`GPMF/MINF`) |
| Firmware | `H23.01.02.32.00` (`udta/FIRM`) |
| Objectif | `LSU3121202401859` (`udta/LENS`) |
| Numéro de série | `C3501325811702` (`GPMF/CASN`) |

## Où vit l'information

```
ftyp        @0          20 o
free        @20          8 o
mdat        @28    ~90 Mo      <- la vidéo
moov        @89 793 449  34 Ko  <- tout le reste, EN FIN DE FICHIER
  mvhd                          timescale + durée
  udta
    FIRM LENS CAME SETT MUID
    HMMT                 332 o  <- les highlights
    BCID GUMI
    GPMF               25 Ko    <- télémétrie, dont un flux HLMT
```

## Piège n°1 — `moov` est à la fin, pas au début

Le brief dit « on ne lit que l'en-tête ». C'est l'idée juste avec le mauvais mot :
chez GoPro, `mdat` vient en premier et `moov` ferme le fichier. Lire les premiers
kilo-octets ne donne rien.

Ça ne coûte pas plus cher pour autant. On parcourt les boîtes de premier niveau
en ne lisant que leur en-tête de 8 octets et en sautant `mdat` par sa taille :
**trois `seek`, puis ~34 Ko lus**. Scanner une carte entière reste une affaire de
secondes. Le tri avant copie tient toujours.

À gérer : `size == 1` (taille 64 bits sur 8 octets de plus, cas d'un `mdat` de
plus de 4 Go) et `size == 0` (la boîte va jusqu'à la fin — un `mdat` ainsi formé
masquerait `moov`, il faut le traiter comme un fichier sans highlights, pas
comme une erreur).

## Piège n°2 — HMMT fait toujours 332 octets, taggé ou non

C'est le piège qui coûte l'app entière.

```
HMMT, charge utile de 324 octets, invariante :
  [0..3]     uint32 BE   nombre de moments
  [4..323]   uint32 BE × 80   emplacements, remplis de zéros
```

GoPro **préalloue 80 emplacements**. Le clip sans aucun highlight porte le même
atome de 332 octets que le clip taggé ; seul le compte change.

Donc :

- **Ne jamais déduire le nombre de moments de la taille de l'atome.**
  `(taille - 8 - 4) / 4` donnerait 80 sur *tous* les clips, tout partirait dans
  `Highlights/`, et l'app perdrait sa seule raison d'être — sans lever la moindre
  erreur. C'est précisément ce que le clip non tagué a permis de voir.
- **La présence de HMMT ne veut pas dire « clip highlighté ».** Le critère est
  `nombre de moments > 0`.
- Borner le compte lu par le nombre d'emplacements réellement disponibles dans
  l'atome avant de boucler : un compte aberrant ne doit pas faire lire au-delà.
- L'absence totale de HMMT (autre caméra, fichier remuxé) se lit « aucun
  highlight », jamais « erreur ».

## Mesures

| Fichier | Durée | HMMT count | Moments |
|---|---|---|---|
| `GX013097.MP4` | 6,17 s (`mvhd` 370370/60000) | 0 | — |
| `GX013129.MP4` | 7,26 s (`mvhd` 435435/60000) | 1 | 3436 ms |

## Recoupement : le flux GPMF/HLMT

`udta/GPMF` contient un flux `HLMT` au format KLV maison de GoPro, décrit par sa
propre `RMRK` :

```
struct: Time (ms), in (ms), out (ms), Location XYZ (deg,deg,m), Type, Confidence (%) Score
```

Sur le clip tagué il porte `00 00 0d 6c` trois fois — soit 3436 en time, in et
out. **Il confirme HMMT exactement.**

On ne l'utilise pas : lire HLMT demanderait un parseur KLV complet pour une
information déjà obtenue en trente lignes. À garder en tête si un jour un modèle
cesse d'écrire HMMT.

## Ce qui reste hors de portée

Les highlights ajoutés après coup dans l'app mobile Quik ne sont pas réécrits
dans le MP4 — ni dans HMMT, ni dans HLMT. Limite à afficher dans l'interface,
pas un bug à corriger.

## Échantillons de test

`Core/Tests/QuiXCoreTests/Fixtures/` contient les deux `moov` réels, remontés
derrière un `mdat` vide pour garder la géométrie « moov en dernier ». 34 Ko
chacun au lieu de 90 Mo, et les mêmes octets que la caméra a écrits.
