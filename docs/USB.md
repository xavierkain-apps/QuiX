# La caméra par le câble

Relevé sur la HERO12 Black de Xavier (série `C350132581xxxx`, firmware `H23.01.02.32.00`),
macOS 26.6, septembre 2026. Tout ce qui suit est mesuré, pas déduit d'une documentation.

## Ce que la caméra n'est pas

**Elle n'expose aucun stockage de masse.** C'est le point de départ, et il n'y a pas de réglage
pour le changer : la HERO12 n'a pas d'option « USB mass storage ». Branchée et allumée, elle
publie trois interfaces USB :

| Interface | Classe | |
|---|---|---|
| CDC Network Control Model | 2 / 13 | réseau, la voie utile |
| CDC Network Data | 10 | |
| MTP | 6 / 1 | protocole appareil photo |
| *(aucune)* | **8** | **stockage de masse — absent** |

Conséquence directe : `/Volumes/` ne montrera jamais la caméra, et `NSWorkspace.didMountNotification`
ne se déclenchera jamais pour elle. Chercher un dossier `DCIM/###GOPRO` sur un volume monté, qui est
le chemin correct pour une carte dans un lecteur, ne peut structurellement rien donner ici.

**Le MTP est un leurre.** Il est bien là, Transfert d'images voit la caméra — mais il ne publie que
deux fichiers de service, `leinfo.sav` et `Get_started_with_GoPro.url`. Aucun clip. Passer par
ImageCaptureCore mènerait à une impasse après beaucoup de travail.

## Ce qu'elle est

Un **serveur HTTP**, joignable par le réseau que monte le CDC NCM. C'est la voie qu'empruntait Quik,
et la seule qui donne accès aux clips.

L'adresse est dérivée du numéro de série, sous la forme `172.2X.1YZ.51`. On ne reproduit pas ce
calcul — il demanderait de connaître le série *avant* de parler à la caméra. On part des interfaces
de la machine : elle reçoit une adresse dans le même `/24`, et la caméra y occupe toujours `.51`.

```
GET /gopro/camera/info                    modèle, série, firmware
GET /gopro/camera/control/wired_usb?p=1   passe en contrôle filaire
GET /gopro/media/list                     le catalogue : dossier, nom, taille, date
GET /videos/DCIM/<dossier>/<nom>          le fichier
```

## Le point qui décide de tout

**Le serveur honore `Range`.** Mesuré sur un clip de 48,7 Mo :

```
Range: bytes=48664916-48699731/48699732
→ HTTP/1.1 206 Partial Content
  Accept-Ranges: bytes
  Content-Length: 34816
```

C'est ce qui sauve le principe de l'app. Les trois `seek` de `FileByteReader` deviennent trois
requêtes `Range`, et le `moov` de fin de fichier s'atteint sans rapatrier le clip. Le tri reste
gratuit par le câble comme sur une carte — voir `HTTPRangeByteReader`.

Si un firmware futur cessait de l'honorer, il faudrait télécharger chaque clip **avant** de savoir
où il va, ce que la règle n°1 du projet interdit. `CameraScanner` vérifie donc `Range` une fois par
session et remonte l'échec au lieu de le contourner en silence.

Les 34 Ko de fin ramenés par `Range` contiennent bien la chaîne attendue :

```
moov  à +3512      udta  à +3628      HMMT  à +3797, 332 octets
```

Et les deux clips de contrôle confirment le piège documenté dans [HILIGHT.md](HILIGHT.md) :
atome **identique** de 332 octets sur les deux, seul le compteur distingue le clip tagué (1) du
clip sans tag (0).

## L'autorisation qui ne se devine pas

macOS classe la caméra comme un périphérique réseau. Toute requête tombe donc sous la permission
**« Réseau local »** — pas « Fichiers et dossiers », qui ne concerne que la carte montée.

Le refus est particulièrement mauvais à diagnostiquer : `URLSession` rend `-1009`, *« la connexion
Internet semble hors service »*, alors qu'il n'est question ni d'Internet ni d'une panne. La seule
marque du refus est dans le `userInfo` :

```
_NSURLErrorNWPathKey = unsatisfied (Local network prohibited), interface: en10
```

Sans traitement particulier, une caméra branchée et une permission refusée sont indiscernables
d'une caméra absente : l'app paraît ne rien voir. `CameraWatcher` distingue donc explicitement les
deux, et l'app propose d'ouvrir le bon panneau des Réglages.

`curl` fonctionne pendant que l'app échoue — le Terminal a déjà la permission. Ce détail fait
perdre du temps : ne pas conclure d'un `curl` qui passe que le code passera.

## Une seule connexion à la fois

Le serveur de la caméra n'en tient qu'une, et ça ne se voit pas tout de suite. Avec
`URLSession.shared`, l'analyse laissait derrière elle une connexion inactive mais ouverte ; le
premier téléchargement qui suivait en réclamait une seconde, que la caméra refusait.

Le symptôme était déroutant, parce qu'il ne désignait pas le coupable : **le premier clip échouait,
les suivants passaient**, et relancer l'import réussissait toujours — la connexion inactive ayant
expiré entre-temps. On accusait le fichier, alors que seul son rang comptait.

Toutes les requêtes passent donc par des sessions à `httpMaximumConnectionsPerHost = 1`. Et comme
un lien USB peut lâcher pour d'autres raisons, `ImportRunner` retente trois fois avec un court
délai — ce qui ne coûte presque rien puisque la reprise repart des octets déjà reçus.

## Se faire réveiller au branchement

Il n'y a rien à surveiller quand l'app ne tourne pas : c'est `launchd` qui réveille QuiX, par un
agent déposé dans `~/Library/LaunchAgents` et apparié à l'apparition du périphérique USB. Tant que
la caméra n'est pas branchée, aucun processus n'existe.

L'agent lance **`open`**, pas l'exécutable : `open` se contente d'activer l'app si elle tourne déjà,
là où lancer le binaire donnerait deux fenêtres et deux imports concurrents sur la même carte.

Et **au premier plan**. On avait d'abord ouvert en arrière-plan (`open -g`) pour ne pas couper le
travail en cours ; c'était une erreur de jugement. Brancher sa caméra est une intention explicite,
et l'app se retrouvait à chercher du regard une fenêtre qui n'était nulle part. `open` sans `-g` ne
suffit pas tout à fait : une app réveillée par `launchd` ne passe pas toujours devant, d'où
l'`NSApp.activate()` au démarrage.

Un agent installé par une version précédente garde le comportement qu'il avait alors. `QuiXApp` le
compare donc au démarrage à ce qu'il devrait être, et ne le réécrit que s'il diffère — recharger
un agent à chaque démarrage pour rien serait une façon discrète de le rendre instable.

Trois détails de l'appariement ont été trouvés à l'essai, et aucun n'est devinable — **un agent qui
n'apparie rien ne se plaint pas**, il ne se déclenche simplement jamais, et `launchctl print`
l'affiche exactement comme s'il fonctionnait :

| | Ce qui marche | Ce qui ne marche pas |
|---|---|---|
| Nom de l'évènement | `com.apple.device-attach` | un nom libre — accepté, affiché, inerte |
| `IOProviderClass` | `IOUSBDevice` | `IOUSBHostDevice`, pourtant la vraie classe du nœud |
| Identifiants | `idVendor` **et** `idProduct` | `idVendor` seul |

Mesuré en rechargeant l'agent caméra branchée : l'appariement IOKit se déclenche aussi pour un
périphérique déjà présent, ce qui permet de vérifier sans débrancher (`runs = 1` dans
`launchctl print`, et l'app s'ouvre).

Le troisième point coûte quelque chose : l'agent ne reconnaît que le modèle mesuré, la HERO12 Black
(`idProduct` 89). Une autre GoPro demanderait son propre identifiant :

```sh
ioreg -p IOUSB -l | grep -A20 GoPro
```

## Deux pièges de mise en œuvre

**La détection ne peut pas être événementielle.** Il n'existe pas de notification pour l'apparition
d'un périphérique réseau comme il en existe pour un volume monté. `CameraWatcher` sonde toutes les
3 secondes ; quand rien n'est branché, aucune requête n'est émise du tout, la liste des candidats
étant vide.

**`URLSession` retient son délégué au-delà de l'appel.** `finishTasksAndInvalidate()` rend la main
avant d'avoir relâché quoi que ce soit. Un délégué qui garde des fermetures non-échappantes les
fait survivre à leur portée, et Swift arrête le programme — l'app plantait après le premier clip
importé, les 85 tests d'alors passant tous. `RemoteVerifiedCopy` relâche donc ses fermetures dès la
fin du transfert, et `RemoteCopyTests` monte un vrai serveur HTTP pour l'éprouver.
