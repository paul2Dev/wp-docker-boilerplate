include .env

.PHONY: up down reset restart logs status wp wp-install pin-versions db-export db-import shell

# Blocheaza versiunile imaginilor Docker (WordPress, MySQL, phpMyAdmin, WP-CLI)
# la digest-ul curent, in .env. Ruleaza o singura data, imediat dupa clonare,
# INAINTE de primul `make up`.
pin-versions:
	@bash scripts/pin-versions.sh

up:
	docker compose up -d db wordpress phpmyadmin
	@echo "WordPress: http://localhost:$(WORDPRESS_PORT)"
	@echo "phpMyAdmin: http://localhost:$(PHPMYADMIN_PORT)"

down:
	docker compose down

# Sterge containerele SI volumele (db_data, wp_data) - repornire completa,
# curata, ca la primul `make up` de dupa clonare. Ireversibil: pierzi baza de
# date si fisierele WordPress din volume. Fa `make db-export` inainte daca ai
# nevoie de datele curente.
reset:
	@echo "ATENTIE: sterge COMPLET containerele SI volumele acestui proiect"
	@echo "(baza de date + fisierele WordPress din wp_data). Ireversibil."
	@echo "Foloseste 'make db-export' inainte daca ai nevoie de datele curente."
	@read -p "Scrie 'da' ca sa confirmi: " confirm && [ "$$confirm" = "da" ] || (echo "Anulat."; exit 1)
	docker compose down -v

restart:
	docker compose restart

logs:
	docker compose logs -f

status:
	docker compose ps

# Run a WP-CLI command, e.g.: make wp CMD="post list"
wp:
	MSYS_NO_PATHCONV=1 docker compose run --rm wpcli wp $(CMD)

# Instaleaza WordPress cu admin generat automat, activeaza tema si pluginurile de baza.
# Ruleaza o singura data, dupa primul `make up`.
wp-install:
	@bash scripts/wp-install.sh

# Exporta baza de date in backups/db-<timestamp>.sql. Folosim clientul mysql
# din containerul db (nu wp-cli) - `wp db import` are un bug cunoscut unde
# ignora flag-urile SSL in verificarea lui interna de SQL modes
# (github.com/wp-cli/db-command/issues/218), asa ca folosim aceeasi unealta
# pentru simetrie si consistenta pentru export/import. --ssl-mode=DISABLED e
# safe: conexiunea ramane in reteaua Docker privata a proiectului.
db-export:
	@mkdir -p backups
	docker compose exec -T db mysqldump -u $(MYSQL_USER) -p$(MYSQL_PASSWORD) --ssl-mode=DISABLED --no-tablespaces $(MYSQL_DATABASE) > backups/db-$$(date +%Y%m%d-%H%M%S).sql
	@echo "Salvat in backups/"

# Importa un dump: make db-import FILE=backups/db-20260711-120000.sql
db-import:
	docker compose exec -T db mysql -u $(MYSQL_USER) -p$(MYSQL_PASSWORD) --ssl-mode=DISABLED $(MYSQL_DATABASE) < $(FILE)

# Shell into the wordpress container
shell:
	docker compose exec wordpress bash
