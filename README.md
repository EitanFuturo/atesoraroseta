# atesoraroseta

The portfolio website of a collage artist who works with torn fragments of billboard posters (**atesoraroseta.com**), plus a back office at `/admin` where every text and image on the public site is edited.

- **Public site** (in Spanish): Obra (the artwork grid), one page per artwork, Torn Posters, Sobre mí and Contacto. No JavaScript and no cookies.
- **Admin** (`/admin`, in Spanish): artworks with their detail photos, Torn Posters, Sobre mí, Contacto and every site text, with reordering, image checks and previews.
- **Stack:** Rails 8.1 on SQLite (Solid Queue, Cache and Cable), Active Storage with libvips, Action Text with the Lexxy editor, Hotwire in the admin only. Deployed with Kamal to a DigitalOcean droplet.

The design and the requirements are in `design/` (`PROMPT.md`, `DESIGN.md`, the canvas). The build plans are in `docs/plans/`, and each work package's notes are in `docs/handoff/` (`WP6.md` has the final QA).

## Requirements

- **Ruby 4.0.7** (`.ruby-version`; with rbenv, run commands from this folder).
- **libvips** 8.x, for images: `brew install vips` (macOS) or `apt install libvips` (Debian/Ubuntu). This Mac uses a local build; see `docs/handoff/WP1.md` §6.
- **Google Chrome**, for the system tests and the screenshot tools.
- **`config/master.key`**, kept in your password manager and never committed. It unlocks `config/credentials.yml.enc`, which holds the admin login and the deploy secrets. Without it the site and the tests still run, but no admin is created.

## Set up and run

```sh
bin/setup --skip-server   # installs the gems, creates the database and loads the seeds
bin/dev                   # starts the site at http://localhost:3000
```

`bin/setup` without `--skip-server` starts the server too. It is safe to run again at any time.

**Seeds** (`db/seeds.rb`):
- **Every environment:** the settings record with the default texts, and the admin user from the credentials.
- **Development only:** sample content, so the site looks like the design at once. That means the sample artwork with its 8 detail photos, eight stand-ins ("Obra de muestra 02" to "09") and twelve generated Torn Posters. It also adds bracketed placeholder texts, a placeholder portrait, a sample email and an Instagram handle. Production never gets these.
- **Start over:** `bin/rails db:seed:replant` empties the development database and loads the seeds again.

## Logging into /admin locally

1. Open http://localhost:3000/admin and log in as **admin@atesoraroseta.com**.
2. The password is in the encrypted credentials. `bin/rails credentials:show` displays it, and it needs `config/master.key`. Don't copy it into files, chats or commits.
3. The seeds create the user. If it is missing, or the password changed, run `bin/rails admin:sync`.

**Without the master key**, create a local admin from environment variables instead. They override the credentials:

```sh
read -rs ADMIN_PASSWORD && export ADMIN_PASSWORD   # type a password of 12 or more characters; it isn't shown
ADMIN_EMAIL=admin@atesoraroseta.com bin/rails admin:sync
```

**To change the password:**
1. Run `bin/rails admin:credentials`. It asks for the email and the new password, twice, without showing it.
2. Run `bin/rails admin:sync` to apply it locally. It also signs out every session.
3. To apply it in production, commit `config/credentials.yml.enc` and deploy (`DEPLOY.md`, B6).

There is no "forgot password". The login allows 5 attempts per 10 minutes from one IP address.

## Tests and checks

```sh
bin/rails test          # models, controllers, the public pages with and without content, the deploy config
bin/rails test:system   # the admin flows in headless Chrome
bin/ci                  # everything: setup, RuboCop, bundler-audit, importmap audit, Brakeman, tests, seeds, system tests
```

Screenshots go to `tmp/page-screenshots/`:
- `bin/screenshots --base http://localhost:3000` shoots the public pages at 1440, 768, 390 and 320 px and flags any sideways scroll. `--reference` shoots the design canvas instead, for comparison.
- `PORT=3000 bin/rails runner script/admin_screenshots.rb` shoots every admin screen, logged in as a throwaway user that it deletes afterwards.

## Deploying

See **[DEPLOY.md](DEPLOY.md)**. It covers the droplet and DNS, the secrets, `kamal setup` and `kamal deploy`, the admin user, and the backups with how to restore them.

## Content still missing

Everything below is entered in `/admin`. Nothing needs code.

- **The real artworks and their photos:** 2400 px on the long side, cut out on a transparent background where possible (WebP or PNG; the sample `obra-01` is prepared this way). Each needs its title, year (or period), medium (técnica) and size (medidas), and the optional text. Add its detail photos.
- **Torn Posters photos**, each with place, city and year.
- **Sobre mí:** the portrait and its alt text, and both bio paragraphs.
- **Contacto:** the email address and the Instagram handle.
- **The default social image** (1200 × 630) and **the site icon** (a square PNG of at least 512 px), under Textos del sitio.
- **The draft copy needs the artist's approval:**
  - the Sobre mí lead, which is also the default search description;
  - the 404 texts;
  - the wording of the static error pages (`public/400.html`, `422.html`, `500.html`).
