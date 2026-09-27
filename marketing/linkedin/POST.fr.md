J'ai construit l'app qui me manquait. Et son site.

Quand je filme en GoPro, j'appuie sur un bouton pendant l'enregistrement dès qu'il se passe quelque chose de bien. La caméra marque l'instant dans le fichier : c'est un HighLight.

Pendant des années, Quik Desktop récupérait ces marques et triait les vidéos à l'import. GoPro l'a abandonné fin 2024. Depuis, je me retrouvais avec des heures de rushs à parcourir pour retrouver trois moments.

Alors j'ai fait QuiX.

Tu branches la caméra, et QuiX range les prises marquées dans un dossier Highlights et le reste dans Clips. Rien d'autre à faire.

Ce que j'ai aimé résoudre en chemin :

→ Trier ne coûte rien. Les marques sont stockées à la fin du fichier vidéo. Lire environ 34 Ko suffit pour savoir où va une vidéo de 4 Go, avant même de la copier.

→ En USB, une GoPro n'est pas un disque. Elle monte une interface réseau et répond en HTTP. Il a fallu la traiter comme un petit serveur, pas comme une clé USB.

→ Effacer la caméra ne se fait jamais tout seul. Le bouton n'apparaît que si chaque fichier a été retrouvé sur le Mac, à la bonne taille.

Côté produit : app macOS native, signée et notarisée par Apple, mises à jour automatiques, en français et en anglais. Et un site en motion design pour la présenter (c'est lui qui défile dans la vidéo).

C'est gratuit, sans compte, sans pub.

Le lien est en commentaire 👇

#macOS #SwiftUI #GoPro #IndieDev #ProductDesign
