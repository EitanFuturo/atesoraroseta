# WP2 handoff: domain models, image pipeline core and seeds

Status: **done**. Commits `3d61d53` to the commit that adds this note, all on `main`.
The quality gate is green: `bin/ci` passes (163 runs, 961 assertions, 0 failures; RuboCop, Brakeman, bundler-audit and importmap audit clean), and so do `bin/rails zeitwerk:check` and `CI=1 bin/rails test` (eager loading).
`bin/rails db:seed:replant` gives `[9, 8, 12, 1]` artworks, details, posters and site rows, every seeded image has width and height, and all 99 preprocessed variants exist.

This note is the contract for WP3, WP4 and WP5. Section 11 lists what is left for each of them.

## 1. Schema

All tables have `created_at` / `updated_at`.

**`artworks`**

| Column | Type | Notes |
|---|---|---|
| `title` | string, not null | |
| `slug` | string, not null | unique index; `\A[a-z0-9]+(?:-[a-z0-9]+)*\z` |
| `year`, `year_end` | integer, nullable | see "Year ranges" |
| `medium`, `dimensions` | string | free text ("120 × 90 cm") |
| `published` | boolean, not null, default false | |
| `position` | integer, not null | acts_as_list, new at the **top**; index |
| `image_alt` | string | |

Plus `has_one_attached :image` (required) and `has_rich_text :description`.

**`artwork_details`**: `artwork_id` (not null, FK to artworks, composite index `[artwork_id, position]`), `position` (integer, not null; acts_as_list `scope: :artwork`, new at the **end**), `alt` (string), `has_one_attached :image` (required).

**`torn_posters`**: `place`, `city` (strings), `year`, `year_end` (integers), `alt` (string), `published` (boolean, not null, default false), `position` (integer, not null, index; acts_as_list, new at the **top**), `has_one_attached :image` (required).

**`sites`**: the single settings row, with one column per text of overview §4.3 (section 5 below), plus `has_rich_text :about_body` and the attachments `portrait`, `og_image` and `favicon`.

The generator's `users` and `sessions` are unchanged.

## 2. Models: what views and the admin use

### `Artwork`

- **Scopes:**
  - `Artwork.published`;
  - `Artwork.ordered`: position, then `COALESCE(year_end, year)` descending, then id. It is built from Arel nodes, so `.last` and `.reverse_order` work;
  - `Artwork.missing_alt`: blank `image_alt`;
  - the generated `Artwork.with_attached_image`. Use it to avoid N+1 queries; it also preloads variant records.
- **`to_param` is the stored slug.**
  - `artwork_path(artwork)` gives `/obra/<slug>`. An edited, unsaved slug doesn't change it, so a re-rendered form still posts to a working URL.
  - Consequence for WP4: an admin route built from an artwork also carries the slug (`admin_artwork_path(artwork)` gives `/admin/artworks/<slug>`). So either look records up with `Artwork.find_by!(slug: params[:id])`, or pass `artwork.id` explicitly.
- **Slug:**
  - generated from the title whenever it is blank, on create or after the admin clears it. For example, "Obra de muestra 02" gives `obra-de-muestra-02`, and "Técnica mixta: año 2024!" gives `tecnica-mixta-ano-2024`;
  - `-2`, `-3`… are added on collision;
  - a title with no letters or digits gives `obra`;
  - editing the title never changes an existing slug;
  - input is stripped and downcased; any other invalid input is a Spanish format error.
- **Neighbours:** `previous` / `next` are the published neighbours in `ordered` order, or `nil` at the ends (no wrap-around). For an unpublished work (admin preview), they are the published works around its position.
- **Alt text:** `alt_text` falls back to the title. `alt_missing?` is true when `image_alt` is blank.
- **`meta_line`** gives `"2024 · Técnica"`, `"2024"`, `"Técnica"` or `nil`: the tile's hover meta, with blanks hidden.
- **`meta_description(limit: 155)`** is the description as plain text, truncated at a word with "…". Without a description, it falls back to `"Título, 2023–2024. Técnica."`, leaving out the blank parts.
- **`details`** are ordered by position (`dependent: :destroy`, `inverse_of`).
- **Moves (acts_as_list):** `insert_at(n)`, `move_higher`, `move_lower`, `move_to_top`, `move_to_bottom`.

### `ArtworkDetail`

- `belongs_to :artwork, touch: true`, so changing a detail updates the artwork's `updated_at`.
- `alt_text` falls back to `"#{artwork.title} (n/N)"`, and `number` is n.
- `alt_missing?`; `ArtworkDetail.missing_alt`.

### `TornPoster`

- **Scopes:** `published`, `ordered` (the same order as artworks) and `missing_alt`.
- **`alt_text`** falls back to `"Lugar, Ciudad"`: whichever parts exist, or `""` when both are blank.
- **The hover label:**
  - `place` is the first line;
  - `meta_line` gives `"Ciudad · 2024"`, either part alone, or `nil`;
  - `labelled?` is false when place, city and year are all blank, in which case there is no label at all.
- **`anchor`** gives `"poster-<id>"`. Use it as the tile's `id` on `/torn-posters` and for "Ver en la web" (`torn_posters_path(anchor: poster.anchor)`).

### Year ranges (`YearRange` concern: `Artwork`, `TornPoster`)

- **`years`** is the admin's single "Año" field (a virtual attribute: permit `:years`, not `:year` / `:year_end`).
  - It accepts `2024`, `2023-2024`, `2023–2024`, `2023—2024` and `2023 — 2024`, with any dash or minus and spaces or no-break spaces. The short form `2023-24` means 2024, and `1999-01` means 2001.
  - Blank clears both columns.
  - It reads back what the admin typed until a save, then the normalised label.
- **Errors** are added to `:years` as whole sentences (the full message equals the message):
  - "Escribe un año (2024) o un periodo (2023–2024)";
  - "Los años deben estar entre 1900 y <next year>";
  - "El año final debe ser posterior al inicial";
  - "Falta el año inicial del periodo".
- **`years_label`** gives `"2024"` or `"2023–2024"` (en dash, no spaces), or `nil`. `sort_year` is the last year.
- **`YearRange.parse(text)`** returns `[year, year_end]`, or nil when the text doesn't parse.

### Image helpers (`ImageAttachments` concern, on every image attachment)

- **Per attachment:** `<name>_width`, `<name>_height`, `<name>_aspect_ratio` (Float) and `<name>_low_resolution?` (long side under 1600 px: a warning, not an error; false when the size is unknown).
  - For example: `artwork.image_width`, `site.portrait_low_resolution?`.
- **Validation applies to new uploads only** (an older image never blocks an edit):
  - **types:** JPEG, PNG or WebP, plus AVIF only when `ImageAttachments.avif_supported?`. On this Mac it is `false`; see WP1 §4 for the gate;
  - **size:** at most 25 MB (`ImageAttachments::MAX_BYTES`, exactly 25 MB allowed);
  - **messages** (Spanish full messages): "Imagen tiene un formato no admitido (usa JPEG, PNG o WebP)", "Imagen pesa más de 25 MB" and "Imagen es obligatoria".
- **For file inputs:** `ImageAttachments.accept` gives `"image/jpeg,image/png,image/webp"`, and `ImageAttachments.format_names` gives "JPEG, PNG o WebP".
- **Analysis right after commit:** width and height exist as soon as `save` returns, for direct uploads (signed ids) too, so Active Storage's AnalyzeJob isn't enqueued.
  - If analysis fails (for example an unreadable file), the save still succeeds and the AnalyzeJob retries.
  - Such an image has `image_width == nil`, and WP4 may flag it.

### `Site`

- **Two ways in:**
  - `Site.current` is the stored row, or an **unsaved** `Site.new` with the defaults, so a GET never writes;
  - `Site.first_or_create!` is what the admin edits; it is created with the defaults.
- **Defaults** come from `config/site_defaults.yml` (`Site::DEFAULTS`), applied to new records only.
- **Required texts** (`Site::REQUIRED_TEXTS`): the labels, headings and link texts that would otherwise leave an empty link or heading. These are `wordmark`, the 4 `nav_*_label`s, `details_label`, `previous_label`, `next_label`, `view_details_label`, `view_detail_one_label`, `year_label`, `medium_label`, `dimensions_label`, `about_contact_link_label`, `instagram_label`, `not_found_title` and `not_found_link_label`.
  - Content may be blank: `torn_posters_intro`, `seo_description`, `about_lead`, `about_body`, `portrait_alt`, `contact_headline`, `email`, `instagram_handle` and `not_found_text`.
- **Validation:** only one row may exist ("Los ajustes del sitio ya existen"). The email format is checked when present, and every text is stripped.
- **Instagram:**
  - `instagram_handle` is normalised: `@usuario`, `usuario`, `https://www.instagram.com/usuario/?igsh=…`, `instagram.com/usuario` and `m.instagram.com/usuario/reels/` all give `usuario` (downcased). The format is `[a-z0-9._]{1,30}`;
  - `instagram_url` gives `"https://www.instagram.com/usuario/"`, and `instagram_at_handle` gives `"@usuario"`. Both are nil without a handle.
- **`view_details_text(count)`** gives "Ver los 8 detalles", or the one-detail label for exactly 1. It replaces `%{count}` only, so a label without it is used as written.
- **`portrait_alt_text`** gives `portrait_alt`, or `""` (decorative). `portrait_alt_missing?` is true when a portrait exists without alt text.

## 3. Variants per attachment (`ImageVariants`)

All of them except `thumb` are **preprocessed**: Active Storage enqueues one TransformJob per variant right after upload (Solid Queue in production; the dev server's async adapter in development).

Every variant is:
- converted to **sRGB** (`export_profile: "srgb"`), then stripped of EXIF (including GPS), XMP, IPTC and ICC data (`keep: "none"` plus `strip: true`, for libvips older and newer than 8.15);
- WebP at quality 82 (`thumb` at 80), except where the table says otherwise;
- alpha-preserving, so cut-outs stay transparent;
- **never upscaled**, except the favicons.

| Attachment | Variants | Output size |
|---|---|---|
| `Artwork#image`, `ArtworkDetail#image` | `width_600`, `width_1200`, `width_2400` | width `min(N, W)`, height follows |
| `Artwork#image`, `Site#og_image` | `og` | exactly 1200×630 JPEG (q85): contained, never upscaled, alpha flattened and padded on `#222221` |
| `TornPoster#image` | `square_600`, `square_1200`, `square_2400` | centred square of side `min(N, shorter side)` (the `object-fit: cover` crop) |
| `Site#portrait` | `portrait_600`, `portrait_1200`, `portrait_2400` | centred 4:5 crop N×1.25N, or the largest 4:5 crop of a smaller image |
| `Site#favicon` | `favicon_32`, `favicon_180`, `favicon_512` | exactly N×N PNG (centred crop; scaled **up** if smaller) |
| every attachment | `thumb` (admin, not preprocessed) | fits 320×320 |

**URLs:**
- `url_for(artwork.image.variant(:width_1200))`, `rails_storage_proxy_path(variant)` and `image_tag(variant)` all give stable proxy URLs (`resolve_model_to_route = :rails_storage_proxy`), served with far-future public cache headers and no cookie.
- The variant's URL key decodes to the same digest it was preprocessed under, so the proxy finds the stored file and no visitor triggers a transform. This is tested.
- **Keep transformation values JSON-safe if you add variants: no symbols.** Rails encodes the variation key as JSON, a symbol comes back as a string, and the digest then changes. `test/models/image_variants_test.rb` checks every variant.

**Implementation:**
- `config/initializers/image_processing.rb` adds two operations to image_processing's libvips processor:
  - `resize_to_fill_limit`: a centred fill crop that never upscales;
  - `resize_and_flatten`: contain, flatten only when there is alpha (libvips' own `flatten` treats the last band as alpha even without one), then pad.
- `ImageGeometry` predicts every output size. It matched libvips on 704 checks: 24 fixed and 40 random sizes, every operation.

## 4. `ResponsiveImage`: the image API for views

It builds no URLs or HTML. The family comes from the attachment (`:width` for artworks and details, `:square` for posters, `:portrait` for the site portrait). Pass it explicitly only to override. `Site#og_image` and `#favicon` have no family and raise `ArgumentError`.

```ruby
image = ResponsiveImage.new(artwork.image)   # obra-01: 1179×1571
image.width                 # => 1179  (the original's metadata: use for width/height attributes)
image.height                # => 1571
image.dimensions?           # => true
image.aspect_ratio          # => 0.7505…
image.aspect_ratio_css      # => "1179 / 1571"
image.frame_width_percent   # => 93.81   (min(100, 125 × w / h), 2 decimals; 100.0 when capped)
image.frame_width_css       # => "93.81%" ("100%" when capped)
image.low_resolution?       # => true
image.candidates            # => [#<data name=:width_600,  width=600,  height=799>,
                            #     #<data name=:width_1200, width=1179, height=1571>]
image.variant(image.candidates.last)  # => artwork.image.variant(:width_1200)
```

- **Candidates** are the family's variants at their real pixel size, smallest first.
  - They are deduplicated, never upscaled, and include the original's width (or its largest crop) when it is smaller than the largest variant.
  - For example: a 300×560 work gives only `[:width_600, 300, 560]`, and a 2000×1500 poster gives squares of 600, 1200 and 1500.
- **Without width/height metadata**, `candidates` is `[]` and the size methods return `nil`.
- A srcset sketch for WP3. The `sizes` value is WP3's layout math.
  ```erb
  <% image = ResponsiveImage.new(artwork.image) %>
  <%= image_tag image.variant(image.candidates.first),
        srcset: image.candidates.map { |c| [ url_for(image.variant(c)), "#{c.width}w" ] },
        sizes: "…", width: image.width, height: image.height, alt: artwork.alt_text %>
  ```
- Tested with the canvas sample sizes (1179×1571 → 93.81, 300×560 → 66.96, 620×480 → 100, 460×600 → 95.83, and so on) and against really processed variants.

## 5. Site texts and defaults

`config/site_defaults.yml` is the single source: the seeds store it, and `Site.current` falls back to it. It contains no bracketed text (tested).

| Column | Default |
|---|---|
| `wordmark` | atesoraroseta |
| `nav_work_label`, `nav_torn_posters_label`, `nav_about_label`, `nav_contact_label` | Obra, Torn Posters, Sobre mí, Contacto |
| `torn_posters_intro` | Fotografías de carteles arrancados que inspiran la obra. |
| `details_label`, `previous_label`, `next_label` | Detalles, Anterior, Siguiente |
| `view_details_label`, `view_detail_one_label` | Ver los %{count} detalles, Ver el detalle |
| `year_label`, `medium_label`, `dimensions_label` | Año, Técnica, Medidas |
| `about_lead` and `seo_description` (same draft text) | Trabajo con fragmentos arrancados de carteles publicitarios: los recojo, los guardo y los vuelvo a componer. |
| `about_contact_link_label`, `contact_headline` | Escríbeme, Escríbeme |
| `instagram_label` | Instagram |
| `not_found_title`, `not_found_text`, `not_found_link_label` | Página no encontrada / La página que buscas no existe o ha cambiado de dirección. / Volver a la obra |
| `email`, `instagram_handle`, `portrait_alt`, `about_body`, `portrait`, `og_image`, `favicon` | blank / none |

**Labels:**
- Every Spanish model and attribute name is in `config/locales/es.yml`: §4.3's admin labels for `Site`; for artworks Título, Dirección (URL), Año, Técnica, Medidas, Descripción, Publicada, Posición, Imagen and Texto alternativo; for posters Lugar and Ciudad.
- WP4's forms can use `Model.human_attribute_name`.

## 6. Routes (`config/routes.rb`)

| Path | Target | Helper |
|---|---|---|
| `GET /` | `artworks#index` | `root_path` |
| `GET /obra/:slug` | `artworks#show` | `artwork_path(artwork)` (or a slug string) |
| `GET /torn-posters` | `torn_posters#index` | `torn_posters_path` (`anchor: poster.anchor`) |
| `GET /sobre-mi` | `pages#about` | `about_path` |
| `GET /contacto` | `pages#contact` | `contact_path` |
| `GET /sitemap.xml` | `sitemaps#show`, format xml | `sitemap_path` |
| `GET /robots.txt` | `robots#show`, format text | `robots_path` |
| `/404`, `/500` (any verb) | `errors#not_found`, `errors#internal_error` | none |
| `GET /up` | `rails/health#show` | `rails_health_check_path` |
| `GET /session/new`, `POST /session`, `DELETE /session` | `sessions#new/create/destroy` | `new_session_path`, `session_path` |
| `GET /admin` | `admin/artworks#index` | `admin_root_path` |

- `resource :session` is limited to `new create destroy`, and there are no password or sign-up routes.
- **`config.exceptions_app = routes` is not set yet.** Setting it before `ErrorsController` exists would break error pages, so WP3 adds it in `config/application.rb` together with the controller.
- `test/routing/routes_test.rb` pins paths and helpers. Paths are checked by generation; recognising a path needs its controller, so WP3 and WP4 can add `assert_recognizes` later.

## 7. Tests: fixtures and helpers

**Fixture files** (`test/fixtures/files/`):
- `obra-01.webp` (1179×1571, alpha);
- `obra-01-d5.jpg` (340×420);
- `small.png` (800×600, ochre left half and blue-grey right half);
- `not-an-image.txt`.

**Records** (all images have analyzed width/height in `test/fixtures/active_storage/*`; no variants are processed):

| Fixture | What it is |
|---|---|
| `artworks(:collage)` | published, position 1, 2024, medium, dimensions, alt, description, 2 details; image obra-01.webp |
| `artworks(:range)` | published, position 2, 2022–2023, **no alt** (falls back to the title); small.png |
| `artworks(:draft)` | **unpublished**, position 3 (sits between range and bare); obra-01-d5.jpg |
| `artworks(:bare)` | published, position 4, only a title and an image; small.png |
| `artwork_details(:collage_first)` / `(:collage_second)` | positions 1 and 2; the second has **no alt** ("Collage de prueba (2/2)") |
| `torn_posters(:street)` | published, 1, Calle de Toledo, Madrid, 2024, **no alt** |
| `torn_posters(:wall)` | published, 2, Lisboa, 2019–2020, alt |
| `torn_posters(:draft)` | **unpublished**, 3 |
| `sites(:main)` | the defaults, plus email `hola@example.com`, Instagram `atesoraroseta`, an about body, and a portrait (340×420) with alt. No og image or favicon |
| `users(:one)`, `users(:two)` | the generator's, with the throwaway password `password` |

- To test without content, delete the rows (for example `Site.delete_all`, or `Artwork.update_all(published: false)`).

**Signing in:**
- `sign_in_as(user)` / `sign_out` work in integration tests (cookie jar) and **system tests**.
- In system tests, the helper creates a real `Session`, visits `/up`, and puts the signed `session_id` cookie into the browser. So it doesn't depend on the login form's labels.
- Verified in headless Chrome against an authenticated route: signed in after `sign_in_as`, sent to `/session/new` after `sign_out`.

**Other helpers:**
- `fixture_attachable("small.png")` returns `{ io:, filename: }` for `attach` or `create!(image: …)`.

**Uploads during tests:**
- Files go to `tmp/storage/run-<pid>/`, deleted when the run ends. Parallel workers share it; concurrent runs don't.

**Minitest 6, for all WPs:**
- There is no `stub` and no `Minitest::Mock`, because `minitest/mock` is gone. Inject dependencies instead: `AdminAccount.sync(credentials:, env:)`, or `ImageAttachments.avif_supported = true/false/nil`.
- `assert_equal nil, x` is an error; use `assert_nil`.

## 8. Admin user, credentials and local login

**`bin/rails admin:sync`** (`AdminAccount.sync`, which the seeds and WP5's entrypoint reuse):
- it reads `admin.email` / `admin.password` from `Rails.application.credentials`. `ADMIN_EMAIL` / `ADMIN_PASSWORD` override them, one key at a time;
- it creates the user, does nothing when the password still matches, or else changes the password and **deletes all that user's sessions**;
- it prints one Spanish line, never the password, for example "Admin: usuario admin@atesoraroseta.com creado.";
- with no email or password (no master key, no `admin` entry), or with unreadable credentials, it prints a warning to stderr and **exits 0**. A too-short password is refused the same way;
- `AdminAccount.sync` returns a `Result(status:, message:)`. The statuses are `:created`, `:updated`, `:unchanged`, `:skipped` and `:invalid`.

**`bin/rails admin:credentials`** (`AdminCredentials`):
- **interactive:** it asks for the email (default: the stored one, or `admin@atesoraroseta.com`) and the password twice with `IO#noecho`, 3 attempts;
- **non-interactive:** it uses `ADMIN_EMAIL` and `ADMIN_PASSWORD` when both are set;
- it requires a password of at least 12 characters and at most 72 bytes (bcrypt's limit), and a valid email;
- it keeps the rest of the file and its comments, replaces an existing top-level `admin:` block in place, and checks that the result parses back to the same keys before writing;
- it refuses to write without the master key or with the wrong one;
- it prints "Guardado. Despliega para aplicarlo en producción."
- **It has not been run against the real `config/credentials.yml.enc`**: the orchestrator does that next (ORCHESTRATION step 3), and the credentials have no `admin` entry until then. Tests use temporary encrypted files and throwaway passwords only.

**Logging in locally** (once the orchestrator has added the credentials):
- run `bin/rails admin:sync` (or `bin/rails db:seed`), then log in at `/session/new` as `admin@atesoraroseta.com`;
- the password is in `bin/rails credentials:show`; never copy it into a file, log, commit or report;
- in a worktree, first copy `config/master.key` from the main checkout, then run `bin/setup --skip-server`;
- without the key everything else works, but no admin is created.

**Changing the admin email** in the credentials creates a second user, and the old one keeps working until it is deleted (`bin/rails runner 'User.find_by(email_address: "old@…").destroy'`). See section 12.

## 9. Seeds

`db/seeds.rb` calls `Seeds.run` (`lib/seeds.rb`):

- **Every environment** (`Seeds::Essential`): `Site.first_or_create!` with the defaults, plus `AdminAccount.sync`. It never creates sample content and never writes a bracketed text. Production and test are identical (tested).
- **Development** (`Seeds::SampleContent`):
  - the 9 works in canvas order (`obra-de-muestra-01, 03, 08, 04, 02, 07, 06, 05, 09`), with the canvas alts and the bracketed medium, dimensions and description;
  - obra-01's 8 details in canvas order;
  - 12 generated 1600×1600 dot-screen posters in the canvas tints (`[Lugar]`, `[Ciudad]`, alt left blank so the fallback and the admin flag show);
  - the two bracketed bio paragraphs, a generated 1600×2000 portrait with alt `[Retrato o foto en el taller]`, `tu-correo@example.com` and `usuario`;
  - one work (obra-03) and one poster (the second) with 2023–2024;
  - everything published.
- **Idempotency:** records are found by slug or image filename, and site fields are filled only while blank. A second run changes nothing, timestamps included (tested).
- **Variants:** development seeding processes every preprocessed variant **inline**, so they exist when it ends. A full replant takes about 11 s.
- **Orphaned files:** `db:seed:replant` truncates the tables but not the uploaded files in `storage/`, so each replant leaves the previous run's files orphaned in development.

## 10. Deviations and decisions

1. **Shared files touched:**
   - `config/application.rb`: one line, `config.active_model.i18n_customize_full_message = true`, so the year errors are whole sentences;
   - a new `config/initializers/image_processing.rb`, with the two operations of section 3;
   - `config/locales/es.yml`: model and attribute names and error messages added, WP1's keys kept.
2. **New uploads are converted to sRGB before their metadata is stripped.** By default libvips keeps the source colour space; stripping a Display P3 or Adobe RGB profile afterwards would shift the colours (checked with a P3 test image). The cost is that wide-gamut colours are clipped to sRGB.
3. **Never-upscaled crops needed a custom operation**, because built-in `resize_to_fill` either upscales or returns a non-square crop. The og image needed one too, because libvips' `flatten` breaks on images without alpha.
4. **The favicons are scaled up to exact sizes**, the only exception to "never upscaled", because `sizes="32x32"`, 180 and 512 must be true. **The og image is contained without upscaling**, so a small source sits small on the ground colour; real works are 2400 px.
5. **A cleared slug is generated again on update too.** The overview only says "on create when blank". Otherwise clearing it would be a validation error.
6. **Additions beyond the overview:**
   - `Site` validates that its label texts are present and that only one row exists;
   - text fields are stripped;
   - the Instagram handle is downcased (Instagram handles are lower case).
7. **Only new uploads are type- and size-checked.** So if AVIF support ever disappears from libvips, records with AVIF images stay editable.
8. **`thumb` is not preprocessed**, as the plan says. The admin generates thumbnails on first view.
9. **Alt text on the generated sample posters is left blank** on purpose: the public fallback "[Lugar], [Ciudad]" applies, and the admin flags them. The overview gives no poster alt.
10. **No gems were added.**

## 11. Open issues and notes for the next WPs

**WP3:**
- Add `ErrorsController` and `config.exceptions_app = routes`.
- Use `ResponsiveImage` for every tile and hero, with `with_attached_image` and `.includes(:details)` against N+1 queries.
- og fallback: `Site.current.og_image.attached? ? site.og_image.variant(:og) : Artwork.published.ordered.first&.image&.variant(:og)` (always 1200×630).
- Favicons: `site.favicon.variant(:favicon_32 / :favicon_180 / :favicon_512)`.
- WP1's open issue 2 (inline `style` in rich text) still applies to `artwork.description` and `site.about_body`.

**WP4:**
- `to_param` is the slug (section 2).
- Permit `:years`, not the columns.
- Image fields:
  - `accept: ImageAttachments.accept`;
  - thumbnails with `variant(:thumb)`;
  - warnings from `image_low_resolution?` (it means little for the favicon);
  - alt flags from `alt_missing?` / `missing_alt` (`Site#portrait_alt_missing?`).
- Reorder with acts_as_list.
- Site form: `Site.first_or_create!`.
- Direct uploads (signed ids) are validated and analysed like any other upload.

**WP5:**
- Call `bin/rails admin:sync` in `bin/docker-entrypoint` after `db:prepare`. On a fresh production database, `db:prepare` also runs the seeds, which only create the settings row and sync the admin.
- Check AVIF inside the image with `bin/rails runner 'p ImageAttachments.avif_supported?'`. It applies WP1's blocked-loader gate.
- Variant files are Active Storage blobs too: the uploads backup copies them unless it filters them out. They can always be regenerated.

## 12. For the user to decide

- **Favicon and og sizing (decision 4):** upscale small favicon uploads (current), or ask for a 512 px source? Keep the og image unscaled (current), or scale small images up?
- **Colour (decision 2):** keep converting to sRGB (current: consistent everywhere), or keep the embedded profile (`keep: "icc"`) so wide-gamut photos keep their full colour on P3 screens, at a few KB per variant?
- **Quality:** WebP at 82 and JPEG at 85 (`ImageVariants::WEBP_QUALITY` / `JPEG_QUALITY`). Raise them if the artist finds the torn-paper texture too soft.
- **Required labels:** the 17 texts in `Site::REQUIRED_TEXTS` can't be blank. Make any of them optional?
- **Changing the admin email** leaves the old user working until it is deleted by hand. Should `admin:sync` remove other users instead?
