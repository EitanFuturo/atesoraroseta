# WP4: Back office at /admin

**Runs in:** your own git worktree and branch, in parallel with WP3 (public site) and WP5 (deploy).
**Depends on:** WP2. Read `docs/handoff/WP1.md` and `docs/handoff/WP2.md`.
**Read first:**
- `docs/plans/00-overview.md` (all; §4.2, 4.3, 4.6, 4.7 and 7.4 matter most);
- `design/PROMPT.md` (Back office, Security and Quality).

## Goal

A clear, safe, Spanish-language CMS where a **non-technical person** edits every public text and image. Don't design it: plain Rails views and a small, neutral stylesheet. No admin gem.

Why no gem: bulk uploads that create records, reordering, a settings singleton, Lexxy, Spanish labels and a strict CSP are simpler to build directly than to bend a gem around. It also leaves no extra dependency to keep upgrading.

## You own

See overview §7.2 for the full list. In short:
- `app/controllers/admin/**`;
- the generated `sessions_controller.rb` and `concerns/authentication.rb`;
- the admin and login views, and the admin layout;
- `app/helpers/admin/**`, `app/assets/stylesheets/admin.css`, `app/javascript/**`, `config/importmap.rb`;
- `config/locales/admin.es.yml`;
- the `namespace :admin` block of `config/routes.rb`;
- `test/controllers/admin/**`, `test/system/**`;
- `docs/handoff/WP4.md`.

You may make **small, additive** model changes the admin needs, such as `accepts_nested_attributes_for` or a bulk-create helper. List each one in your handoff.

**Don't touch** the public controllers, views or CSS, or anything deployment-related. Public pages don't exist in your branch, so don't follow links to them in tests; assert the `href` instead.

## What the admin must do (PROMPT.md, plus overview §4.3)

**Navigation:** Obras · Torn Posters · Sobre mí · Contacto · Textos del sitio · Ver la web ↗ · Cerrar sesión.

**Obras**
- **List:** thumbnail, title, year, a Publicada/Borrador badge, warnings ("imagen pequeña", "falta texto alternativo"), ↑ ↓ reorder, Editar, and "Ver en la web".
- **Form:**
  - title, slug (prefilled from the title; editable, with a hint), técnica, medidas;
  - **Año**: one text field bound to the `years` virtual attribute (overview §4.2 "Year ranges"), with the hint "Un año (2024) o un periodo (2023–2024)";
  - description (Lexxy, **file attachments disabled**);
  - publicada (toggle);
  - main image (required), with its thumbnail, pixel size and low-resolution warning;
  - alt text.
- **Details** live on the artwork's edit page:
  - **upload several at once** (multiple file input with **direct uploads**, so each file is its own request, with a visible per-file progress line);
  - each detail shows its thumbnail, an alt field, ↑ ↓ and Eliminar;
  - all the alts save at once.
- **Delete** asks for confirmation (`turbo_confirm`).

**Torn Posters**
- **Upload many at once** (direct uploads). Records are created **unpublished**, keeping the upload order on screen, so the first file ends up first.
- The index is a **bulk-edit table**: thumbnail, lugar, ciudad, año (the same `years` field, so ranges work), texto alternativo, publicada, ↑ ↓, Eliminar, and one "Guardar cambios" button.
  - HTML forms can't nest, so the ↑ ↓ and Eliminar buttons must sit outside the bulk form. Use the button `form="…"` attribute, pointing at small forms rendered after the table, or a similar approach.
  - Offer "Marcar todas como publicadas".
- **Single edit page:** for replacing a photo.
- **"Ver en la web":** links to `/torn-posters#poster-<id>`. While the poster is unpublished, show it greyed out with "(sin publicar)".

**Sobre mí**
- Fields: lead, body (Lexxy), the portrait with alt (thumbnail, low-resolution warning) and `about_contact_link_label`.
- "Ver en la web" goes to `/sobre-mi`.

**Contacto**
- Fields: headline, email, Instagram handle (hint: "sin @; también puedes pegar el enlace del perfil") and `instagram_label`.
- "Ver en la web" goes to `/contacto`.

**Textos del sitio:** one form in fieldsets.
- *Cabecera y menú:* wordmark and the 4 menu labels.
- *Torn Posters:* intro.
- *Página de cada obra:* the 8 labels, with a hint that `%{count}` is replaced by the number.
- *Buscadores y redes sociales:* SEO description and the default OG image.
- *Icono del sitio:* favicon, square PNG/SVG.
- *Página no encontrada:* the 3 texts.

"Ver en la web" goes to `/`.

**Every image field:**
- `accept` lists only the allowed types (AVIF only when supported);
- the current thumbnail, with "ancho × alto px";
- the low-resolution warning, when the long side is under 1600 px: "Imagen pequeña: N px en el lado largo. Para que se vea nítida en pantallas grandes, sube al menos 1600 px.";
- a client-side check that rejects files over 25 MB before uploading, while the server still validates;
- Spanish validation errors.

**Every record:** a "Ver en la web" link. Unpublished artworks open in preview, since a logged-in admin can see them.

## Steps (commit after each)

1. **Set up the worktree.** Run `bin/setup --skip-server` and start the server on port **3004**.
2. **Auth in Spanish and secure:**
   - Translate and lightly style `sessions/new` in the admin layout.
   - There is no password recovery (WP1 removed it) and no sign-up anywhere.
   - Set the login rate limit to **5 attempts per 10 minutes** per IP, with a Spanish message.
   - After login, go to `admin_root_url`.
   - To log in by hand for your manual pass:
     1. copy `config/master.key` from the main checkout into your worktree;
     2. read the credentials with `bin/rails credentials:show`;
     3. never write the password into any file, commit, screenshot name or report.

     The system tests use fixture users with throwaway passwords.
3. **Admin base:**
   - `Admin::BaseController`, where authentication is required by default, with the `admin` layout.
   - `allow_browser versions: :modern` is fine here.
   - The `admin` layout includes `csrf_meta_tags`, `csp_meta_tag` and `javascript_importmap_tags`, plus `admin.css` and the editor CSS, linked by name.
   - Flash messages, error summaries and `admin.es.yml`.
4. **JS** (importmap):
   - Pin `@rails/activestorage` and start it for direct uploads.
   - A Stimulus controller shows upload progress and does the 25 MB check.
   - Lexxy with attachments disabled. Check that the CSP from WP1 allows everything Lexxy needs; if it doesn't, make the smallest admin-only CSP override and document it.
5. **Build, in order:** Obras CRUD, details, reordering, Torn Posters (bulk upload, bulk edit, reordering), Sobre mí, Contacto, Textos del sitio. Commit after each.
6. **Tests:**
   - **Controller and integration:**
     - **every `/admin` route** (iterate `Rails.application.routes`) redirects to the login when signed out;
     - each create, update, destroy and move works;
     - the bulk actions work;
     - validation errors render in Spanish;
     - unpermitted params are ignored;
     - the rate limit triggers. Swap in a memory cache store for that test.
   - **System** (Selenium headless Chrome), PROMPT's main flows:
     - log in (a wrong password fails, the right one works, and there is no "forgot password" link);
     - typing `2023-24` as the year of an artwork saves 2023–2024;
     - **create an artwork with an image**, alt text and the published toggle;
     - **upload several details** and edit their alts;
     - **reorder** artworks and details;
     - **edit Sobre mí**: the lead, the rich-text body and a portrait upload;
     - bulk-upload Torn Posters and publish them;
     - a wrong file type shows a Spanish error.
7. **Quality gate:** the full suite, including the system tests, RuboCop, Brakeman and the audits, is clean.
8. **Manual pass:** click through every screen at 1280px and at about 800px wide. Take screenshots into `tmp/screenshots/admin/`. Make sure a non-technical person can tell what each field does.
9. **Handoff** (`docs/handoff/WP4.md`):
   - the routes;
   - the screens, with a screenshot per screen;
   - the model changes you made;
   - CSP changes, if any;
   - how to fill a Lexxy editor in system tests;
   - anything left.

   Commit.

## Acceptance

- [ ] Everything in "What the admin must do" works in the browser and is covered by the tests listed in step 6.
- [ ] Signed out, no `/admin` page or action is reachable, and nothing offers sign-up.
- [ ] All copy is in Spanish, from `admin.es.yml` and the `rails-i18n` model translations.
- [ ] Tests, system tests, RuboCop and Brakeman are clean, and every step is committed on your branch.

## Report back (at most 25 lines)

- status;
- branch name and last commit;
- test counts (unit and system);
- model changes;
- CSP changes;
- anything that needs the user's decision.
