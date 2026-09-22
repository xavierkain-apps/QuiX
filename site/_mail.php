<?php
// Readable notification emails, shared by the download gate and the feedback form.
//
// Why email and not Discord or a database: every feedback message comes from a person who may
// want an answer. With Reply-To set to their address, answering is one click in the inbox. The
// record itself already exists — each endpoint appends one JSON line to a register kept outside
// the web root — so a database would add nothing at this volume, and a chat webhook would add a
// third-party service and a secret to look after.
//
// The file is not meant to be reached over HTTP; .htaccess denies it. It only defines functions.

declare(strict_types=1);

/** A subject line with accents and symbols, encoded so every client shows it as written. */
function sujet_mime(string $texte): string
{
    return mb_encode_mimeheader($texte, 'UTF-8', 'B', "\r\n");
}

/**
 * Sends a multipart email: plain text for any client, HTML for the ones that render it.
 *
 * @param array<string,string> $lignes label => value, shown as a small table under the message
 */
function envoyer(string $a, string $sujet, string $titre, string $message, array $lignes, ?string $repondreA): bool
{
    $h = fn(string $s): string => htmlspecialchars($s, ENT_QUOTES, 'UTF-8');

    // Callers validate the address already; this guard makes a header injection impossible even
    // if one of them stops doing so.
    if ($repondreA !== null && (preg_match('/[\r\n]/', $repondreA) || !filter_var($repondreA, FILTER_VALIDATE_EMAIL))) {
        $repondreA = null;
    }

    // Plain text.
    $texte = $titre . "\n" . str_repeat('─', 40) . "\n\n";
    if ($message !== '') $texte .= $message . "\n\n";
    foreach ($lignes as $label => $valeur) {
        // str_pad counts bytes: « Caméra » would come out one column short. Pad on characters.
        if ($valeur !== '') $texte .= $label . str_repeat(' ', max(1, 12 - mb_strlen($label))) . $valeur . "\n";
    }
    if ($repondreA) $texte .= "\nRépondre à ce mail écrit directement à " . $repondreA . ".\n";

    // HTML, inline styles only: mail clients strip <style> blocks.
    $rangees = '';
    foreach ($lignes as $label => $valeur) {
        if ($valeur === '') continue;
        $rangees .= '<tr><td style="padding:5px 16px 5px 0;color:#8a8a93;white-space:nowrap;vertical-align:top">'
                  . $h($label) . '</td><td style="padding:5px 0;color:#1d1d22">' . $h($valeur) . '</td></tr>';
    }
    $html = '<!DOCTYPE html><html><body style="margin:0;background:#f4f4f6;padding:24px;'
          . 'font-family:-apple-system,BlinkMacSystemFont,Helvetica,Arial,sans-serif;font-size:15px;line-height:1.5">'
          . '<div style="max-width:560px;margin:0 auto;background:#fff;border-radius:12px;overflow:hidden;border:1px solid #e4e4ea">'
          . '<div style="background:#101017;color:#fff;padding:16px 22px;font-weight:600">'
          . '<span style="color:#00A3E4">●</span>&nbsp; ' . $h($titre) . '</div>'
          . '<div style="padding:22px">';
    if ($message !== '') {
        $html .= '<div style="white-space:pre-wrap;border-left:3px solid #00A3E4;padding:2px 0 2px 14px;margin:0 0 20px;color:#1d1d22">'
               . $h($message) . '</div>';
    }
    $html .= '<table style="border-collapse:collapse;font-size:13.5px">' . $rangees . '</table>';
    if ($repondreA) {
        $html .= '<p style="margin:20px 0 0;font-size:13px;color:#8a8a93">Répondre à ce mail écrit directement à '
               . '<a href="mailto:' . $h($repondreA) . '" style="color:#0090CC">' . $h($repondreA) . '</a>.</p>';
    }
    $html .= '</div></div></body></html>';

    $frontiere = 'quix-' . bin2hex(random_bytes(8));
    $entetes = "From: QuiX <no-reply@quix.xavier-kain.fr>\r\n"
             . ($repondreA ? "Reply-To: " . $repondreA . "\r\n" : '')
             . "MIME-Version: 1.0\r\n"
             . "Content-Type: multipart/alternative; boundary=\"$frontiere\"";
    $corps = "--$frontiere\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: base64\r\n\r\n"
           . chunk_split(base64_encode($texte))
           . "--$frontiere\r\nContent-Type: text/html; charset=utf-8\r\nContent-Transfer-Encoding: base64\r\n\r\n"
           . chunk_split(base64_encode($html))
           . "--$frontiere--\r\n";

    return @mail($a, sujet_mime($sujet), $corps, $entetes);
}
