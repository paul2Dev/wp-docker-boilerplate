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
# Imaginea oficiala mysql porneste, la prima initializare, un server TEMPORAR
# (creeaza db/user), il opreste, apoi porneste serverul real - un singur ping
# reusit poate cadea exact in fereastra serverului temporar, chiar inainte de
# restart. Cerem doua ping-uri reusite, la cateva secunde distanta, ca sa nu
# prindem acea fereastra. (wp db check ar fi un test mai fidel, dar clientul
# mariadb-check din imaginea wordpress:cli are o problema de compatibilitate
# TLS cu certificatul self-signed al MySQL 8 si esueaza mereu.)
wait_for_db_ping() {
  local tries=0
  until docker compose exec -T db mysqladmin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD}" --silent >/dev/null 2>&1; do
    tries=$((tries + 1))
    if [ "$tries" -ge 30 ]; then
      echo "Baza de date nu a pornit in timp util (30s). Verifica 'make logs'." >&2
      exit 1
    fi
    sleep 1
  done
}

wait_for_db_ping
sleep 8
wait_for_db_ping

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
INSTALL_TRIES=0
until docker compose run --rm wpcli wp core install \
  --url="http://localhost:${WORDPRESS_PORT}" \
  --title="${WEBSITE_NAME}" \
  --admin_user="${ADMIN_USER}" \
  --admin_password="${ADMIN_PASSWORD}" \
  --admin_email="${ADMIN_EMAIL}" \
  --skip-email; do
  INSTALL_TRIES=$((INSTALL_TRIES + 1))
  if [ "$INSTALL_TRIES" -ge 5 ]; then
    echo "core install a esuat de $INSTALL_TRIES ori. Verifica 'make logs'." >&2
    exit 1
  fi
  echo "core install a esuat (posibil DB inca in restart) - reincerc in 3s..."
  sleep 3
done

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
