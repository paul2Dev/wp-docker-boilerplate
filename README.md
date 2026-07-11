# Boilerplate WordPress + Docker

Punct de pornire pentru un proiect WordPress nou, cu Docker Compose + WP-CLI:

- servicii: WordPress, MySQL, phpMyAdmin, Mailpit (mail catcher local)
- instalare automată: admin generat, temă activată, plugin-uri de bază instalate
- versiuni de imagini Docker blocate per-proiect

Poate fi folosit și ca punct de pornire pentru migrarea unui site static
existent într-o temă WordPress clasică (vezi pasul opțional cu
`html-export/` din „Pornire proiect nou"), dar nu e limitat la asta.

`.todo` e un fișier gol, gata pentru notele și planul pe etape ale noului
proiect.

## Pornire proiect nou

1. Clonează acest repo într-o locație nouă, cu numele proiectului:

   ```
   git clone <url-repo> ../nume-proiect-nou/
   cd ../nume-proiect-nou/
   ```

2. Completează `.env` (se generează automat din `.env.example` la prima
   comandă `make` rulată, dacă nu există deja):

   - `THEME_SLUG` — slug-ul temei (folosit și ca nume de folder în `wp-content/themes/`)
   - `WEBSITE_NAME` — numele site-ului (folosit ca titlu WordPress și ca bază pentru
     username-ul admin, generat automat: `adm_user_<slug derivat din WEBSITE_NAME>`).
     Dacă numele conține spații, pune-l între ghilimele: `WEBSITE_NAME="Ferma Populești"`
   - `ADMIN_EMAIL` — emailul admin-ului
   - parolele DB, dacă vrei altele decât valorile implicite

3. **Opțional**, dacă transformi un site static existent într-o temă WordPress:
   pune arhiva exportată (HTML/CSS/JS) în `html-export/` — nu e folosită
   automat de nimic, ci ca material de referință pentru asistentul AI
   (Claude Code), care o poate citi ca să reconstruiască marcajul static ca
   șabloane PHP în `theme/`. Sari peste pasul ăsta la un proiect nou, de la zero.

4. Blochează versiunile imaginilor Docker pentru acest proiect (o singură
   dată, înainte de primul `make up`):

   ```
   make pin-versions
   ```

   (vezi secțiunea „Versiuni" mai jos pentru ce face exact)

5. Pornește stack-ul:

   ```
   make up
   ```

6. Instalează WordPress (o singură dată, după primul `make up`):

   ```
   make wp-install
   ```

   Comanda automat:

   - generează un username admin (`adm_user_<slug site>`) și o parolă random
     puternică de 20 caractere
   - instalează WordPress și activează tema din `THEME_SLUG`
   - instalează și activează pluginurile de bază:
     - Contact Form 7
     - CFDB7 (Database Addon for Contact Form 7)
     - ACF (Advanced Custom Fields)
     - CAPTCHA 4WP
     - Limit Login Attempts Reloaded
   - afișează credențialele în terminal și le salvează local în
     `wp-admin-credentials.txt` (fișier gitignored, nu ajunge niciodată în repo)

   Rulând comanda a doua oară, dacă WordPress e deja instalat, nu se
   suprascrie nimic.

## Teme

`theme/` (rădăcina proiectului) e sursa **git-tracked** a temei active
(`THEME_SLUG`) — aici lucrezi, aici e istoricul de git.

După primul `make up`, apare și `wp-content/themes/` (gitignored) — o
oglindă live a **tuturor** temelor din container: cele implicite WordPress
(`twentytwentyfive` etc.) și orice mai instalezi manual sau prin
`make wp CMD="theme install ..."`. Poți naviga/edita orice temă direct de-acolo
din editor; pentru tema activă însă, editează în `theme/` — `wp-content/themes/<THEME_SLUG>/`
e doar un mountpoint gol pe host (conținutul real vine din `theme/`), nu
sursa reală.

Boilerplate-ul ține o singură temă custom "activă" (git-tracked) o dată —
`theme/` + `THEME_SLUG`. Dacă te răzgândești pe parcurs:

- **Pornești o temă custom nouă, de la zero** — suprascrii conținutul din
  `theme/` cu noua temă (dacă ai commis codul vechi, rămâne recuperabil din
  istoricul git), actualizezi header-ul din `theme/style.css` (Theme Name,
  Text Domain) și `THEME_SLUG` din `.env`, apoi `make up` (remontează la noul
  path) + `make wp CMD="theme activate <noul-slug>"`.

- **Pornești de la o temă existentă** (WordPress.org sau un zip cumpărat) —
  `make wp CMD="theme install <slug> --activate"` (sau extragi zip-ul manual
  în `wp-content/themes/`) — apare imediat, editabilă, dar necomisă în git
  (cod vendor, ca `node_modules`). Dacă vrei să continui să lucrezi la ea cu
  istoric git, o muți în `theme/` și actualizezi `THEME_SLUG` să corespundă.

## Media

`wp-content/uploads/` (gitignored, ca și `wp-content/themes/`) e mapat direct
pe host — pozele/PDF-urile încărcate prin wp-admin trăiesc pe disc, nu doar în
volumul Docker `wp_data`. Asta înseamnă că **supraviețuiesc unui `make
reset`** (care șterge volumele) și pot fi copiate/arhivate manual oricând,
fără nicio comandă dedicată.

## Mail

Nimic din stack nu poate trimite email real (nu există sendmail/SMTP extern
configurat) — orice email trimis de WordPress (reset de parolă, notificări,
formulare Contact Form 7) e prins de **Mailpit**, un server SMTP local cu UI
web la http://localhost:8025, fără să iasă niciodată din mașina ta. Ruta e
făcută de `mu-plugins/mailpit.php` (git-tracked, activ automat, fără să fie
nevoie de `theme activate` sau `plugin activate`).

## Versiuni

În `.env`, aceste variabile pornesc ca tag-uri "rolling" (ex.
`wordpress:php8.3-apache` — orice versiune e curentă la momentul respectiv):

- `WORDPRESS_IMAGE`
- `MYSQL_IMAGE`
- `PHPMYADMIN_IMAGE`
- `WPCLI_IMAGE`
- `MAILPIT_IMAGE`

`make pin-versions` le rezolvă la digest-ul exact al imaginii de acum și le
suprascrie în `.env`. De atunci încolo, versiunile rămân blocate pentru acest
proiect — nu se mai schimbă la `make up`, indiferent cât timp trece sau ce se
publică ulterior pe Docker Hub. Un proiect nou, clonat peste 2 luni, va
bloca la rândul lui versiunile curente din acel moment — fiecare proiect e
independent.

## Comenzi disponibile (Makefile)

- `make pin-versions` — blochează versiunile imaginilor Docker pentru acest proiect (o singură dată, înainte de primul `make up`)
- `make up` — pornește `db`, `wordpress`, `phpmyadmin`, `mailpit` (WordPress: http://localhost:8080, phpMyAdmin: http://localhost:8081, Mailpit: http://localhost:8025)
- `make wp-install` — instalează WordPress cu admin generat automat, activează tema și pluginurile de bază (o singură dată)
- `make down` — oprește containerele
- `make reset` — oprește containerele **și șterge volumele** (db + nucleul WordPress) — repornire completă, curată; ireversibil, fă `make db-export` înainte dacă ai nevoie de date (media din `wp-content/uploads/` nu e afectată, e pe host)
- `make restart` — repornește containerele
- `make logs` — urmărește log-urile
- `make status` — starea containerelor
- `make wp CMD="..."` — orice altă comandă WP-CLI, ex. `make wp CMD="post list"`
- `make db-export` — salvează un dump al bazei de date în `backups/db-<timestamp>.sql` (gitignored)
- `make db-import FILE=backups/db-....sql` — restaurează un dump
- `make shell` — shell în containerul WordPress

## Structura folderului

```
docker-compose.yml         # wordpress + db + wpcli + phpmyadmin + mailpit
Makefile                   # comenzile de mai sus
scripts/wp-install.sh      # logica din spatele `make wp-install`
scripts/pin-versions.sh    # logica din spatele `make pin-versions`
.env / .env.example        # config local (porturi, parole DB, THEME_SLUG, WEBSITE_NAME, ADMIN_EMAIL, imagini Docker)
.gitignore                 # .env, .todo, html-export/, wp-admin-credentials.txt, wp-content/ raman locale, necomise
.todo                      # gol - notele si planul pe etape ale proiectului curent
html-export/                # aici intra arhiva site-ului vechi (montata read-only in wpcli ca /export)
import/                     # scripturi WP-CLI de import (create-page-*.php, etc.) - se scriu per proiect
theme/                      # sursa git-tracked a temei active (style.css, functions.php, header.php, footer.php, index.php)
mu-plugins/                 # sursa git-tracked a must-use plugins (ex. mailpit.php - vezi "Mail")
wp-content/                 # gitignored - toate temele (vezi "Teme") + media incarcata (vezi "Media")
wp-admin-credentials.txt   # generat de make wp-install (gitignored, nu exista pana la primul install)
```

Fiecare proiect construit din acest boilerplate are propriul stack Docker
izolat (numele stack-ului = numele folderului proiectului), deci poți avea
mai multe proiecte pe disc fără să se amestece containerele — doar nu le
porni pe amândouă simultan dacă ai lăsat aceleași porturi (8080/8081) în
`.env`.
