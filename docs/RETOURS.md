# Recevoir les retours des utilisateurs

Deux boutons, dans les Réglages et dans le menu Aide : **Signaler un bug** et **Proposer une
idée**. Chacun ouvre dans le navigateur un ticket GitHub **pré-rempli** — un canevas de
questions, et ce qu'on a mesuré de la machine.

## Pourquoi pas un formulaire dans l'app

Un formulaire demanderait un serveur, une adresse où poster, une politique de confidentialité,
et ferait transiter par QuiX des textes libres que l'utilisateur n'a pas vus partir. Ouvrir une
page pré-remplie ne fait rien de tout cela : il lit ce qui part, l'efface s'il veut, et envoie
lui-même. **Rien ne quitte le Mac sans qu'il ait cliqué.**

Le prix en est un compte GitHub. C'est un mur pour un public qui vient d'Instagram, et c'est
la limite connue de cette version. Le jour où le site porte un formulaire, une seule ligne
change : `Feedback.destination`.

## Ce qui est joint, et rien d'autre

```
QuiX 0.1.0 (1) · macOS 26.6.2 · Mac16,6 · Camera HERO12 Black
```

Quatre choses, et elles sont toutes nécessaires :

- **la version de QuiX**, sans quoi on corrige un bug déjà corrigé ;
- **la version de macOS**, parce que les autorisations et les notifications changent de
  comportement d'une version à l'autre — [docs/NOTIFICATIONS.md](NOTIFICATIONS.md) en est une
  démonstration ;
- **le modèle de Mac**, parce qu'un défaut de copie USB peut tenir au contrôleur. Des centaines
  de milliers de Mac portent le même identifiant : il n'identifie personne ;
- **le modèle de caméra**, le plus important de tous. Le format HiLight n'a été mesuré que sur
  une HERO12 Black — voir [docs/HILIGHT.md](HILIGHT.md). Un rapport sans le modèle ne mène
  nulle part.

Aucun nom de fichier, aucun chemin, aucune adresse, aucun identifiant de machine.

## Ce qu'on en fait

Les tickets arrivent étiquetés `bug` ou `enhancement`. Un bug qui cite un modèle de caméra
autre que la HERO12 est le plus précieux du lot : c'est la couverture matérielle qu'on ne peut
pas acheter.
