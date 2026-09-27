<?php
// Readable notification emails, shared by the download gate and the feedback form.
//
// Why email and not Discord or a database: every feedback message comes from a person who may
// want an answer. With Reply-To set to their address, answering is one click in the inbox. The
// record itself already exists — each endpoint appends one JSON line to a register kept outside
// the web root — so a database would add nothing at this volume, and a chat webhook would add a
// third-party service and a secret to look after.
//
// How mail leaves the server. When mail.ini exists one level above the web root, messages are sent
// through Gmail's SMTP, authenticated as Xavier's own address: they are genuine Gmail messages,
// pass SPF, DKIM and DMARC for gmail.com, and appear in his Sent folder. Putting a @gmail.com From
// on mail sent by the host instead would be spoofing, which is exactly what spam filters look for.
// Without mail.ini — or if Gmail refuses — PHP's mail() is used, as before, so nothing is lost.
//
// mail.ini, outside the web root and never in the repository:
//   smtp_user     = "xavierkain.consulting@gmail.com"
//   smtp_password = "<Google app password, 16 letters>"
//   from_name     = "Xavier — QuiX"
//
// The file is not meant to be reached over HTTP; .htaccess denies it. It only defines functions.

declare(strict_types=1);

const REGLAGES_MAIL = __DIR__ . '/../mail.ini';

/** Gmail SMTP settings, or null when mail.ini is absent or incomplete. */
function reglages_smtp(): ?array
{
    if (!is_readable(REGLAGES_MAIL)) return null;
    $r = parse_ini_file(REGLAGES_MAIL) ?: [];
    if (empty($r['smtp_user']) || empty($r['smtp_password'])) return null;
    return [
        'host'     => $r['smtp_host'] ?? 'smtp.gmail.com',
        'port'     => (int) ($r['smtp_port'] ?? 587),
        'user'     => $r['smtp_user'],
        'password' => $r['smtp_password'],
        'name'     => $r['from_name'] ?? 'QuiX',
    ];
}

/**
 * Sends one message: through Gmail when configured, through mail() otherwise.
 * `$html` is optional; without it the message is plain text.
 */
function transport(string $a, string $sujet, string $texte, ?string $html, ?string $repondreA): bool
{
    $smtp = reglages_smtp();
    if ($smtp) {
        require_once __DIR__ . '/lib/phpmailer/Exception.php';
        require_once __DIR__ . '/lib/phpmailer/PHPMailer.php';
        require_once __DIR__ . '/lib/phpmailer/SMTP.php';
        $m = new PHPMailer\PHPMailer\PHPMailer(true);
        try {
            $m->isSMTP();
            $m->Host = $smtp['host'];
            $m->Port = $smtp['port'];
            $m->SMTPAuth = true;
            $m->Username = $smtp['user'];
            $m->Password = $smtp['password'];
            $m->SMTPSecure = $smtp['port'] === 465
                ? PHPMailer\PHPMailer\PHPMailer::ENCRYPTION_SMTPS
                : PHPMailer\PHPMailer\PHPMailer::ENCRYPTION_STARTTLS;
            $m->Timeout = 10;
            $m->CharSet = 'UTF-8';
            $m->setFrom($smtp['user'], $smtp['name']);
            $m->addAddress($a);
            if ($repondreA) $m->addReplyTo($repondreA);
            $m->Subject = $sujet;
            if ($html !== null) {
                $m->isHTML(true);
                $m->Body = $html;
                $m->AltBody = $texte;
            } else {
                $m->Body = $texte;
            }
            return $m->send();
        } catch (Throwable $e) {
            // Gmail refused (wrong app password, quota…). Log it, and still try the old path:
            // a message that may land in spam beats one that never leaves.
            error_log('QuiX mail via Gmail failed: ' . $m->ErrorInfo);
        }
    }

    $frontiere = 'quix-' . bin2hex(random_bytes(8));
    $entetes = "From: QuiX <no-reply@quix.xavier-kain.fr>\r\n"
             . ($repondreA ? "Reply-To: " . $repondreA . "\r\n" : '')
             . "MIME-Version: 1.0\r\n";
    if ($html === null) {
        $entetes .= "Content-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: base64";
        $corps = chunk_split(base64_encode($texte));
    } else {
        $entetes .= "Content-Type: multipart/alternative; boundary=\"$frontiere\"";
        $corps = "--$frontiere\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: base64\r\n\r\n"
               . chunk_split(base64_encode($texte))
               . "--$frontiere\r\nContent-Type: text/html; charset=utf-8\r\nContent-Transfer-Encoding: base64\r\n\r\n"
               . chunk_split(base64_encode($html))
               . "--$frontiere--\r\n";
    }
    return @mail($a, sujet_mime($sujet), $corps, $entetes);
}

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

    return transport($a, $sujet, $texte, $html, $repondreA);
}
