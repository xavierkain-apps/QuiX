# Échantillons

Extraits le 2026-09-07 de deux clips réels d'une **HERO12 Black**
(`GX013097.MP4` et `GX013129.MP4`, non versionnés).

Chaque fichier est le `ftyp` et le `free` d'origine, un `mdat` réduit à son
en-tête vide, puis **l'atome `moov` réel, octet pour octet**. La vidéo saute,
la géométrie reste : `moov` arrive en dernier, comme sur la carte.

| Fichier | HMMT count | Moments | Ce qu'il prouve |
|---|---|---|---|
| `hero12-sans-highlight.mp4` | 0 | — | HMMT fait 332 octets **même sans highlight** : la taille de l'atome ne dit rien du nombre de moments |
| `hero12-un-highlight.mp4` | 1 | 3436 ms | Lecture d'un moment réel, `moov` en fin de fichier |

Le premier est le plus important des deux. Voir `docs/HILIGHT.md`.
