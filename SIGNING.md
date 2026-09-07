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

Pour chacun, choisir **Repository access : All repositories**.

C'est le réglage qui fait la différence. « Selected repositories » demanderait d'ajouter chaque
nouvelle app à la main dans les cinq secrets ; « All repositories » veut dire qu'un dépôt créé
demain dans l'organisation les a déjà. C'est une organisation privée qui ne contient que les apps
de Xavier : il n'y a personne à qui les cacher.

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

## Vérifier

Pousser un commit sur QuiX. Dans le job « App — bundle macOS », les étapes **Importer le
certificat Developer ID** et **Notariser** doivent **apparaître au lieu d'être sautées**, et
l'étape de vérification doit répondre `accepted` à `spctl --assess`. C'est un signal sans
ambiguïté : soit les deux étapes tournent, soit elles sont grisées.

### Si elles restent grisées

L'organisation est en plan **Free**. GitHub y restreint certaines fonctions d'Actions sur les
dépôts privés, et je n'ai pas pu vérifier depuis ce serveur si les secrets d'organisation en font
partie — le jeton n'a pas le scope `admin:org`. Le test ci-dessus tranche en une minute.

Si les secrets d'organisation ne passent pas sur un dépôt privé Free, il reste deux issues : poser
les cinq secrets sur chaque dépôt (deux minutes par app, la situation actuelle de FCP CleanX), ou
passer l'organisation en plan Team. Rien d'autre à changer dans le code : le workflow lit les
secrets au même endroit dans les deux cas.

## Ce que les secrets ne font pas tout seuls

Une nouvelle app dans l'organisation est signée automatiquement **à condition d'avoir le workflow**.
Les secrets ne signent rien ; c'est `.github/workflows/ci.yml` qui les utilise. Pour une prochaine
app, copier le job « App — bundle macOS » de QuiX et remplacer le nom du projet, du schéma et du
bundle suffit — c'est le seul fichier à reprendre.

## Le coût en minutes

Les exécuteurs macOS comptent **dix fois** leur temps réel dans le quota Actions. Le plan Free de
l'organisation donne 2 000 minutes par mois, soit environ **200 minutes de macOS réelles** — le job
de QuiX en consomme un peu plus d'une par push. Largement suffisant, mais c'est partagé avec FCP
CleanX et les suivantes : à surveiller le jour où il y aura quatre apps qui compilent à chaque
commit.
