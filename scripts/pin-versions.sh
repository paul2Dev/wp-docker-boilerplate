#!/usr/bin/env bash
# Rezolva tag-urile "rolling" din .env (WORDPRESS_IMAGE, MYSQL_IMAGE,
# PHPMYADMIN_IMAGE, WPCLI_IMAGE) la digest-ul exact al imaginii curente si le
# suprascrie in .env. Un digest e imuabil - spre deosebire de un tag, care
# poate fi re-publicat cu continut nou pe Docker Hub - deci odata rulat,
# versiunile raman blocate pentru acest proiect indiferent de ce se
# actualizeaza ulterior pe Docker Hub sau ce trag alte proiecte pe aceeasi
# masina.
#
# Ruleaza o singura data, imediat dupa clonare, INAINTE de primul `make up`.
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE=".env"

pin_image() {
  local var_name="$1"
  local current
  current=$(grep "^${var_name}=" "$ENV_FILE" | cut -d= -f2-)

  if [[ "$current" == *"@sha256:"* ]]; then
    echo "${var_name} e deja pinned (${current}) - sar peste."
    return
  fi

  echo "Rezolv ${var_name} (${current})..."
  docker pull "$current" >/dev/null
  local digest
  digest=$(docker inspect --format '{{index .RepoDigests 0}}' "$current")

  sed -i.bak "s|^${var_name}=.*|${var_name}=${digest}|" "$ENV_FILE"
  rm -f "${ENV_FILE}.bak"

  echo "  -> ${var_name}=${digest}"
}

pin_image WORDPRESS_IMAGE
pin_image MYSQL_IMAGE
pin_image PHPMYADMIN_IMAGE
pin_image WPCLI_IMAGE

echo ""
echo "Versiunile sunt blocate in .env pentru acest proiect si nu se vor mai"
echo "schimba la 'make up', indiferent cat timp trece sau ce imagini noi apar"
echo "pe Docker Hub. Pentru a le actualiza manual, sterge liniile respective"
echo "din .env (revin la tag-urile rolling din .env.example) si ruleaza din"
echo "nou 'make pin-versions'."
