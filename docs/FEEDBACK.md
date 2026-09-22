# Recevoir les retours des utilisateurs

Deux boutons, dans les Réglages et dans le menu Aide : **Signaler un bug** et **Proposer une
idée**. Chacun ouvre, dans le navigateur, le formulaire de
[quix.xavier-kain.fr/retour](https://quix.xavier-kain.fr/retour), avec le contexte technique
déjà rempli.

## Pourquoi une page web

**Pas un formulaire dans l'app** : il ferait transiter par QuiX des textes que l'utilisateur
n'aurait pas vus partir, et obligerait l'app à porter une politique de confidentialité. La page
montre ce qui part avant qu'il n'appuie. Rien ne quitte le Mac sans un clic de sa part.

**Pas GitHub non plus**, bien que le dépôt soit public et que les tickets s'y classent tout
seuls. Un compte GitHub est un mur pour quelqu'un qui vient d'Instagram pour trier ses clips.
Le serveur, lui, peut ouvrir le ticket à sa place.

## Ce que l'app passe dans l'URL

```
?type=bug&version=0.1.0+(1)&os=26.6.2&mac=Mac16,6&lang=fr_FR&camera=HERO12+Black
```

Des versions et des modèles, rien d'autre. **Jamais un chemin, jamais un nom de fichier, jamais
une adresse** : ce qui passe par une URL se retrouve dans les journaux du serveur.

Chacun de ces champs sert :

- **la version de QuiX**, sans quoi on corrige un bug déjà corrigé ;
- **la version de macOS**, parce que les autorisations et les notifications changent de
  comportement d'une version à l'autre — [NOTIFICATIONS.md](NOTIFICATIONS.md) en est une
  démonstration ;
- **le modèle de Mac**, parce qu'un défaut de copie USB peut tenir au contrôleur. Des centaines
  de milliers de Mac portent le même identifiant : il n'identifie personne ;
- **le modèle de caméra**, le plus important. Le format HiLight n'a été mesuré que sur une
  HERO12 Black — voir [HILIGHT.md](HILIGHT.md). Un rapport sans le modèle ne mène nulle part.

L'écran des réglages affiche ces lignes telles qu'elles partiront : on doit pouvoir lire ce
qu'on envoie avant de l'envoyer.

## Ce qu'il reste à faire côté serveur

Le formulaire n'existe pas encore : le lien mène à une page absente. Il lui faut un champ libre,
un champ e-mail **facultatif** — pour pouvoir répondre, pas pour constituer une liste — et de
quoi déposer une capture. Derrière, un ticket GitHub ouvert par le serveur, étiqueté `bug` ou
`enhancement` selon `type`.
