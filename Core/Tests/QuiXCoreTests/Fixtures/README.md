# Échantillons

Extraits le 2026-09-07 de deux clips réels d'une **HERO12 Black** (non versionnés).

Chaque fichier est le `ftyp` et le `free` d'origine, un `mdat` réduit à son en-tête vide, puis
**l'atome `moov` réel**. La vidéo saute, la géométrie reste : `moov` arrive en dernier, comme sur
la carte.

| Fichier | HMMT count | Moments | Ce qu'il prouve |
|---|---|---|---|
| `hero12-sans-highlight.mp4` | 0 | — | HMMT fait 332 octets **même sans highlight** : la taille de l'atome ne dit rien du nombre de moments |
| `hero12-un-highlight.mp4` | 1 | 3436 ms | Lecture d'un moment réel, `moov` en fin de fichier |

Le premier est le plus important des deux. Voir `docs/HILIGHT.md`.

## Ce qui a été retiré

Le dépôt est public. Trois identifiants matériels ont été remplacés **avant l'ouverture**, à
longueur d'octets constante pour ne déplacer aucun offset :

- le numéro de série de la caméra (`GPMF/CASN`),
- celui de l'objectif (`udta/LENS` et `GPMF/LINF`),
- l'empreinte binaire du boîtier, commune à `udta/CAME`, `udta/MUID` et au GPMF,

et les atomes d'identifiant pur — `CAME`, `MUID`, `GUMI`, `BCID` — ont été mis à zéro. Rien de tout
ça n'est lu, ni par le moteur ni par les tests.

**Aucune donnée GPS n'a jamais été présente.** La télémétrie GoPro vit dans une piste `gpmd` à
l'intérieur du `mdat`, qui ne fait pas partie des échantillons ; le champ « Location XYZ » de
l'enregistrement `HLMT` est à zéro sur ces deux clips.

Ce qui reste est ce qui documente le format et sert aux tests : modèle, version de firmware,
réglages de prise de vue, et l'atome `HMMT` intact.
