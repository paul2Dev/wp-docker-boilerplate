include .env

.PHONY: help up down reset restart logs status wp wp-install pin-versions db-export db-import shell

.DEFAULT_GOAL := help

# `make` fara argument afiseaza asta, ca sa nu pornesti din greseala vreo
# comanda (ex. pin-versions, care trage imagini de pe Docker Hub).
help:
	@echo "Comenzi disponibile:"
	@echo "  make pin-versions        - blocheaza versiunile imaginilor Docker (o singura data, inainte de primul up)"
	@echo "  make up                  - porneste db, wordpress, phpmyadmin"
	@echo "  make wp-install          - instaleaza WordPress cu admin generat automat (o singura data, dupa primul up)"
	@echo "  make down                - opreste containerele"
	@echo "  make reset               - opreste containerele SI sterge volumele (cere confirmare)"
	@echo "  make restart             - reporneste containerele"
	@echo "  make logs                - urmareste log-urile"
	@echo "  make status              - starea containerelor"
	@echo "  make wp CMD=\"...\"        - orice comanda WP-CLI, ex. make wp CMD=\"post list\""
	@echo "  make db-export           - salveaza un dump al bazei de date in backups/"
	@echo "  make db-import FILE=...  - restaureaza un dump (cere confirmare)"
	@echo "  make shell               - shell in containerul WordPress"

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
	@echo "ATENTIE: suprascrie COMPLET baza de date curenta cu continutul din $(FILE)."
	@echo "Ireversibil. Foloseste 'make db-export' inainte daca vrei sa pastrezi ce ai acum."
	@read -p "Scrie 'da' ca sa confirmi: " confirm && [ "$$confirm" = "da" ] || (echo "Anulat."; exit 1)
	docker compose exec -T db mysql -u $(MYSQL_USER) -p$(MYSQL_PASSWORD) --ssl-mode=DISABLED $(MYSQL_DATABASE) < $(FILE)

# Shell into the wordpress container
shell:
	docker compose exec wordpress bash
