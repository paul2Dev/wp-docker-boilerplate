<?php
/**
 * Theme setup, asset enqueue, nav menus.
 *
 * "px_" e un prefix placeholder - redenumeste-l (functii + hook-uri) cu
 * initialele proiectului curent inainte sa adaugi cod specific site-ului.
 */

function px_enqueue_assets() {
	$dir = get_template_directory();
	$uri = get_template_directory_uri();

	// Adauga aici stylesheet-urile/scripturile din export, in aceeasi ordine
	// de incarcare ca originalul (vezi assets/css, assets/js).
	wp_enqueue_style( 'px-theme-style', get_stylesheet_uri(), array(), filemtime( "{$dir}/style.css" ) );
}
add_action( 'wp_enqueue_scripts', 'px_enqueue_assets' );

function px_theme_setup() {
	add_theme_support( 'title-tag' );
	add_theme_support( 'post-thumbnails' );

	register_nav_menus( array(
		'primary' => 'Meniu principal',
		'footer'  => 'Meniu footer',
	) );
}
add_action( 'after_setup_theme', 'px_theme_setup' );

/**
 * Hardening minim de login (cerut explicit de user, 26-07-08):
 * 1. REST API expune implicit /wp/v2/users, care dezvaluie username-ul
 *    contului de admin oricui neautentificat - jumatate din ce-i trebuie
 *    unui atac de brute-force pe login. Blocam ruta doar pentru vizitatori
 *    neautentificati, ramane functionala in admin (Gutenberg etc. se bazeaza
 *    pe ea), desi tema nu foloseste block editor.
 * 2. XML-RPC (xmlrpc.php) e o tinta clasica de amplificare brute-force
 *    (system.multicall) - dezactivat, nefolosit de tema/plugin-urile actuale.
 */
add_filter( 'rest_endpoints', function ( $endpoints ) {
	if ( ! is_user_logged_in() ) {
		unset( $endpoints['/wp/v2/users'] );
		unset( $endpoints['/wp/v2/users/(?P<id>[\d]+)'] );
	}
	return $endpoints;
} );

/**
 * Filtrul "xmlrpc_enabled" NU blocheaza de fapt tot xmlrpc.php (dezactiveaza
 * doar pingback-urile) - metode ca system.listMethods raman accesibile prin
 * el. Blocam direct cererea, cat mai devreme posibil.
 */
add_action( 'init', function () {
	if ( defined( 'XMLRPC_REQUEST' ) && XMLRPC_REQUEST ) {
		status_header( 403 );
		exit( 'XML-RPC services are disabled on this site.' );
	}
} );

/**
 * 3. ?author=1 (author archive query) e o alta cale de a scoate username-ul
 *    adminului: WP redirecteaza automat catre /author/username/ prin
 *    redirect_canonical(), scurgand slug-ul prin header-ul Location. Filtrul
 *    rest_endpoints de mai sus nu acopera asta - blocam explicit cererea
 *    inainte de randare.
 *    redirect_canonical() e agatat tot pe template_redirect, prioritate 10,
 *    dar de catre core, inaintea temei - trebuie sa rulam mai devreme
 *    (prioritate 0) ca sa apucam cererea inainte de redirect.
 */
add_action( 'template_redirect', function () {
	if ( is_author() && ! is_user_logged_in() ) {
		status_header( 403 );
		exit;
	}
}, 0 );

/**
 * 4. wp-sitemap-users-1.xml (sitemap-ul de core, /wp-sitemap.xml) listeaza
 *    automat autorii de continut publicat - inca o scurgere de username-uri,
 *    neacoperita de filtrele de mai sus. Scoatem provider-ul "users".
 */
add_filter( 'wp_sitemaps_add_provider', function ( $provider, $name ) {
	if ( 'users' === $name ) {
		return false;
	}
	return $provider;
}, 10, 2 );
