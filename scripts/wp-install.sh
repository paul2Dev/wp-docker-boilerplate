#!/usr/bin/env bash
# Instaleaza WordPress cu un admin generat automat (adm_user_<slug site> + parola
# random de 20 caractere), activeaza tema din THEME_SLUG si pluginurile de baza.
# Apelata din Makefile via `make wp-install`.
set -euo pipefail

cd "$(dirname "$0")/.."

set -a
source .env
set +a

export MSYS_NO_PATHCONV=1

echo "Astept ca baza de date sa fie gata..."
TRIES=0
until docker compose exec -T db mysqladmin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD}" --silent >/dev/null 2>&1; do
  TRIES=$((TRIES + 1))
  if [ "$TRIES" -ge 30 ]; then
    echo "Baza de date nu a pornit in timp util (30s). Verifica 'make logs'." >&2
    exit 1
  fi
  sleep 1
done

if docker compose run --rm -T wpcli wp core is-installed >/dev/null 2>&1; then
  echo "WordPress e deja instalat pe acest stack."
  echo "Foloseste 'make wp CMD=\"...\"' pentru comenzi individuale (nu suprascriu instalarea existenta)."
  exit 0
fi

echo "Generez username si parola admin..."
CREDS=$(docker compose run --rm -T wpcli php -r '
$site = $argv[1];
$slug = iconv("UTF-8", "ASCII//TRANSLIT//IGNORE", $site);
$slug = strtolower($slug);
$slug = preg_replace("/[^a-z0-9]+/", "_", $slug);
$slug = trim($slug, "_");

$chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789-_.,!@#%^*+=";
$password = "";
for ($i = 0; $i < 20; $i++) {
    $password .= $chars[random_int(0, strlen($chars) - 1)];
}

echo $slug . PHP_EOL . $password;
' "$WEBSITE_NAME")

SITE_SLUG=$(echo "$CREDS" | sed -n 1p)
ADMIN_PASSWORD=$(echo "$CREDS" | sed -n 2p)
ADMIN_USER="adm_user_${SITE_SLUG}"

echo "Instalez WordPress..."
docker compose run --rm wpcli wp core install \
  --url="http://localhost:${WORDPRESS_PORT}" \
  --title="${WEBSITE_NAME}" \
  --admin_user="${ADMIN_USER}" \
  --admin_password="${ADMIN_PASSWORD}" \
  --admin_email="${ADMIN_EMAIL}" \
  --skip-email

echo "Activez tema ${THEME_SLUG}..."
docker compose run --rm wpcli wp theme activate "${THEME_SLUG}"

echo "Instalez pluginurile de baza..."
docker compose run --rm wpcli wp plugin install \
  contact-form-7 \
  contact-form-cfdb7 \
  advanced-custom-fields \
  advanced-nocaptcha-recaptcha \
  limit-login-attempts-reloaded \
  --activate

CREDS_FILE="wp-admin-credentials.txt"
{
  echo "URL:    http://localhost:${WORDPRESS_PORT}/wp-admin/"
  echo "User:   ${ADMIN_USER}"
  echo "Parola: ${ADMIN_PASSWORD}"
} > "$CREDS_FILE"

echo ""
echo "WordPress instalat cu succes."
echo "----------------------------------------"
cat "$CREDS_FILE"
echo "----------------------------------------"
echo "Credentialele au fost salvate si in ${CREDS_FILE} (fisier local, necomis in git)."
