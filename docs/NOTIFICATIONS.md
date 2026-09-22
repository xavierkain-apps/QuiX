# L'icône absente des notifications

La bannière de fin d'import s'affiche, avec le bon titre et le bon texte, mais à la place de
l'icône de QuiX macOS dessine son **gabarit vide** — le carré arrondi pâle strié d'une grille.

**Ce n'est pas un défaut de QuiX.** C'est l'enregistrement de l'identifiant
`com.xavierkain.QuiX` auprès du système de notifications du Mac de développement qui est
abîmé. Un Mac qui installe QuiX une seule fois n'a pas le problème.

## La preuve

Une app témoin de quarante lignes — rien d'autre qu'une notification — signée du même
certificat, posée dans `/Applications`, portant **le même fichier `AppIcon.icns` que QuiX** :

| Identifiant du témoin | Icône dans la bannière |
|---|---|
| `com.xavierkain.SondeNotif` (neuf) | **affichée** |
| `com.xavierkain.QuiX` | **absente** |

Même binaire, même icône, même signature. Seul l'identifiant change. L'icône n'entre pas en
ligne de compte : c'est l'identifiant qui porte le défaut.

## Ce qui a été écarté en chemin

Chaque essai a été vérifié de la même façon : un import réel depuis une fausse carte GoPro,
puis une capture de la **fenêtre de la bannière par son identifiant** — jamais une capture
d'écran, qui emporterait ce qu'il y a derrière.

| Piste | Résultat |
|---|---|
| Six copies périmées du bundle dans LaunchServices, dont trois fantômes | désenregistrées — sans effet |
| Caches d'icônes, `usernoted`, `NotificationCenter`, `iconservicesagent` | vidés et relancés — sans effet |
| Réinstallation propre dans `/Applications` | sans effet |
| `NSPrincipalClass` absent de l'`Info.plist` | ajouté — sans effet, mais gardé : c'est correct |
| Nom localisé de l'app résolu en « ? » par `lsregister` | corrigé — sans effet, mais gardé |
| Catalogue d'assets (dix tailles, `Assets.car` complet) | forme d'origine — sans effet |
| Format Icon Composer `AppIcon.icon` de macOS 26 | accepté par `actool` — sans effet |
| `.icns` complet, dix types `ic04`→`ic14`, sans catalogue | forme actuelle — sans effet |
| `tccutil reset All com.xavierkain.QuiX` | sans effet : les notifications ne sont pas dans TCC |
| Purge de l'historique de notifications de l'app | sans effet |

Le journal système dit, pendant chaque bannière :

```
iconservicesagent: Failed to find named image for name:<private> … appearanceName:NSAppearanceNameAqua
```

## Comment le réparer sur ce Mac

Le magasin qui porte le défaut vit dans le conteneur scellé de `usernoted` ; aucune commande
n'y touche. `usernoted` reconstruit ses fiches d'applications **à l'ouverture de session** :
**quitter QuiX, redémarrer le Mac, rouvrir QuiX**. Non vérifié — on ne redémarre pas la
machine de quelqu'un pour tester.

## Ce qui reste utile de cette chasse

Trois corrections de fond, gardées parce qu'elles sont justes même si elles n'ont rien résolu
ici : un `Info.plist` qui nous appartient, un `.icns` complet au lieu des quatre tailles que
gardait Xcode, et le nom de l'app déclaré dans les catalogues de langue.
