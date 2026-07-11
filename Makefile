include .env

.PHONY: up down restart logs status wp wp-install pin-versions shell

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

# Shell into the wordpress container
shell:
	docker compose exec wordpress bash
