# atesoraroseta build: overview and shared conventions

**Status:** approved by the user on 2026-10-12, after updates for year ranges, the admin password in encrypted credentials with no recovery, the domain `atesoraroseta.com`, and a droplet shared with other projects. The orchestrator runs the WPs as described in `docs/plans/ORCHESTRATION.md`. Section 4 binds every work package (WP).
If a decision turns out not to work, don't change it quietly. Do the conservative thing, write it down in your handoff note, and say so in your report.

Every WP is run by a fresh subagent with no memory of the planning conversation, so everything you need is in these files.
Read this whole overview first, then your own plan file.

## 1. The job

The portfolio website of a collage artist who works with torn billboard-poster fragments, plus a back office at `/admin` where every public text and image is edited.
The visual design is finished: build it faithfully and don't redesign it. Stack: Rails 8.1 on SQLite, deployed with Kamal to one DigitalOcean droplet.

## 2. Sources, in order of precedence

1. The user's later messages, then **`design/PROMPT.md`**: the requirements. Read it in full.
2. **This overview**: decisions the user approves.
3. **`design/canvas/source/*.dc.html`**: exact markup and inline layout values per artboard. See `design/canvas/README.md`.
4. **`design/DESIGN.md`**: tokens, type, layout, components and states.
5. **`design/site.css`**: the production stylesheet base.

PROMPT.md overrides these parts of DESIGN.md:
- "A static site… Astro": it is a Rails app with a database-backed admin.
- The content model "via Markdown/YAML content collections" and the `cutout` flag: use the models in section 4.2. There is no cutout flag.
- The Google Fonts `<link>`: self-host the WOFF2 files.

Out of scope: the canvas's `Font-options` artboard, `design/explorations/`, the stale `project/site.css` inside the canvas, and the pinned hover demo (`is-demo`, `is-on`).

## 3. Work packages

| WP | Plan | Runs in | Starts after |
|---|---|---|---|
| WP1 Toolchain and app skeleton | `01-toolchain-and-skeleton.md` | main checkout | user OK |
| WP2 Domain, images core and seeds | `02-domain-and-content.md` | main checkout | WP1 |
| WP3 Public site | `03-public-site.md` | own git worktree/branch | WP2 |
| WP4 Admin | `04-admin.md` | own git worktree/branch | WP2 |
| WP5 Deploy and backups | `05-deploy-and-backups.md` | own git worktree/branch | WP2 |
| WP6 Integration, QA and handoff | `06-qa-and-handoff.md` | main checkout | WP3–5 finished |

WP3, WP4 and WP5 run **in parallel**. WP6 merges their branches into `main`, resolves conflicts and runs the suite before its QA. The orchestrator, the main Claude session, only launches, verifies and reports (`ORCHESTRATION.md`).
To keep merges clean, every WP edits only the files it owns (section 7.2).

When you finish, write **`docs/handoff/WPn.md`** covering:
- what you built, and the APIs other WPs use;
- how to verify it;
- deviations and decisions you made;
- open issues;
- anything the user must decide.

Then reply with a short report (format in your plan).

## 4. Decisions

### 4.1 Stack and versions (checked 2026-10-10)

- **Ruby 4.0.7** (rbenv) and **Rails 8.1.4**.
- **SQLite**: the `sqlite3` gem 2.x bundles its own SQLite.
- Propshaft and importmap. **No Node build step.**
- Hotwire (Turbo and Stimulus) **in the admin only**.
- Solid Queue, Solid Cache and Solid Cable; Thruster; **Kamal 2.12**.
- **Active Storage with libvips.** Rails 8.1.4's generator pins `image_processing ~> 1.2`. Version 2.x (2.2.0) carries security fixes and makes `ruby-vips` a manual dependency. Use `image_processing ~> 2.2` plus `ruby-vips` if a real Active Storage variant works with it (WP1 verifies). Otherwise keep 1.x and note why.
- **Action Text with the Lexxy editor** (gem `lexxy` 1.0.x, docs at https://lexxy.dev/docs/). It saves real `<p>` paragraphs, which the design's body text needs. Trix, the default, saves `<div>` with `<br>`. If Lexxy won't work with importmap, Propshaft or the CSP, fall back to Trix and say so.
- **Authentication:** Rails' built-in generator (`bin/rails generate authentication`).
- **Ordering:** `acts_as_list`.
- **Spanish defaults:** `rails-i18n` (validation messages etc. in Spanish). `aws-sdk-s3` (`require: false`) for the uploads backup.
- **Tests:** Minitest. System tests use Selenium with headless Chrome (Chrome is installed).

### 4.2 Data model

Code identifiers are English. Everything a user sees is Spanish.

**`Artwork`** (`artworks`)
- `title` string, not null.
- `slug` string, not null, unique index. Generated from the title on create when blank (`parameterize`, so "Obra de muestra 02" → `obra-de-muestra-02`). Add `-2`, `-3`… on collision. Editable, format `\A[a-z0-9]+(?:-[a-z0-9]+)*\z`. Editing the title never changes an existing slug.
- `year` and `year_end`: integers, both nullable. A single year (2024) or a range (2023–2024); see "Year ranges" below.
- `medium` string (técnica) and `dimensions` string (medidas, free text such as "120 × 90 cm").
- `published` boolean, not null, default **false**.
- `position` integer, not null (acts_as_list; **new records go to the top**).
- `image_alt` string; timestamps.
- `has_one_attached :image` (**required**); `has_rich_text :description` (optional).
- `has_many :details, -> { order(:position) }, class_name: "ArtworkDetail", dependent: :destroy`.
- Scopes: `published`, and `ordered` = position ascending, then `COALESCE(year_end, year)` descending, then id.
- `previous` / `next`: neighbours among published works, in `ordered` order. **No wrap-around**: the first work has no previous and the last has no next.

**`ArtworkDetail`** (`artwork_details`)
- `artwork_id` FK, not null; `position` integer, not null (acts_as_list `scope: :artwork`, new records at the **end**); `alt` string; timestamps.
- `has_one_attached :image` (required).

**`TornPoster`** (`torn_posters`)
- `place`, `city`: strings; `year` and `year_end` (the same year-range rules); `alt` string.
- `published` boolean, not null, default **false**; `position` integer, not null (acts_as_list, new records at the **top**); timestamps.
- `has_one_attached :image` (required).

**`Site`** (`sites`): the single settings record. Its fields are in 4.3.
- `has_rich_text :about_body`; `has_one_attached :portrait`, `:og_image`, `:favicon`.
- `Site.current` returns the stored record, or an **unsaved** instance with the defaults, so public pages render even before seeding and a GET never writes. The admin edits `Site.first_or_create!`.
- Default texts are defined once (e.g. `config/site_defaults.yml`) and used by both the seeds and `Site.current`.

**`User` / `Session`**: from the generator.
- No sign-up and **no password recovery**. The password comes from the encrypted credentials (§4.7).
- Validate password length ≥ 12 when a password is set.

**Year ranges** (shared concern, used by `Artwork` and `TornPoster`)
- Storage is numeric: `year` is the first or only year, and `year_end` is set only for a range.
  - Both must be within 1900..(current year + 1).
  - `year_end` must be greater than `year` and requires `year`.
- The admin edits one text field, **`years`** (a virtual attribute), labelled "Año".
  - It accepts `2024`, `2023-2024`, `2023–2024`, `2023 — 2024` and the short form `2023-24` (meaning 2024). Blank clears both columns.
  - Anything else is a Spanish error: "Escribe un año (2024) o un periodo (2023–2024)".
- Display (`years_label`): `2024`, or `2023–2024` with an **en dash** and no spaces, everywhere on the public site.

**Image rules** (shared concern)
- Accepted types: `image/jpeg`, `image/png`, `image/webp`, plus `image/avif` **only if** `Vips.get_suffixes.include?(".avif")`.
- Maximum 25 MB. Error messages in Spanish.
- `low_resolution?` is true when the long side is under 1600 px. It is a warning, not a validation error.

**Alt text:** each image's alt is stored on its record. When it is blank, public pages fall back to:
- artwork: its title;
- detail: `"#{artwork.title} (n/N)"`;
- poster: `[place, city].compact_blank.join(", ")`;
- otherwise `""` (decorative).

The admin flags every record whose alt is blank.

### 4.3 Site texts: one settings record

Every visible public word comes from here, or from records.
- "Production default" is the seed value. Blank means "not set yet".
- **(+)** marks additions to PROMPT.md's list: words the design shows that the list missed.

| Column | Admin label | Production default | Shown |
|---|---|---|---|
| `wordmark` | Nombre (logotipo) | `atesoraroseta` | header; page titles |
| `nav_work_label` | Menú: Obra | `Obra` | menu, back link, hidden h1, title |
| `nav_torn_posters_label` | Menú: Torn Posters | `Torn Posters` | menu, hidden h1, title |
| `nav_about_label` | Menú: Sobre mí | `Sobre mí` | menu, h1, title |
| `nav_contact_label` | Menú: Contacto | `Contacto` | menu, h1, title |
| `torn_posters_intro` | Torn Posters: introducción | `Fotografías de carteles arrancados que inspiran la obra.` | /torn-posters |
| `details_label` | Etiqueta «Detalles» | `Detalles` | artwork page |
| `previous_label` | Etiqueta «Anterior» | `Anterior` | artwork page |
| `next_label` | Etiqueta «Siguiente» | `Siguiente` | artwork page |
| `view_details_label` | Enlace a detalles (varios) | `Ver los %{count} detalles` | artwork page |
| `view_detail_one_label` (+) | Enlace a detalles (uno) | `Ver el detalle` | artwork page with exactly 1 detail |
| `year_label` | Etiqueta «Año» | `Año` | artwork page |
| `medium_label` | Etiqueta «Técnica» | `Técnica` | artwork page |
| `dimensions_label` | Etiqueta «Medidas» | `Medidas` | artwork page |
| `seo_description` | Descripción para buscadores | same as `about_lead` (draft copy) | meta description fallback |
| `og_image` (attachment) | Imagen para redes sociales | none (falls back to the first artwork) | og:image |
| `favicon` (attachment) (+) | Icono del sitio | none (no icon linked) | `<link rel="icon">` |
| `about_lead` | Sobre mí: frase principal | `Trabajo con fragmentos arrancados de carteles publicitarios: los recojo, los guardo y los vuelvo a componer.` | /sobre-mi |
| `about_body` (rich text) | Sobre mí: texto | blank | /sobre-mi |
| `portrait` + `portrait_alt` | Retrato + texto alternativo | none | /sobre-mi |
| `about_contact_link_label` (+) | Sobre mí: enlace a contacto | `Escríbeme` | /sobre-mi |
| `contact_headline` | Contacto: titular | `Escríbeme` | /contacto |
| `email` | Correo electrónico | blank | /contacto (mailto) |
| `instagram_handle` | Usuario de Instagram | blank | /contacto |
| `instagram_label` (+) | Etiqueta «Instagram» | `Instagram` | /contacto |
| `not_found_title` (+) | 404: título | `Página no encontrada` (draft) | 404 page |
| `not_found_text` (+) | 404: texto | `La página que buscas no existe o ha cambiado de dirección.` (draft) | 404 page |
| `not_found_link_label` (+) | 404: enlace | `Volver a la obra` (draft) | 404 page |

- Store the Instagram handle without "@" and normalise pasted URLs and "@handle". Display it as `@handle`, linking to `https://www.instagram.com/<handle>/`.
- Strings that screen readers announce but aren't visible go in `config/locales/public.es.yml`, not in the database: the nav `aria-label`s "Principal" and "Otras obras", and any visually hidden helper text.
- Page titles are `"<page> — <wordmark>"`. Home uses `nav_work_label` (so "Obra — atesoraroseta"), and an artwork page uses its title.

### 4.4 Routes

Public routes (WP2 writes them; WP3 implements the controllers):

```
GET /                      artworks#index        (root)
GET /obra/:slug            artworks#show         (as: :artwork)
GET /torn-posters          torn_posters#index
GET /sobre-mi              pages#about           (as: :about)
GET /contacto              pages#contact         (as: :contact)
GET /sitemap.xml           sitemaps#show
GET /robots.txt            robots#show           (delete public/robots.txt)
    /404, /500             errors#not_found / errors#internal_error  (config.exceptions_app = routes)
GET /up                    rails/health#show     (Rails default)
```

The auth route is the generator's `resource :session`. **No password routes**: WP1 deletes the generator's password-reset pieces.

The admin lives under `namespace :admin`. WP2 adds only `root "artworks#index"` there, and WP4 fills in the rest. WP4 is the only WP that edits the admin block. **WP3 never edits `config/routes.rb`.**

### 4.5 Image pipeline

- **Storage:** Active Storage Disk service in `storage/`. In production that is a persistent Docker volume, shared with the SQLite files.
- **URLs:** `config.active_storage.resolve_model_to_route = :rails_storage_proxy`. This gives stable URLs with far-future public cache headers, which Thruster caches and compresses. There are no expiring redirect URLs.
- **Metadata:** width and height must exist before the first render. **Analyze synchronously right after an image is attached** (model callback), rather than relying only on the async `AnalyzeJob`.
- **Variants:** named variants, WebP with metadata stripped, never upscaled, alpha kept. Mark public variants `preprocessed: true` so Solid Queue builds them right after upload and no visitor waits. Rails 8.1.4 still uses `preprocessed:`; verify against the installed gem.
  - Artwork, ArtworkDetail: widths 600 / 1200 / 2400, height follows the image (`resize_to_limit [w, nil]`).
  - TornPoster: centred square crops 600 / 1200 / 2400, the same crop as `object-fit: cover`.
  - Site portrait: centred 4:5 crops 600 / 1200 / 2400.
  - Artwork and `Site#og_image`: `og`, 1200×630 **JPEG**. The image is contained, padded and flattened on the ground colour `#222221`.
  - `Site#favicon`: 32, 180 and 512 square PNGs.
  - Every image: `thumb` (about 320px long side, WebP) for the admin.
- **`srcset`:** use only the candidates that exist, i.e. widths at or below the original width, plus the original width when it is smaller than the largest. Dedupe them, and give each `w` descriptor the **actual** pixel width. The `width`/`height` attributes are the original's metadata. `sizes` follows the layout math in WP3.
- **Tiles:** frame `aspect-ratio: W / H; width: min(100%, 125% × W/H)`, written as a percentage with 2 decimals, the way the canvas writes `93.81%`. On phones `site.css` forces `width: 100% !important`.
- **Loading:**
  - Eager: the first row (home: the first 3 tiles; Torn Posters: the first 4), the artwork hero and the portrait.
  - The first image gets `fetchpriority="high"`.
  - Everything else gets `loading="lazy" decoding="async"`.

### 4.6 Front-end policy

- **Public pages ship no JavaScript** (DESIGN.md: "The UI needs no JavaScript"; hover is pure CSS).
- **Public pages set no cookies**: no `csrf_meta_tags` in the public layout, no session writes, and the CSP nonce generator doesn't touch the session. So there is no cookie banner and pages are cache-friendly.
- **Public CSS**, linked **by name**, never with `stylesheet_link_tag :app`, which would also pull in the admin and editor CSS:
  - `site.css` is `design/site.css` verbatim, except that the demo-only `.is-demo` / `.is-on` selectors are removed;
  - `layout.css` turns the canvas's inline layout values into classes;
  - `fonts.css` holds the `@font-face` rules.
- No global CSS reset. The canvas sets `body { margin: 0 }` and explicit margins inline, so replicate those exact values.
- On public pages, the only inline `style` attributes are the per-tile `width` and `aspect-ratio`.
- **Admin:** importmap with Turbo, Stimulus, Lexxy and Active Storage direct uploads, plus its own `admin.css` and the editor's CSS.

### 4.7 Security

- **CSP**:
  - `default-src 'self'`;
  - `script-src 'self'` plus a **per-request nonce**. Nonces apply only to `script-src`, and the generator uses `SecureRandom.base64(16)`, not the session id;
  - `style-src 'self' 'unsafe-inline'`, needed for the per-tile inline sizes and the editor's styles;
  - `img-src 'self' data: blob:`; `font-src 'self'`; `connect-src 'self'`;
  - `object-src 'none'`; `base-uri 'self'`; `form-action 'self'`; `frame-ancestors 'none'`.
- **Every `/admin` route requires login.**
  - There is no sign-up.
  - Use strong params everywhere.
- **Remove `allow_browser versions: :modern` from `ApplicationController`.** On public pages it would answer older iPhones and Safaris with a 406. WP4 may set it on `Admin::BaseController`.
- **The admin account comes from Rails encrypted credentials** (`config/credentials.yml.enc`), under `admin.email` (`admin@atesoraroseta.com`; it is only a login name, since nothing sends email) and `admin.password`.
  - **`bin/rails admin:credentials`** (WP2) writes both into the encrypted credentials:
    - interactively, it prompts with no echo and asks for the password twice;
    - non-interactively, it reads `ADMIN_EMAIL`/`ADMIN_PASSWORD`.

    This is how the password is set and changed. The next deploy, or `admin:sync`, applies it.
  - **`bin/rails admin:sync`** creates the admin user, or updates its password. When the password changes, it **deletes all that user's sessions**.
  - It runs from `db/seeds.rb`, and **on every production boot** in `bin/docker-entrypoint`, after `db:prepare`. To change the password, edit the credentials and deploy.
  - Environment variables `ADMIN_EMAIL` / `ADMIN_PASSWORD`, when set, override the credentials (for CI and the deploy rehearsal).
  - With neither available (e.g. no master key), it prints a warning and skips. It never fails a boot or `bin/setup`.
- **No password recovery.** WP1 deletes the generator's `PasswordsController`, its routes, views, `PasswordsMailer` and their tests. Nothing in the app sends email, so there is no SMTP.
- **The real admin password is never written in plain text** anywhere: not in code, seeds, tests, fixtures, plans, handoff notes, commit messages, logs or reports.
  - The orchestrator puts it into the encrypted credentials right after WP2, with `admin:credentials`, and commits the encrypted file before WP3–5 start.
  - To log in locally, read it with `bin/rails credentials:show`. In a worktree, first copy `config/master.key` from the main checkout. Never repeat it in any output.
  - Test fixtures use their own throwaway password.
- **Login rate limit:** at most **5 attempts per 10 minutes** per IP, with a Spanish message.

### 4.8 Deployment and backups

- **Domain:** `atesoraroseta.com`, with `www.atesoraroseta.com` redirecting to it. The droplet's IP isn't known yet, so it stays the placeholder `<DROPLET_IP>` until the user provides it. The domain's DNS doesn't point at the droplet yet either.
- **The droplet is shared with the user's other projects, which have other domains.**
  - kamal-proxy runs once per server on ports 80/443, and routes each request **by host name** to the right app, with its own Let's Encrypt certificate.
  - Every project is its own Kamal app, deployed to the same IP. This app must be a good neighbour:
    - unique names: service `atesoraroseta`, volume `atesoraroseta_storage`, accessory names prefixed with the service (Kamal does this);
    - no host ports published;
    - no server-wide changes beyond what Kamal itself does;
    - no global proxy settings (only per-app proxy options in `deploy.yml`).
  - Everything on the server goes through kamal-proxy. A future static site or non-Rails app is deployed as its own small container with Kamal too.
- One DigitalOcean droplet (Ubuntu LTS) running Kamal 2 with kamal-proxy and automatic Let's Encrypt. **2 GB RAM** covers this app plus one more small app; 4 GB suits several.
- Docker named volume `atesoraroseta_storage` mounted at `/rails/storage`, holding the SQLite databases and the Active Storage files.
- **Registry:** DigitalOcean Container Registry. Its free tier holds 1 repository, so several projects need the paid tier (or GitHub's registry). `DEPLOY.md` says so.
- **Secrets live in Rails encrypted credentials.** The only thing to keep safe is `config/master.key`, stored in a password manager.
  - Credential keys: `admin.email`, `admin.password`, `kamal.registry_password`, `spaces.access_key_id`, `spaces.secret_access_key`.
  - `.kamal/secrets` reads them with `bin/rails credentials:fetch <key>`, plus `RAILS_MASTER_KEY=$(cat config/master.key)`. This is the pattern in Rails' own Kamal template.
  - The app reads `admin.*` and `spaces.*` directly, since it has the master key.
  - Environment variables of the same meaning override the credentials (`ADMIN_*`, `SPACES_*`), for CI and the local rehearsal.
- **Backups** go to a private DigitalOcean Spaces bucket **for this project only** (`atesoraroseta-backups`), with an access key scoped to that bucket. Other projects get their own buckets.
  - **Database:** Litestream v0.5.x runs as a **Kamal accessory** on the same volume. It continuously replicates `production.sqlite3` to `db/` in the bucket; cache, queue and cable databases are ephemeral. It is an accessory, not the litestream gem's Puma plugin, so exactly one Litestream process exists even while a zero-downtime deploy overlaps two app containers.
  - **Uploads:** a nightly Solid Queue recurring job copies every Active Storage file that isn't in the bucket yet to `uploads/<key>`. It is **copy-only and never deletes**, so every point-in-time database restore still finds its images. A rake task restores them.
  - **Why not Spaces as primary storage:**
    - images are served from local disk next to the app, with no CORS or CDN wiring;
    - deleting something in the admin can't destroy the only copy;
    - restores are point-in-time.
- **`DEPLOY.md`** has the exact steps (see WP5).

### 4.9 Clarifications beyond PROMPT.md and DESIGN.md

- **Grids are intrinsic.** Implement the canvas formulas exactly: Obra `repeat(auto-fill, minmax(min(100%, 300px), 1fr))`, details `columns: 3 300px`. The guide says so; DESIGN.md's breakpoint table is approximate.
- **At 320px the menu wraps onto two rows.** One row needs a viewport of at least ~359px. This is accepted unless the user decides otherwise. Nothing may scroll sideways.
- **Hide whatever is empty:**
  - no details section and no "Ver…" link without details;
  - no "·" when the year (or the medium) is blank;
  - no meta line when both are blank;
  - no description paragraph when it is empty;
  - no portrait figure without a portrait;
  - no email link without an email;
  - no Instagram row without a handle;
  - in poster labels, no place line or "city · year" parts that are blank, and no label at all when everything is blank.
- **Unpublished records answer 404** to visitors.
  - A logged-in admin can open an unpublished artwork page. It then shows a small admin-only notice, which is the one addition on public pages and is never visible to visitors.
  - Grids always list published records only.
  - Posters have no page of their own, so their "Ver en la web" link points to `/torn-posters#poster-<id>`.
- **SEO:**
  - Meta descriptions:
    - home and contacto use `seo_description`;
    - an artwork page uses its description as plain text, truncated to about 155 characters, falling back to "title, year. medium.";
    - Torn Posters uses its intro;
    - Sobre mí uses the lead.
  - og:image: the artwork's `og` variant on artwork pages; elsewhere `Site#og_image`, else the first published artwork's `og` variant.
  - Also: canonical URLs; `sitemap.xml` with the static pages and the published artworks, with `lastmod`; and `robots.txt` that disallows `/admin` and `/session` and points to the sitemap.
- **404:**
  - Rendered dynamically in the site layout through `exceptions_app`, built from existing components only (the Contacto page's structure).
  - The static `public/404.html` and `500.html` are restyled fallbacks; hard-coded copy is unavoidable there.
  - Delete the Rails default icons and `406-unsupported-browser.html`.
- **No analytics, no cookie banner.** The time zone stays at its default.

## 5. Canvas values DESIGN.md doesn't state

Each `<main>` has its own `padding-top`:

| Page | `padding-top` |
|---|---|
| Obra | `clamp(8px, 1.1vw, 16px)` |
| Artwork | `clamp(4px, 0.6vw, 8px)` |
| Torn Posters | `clamp(8px, 1.1vw, 16px)` |
| Sobre mí | `clamp(8px, 1.7vw, 24px)` |
| Contacto | `clamp(40px, 8.4vw, 120px)` |

**Header**
- Wordmark: `display:block; padding-block:8px; line-height:1`.
- Menu `ul`: `display:flex; flex-wrap:wrap; gap:0 clamp(14px,2.2vw,32px); margin:0; padding:0; list-style:none`.
- Menu links: `display:block; padding-block:12px; line-height:20px`.

**Visually hidden h1**: `position:absolute; width:1px; height:1px; margin:0; overflow:hidden; clip-path:inset(50%); white-space:nowrap`.

**Artwork page**
- **Back link:** `inline-flex; align-items:center; gap:10px; padding-block:12px; font-size:11.5px; line-height:20px; font-weight:450; letter-spacing:.18em; uppercase`, with this 14px SVG: `<path d="M13 7H1.5M6 2.5 1.5 7 6 11.5">`, stroke-width 1.2, round caps and joins.
- **Hero:** `<section aria-labelledby="titulo-obra">` with `margin-top: clamp(8px,1.7vw,24px)`.
- **Text column:** `padding-top:6px`.
- **h1:** id `titulo-obra`, letter-spacing −0.005em.
- **`dl`:** adds `border-bottom: 1px solid var(--line)`.
- **`dt`:** `flex: 0 0 84px; padding-top: 4px`.
- **Técnica `dd` and the description `p`:** `text-wrap: pretty`.
- **"Ver los N detalles":** `align-self:flex-start; padding-block:12px; font-size:13px; line-height:20px; letter-spacing:.04em`.
- **Details:** `<section id="detalles" aria-labelledby="titulo-detalles">` with `<h2 id="titulo-detalles" class="label">` (`margin: 0 0 28px; padding-bottom: 20px; border-bottom`).
- **Detail images:** `display:block; width:100%; height:auto`.
- **Prev/next nav:**
  - The nav: `display:flex; flex-wrap:wrap; justify-content:space-between; gap:16px 40px`.
  - Each link: `display:flex; flex-direction:column; gap:8px; padding-block:8px`, and "Siguiente" adds `align-items:flex-end; margin-left:auto; text-align:right`.
  - The label row: `inline-flex; gap:10px; 11px/14px; weight 500; .22em; uppercase`, with a 12px SVG at stroke-width 1.3. The previous arrow path is `M13 7H1.5M6 2.5 1.5 7 6 11.5`; the next arrow path is `M1 7h11.5M8 2.5 12.5 7 8 11.5`.
  - The title: Bodoni italic 22/1.2, colour `var(--ink)`.

**Hero image filter**: `drop-shadow(0 2px 3px rgba(0,0,0,.30)) drop-shadow(0 24px 40px rgba(0,0,0,.48))`.

**Torn Posters**
- Intro `p`: `max-width:520px; margin:8px 0 clamp(28px,2.8vw,40px); 15px/1.6; color:var(--ink-2); text-wrap:pretty`.
- Tile label: `left:12px; bottom:12px; max-width:calc(100% - 24px); padding:10px 13px 11px`, title 20px.
- The canvas's "Foto 01" captions are placeholders. Don't ship them.

**Sobre mí**
- Row: `flex-wrap; align-items:flex-start; gap:clamp(40px,6.7vw,96px)`.
- Figure: `margin:0`.
- Text column: `padding-top:4px`.
- Lead: letter-spacing −0.005em, `text-wrap: pretty`.
- Body paragraphs: `text-wrap: pretty`.
- "Escríbeme" link: `align-self:flex-start; padding-block:12px; 15px/20px; letter-spacing:.02em`.

**Contacto**
- Email link: `align-self:flex-start`.
- Instagram row: `display:flex; flex-wrap:wrap; gap:24px 64px` with an inner column at `gap:6px`.
- Handle link: `padding-block:10px; 15px/24px; letter-spacing:.02em`.

## 6. Development seed content (canvas order)

- Obra order matches the canvas: `obra-01, 03, 08, 04, 02, 07, 06, 05, 09`.
- Titles are "Obra de muestra 01" … "09", numbered by file.
- `obra-01` alt: "Collage de carteles arrancados en azules, ocres y rosas sobre papel blanco rasgado (obra de muestra)".
- Stand-in alt: "Imagen provisional: fragmento de la obra de muestra".

Details of obra-01, in order:

| # | File | Alt |
|---|---|---|
| 1 | d5 | "Detalle: papel blanco arrugado sobre azul" |
| 2 | d1 | "Detalle: borde rasgado con las marcas de imprenta del cartel" |
| 3 | d6 | "Detalle: banda amarilla y cremallera impresa" |
| 4 | d8 | "Detalle: curva de trama beige junto a una forma gris" |
| 5 | d3 | "Detalle: trama de puntos de un cabello impreso" |
| 6 | d2 | "Detalle: rosa arrancado que deja ver el papel blanco" |
| 7 | d4 | "Detalle: capas rasgadas en verde y azul" |
| 8 | d7 | "Detalle: ocre, azul y verde azulado en la parte inferior" |

Twelve generated posters:
- Tints in order: `#516268 #7E5F35 #32333A #944B4F #99958B #383958 #865A47 #485749 #5A6470 #2E323C #8A5636 #5E6166`.
- Each has a faint dot screen like the canvas (1px dots of black at 20% opacity on a 6px grid).
- They are 1600×1600 so no low-resolution warning shows.

Bracketed canvas placeholders are allowed **in development seeds only**, so the dev site looks like the canvas. Never seed them in production:
- artwork texts;
- `[Lugar]` / `[Ciudad]`;
- the two bracketed bio paragraphs;
- a generated placeholder portrait: `--surface` plus a faint dot screen, 4:5, alt "[Retrato o foto en el taller]";
- email `tu-correo@example.com` and Instagram `usuario`.

## 7. Conventions

### 7.1 Working rules

- Run **Ruby 4.0.7** from the project root, where `.ruby-version` is set.
- Before relying on an API from memory, confirm it in the installed gem source (`bundle info --path <gem>`).
- **Commit after every step** in small commits with imperative subjects. End each message with:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- Never commit secrets: `config/master.key` stays ignored. Never rewrite history or force-push.
- Worktree WPs commit only on their own branch.
- **Keep it green at every code commit:**
  - `bin/rails test` and `bin/rails test:system`;
  - `bin/rubocop` (omakase config);
  - `bin/brakeman --no-pager`;
  - `bin/importmap audit`;
  - `bin/bundler-audit`, if present.
- **Dev server ports:** WP3 3003, WP4 3004, WP5 3005, WP6 3006. Stop the servers you start, and never kill processes you didn't start.
- Don't add gems beyond section 4.1 without a strong reason. If you add one, say so in your handoff.
- Don't install global tools except where your plan says to.
- **You can't ask the user anything.** Take the conservative option, write it down, and report it.
- **Don't change the design.** If something in the spec doesn't work in practice, keep the spec's behaviour where possible and report it with a proposed fix.

### 7.2 File ownership (keeps the parallel merges clean)

**WP2**
- `app/models/**`, `db/**`, `config/site_defaults.yml`, `lib/tasks/admin.rake`;
- `test/models/**`, `test/fixtures/**`, `test/test_helper.rb`;
- `config/routes.rb` (initial version).

**WP3**
- **Controllers:** the public controllers (`artworks`, `torn_posters`, `pages`, `sitemaps`, `robots`, `errors`).
- **Views:** `app/views/{layouts/application,artworks,torn_posters,pages,sitemaps,errors,public}/**`, plus `app/views/layouts/action_text/**` and `app/views/active_storage/**`.
- **Helpers:** public helpers in `app/helpers/`, but not `admin/`.
- **Assets:** `app/assets/stylesheets/{site,layout,fonts}.css`, `app/assets/fonts/**`.
- **Static and config:** `public/*.html`, the public icon files, `config/locales/public.es.yml`, `bin/screenshots`.
- **Tests:** `test/controllers/` (public), `test/integration/**`.

**WP4**
- **Controllers and views:**
  - `app/controllers/admin/**`;
  - the generated `sessions_controller.rb` and `concerns/authentication.rb`;
  - `app/views/{admin,sessions}/**`;
  - `app/views/layouts/admin*`.
- **Assets and JS:** `app/helpers/admin/**`, `app/assets/stylesheets/admin.css`, `app/javascript/**`, `config/importmap.rb`.
- **Config:** `config/locales/admin.es.yml`, and the `namespace :admin` block of `config/routes.rb`.
- **Tests:** `test/controllers/admin/**`, `test/system/**`.
- **Models:** WP4 may make small, additive changes the admin needs (e.g. `accepts_nested_attributes_for`), listed in its handoff.

**WP5**
- **Docker and Kamal:** `Dockerfile`, `.dockerignore`, `bin/docker-entrypoint`, `config/deploy.yml`, `.kamal/**`.
- **Config:** `config/litestream.yml`, `config/environments/production.rb`, `config/storage.yml`, `config/recurring.yml`.
- **Code and docs:** `app/jobs/backup_*`, `lib/tasks/backup.rake`, `DEPLOY.md`, and the tests for those.

**Shared files** (touch them minimally and mention it in your handoff): `Gemfile`/`Gemfile.lock` (WP1 adds everything in section 4.1 up front), `config/application.rb`, `config/initializers/*`, `config/locales/es.yml`.

### 7.3 Environment (this Mac, checked 2026-10-10)

- **Machine:** macOS 14 on arm64, Homebrew 6. Google Chrome is installed. Node 26 and npx are available (for Lighthouse only). `gh` is not installed.
- **Ruby:** rbenv has Ruby 3.3.x only, and ruby-build is from 2024, too old for Ruby 4. Global gems: rails 8.0.1, kamal 2.5.3. WP1 installs Ruby 4.0.7 and Rails 8.1.4.
- **Images and data:** **libvips is not installed** (WP1: `brew install vips`); libheif 1.17.6 is present. System sqlite3 is 3.43.
- **Docker** Desktop is installed but **not running**. Start it with `open -a Docker` and wait for `docker info` (only WP5 needs it).
- **Headless Chrome can't lay out narrower than ~500px with `--window-size`.** For 390 and 320, use CDP `Emulation.setDeviceMetricsOverride` or an exact-width iframe.

### 7.4 Gotchas

- `stylesheet_link_tag :app` links **every** stylesheet, admin and editor CSS included. Link stylesheets by name.
- `csrf_meta_tags`, or a CSP nonce generator built on `request.session`, writes the session cookie. Neither may run on public pages.
- Active Storage analysis is asynchronous by default, so width and height can be missing right after upload. Hence the synchronous analysis in 4.5.
- Uploading many files in one multipart request through kamal-proxy and Puma is slow and can time out. The admin uses **direct uploads**, one request per file.
- Git worktrees don't contain ignored files (`config/master.key`, `storage/`, `tmp/`).
  - Copy `config/master.key` from the main checkout (`/Users/eitanfuturo/develop/projects/atesoraroseta/config/master.key`) into your worktree, then run `bin/setup --skip-server`.
  - Without the key the app still runs and the tests still pass, but the seeds can't create the admin, so you can't log in locally.
  - Never commit the key.
- **Agent worktrees may live under `.claude/`.** WP1 adds `/.claude/` to `.gitignore`, and to RuboCop's and Brakeman's excludes.
