# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A **boilerplate**, not a live site. It's meant to be cloned once per real
project (`git clone <this-repo> ../nume-proiect-nou/`), then customized
(`THEME_SLUG`, `WEBSITE_NAME`, theme code) inside the clone. Changes made
here should stay generic — project-specific content belongs in the clone,
not in this template.

`README.md` is the user-facing setup guide (Romanian) and is the source of
truth for the intended workflow; keep it in sync with any change here.

## Commands

```
make                        # prints command list (default target, no-arg safe)
make pin-versions           # resolve rolling image tags to sha256 digests in .env (run once, before first `make up`)
make up                     # start db, wordpress, phpmyadmin, mailpit
make wp-install             # generate admin user/password, install WP, activate theme, install base plugins (idempotent)
make wp CMD="post list"     # arbitrary wp-cli command
make db-export              # dump DB to backups/db-<timestamp>.sql
make db-import FILE=...     # restore a dump (asks for typed "da" confirmation)
make reset                  # docker compose down -v (asks for typed "da" confirmation)
make shell                  # bash inside the wordpress container
```

There is no test suite, linter, or build step — this is Docker Compose + a
few shell scripts + a WordPress classic theme skeleton, not an application
with its own toolchain.

To iterate on the Makefile or scripts, verify against a live stack rather
than reasoning about it statically — see "Gotchas" below for why: several of
the current workarounds were only discoverable by actually running the
commands (MySQL 8 auth/TLS quirks, a real wp-cli bug, PHPMailer validation).
`make reset` before and after a test run keeps state clean; uploaded media
in `wp-content/uploads/` and files in `backups/` survive `make reset` (only
Docker volumes are wiped), so `rm -rf wp-content backups wp-admin-credentials.txt`
if you need a truly blank slate.

## Architecture

### .env is read twice, by two different parsers

`docker-compose.yml` uses `${VAR}` substitution (Docker's own env parsing,
tolerant of unquoted values with spaces). The `Makefile` also does
`include .env` so Make variables (`$(WORDPRESS_PORT)` etc.) are available in
recipes like `up`'s echo lines. Because of the `include`, `.env` must also be
valid Makefile syntax — and `scripts/wp-install.sh` further `source`s it as
a bash script. The practical constraint: **values with spaces must be
quoted** (`WEBSITE_NAME="Ferma Populești"`), otherwise bash's `source` splits
on the space and silently breaks (this was a real bug hit during
development — bash treats `WEBSITE_NAME=Placeholder Website` as an
assignment followed by a stray `Website` command).

`.env` is gitignored (contains local passwords); only `.env.example` is
committed. The Makefile has a rule `.env: cp .env.example .env` — GNU Make
auto-builds a missing included file and restarts, so a fresh clone with no
`.env` at all still works on the very first `make` invocation instead of
crashing with "No rule to make target '.env'".

### Version pinning is digest-based, not tag-based

`.env.example` ships rolling tags (`wordpress:php8.3-apache`, `mysql:8.0`,
etc.). `make pin-versions` (`scripts/pin-versions.sh`) resolves each to its
current `image@sha256:...` digest and rewrites `.env` in place — a digest is
immutable, unlike a tag which can be republished. This makes version
selection a one-time, per-project decision (whatever was current when you
ran `pin-versions`) instead of drifting based on whichever machine's Docker
image cache happens to be warm. The rule is idempotent (skips vars that
already contain `@sha256:`).

### wp-content is split: git-tracked source vs. gitignored mirror

Two different bind-mount strategies coexist in `docker-compose.yml`, and
**mount order matters** (Docker resolves overlapping mounts by specificity,
so the narrower path must be listed after the broader one):

- `./theme` → `wp-content/themes/${THEME_SLUG}` and `./mu-plugins` →
  `wp-content/mu-plugins` are the **git-tracked source** for the active
  theme and must-use plugins. Edit these.
- `./wp-content/themes` → `wp-content/themes` (broader, listed *before* the
  `theme/` mount above) and `./wp-content/uploads` → `wp-content/uploads`
  are gitignored **live mirrors** — visibility/editability on host for
  default WP themes, any additionally-installed theme, and uploaded media,
  without polluting git. The uploads mirror also means media survives
  `make reset` (which only destroys Docker volumes, not host directories).

`wp_data` (the named Docker volume) still backs the *rest* of
`/var/www/html` (WP core, plugins, etc.) — only the paths explicitly
bind-mounted above are visible on host.

### wp-install.sh: generation, not configuration

`make wp-install` generates the admin username (`adm_user_<slug>`, slug
derived from `WEBSITE_NAME` via `iconv` transliteration + lowercasing) and a
20-character password from a shell-safe character set (deliberately
excludes `` ` $ " ' \ `` and spaces, since the password gets interpolated
into a `docker compose run` command line). Generation happens via `php -r`
inside the `wpcli` container rather than `wp eval`, because `wp eval`
requires a bootstrapped WordPress and fails with "not installed" before
`core install` has run. The script is idempotent (`wp core is-installed`
guard) and writes credentials to `wp-admin-credentials.txt` (gitignored).

## Gotchas (found via live testing, not documented upstream)

These cost real debugging time once each; don't re-derive them from
scratch:

- **MySQL 8 first-boot restart race**: the official `mysql` image starts a
  *temporary* init server (creates db/user), shuts it down, then starts the
  *real* server. A single successful `mysqladmin ping` can land in that gap.
  `wp-install.sh` requires two pings 8 seconds apart before proceeding, and
  `core install` itself is wrapped in a retry loop as a second line of
  defense.
- **`wordpress:cli` (Alpine) client vs. MySQL 8 defaults**: the bundled
  `mariadb-dump`/`mariadb-check` don't ship `caching_sha2_password` (MySQL
  8's default auth plugin) and reject the server's self-signed TLS cert.
  Fixed server-side in `docker-compose.yml`'s `db` service:
  `--default-authentication-plugin=mysql_native_password --skip-ssl`.
- **`wp db import` ignores SSL flags** (upstream bug,
  wp-cli/db-command#218) — its internal "get current SQL modes" pre-check
  uses its own mysqli connection that isn't affected by `--skip-ssl`. Worked
  around by having `make db-export`/`db-import` shell out to the `db`
  container's own `mysql`/`mysqldump` client directly instead of going
  through `wp db export`/`import`.
- **`mysqldump` needs `--no-tablespaces`** or it errors on missing PROCESS
  privilege (the `wordpress` DB user doesn't have it) — harmless but noisy
  without the flag.
- **PHPMailer rejects WordPress's default From address** (`wordpress@localhost`
  — no dot, fails PHPMailer's strict validator) regardless of mail
  transport. Fixed via `wp_mail_from` filter in `mu-plugins/mailpit.php`,
  not a Mailpit-specific issue.
- **`wpcli`'s uid 33 has no `/etc/passwd` entry** in the Alpine image (only
  uid 82/`www-data` exists there; 33 is forced to match the Debian
  `wordpress` image's `www-data` for file-permission consistency across the
  shared `wp_data` volume). `$HOME` falls back to `/`, so wp-cli tries to
  write its cache to `/.wp-cli/cache/` and fails silently on permission
  denied. Fixed with `WP_CLI_CACHE_DIR=/tmp/wp-cli-cache`.
- **`WORDPRESS_CONFIG_EXTRA` is re-evaluated per container, per request**
  (it's a literal `eval($configExtra)` in wp-config.php reading `getenv()`
  each load, not baked in once at generation time). The `wordpress` service
  has `DISALLOW_FILE_EDIT`/`DISALLOW_FILE_MODS` set; `wpcli` deliberately
  does not have this env var, which is *why* `make wp`/`make wp-install`
  aren't blocked by it — not because wp-cli specially bypasses the
  constants.
- **Git Bash on Windows path-mangles Docker args**: any `docker compose
  run`/`exec` invocation whose arguments include container-side absolute
  paths (e.g. `/var/www/html/...`) needs `MSYS_NO_PATHCONV=1` prefixed, or
  Git Bash silently rewrites the path to a Windows one before Docker ever
  sees it.
