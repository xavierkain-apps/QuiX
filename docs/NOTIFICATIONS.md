# L'icône absente des notifications

La bannière de fin d'import s'affiche, avec le bon titre et le bon texte, mais à la place de
l'icône de QuiX macOS dessine son **gabarit vide** — le carré arrondi pâle strié d'une grille,
celui d'Icon Composer quand aucune image n'est fournie.

## Ce qui a été écarté, mesuré et non supposé

Chaque essai a été vérifié de la même façon : un import réel depuis une fausse carte GoPro,
puis une capture de la **fenêtre de la bannière par son identifiant** — jamais une capture
d'écran, qui emporterait ce qu'il y a derrière.

| Piste | Résultat |
|---|---|
| Copies périmées du bundle dans LaunchServices (six, dont trois fantômes) | désenregistrées — sans effet |
| Cache d'icônes utilisateur, `usernoted`, `NotificationCenter` | vidés et relancés — sans effet |
| Réinstallation propre dans `/Applications` | sans effet |
| `NSPrincipalClass` absent de l'`Info.plist` | ajouté — sans effet, mais gardé : c'est correct |
| Catalogue d'assets (dix tailles, `Assets.car` complet) | forme d'origine — sans effet |
| Format Icon Composer `AppIcon.icon` de macOS 26 | accepté par `actool` — sans effet |
| `.icns` complet, dix types `ic04`→`ic14`, sans catalogue | forme actuelle — sans effet |

Le bundle est par ailleurs irréprochable : `codesign` donne `Identifier=com.xavierkain.QuiX`,
signé Developer ID et notarisé ; `lsregister` résout l'app ; et `NSWorkspace.icon(forFile:)`
rend l'icône jusqu'en 2048 px.

## Les deux indices qui restent

**Le journal.** Pendant la bannière, `iconservicesagent` écrit :

```
Failed to find named image for name:<private> scaleFactor:0.000000 … appearanceName:NSAppearanceNameAqua
```

**L'absence.** `com.apple.ncprefs` liste 144 apps autorisées à notifier — Chrome, Notion,
WhatsApp, jusqu'à l'app GoPro. **QuiX n'y est pas**, alors que ses notifications arrivent.
C'est l'anomalie : une app dont les bannières s'affichent sans qu'elle figure parmi les
clients enregistrés. Le gabarit vide ressemble à la conséquence de cette absence, pas à un
problème d'icône.

Une hypothèse tient : le bundle de `/Applications/QuiX.app` a été remplacé des dizaines de fois
pendant le développement. Si l'enregistrement est lié au bundle et disparaît avec lui,
l'autorisation, elle, reste accordée — donc l'invite système ne revient jamais, et
l'enregistrement n'est jamais recréé. Sur un Mac qui installe QuiX une fois, le problème
n'existerait pas. **Ce n'est pas démontré.**

## Ce qui trancherait

Une app témoin, avec un identifiant neuf, qui poste une notification. Son invite d'autorisation
demande un clic. Si elle obtient son icône, le défaut est propre à l'enregistrement de QuiX sur
ce Mac ; sinon, aucune app tierce n'obtient d'icône ici et il n'y a rien à corriger dans QuiX.
