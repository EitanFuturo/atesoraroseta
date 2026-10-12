# Build the atesoraroseta website

You're building the portfolio website of a collage artist who works with torn fragments of billboard posters, plus a back office at `/admin` where every text and image on the public site is edited. The visual design is finished. Build it faithfully; don't redesign it.

## What you have

- `design/DESIGN.md`: the full spec. It covers tokens, type, layout per breakpoint, every component, routes, the content model, image rules and a "Done when" checklist. It is the source of truth.
- `design/site.css`: the production stylesheet, with tokens, shared text styles, hover/focus/current-page states and responsive overrides. Make it the base of the app's stylesheet, and move the inline layout values described in DESIGN.md into classes next to it.
- `design/img/`: the one real sample artwork (`obra-01.webp`, already cut out on transparency), its 8 detail photos (`obra-01-d1…d8.jpg`) and stand-in crops of it (`obra-02…09.jpg`). Use them for development seeds only.
- The design canvas: https://claude.ai/artifact/1ztW4VbnoU3EeApQhkp8vo. It has desktop (1440) and mobile (390) artboards of every page, plus a build guide. If you have the Artifact tool, read the artboards' source for exact markup and values (`project/Main.dc.html`, `Obra-detalle`, `Torn-posters`, `Sobre-mi`, `Contacto`, `Guia`). If not, DESIGN.md has everything you need. Ignore the `Font-options` artboard and `design/explorations/`. The canvas's pinned "hover demo" (one label always open) is for the mockup only; don't ship it.

## Stack

Use the latest stable Ruby on Rails (check RubyGems for the current version; Rails 8 or newer) on the latest stable Ruby, keeping its defaults where they fit:
- SQLite in production with Solid Queue, Solid Cache and Solid Cable; Propshaft, importmap and Hotwire. No Node build step unless something truly needs one.
- Active Storage for uploads, with `image_processing` and libvips for variants.
- Action Text for the two formatted texts: the Sobre mí body and the artwork description.
- Rails' built-in authentication generator for the admin login.
- Kamal for deploying to a single DigitalOcean droplet.

If you would strongly recommend a different stack for this job (a small portfolio with a CMS on one server, edited by a non-technical person), tell me why in a few lines before writing any code, and wait for my answer. Otherwise go ahead with Rails.

## Public site

| Route | Page |
|---|---|
| `/` | Obra: the artwork grid, nothing else besides the header |
| `/obra/:slug` | One artwork: image, title, year, medium, size, optional text, every detail photo, previous and next |
| `/torn-posters` | Grid of photos of the torn posters that inspired the work |
| `/sobre-mi` | About the artist |
| `/contacto` | Email as a `mailto:` link, plus Instagram |

- Spanish, `<html lang="es">`. Page titles follow `Obra — atesoraroseta`.
- Match DESIGN.md and the canvas at 1440 and 390 px. That means:
  - a plain graphite ground;
  - Bodoni Moda and Jost type;
  - the lower-case wordmark;
  - the grid of 4:5 cells, each work at its own proportions;
  - the smoked-glass hover label, in pure CSS;
  - the artwork page with masonry details and previous/next links;
  - the square Torn Posters grid;
  - the Sobre mí and Contacto pages.
- Every word and image shown comes from the database (see Back office). Views hold no hard-coded copy; defaults live in the seeded settings.
- Images:
  - Serve Active Storage variants as WebP with `srcset` and `sizes` (about 600, 1200 and 2400 px wide).
  - Set width and height from the blob metadata so nothing shifts as images load.
  - Preprocess variants on upload, through Solid Queue, so no visitor waits.
  - Lazy-load everything below the first row.
  - Keep transparency for cut-out PNG/WebP uploads, so the drop-shadow follows the torn edge.
  - Compute each tile's frame width and aspect ratio from the image's dimensions, as DESIGN.md describes. A `cutout` flag isn't needed, because the drop-shadow works for both cut-outs and plain photos.
- Hide whatever is empty:
  - no details section, and no "Ver los N detalles" link, when an artwork has no detail photos;
  - no "·" separator when the year is blank;
  - no Instagram row without a handle.
  - Unpublished records return 404, but a logged-in admin can still preview them.
- Self-host the two fonts as WOFF2 files (both are open-source) instead of linking Google Fonts, so visitors' IP addresses aren't sent to Google.
- Basic SEO:
  - a title and meta description on every page;
  - an Open Graph image (the artwork itself on artwork pages, the first artwork elsewhere);
  - `sitemap.xml`;
  - a 404 page in the site's style.

## Back office at /admin

Don't design it. Use a conventional, well-maintained approach that works with your Rails version. That can be an admin gem with Active Storage support (for example Administrate, Madmin, or Avo's free edition) or plain Rails views with a small, neutral stylesheet. Clear, functional and safe matters more than looks. Write the admin labels in Spanish.

The admin must be able to change **every text and every image the public site shows**:
- **Obras (artworks):**
  - Fields: title, slug (generated from the title, editable), year, medium (técnica), dimensions (medidas), optional description (rich text), published toggle and position.
  - A main image (required) with alt text.
  - Any number of detail photos, each with alt text and its own order, uploaded several at once.
  - Reorder artworks, and the details within an artwork, by drag-and-drop or with up/down buttons.
- **Torn Posters photos:** upload many at once. Each has place, city, year, alt text, position and a published toggle, and they can be reordered.
- **Sobre mí:** lead sentence, body (rich text), and a portrait image with alt text.
- **Contacto:** headline ("Escríbeme"), email and Instagram handle.
- **Site texts:**
  - the wordmark ("atesoraroseta") and the four menu labels;
  - the Torn Posters intro line;
  - the small labels: "Detalles", "Anterior", "Siguiente", "Ver los %{count} detalles", "Año", "Técnica", "Medidas";
  - the SEO description and default Open Graph image.
  - Keep these in one settings record, seeded with the defaults from the design.
- Uploads:
  - Accept JPEG, PNG and WebP (AVIF too if your libvips build supports it), up to about 25 MB.
  - Warn when an image is under 1600 px on its long side.
  - Show a thumbnail next to every image field, and a "Ver en la web" link on every record.

Security:
- `/admin` and every admin route require login, and there is no public sign-up.
- Create the first admin from environment variables, in `db/seeds.rb` or with a rake task, and document how.
- Rate-limit the login form, use strong parameters, and set a sensible Content Security Policy.
- Password reset by email is optional. If you keep it, document the SMTP settings.

## Seeds

- **Development:**
  - the sample artwork `obra-01` with its 8 detail photos;
  - the eight stand-ins as extra artworks, clearly titled "Obra de muestra 02" to "Obra de muestra 09";
  - twelve placeholder Torn Posters (flat tinted images generated in the seed).
  - The aim is that the site looks like the canvas as soon as it starts.
- **Production:** only the admin user and the default site texts. No sample artworks.
- Default texts come from the design. The Sobre mí lead is draft copy: "Trabajo con fragmentos arrancados de carteles publicitarios: los recojo, los guardo y los vuelvo a componer." The bracketed placeholders in the design ([Título de la obra], [Año], [tu-correo@dominio.com] and so on) are not real content. Never seed them into production.

## Deployment (DigitalOcean)

Set up Kamal for one droplet (Ubuntu with Docker):
- kamal-proxy with automatic Let's Encrypt SSL;
- a persistent volume for the SQLite databases and Active Storage files;
- a container registry (DigitalOcean Container Registry, Docker Hub or GitHub);
- off-server backups, for example Litestream for the databases plus a nightly sync of the uploads to DigitalOcean Spaces. Storing uploads on Spaces from the start is also fine. Choose one setup and explain why.

Write `DEPLOY.md` with exact steps for each of these:
- creating the droplet and pointing the domain;
- setting the secrets (RAILS_MASTER_KEY, the registry token, the admin credentials);
- `kamal setup` and `kamal deploy`;
- creating the admin user;
- restoring from a backup.

## Quality

- Tests (Minitest):
  - model validations;
  - public pages render both with and without content;
  - the admin requires login;
  - system tests for the main admin flows: creating an artwork with images, uploading details, reordering, editing Sobre mí.
- `bin/rubocop` and `bin/brakeman` run clean.
- Go through DESIGN.md's "Done when" list at 1440, 768, 390 and 320 px widths, using the keyboard only and with reduced motion on.

## How to work

1. Read `design/DESIGN.md` and `design/site.css` first. Then send me a short plan covering the models, the admin approach, the image pipeline and the deployment and backup setup, plus any stack objection. Wait for my OK.
2. Build in small steps, with a git commit after each: the public site against the seeds first, then the admin, then deployment.
3. Don't change the design. If part of the spec is ambiguous or doesn't work in practice, tell me and propose a fix instead of quietly changing it.
4. When you finish, tell me how to run the site locally, how to log into `/admin`, and what content is still missing.
