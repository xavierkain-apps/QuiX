# QuiX

App macOS qui importe les clips d'une GoPro et sépare automatiquement les prises
**highlightées** du reste. Remplace la seule fonction de Quik Desktop dont
Xavier se servait, après son abandon par GoPro fin 2024.

## À lire en premier

**[BRIEF.md](BRIEF.md)** — le besoin, le format des tags HiLight, les pièges des
fichiers GoPro, l'architecture et l'ordre de construction. Le lire en entier
avant d'écrire du code.

**[docs/HILIGHT.md](docs/HILIGHT.md)** — le format HiLight tel qu'il est réellement
écrit par la HERO12 de Xavier, mesuré sur deux vrais clips. Deux pièges y sont
relevés, dont un qui casse l'app en silence.

**[docs/USB.md](docs/USB.md)** — ce que la caméra est vraiment quand on la branche :
pas un disque, mais un serveur HTTP. À lire avant de toucher au chemin USB.

## Structure

- `Core/` — moteur Swift pur (parsing HMMT + import), testable sur Linux
- `App/` — app SwiftUI macOS, compilée sur le Mac uniquement
- `docs/` — décisions et notes

## Les quatre choses à ne pas oublier

1. **Le tri est gratuit.** Les tags HiLight sont dans `moov/udta/HMMT`, et chez
   GoPro `moov` est en **fin** de fichier : trois `seek` et ~34 Ko lus suffisent
   à savoir où va un clip. Ne pas copier puis trier. Et ne jamais déduire le
   nombre de highlights de la taille de HMMT — voir [docs/HILIGHT.md](docs/HILIGHT.md).
2. **Une prise, un dossier.** Les chapitres d'une longue prise partagent le
   numéro de fichier GoPro. Si l'un est taggé, tous suivent.
3. **Jamais d'effacement de la carte.** L'effacement reste une action manuelle,
   dans la caméra.
4. **La caméra en USB n'est pas un disque.** Elle n'expose aucun stockage de masse :
   elle monte un réseau et répond en HTTP. Le tri y reste gratuit parce qu'elle
   honore `Range` — mesuré, pas supposé. Voir [docs/USB.md](docs/USB.md).

## Où l'on se trouve

Ce dépôt se travaille depuis deux machines, et la consigne n'est pas la même :

- **Sur le serveur Linux de Xavier**, où le projet a été écrit : on écrit le code
  et les décisions, on ne compile rien. La machine est saturée (~200 Mo de RAM
  libre, swap au plafond) et Swift n'y est même pas installé. C'est
  l'intégration continue qui compile et qui teste — voir
  [.github/workflows/ci.yml](.github/workflows/ci.yml).
- **Sur le Mac** : on compile, on lance, on essaie sur une vraie carte. Les
  commandes exactes sont dans le [README](README.md), section « Construire sur
  le Mac », et ce qu'il faut vérifier à la main dans
  [VERIFICATION.md](VERIFICATION.md).
