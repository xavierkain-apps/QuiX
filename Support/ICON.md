# L'icône

Trois fichiers, dans cet ordre :

1. `tools/AppIcon.swift` dessine les dix tailles PNG dans `Support/AppIcon.iconset/`.
2. `iconutil -c icns Support/AppIcon.iconset -o App/AppIcon.icns` les assemble.
3. `App/AppIcon.icns` est versionné et copié tel quel dans le bundle, désigné par
   `CFBundleIconFile` dans [Info.plist](Info.plist).

```sh
swift tools/AppIcon.swift Support/AppIcon.iconset
iconutil -c icns Support/AppIcon.iconset -o App/AppIcon.icns
```

## Pourquoi pas un catalogue d'assets

C'est la voie normale, et c'est celle qu'on suivait. Elle produit un `.icns` **amputé** :
Xcode n'y met que les tailles qu'il juge utiles, et le reste ne vit que dans `Assets.car`.
Passer par `iconutil` donne les dix types — `ic04` à `ic14` — dans un seul fichier que
n'importe quel client système sait lire.

Cela dit, ça n'a pas résolu le problème pour lequel on l'a fait : l'icône reste absente des
notifications. Voir [docs/NOTIFICATIONS.md](../docs/NOTIFICATIONS.md).
