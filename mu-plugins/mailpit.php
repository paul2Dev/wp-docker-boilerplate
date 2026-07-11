<?php
/**
 * Ruteaza wp_mail() prin Mailpit (SMTP local, fara autentificare) in loc sa
 * incerce sendmail-ul inexistent din container. UI: http://localhost:${MAILPIT_PORT}.
 */

add_action( 'phpmailer_init', function ( $phpmailer ) {
	$phpmailer->isSMTP();
	$phpmailer->Host       = 'mailpit';
	$phpmailer->Port       = 1025;
	$phpmailer->SMTPAuth   = false;
	$phpmailer->SMTPAutoTLS = false;
} );

/**
 * Adresa implicita WordPress ("wordpress@localhost", derivata din hostname-ul
 * serverului) e respinsa de validatorul strict al PHPMailer (necesita un
 * domeniu cu punct) - inainte sa apuce sa incerce macar conexiunea SMTP.
 * Domeniul nu trebuie sa fie real, Mailpit nu livreaza nicaieri.
 */
add_filter( 'wp_mail_from', fn() => 'wordpress@mailpit.local' );
