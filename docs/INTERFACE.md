# L'interface

Reprend le handoff `design_handoff_quix`, blocs `#2a` (popover), `#2b` (Transfert), `#2c`
(Bibliothèque) et `#4c` (icône). Ce fichier ne redit pas les valeurs — elles sont dans
[`App/Theme.swift`](../App/Theme.swift), en un seul exemplaire — mais ce que la mise en œuvre a
demandé de décider.

## Un seul endroit pour les jetons

Les maquettes sont en CSS, avec des couleurs en `oklch` que SwiftUI ne lit pas. `Theme.swift` porte
les équivalents sRGB **nommés par leur rôle** — `Ink.blue`, `Ink.raised`, `Ink.tertiary` — et non
par leur teinte. Changer l'accent un jour se fait là, et pas dans quinze vues.

L'échelle typographique du handoff est au demi-point (13,5 · 12,5 · 11,5) et ne correspond à aucun
style natif : on la pose telle quelle plutôt que d'approcher avec `.callout` et de dériver écran par
écran.

## Le thème est sombre par choix

`NSApp.appearance = .darkAqua` au démarrage. Sans cela, les barres de titre et les contrôles
système restent clairs au milieu de fenêtres à l'encre — le défaut se voit tout de suite sur une
capture, et jamais dans le code.

## Une fenêtre, deux onglets

Le handoff dessinait Transfert et Bibliothèque en deux fenêtres. Ce sont deux onglets d'une seule :
« Ouvrir les highlights » ne fait plus surgir une seconde fenêtre par-dessus la première, il bascule
d'onglet — on reste au même endroit.

L'onglet courant vit dans `AppRouter`, hors des vues, parce que trois endroits le changent : le
popover, la barre de menus, et le bouton du Transfert. Il voyage jusqu'aux vues profondes par
l'environnement plutôt que de main en main.

Le Transfert perd la largeur de 860 pt que le handoff lui donnait : il partage désormais la fenêtre
et s'étire. Sa table remplit la hauteur disponible, le pied reste ancré en bas.

## Les réglages ont leur fenêtre

Ils vivaient au pied du popover, qui n'est pas fait pour ça : on l'ouvre pour savoir où en est
l'import, pas pour cocher des cases. Fenêtre de `Settings`, donc ⌘, comme partout sur macOS.

Elle montre aussi l'**état des autorisations**, ce qu'aucun autre écran ne fait. Les deux que QuiX
demande échouent de la même façon trompeuse — l'app voit le matériel et ne trouve rien. Faute d'API
pour interroger la permission « Réseau local », l'état se déduit de ce que la caméra répond :
« manquante » n'est affirmé que si une caméra est branchée et refuse, « demandée au besoin » sinon.

## Les menus

SwiftUI en ajoute par défaut qui ne correspondent à rien ici : l'app ne crée pas de document,
n'imprime pas, n'a pas de barre d'outils. Ils sont retirés plutôt que laissés grisés, ce qui donne
l'air d'une app inachevée. Restent les onglets, en ⌘1 et ⌘2.

## Ce que le popover ne peut pas faire

Une `MenuBarExtra` ne s'ouvre **pas** par programme. C'est sans conséquence tant que l'utilisateur
clique, mais l'app se réveille aussi toute seule au branchement de la caméra : dans ce cas le
popover reste fermé et rien ne s'affiche.

La fenêtre s'ouvre donc d'elle-même, sur l'onglet Transfert, quand l'état passe à `ready` ou
`importing`. Le déclencheur est posé sur la vue de l'item de barre de menus, seule à vivre en
permanence — le placer dans la fenêtre ne l'aurait ouverte que lorsqu'elle l'était déjà.

## Une seule file, deux affichages

Le popover et la table de Transfert montrent les mêmes fichiers. `ImportModel.queue` les calcule à
partir du plan et de la progression ; les deux vues s'y abonnent. Dessiner la même chose deux fois
aurait fini par donner deux vérités.

L'état par fichier se déduit de `ImportProgress.fileIndex` — avant, c'est vérifié ; à l'index, en
cours ; après, en attente — sans rien changer à `Core`. Le passage d'un fichier au suivant compte
donc autant que le pourcentage dans la remontée de progression : sans lui, la file afficherait le
premier fichier « en cours » pendant tout un import de petits clips.

Le plan est publié dès qu'il existe, et pas seulement au démarrage de la copie : la table montre la
file « en attente » avant qu'on ait cliqué sur Importer.

## Vignettes

Extraites à la volée par `AVAssetImageGenerator`, **au premier moment tagué** quand il y en a un —
l'image qui dit pourquoi la prise est dans `Highlights/`. À défaut, à une seconde du début, et non
à zéro : la première image d'un clip GoPro est souvent noire.

Le cadre impose le 16:9 et l'image s'y recadre, via un `GeometryReader`. Sans lui c'est l'image qui
dicte sa taille, et une prise filmée à la verticale étire la vignette sur toute la hauteur de la
grille.

## Moments

La piste de l'inspecteur place chaque tag au prorata de la durée du clip, plafonné à 98 %. Un
fichier dont la durée n'est pas encore chargée répartit ses moments régulièrement plutôt que de
les empiler tous à gauche.

## Un piège de mise en page

`Color.clear.frame(width: 24)` ne contraint que la largeur. Une `Color` étant extensible, la hauteur
restait libre : l'en-tête de la table s'étirait sur toute la fenêtre et poussait les lignes vers le
bas, avec ses intitulés flottant au milieu du vide. Le défaut ne se voit ni à la compilation ni à la
lecture du code — seulement à l'écran.

## L'icône

Redessinée en Core Graphics d'après `#4c`, et non exportée d'un outil : les proportions du handoff
sont données en 168e, donc directement calculables à chaque taille. Le générateur est dans
l'historique du dépôt ; les PNG sont dans `App/Assets.xcassets`.

Un piège en passant : un dégradé Core Graphics ne peint **rien** au-delà de son axe sans
`.drawsBeforeStartLocation` / `.drawsAfterEndLocation`. Les deux coins opposés du squircle
restaient transparents, ce qui ne se voit qu'à l'œil.

Le glyphe de la barre de menus est dessiné en code plutôt qu'importé : c'est une forme de dix
lignes, et une image de plus serait une image de plus à régénérer au premier changement de
proportion.
