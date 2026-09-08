# Signature et notarisation

La CI signe et notarise l'app **dès que les cinq secrets existent**. Sans eux, elle produit quand
même un bundle, en signature ad hoc : il se lance, mais Gatekeeper avertit au premier démarrage sur
une machine qui ne l'a pas compilé.

QuiX vit dans l'organisation **`xavierkain-apps`**, avec FCP CleanX. L'objectif est que les secrets
y soient posés **une fois pour toutes**, au niveau de l'organisation, pour que chaque nouvelle app
soit signée sans rien avoir à recopier.

## Comment fabriquer les cinq valeurs

À faire sur le Mac. Rien à refaire si le `.p12` de FCP CleanX a été gardé : c'est le même
certificat qui signe toutes les apps distribuées hors App Store.

**1. Le certificat.** Xcode ▸ Settings ▸ Accounts ▸ l'Apple ID ▸ **Manage Certificates…** ▸ **+** ▸
**Developer ID Application**. Puis Trousseau d'accès ▸ « Mes certificats » ▸ clic droit sur
« Developer ID Application: … » ▸ **Exporter…** ▸ format `.p12` ▸ choisir un mot de passe.

**2. L'encoder**, parce qu'un secret GitHub ne prend que du texte :

```sh
base64 -i certificat.p12 | pbcopy
```

La CI accepte aussi l'hexadécimal (`xxd -p certificat.p12 | pbcopy`) : ce sont les mêmes octets,
et elle reconnaît lequel des deux elle a reçu. Ce qu'elle ne peut pas deviner, c'est un `.cer`
téléchargé depuis le portail Apple — il ne contient pas la clé privée.

**3. Le mot de passe d'application.** https://account.apple.com ▸ Connexion et sécurité ▸
**Mots de passe d'application** ▸ en créer un, nom « CI apps macOS ». Ce n'est **pas** le mot de
passe Apple.

**4. L'identifiant d'équipe.** https://developer.apple.com/account ▸ Membership details, dix
caractères.

| Secret | Contenu |
|---|---|
| `MACOS_CERT_P12` | Le `.p12` encodé en base64 (étape 2) |
| `MACOS_CERT_PASSWORD` | Le mot de passe choisi à l'export |
| `APPLE_ID` | L'Apple ID, en clair |
| `APPLE_APP_PASSWORD` | Le mot de passe d'application (étape 3) |
| `APPLE_TEAM_ID` | L'identifiant d'équipe (étape 4) |

## Où les poser — au niveau de l'organisation

https://github.com/organizations/xavierkain-apps/settings/secrets/actions ▸ **New organization
secret**, cinq fois.

Pour chacun, **Repository access : Public repositories**.

C'est le seul choix disponible : l'organisation est en plan **Free**, où GitHub écrit noir sur blanc
« Organization secrets cannot be used by private repositories with your plan ». C'est pour cette
raison que QuiX est un dépôt **public**. Le contenu des échantillons a été audité avant l'ouverture,
voir plus bas.

En ligne de commande, si tu préfères — il faut d'abord élargir le jeton, `gh` ne demande pas le
scope `admin:org` par défaut :

```sh
gh auth refresh -h github.com -s admin:org

base64 -i certificat.p12 | gh secret set MACOS_CERT_P12 --org xavierkain-apps --visibility all
gh secret set MACOS_CERT_PASSWORD --org xavierkain-apps --visibility all
gh secret set APPLE_ID            --org xavierkain-apps --visibility all
gh secret set APPLE_APP_PASSWORD  --org xavierkain-apps --visibility all
gh secret set APPLE_TEAM_ID       --org xavierkain-apps --visibility all
```

(`--visibility all` vaut « tous les dépôts auxquels le plan donne droit », soit les publics ici.)

## Vérifier

Pousser un commit. Dans le job « App — bundle macOS », les étapes **Importer le certificat
Developer ID** et **Notariser** doivent **apparaître au lieu d'être sautées**, et l'étape de
vérification doit répondre `accepted` à `spctl --assess`. C'est un signal sans ambiguïté : soit les
deux étapes tournent, soit elles sont grisées.

## Deux pièges rencontrés, et réglés

**Le certificat peut être fourni en hexadécimal.** `xxd -p certificat.p12` et
`base64 -i certificat.p12` portent les mêmes octets ; la CI reconnaît lequel elle a reçu. Ce qu'elle
refuse, à raison, c'est un `.cer` du portail Apple — il ne contient pas la clé privée.

**`xcodebuild build` injecte un entitlement de débogage.** `com.apple.security.get-task-allow`
autorise un débogueur à s'attacher au processus : normal en développement, refusé par Apple à la
notarisation. `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` le retire, et la vérification le contrôle
avant chaque soumission — une seconde ici plutôt que deux minutes d'aller-retour chez Apple pour un
message qui ne dit pas comment s'en défaire.

## Ce qu'un dépôt public change

**Le certificat reste hors d'atteinte.** GitHub retient les secrets sur toute proposition de
modification venue d'un fork, et le workflow ajoute la garde explicite : les étapes de signature ne
tournent que sur un `push`, jamais sur une `pull_request`. Le droit d'écriture du jeton est réduit
au seul job qui publie une release.

**Les minutes deviennent gratuites.** Les exécuteurs standards sont sans quota sur un dépôt public,
macOS compris. La contrainte des 2 000 minutes mensuelles de l'organisation ne s'applique plus à
QuiX — elle ne concerne plus que les dépôts restés privés.

**Les échantillons ont été nettoyés.** Voir
[Core/Tests/QuiXCoreTests/Fixtures/README.md](Core/Tests/QuiXCoreTests/Fixtures/README.md) : les
numéros de série de la caméra et de l'objectif, et l'empreinte binaire du boîtier, ont été
remplacés par des zéros avant l'ouverture du dépôt — historique git réécrit compris. Aucune donnée
GPS n'a jamais été présente : la télémétrie vit dans le `mdat`, qui n'est pas dans les échantillons.

## Ce que les secrets ne font pas tout seuls

Une nouvelle app dans l'organisation est signée automatiquement **à condition d'avoir le workflow**.
Les secrets ne signent rien ; c'est `.github/workflows/ci.yml` qui les utilise. Pour une prochaine
app, copier le job « App — bundle macOS » de QuiX et remplacer le nom du projet, du schéma et du
bundle suffit — c'est le seul fichier à reprendre.

## Pour la prochaine app

Si elle est publique, elle hérite des cinq secrets sans rien faire, et ses minutes sont gratuites.

Si elle doit rester privée, les secrets d'organisation ne l'atteindront pas : il faudra les reposer
sur son dépôt, comme pour FCP CleanX aujourd'hui, ou passer l'organisation en plan Team.
