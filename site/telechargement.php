<?php
// Le lien de téléchargement, en échange d'un prénom et d'une adresse.
//
// Le fichier lui-même n'est pas servi d'ici : il vit sur les releases GitHub, qui s'occupent de
// la bande passante et versionnent pour nous. Cette page ne fait que trois choses — vérifier ce
// qui est saisi, le consigner, et donner le lien.
//
// **Aucune donnée ne part ailleurs.** Pas de traceur, pas de service tiers. Les inscriptions
// s'écrivent dans un fichier hors de la racine web, que rien ne sert publiquement.

declare(strict_types=1);

const TELECHARGEMENT = 'https://github.com/xavierkain-apps/QuiX/releases/latest/download/QuiX.zip';
const DESTINATAIRE   = 'xavierkain.consulting@gmail.com';
const REGISTRE       = __DIR__ . '/../quix-inscriptions.jsonl';

$langue = ($_POST['langue'] ?? 'en') === 'fr' ? 'fr' : 'en';

$mots = [
    'en' => [
        'title'    => 'Your download — QuiX',
        'ok'       => 'Thank you. Your download is starting.',
        'manual'   => 'If nothing happens, use this link:',
        'mailed'   => 'The link is also on its way to your inbox.',
        'back'     => 'Back to the site',
        'invalid'  => 'That email address does not look right. Go back and try again.',
        'missing'  => 'A first name and an email address are needed.',
        'next'     => 'Once downloaded: unzip it, drag QuiX into Applications, and plug your GoPro in — switched on.',
    ],
    'fr' => [
        'title'    => 'Votre téléchargement — QuiX',
        'ok'       => 'Merci. Le téléchargement démarre.',
        'manual'   => 'Si rien ne se passe, voici le lien :',
        'mailed'   => 'Le lien part aussi dans votre boîte mail.',
        'back'     => 'Retour au site',
        'invalid'  => "Cette adresse e-mail ne semble pas valide. Revenez en arrière et réessayez.",
        'missing'  => 'Il faut un prénom et une adresse e-mail.',
        'next'     => "Une fois téléchargé : décompressez, glissez QuiX dans Applications, et branchez votre GoPro — allumée.",
    ],
][$langue];

function page(string $titre, string $corps, string $langue): never
{
    http_response_code(200);
    header('Content-Type: text/html; charset=utf-8');
    echo '<!DOCTYPE html><html lang="' . $langue . '"><head><meta charset="utf-8">',
         '<meta name="viewport" content="width=device-width, initial-scale=1">',
         '<meta name="robots" content="noindex">',
         '<title>', htmlspecialchars($titre, ENT_QUOTES), '</title>',
         '<link rel="icon" href="assets/favicon.png">',
         '<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;600;800&family=JetBrains+Mono&display=swap" rel="stylesheet">',
         '<link rel="stylesheet" href="assets/style.css"></head><body>',
         '<main class="wrap" style="max-width:640px;padding-top:96px;text-align:center">',
         '<img src="assets/icon-256.png" alt="QuiX" width="84" height="84" style="margin:0 auto 28px">',
         $corps,
         '</main></body></html>';
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Location: ./');
    exit;
}

// Un champ que personne ne voit et que les robots remplissent.
if (($_POST['site'] ?? '') !== '') {
    header('Location: ./');
    exit;
}

$prenom = trim((string) ($_POST['prenom'] ?? ''));
$email  = trim((string) ($_POST['email'] ?? ''));

if ($prenom === '' || $email === '') {
    page($mots['title'], '<h2>' . $mots['missing'] . '</h2><p><a class="btn" href="./">' . $mots['back'] . '</a></p>', $langue);
}
if (!filter_var($email, FILTER_VALIDATE_EMAIL) || mb_strlen($email) > 160) {
    page($mots['title'], '<h2>' . $mots['invalid'] . '</h2><p><a class="btn" href="./">' . $mots['back'] . '</a></p>', $langue);
}

$inscription = [
    'date'      => gmdate('c'),
    'prenom'    => mb_substr($prenom, 0, 80),
    'email'     => $email,
    'nouvelles' => ($_POST['nouvelles'] ?? '') === '1',
    'langue'    => $langue,
];
@file_put_contents(REGISTRE, json_encode($inscription, JSON_UNESCAPED_UNICODE) . "\n", FILE_APPEND | LOCK_EX);

// L'e-mail n'est pas la voie principale : le lien s'affiche de toute façon ci-dessous. S'il
// n'arrive pas, personne n'est bloqué.
$sujet = $langue === 'fr' ? 'Votre telechargement QuiX' : 'Your QuiX download';
$corps = $langue === 'fr'
    ? "Bonjour " . $inscription['prenom'] . ",\n\nVoici QuiX :\n" . TELECHARGEMENT
      . "\n\nDecompressez, glissez QuiX dans Applications, et branchez votre GoPro allumee.\n\nXavier"
    : "Hi " . $inscription['prenom'] . ",\n\nHere is QuiX:\n" . TELECHARGEMENT
      . "\n\nUnzip it, drag QuiX into Applications, and plug your GoPro in, switched on.\n\nXavier";
@mail($email, $sujet, $corps, "From: QuiX <no-reply@quix.xavier-kain.fr>\r\nContent-Type: text/plain; charset=utf-8");
@mail(DESTINATAIRE, 'QuiX — nouvelle inscription', json_encode($inscription, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT),
      "From: QuiX <no-reply@quix.xavier-kain.fr>\r\nContent-Type: text/plain; charset=utf-8");

$lien = htmlspecialchars(TELECHARGEMENT, ENT_QUOTES);
page($mots['title'],
    '<h2 style="text-transform:none">' . $mots['ok'] . '</h2>'
  . '<p style="color:var(--muted)">' . $mots['next'] . '</p>'
  . '<p style="margin-top:28px"><a class="btn" href="' . $lien . '">QuiX.zip</a></p>'
  . '<p class="note" style="margin-top:18px">' . $mots['manual'] . '<br><span class="mono">' . $lien . '</span></p>'
  . '<p class="note">' . $mots['mailed'] . '</p>'
  . '<p style="margin-top:36px"><a class="mono note" href="./">' . $mots['back'] . '</a></p>'
  . '<script>setTimeout(function(){location.href=' . json_encode(TELECHARGEMENT) . ';},1200);</script>',
    $langue);
