# Checklist matérielle

Ce que l'intégration continue ne peut pas prouver. À cocher sur le Mac, avec la vraie GoPro et un
lecteur de carte.

L'automatisé est ailleurs : `swift test --package-path Core` couvre le décodage HMMT sur les deux
`moov` réels, le regroupement en prises, le plan d'import, l'idempotence et la copie vérifiée ; la
CI compile l'app sur macOS. Rien de ce qui suit n'est automatisable sans matériel.

## Préparation, une seule fois

- [ ] Ouvrir `QuiX.xcodeproj`, onglet **Signing & Capabilities**, choisir l'équipe de développement.
      Xcode inscrit `DEVELOPMENT_TEAM` dans le projet — à committer.
- [ ] Compiler, lancer, choisir le dossier d'import quand l'app le demande.
- [ ] **Accorder l'accès aux volumes amovibles** quand macOS le demande, au premier branchement.
      Sans cette autorisation, l'app voit le volume monter et ne trouve aucun fichier dedans — le
      symptôme ressemble exactement à une carte vide.
      La présence de `NSRemovableVolumesUsageDescription` dans l'`Info.plist` est vérifiée par la
      CI ; ce qui reste à voir à la main, c'est que macOS pose bien la question.

## Le comportement quotidien

- [ ] **1.** Carte GoPro dans le lecteur : la fenêtre réagit seule et l'import démarre.
- [ ] **2.** **Les highlights sont les bons.** Prendre une prise dont on se souvient d'avoir tagué,
      vérifier qu'elle est dans `Highlights/` — et qu'une prise non taguée est dans `Clips/`.
      C'est le seul point qui valide le produit ; tout le reste n'est que de la plomberie.
- [ ] **3.** **Une longue prise à plusieurs chapitres.** Filmer plus de 4 Go d'un coup, tagger un
      seul chapitre, vérifier que **tous** les chapitres arrivent ensemble dans `Highlights/`.
      Ce cas produit un `mdat` de plus de 4 Go, donc un en-tête de taille sur 64 bits : c'est aussi
      le seul moyen de vérifier en vrai le chemin de code testé par `testSixtyFourBitSizeIsUnderstood`.
- [ ] **4.** **La carte est intacte.** Après un import complet, comparer le nombre de fichiers dans
      `DCIM/` avant et après. Rien ne doit avoir bougé.
- [ ] **5.** **Rebrancher la même carte ne recopie rien.** Le second import doit annoncer
      « déjà importé » sur toute la carte et ne créer aucun dossier daté vide.
- [ ] **6.** **Débrancher la carte en plein import.** L'app doit s'arrêter proprement, et il ne doit
      rester aucun `.quix-partiel` ni aucun `.MP4` tronqué dans le dossier de destination.
- [ ] **7.** **Une carte qui n'est pas une GoPro** — clé USB, carte d'appareil photo, disque
      externe. L'app ne doit rien faire du tout, même si le volume s'appelle « GOPRO ».
- [ ] **8.** Case « demander confirmation » cochée : brancher la carte affiche le résumé et attend
      le clic. Décochée : l'import part seul.
- [ ] **9.** « Ouvrir les highlights » ouvre bien le dossier dans le Finder.
- [ ] **10.** **La durée sur une carte pleine.** Chronométrer le scan d'une carte bien remplie : il
      doit se compter en secondes, pas en minutes. Si c'est long, c'est que quelque chose lit les
      vidéos au lieu de leurs en-têtes, et toute la conception s'effondre.

## Ce qu'on sait déjà ne pas marcher

- [ ] **La caméra branchée en USB** se présente en MTP et n'apparaît pas sous `/Volumes/`. L'app ne
      la verra pas. C'est attendu : le chemin nominal est la carte dans un lecteur. Vérifier au
      moins que ça ne provoque rien de bizarre.
- [ ] **Les highlights ajoutés après coup dans l'app mobile Quik** ne sont pas dans le MP4 et ne
      seront jamais vus. Vérifier que la fenêtre le dit clairement.

## Avant de distribuer

`codesign --verify`, l'universalité du binaire et le runtime durci sont vérifiés par la CI à chaque
push — voir [SIGNING.md](SIGNING.md). Ne reste que ce qui demande une vraie machine :

- [ ] Télécharger l'artefact `QuiX` de la CI sur un Mac qui n'a jamais compilé le projet, et le
      lancer. Sans les secrets de signature, Gatekeeper doit avertir une fois ; avec, il ne doit
      rien dire du tout.
- [ ] Lancer l'app depuis un compte utilisateur qui ne l'a jamais vue, pour retomber sur la demande
      d'autorisation des volumes amovibles à froid.
