# Signature et notarisation

La CI signe et notarise l'app **dès que les cinq secrets ci-dessous existent sur le dépôt**. Sans
eux, elle produit quand même un bundle, en signature ad hoc : il se lance, mais Gatekeeper avertit
au premier démarrage sur une machine qui ne l'a pas compilé.

## Les cinq secrets

Ce sont ceux du **compte développeur**, pas de l'app : le même certificat Developer ID signe toutes
les apps macOS distribuées hors App Store. Ils existent déjà pour FCP CleanX.

| Secret | Contenu |
|---|---|
| `MACOS_CERT_P12` | Certificat **Developer ID Application** exporté en `.p12`, encodé en base64 |
| `MACOS_CERT_PASSWORD` | Mot de passe choisi à l'export du `.p12` |
| `APPLE_ID` | L'Apple ID, en clair |
| `APPLE_APP_PASSWORD` | **Mot de passe d'application**, pas le mot de passe Apple |
| `APPLE_TEAM_ID` | Identifiant d'équipe, dix caractères |

La marche à suivre pour les fabriquer est dans le
[SIGNING.md de FCP CleanX](https://github.com/xavierkain-apps/FCP-libcleaner/blob/main/SIGNING.md),
étapes 1 et 2. Rien à refaire si le `.p12` a été gardé.

## Les poser sur QuiX

Deux chemins, et le second est le bon si d'autres apps doivent suivre.

**Le plus rapide** — cinq secrets de dépôt, comme sur FCP CleanX :

```sh
gh secret set MACOS_CERT_P12      --repo XavierKain/QuiX < certificat.p12.base64
gh secret set MACOS_CERT_PASSWORD --repo XavierKain/QuiX
gh secret set APPLE_ID            --repo XavierKain/QuiX
gh secret set APPLE_APP_PASSWORD  --repo XavierKain/QuiX
gh secret set APPLE_TEAM_ID       --repo XavierKain/QuiX
```

**Le durable** — des secrets d'**organisation** sur `xavierkain-apps`, partagés entre toutes les
apps. C'est ce que le SIGNING.md de FCP CleanX décrivait, mais ça n'a jamais été fait : ses cinq
secrets sont en réalité attachés au dépôt, ce qui oblige à les recopier pour chaque nouvelle app.
Pour corriger ça, il faut les créer dans
[les réglages de l'organisation](https://github.com/organizations/xavierkain-apps/settings/secrets/actions)
en visibilité « Selected repositories », puis transférer QuiX dans l'organisation.

Les valeurs ne peuvent pas être recopiées d'un dépôt à l'autre en ligne de commande : GitHub les
chiffre en écriture seule et ne les rend jamais, même à un administrateur de l'organisation. Il faut
repartir du `.p12` d'origine.

## Vérifier

Pousser un commit. Dans le job « App — bundle macOS », les étapes **Importer le certificat** et
**Notariser** doivent apparaître au lieu d'être sautées, et l'étape de vérification doit répondre
`accepted` à `spctl --assess`. L'app se lance alors sans aucun avertissement sur n'importe quel Mac.
