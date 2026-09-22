<?php
// Le formulaire de retour, vers lequel l'app envoie depuis ses Réglages et son menu Aide.
//
// L'app passe le contexte technique en paramètres d'URL — version, macOS, modèle de Mac, modèle
// de caméra. **Rien de personnel n'y transite** : voir docs/FEEDBACK.md. Ce qui est saisi ici
// est consigné dans un fichier hors racine web et envoyé par e-mail.

declare(strict_types=1);

const DESTINATAIRE = 'xavierkain.consulting@gmail.com';
const REGISTRE     = __DIR__ . '/../../quix-retours.jsonl';

function propre(string $clef, int $max = 120): string
{
    $valeur = (string) ($_GET[$clef] ?? $_POST[$clef] ?? '');
    // Ces champs ne portent que des versions et des modèles : on refuse tout le reste plutôt
    // que d'échapper du HTML qui n'a rien à faire là.
    $valeur = preg_replace('/[^A-Za-z0-9 ._()+,:-]/', '', $valeur) ?? '';
    return mb_substr(trim($valeur), 0, $max);
}

$langue = str_starts_with(strtolower($_SERVER['HTTP_ACCEPT_LANGUAGE'] ?? 'en'), 'fr') ? 'fr' : 'en';
if (isset($_REQUEST['lang']) && in_array($_REQUEST['lang'], ['fr', 'en'], true)) {
    $langue = $_REQUEST['lang'];
}

$type = ($_GET['type'] ?? $_POST['type'] ?? 'bug') === 'idea' ? 'idea' : 'bug';

$mots = [
    'en' => [
        'title'    => 'Send feedback — QuiX',
        'bug'      => 'Report a bug', 'idea' => 'Suggest a feature',
        'lead'     => 'Tell me what happened, or what you would like. The technical details below came from the app; they are versions and models, nothing personal.',
        'what'     => 'What happened', 'want' => 'What you would like',
        'hint'     => 'What you did, what you expected, what you got instead.',
        'hintIdea' => 'What you are trying to do, and what would make it easier.',
        'email'    => 'Email (optional)',
        'emailNote'=> 'Only so I can reply. Leave it blank if you prefer.',
        'context'  => 'Sent with your message',
        'send'     => 'Send',
        'thanks'   => 'Thank you — it arrived.',
        'thanksBody' => 'If you left an address, I will come back to you.',
        'empty'    => 'The message is empty.',
        'back'     => 'Back to the site',
    ],
    'fr' => [
        'title'    => 'Envoyer un retour — QuiX',
        'bug'      => 'Signaler un bug', 'idea' => 'Proposer une idée',
        'lead'     => "Dites-moi ce qui s'est passé, ou ce que vous aimeriez. Les détails techniques ci-dessous viennent de l'app ; ce sont des versions et des modèles, rien de personnel.",
        'what'     => "Ce qui s'est passé", 'want' => 'Ce que vous aimeriez',
        'hint'     => "Ce que vous avez fait, ce que vous attendiez, ce que vous avez eu à la place.",
        'hintIdea' => "Ce que vous cherchez à faire, et ce qui vous simplifierait la vie.",
        'email'    => 'E-mail (facultatif)',
        'emailNote'=> 'Uniquement pour pouvoir vous répondre. Laissez vide si vous préférez.',
        'context'  => 'Envoyé avec votre message',
        'send'     => 'Envoyer',
        'thanks'   => "Merci — c'est arrivé.",
        'thanksBody' => 'Si vous avez laissé une adresse, je vous réponds.',
        'empty'    => 'Le message est vide.',
        'back'     => 'Retour au site',
    ],
][$langue];

$contexte = [
    'version' => propre('version', 40),
    'os'      => propre('os', 20),
    'mac'     => propre('mac', 40),
    'camera'  => propre('camera', 60),
    'lang'    => propre('lang', 10),
];

function page(string $titre, string $corps, string $langue): never
{
    header('Content-Type: text/html; charset=utf-8');
    echo '<!DOCTYPE html><html lang="', $langue, '"><head><meta charset="utf-8">',
         '<meta name="viewport" content="width=device-width, initial-scale=1">',
         '<meta name="robots" content="noindex">',
         '<title>', htmlspecialchars($titre, ENT_QUOTES), '</title>',
         '<link rel="icon" href="../assets/favicon.png">',
         '<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@400;600;800&family=JetBrains+Mono&display=swap" rel="stylesheet">',
         '<link rel="stylesheet" href="../assets/style.css"></head><body>',
         '<main class="wrap" style="max-width:640px;padding-top:80px;padding-bottom:80px">',
         '<a href="../"><img src="../assets/icon-256.png" alt="QuiX" width="64" height="64" style="margin:0 auto 26px"></a>',
         $corps,
         '</main></body></html>';
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (($_POST['site'] ?? '') !== '') { header('Location: ../'); exit; }

    $message = trim((string) ($_POST['message'] ?? ''));
    if ($message === '') {
        page($mots['title'], '<h2 style="text-transform:none">' . $mots['empty'] . '</h2>'
            . '<p><a class="btn" href="javascript:history.back()">' . $mots['back'] . '</a></p>', $langue);
    }

    $email = trim((string) ($_POST['email'] ?? ''));
    if ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) $email = '';

    $retour = [
        'date'     => gmdate('c'),
        'type'     => $type,
        'message'  => mb_substr($message, 0, 8000),
        'email'    => $email,
        'langue'   => $langue,
        'contexte' => $contexte,
    ];
    @file_put_contents(REGISTRE, json_encode($retour, JSON_UNESCAPED_UNICODE) . "\n", FILE_APPEND | LOCK_EX);
    @mail(DESTINATAIRE, 'QuiX — ' . $type . ' — ' . ($contexte['camera'] ?: 'camera inconnue'),
          json_encode($retour, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT),
          "From: QuiX <no-reply@quix.xavier-kain.fr>\r\nContent-Type: text/plain; charset=utf-8");

    page($mots['title'],
        '<h2 style="text-transform:none">' . $mots['thanks'] . '</h2>'
      . '<p style="color:var(--muted)">' . $mots['thanksBody'] . '</p>'
      . '<p style="margin-top:32px"><a class="btn" href="../">' . $mots['back'] . '</a></p>', $langue);
}

$titre  = $type === 'idea' ? $mots['idea'] : $mots['bug'];
$label  = $type === 'idea' ? $mots['want'] : $mots['what'];
$indice = $type === 'idea' ? $mots['hintIdea'] : $mots['hint'];

$lignes = array_values(array_filter([
    $contexte['version'] ? 'QuiX ' . $contexte['version'] : '',
    $contexte['os'] ? 'macOS ' . $contexte['os'] : '',
    $contexte['mac'],
    $contexte['camera'],
]));

$champsCaches = '';
foreach ($contexte as $clef => $valeur) {
    $champsCaches .= '<input type="hidden" name="' . $clef . '" value="' . htmlspecialchars($valeur, ENT_QUOTES) . '">';
}

page($mots['title'],
    '<h2 style="text-transform:none;font-size:32px">' . $titre . '</h2>'
  . '<p style="color:var(--muted);line-height:1.55">' . $mots['lead'] . '</p>'
  . '<form class="gate" method="post" style="max-width:none;margin-top:28px">'
  . '<input type="hidden" name="type" value="' . $type . '">'
  . '<input type="hidden" name="lang" value="' . $langue . '">'
  . $champsCaches
  . '<div style="position:absolute;left:-9999px" aria-hidden="true"><input type="text" name="site" tabindex="-1" autocomplete="off"></div>'
  . '<div><label for="message">' . $label . '</label>'
  . '<textarea id="message" name="message" rows="8" required maxlength="8000" placeholder="' . htmlspecialchars($indice, ENT_QUOTES) . '" '
  . 'style="width:100%;font:inherit;font-size:14px;color:var(--text);background:rgba(255,255,255,.05);border:.5px solid var(--line);border-radius:10px;padding:12px 14px;resize:vertical"></textarea></div>'
  . '<div><label for="email">' . $mots['email'] . '</label>'
  . '<input id="email" name="email" type="email" maxlength="160" autocomplete="email">'
  . '<p class="note" style="margin:6px 0 0">' . $mots['emailNote'] . '</p></div>'
  . ($lignes
      ? '<div><div class="kicker mono" style="margin-bottom:8px">' . $mots['context'] . '</div>'
        . '<p class="mono note" style="margin:0">' . htmlspecialchars(implode(' · ', $lignes), ENT_QUOTES) . '</p></div>'
      : '')
  . '<button class="btn" type="submit">' . $mots['send'] . '</button>'
  . '</form>', $langue);
