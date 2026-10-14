# WP4 handoff: back office at /admin

Status: **done**, on branch `worktree-agent-a65654b078e098a74` (commits `3d3bd14` to the one adding this note, on top of `0c8422b`).
The quality gate is green: `bin/ci` passes every step (setup, RuboCop, bundler-audit, importmap audit, Brakeman, 244 tests, the test seeds, 20 system tests), and so do `bin/rails zeitwerk:check` and `CI=1 bin/rails test`.
WP4's own tests are 85 integration tests (`test/controllers/admin/**`, `test/controllers/sessions_controller_test.rb`) and 20 system tests (`test/system/admin/**`).

No gems were added. No admin gem: plain Rails views, a small neutral stylesheet (`admin.css`), Hotwire, Lexxy and Active Storage direct uploads.

## 1. What was built

- **Login** (`/session/new`), in Spanish, in the admin layout.
  - After logging in you go to `/admin`, or back to the admin page that asked for the login (GET and HEAD pages only).
  - The rate limit is 5 attempts per 10 minutes per IP, with a Spanish message.
  - There is no password recovery and no sign-up anywhere.
  - "Cerrar sesión" logs out.
  - The form is `novalidate`, so the Spanish server messages are shown rather than the browser's.
- **Every admin page** (`Admin::BaseController`):
  - requires login (the `before_action` is declared again there, so no admin page depends on `ApplicationController`);
  - requires a modern browser (`allow_browser versions: :modern`). Older browsers get a Spanish page, `admin/unsupported_browser`, rendered through a `block:`, because WP3 deleted `public/406-unsupported-browser.html`. The login page does the same.
- **Admin layout** (`layouts/admin`):
  - in the head: `csrf_meta_tags`, `csp_meta_tag`, `javascript_importmap_tags`, and the stylesheets `lexxy` and `admin` linked by name;
  - `turbo-cache-control: no-cache`, `robots: noindex`;
  - the menu: Obras · Torn Posters · Sobre mí · Contacto · Textos del sitio · Ver la web ↗ (new tab) · Cerrar sesión;
  - flash messages, a skip link, and the title "<page> — Panel de <wordmark>".
- **Obras**:
  - **The list:** thumbnail, title, years, number of details, Publicada/Borrador badge, warnings ("Imagen pequeña", "Falta el texto alternativo", "N detalles sin texto alternativo"), ↑ ↓, Editar, and "Ver en la web" (unpublished works: "Ver en la web (vista previa)").
  - **The form:**
    - title, and the slug, filled from the title as you type on new works, with a hint;
    - Año (the `years` field), técnica and medidas;
    - the description: Lexxy with a Spanish toolbar (bold, italic, link, undo, redo), no attachments, no Markdown shortcuts, no colour highlights;
    - the published switch;
    - the main image (thumbnail, "ancho × alto px", low-resolution warning, direct upload with progress) and its alt text, flagged when missing.
  - **Delete** asks first.
- **Details**, on the work's page:
  - "Añadir detalles" takes several files at once; each is a direct upload (its own request) with its own progress line. They become details at the end, in the order chosen.
  - Each detail has its thumbnail, size, warnings, an alt field (flagged when missing, showing the fallback), ↑ ↓ and Eliminar (with confirmation).
  - The alt fields belong to the work's form, so one "Guardar cambios" saves every alt at once (§5, decision 3).
- **Torn Posters:**
  - **"Subir fotos"** takes many files at once (direct uploads). Each becomes an unpublished poster at the top, the first file first.
  - **The index is one bulk-edit form:** thumbnail, lugar, ciudad, año (`years`, so ranges work), texto alternativo, publicada, ↑ ↓, Eliminar, and "Guardar cambios" (above and below the table).
    - "Marcar todas como publicadas" is a second submit button of the same form: it saves the table and publishes every photo.
    - ↑ ↓ and Eliminar sit in the table but belong to small forms rendered after it (`form="…"`), since forms can't nest.
    - Nothing is saved unless every row is valid; errors point at their row ("Foto 2: …").
  - **"Ver en la web"** goes to `/torn-posters#poster-<id>`. While a poster is unpublished it is greyed out, "(sin publicar)", and not a link.
  - **Each photo has its own page** to replace the image, with its other fields too.
- **Sobre mí:** lead, body (Lexxy), the link to Contacto, and the portrait with its alt (flagged when missing). The portrait can be removed. "Ver en la web" goes to `/sobre-mi`.
- **Contacto:**
  - headline and email;
  - the Instagram handle, with the hint "Sin @; también puedes pegar el enlace del perfil…" and the current link shown;
  - the "Instagram" label.

  "Ver en la web" goes to `/contacto`.
- **Textos del sitio:** one form in the plan's six fieldsets. The `%{count}` hint is on "Enlace a detalles (varios)", and required texts are marked "(obligatorio)". "Ver en la web" goes to `/`.
- **Every image field:**
  - `accept` is `ImageAttachments.accept` (AVIF only when supported);
  - the current thumbnail with "ancho × alto px";
  - the low-resolution warning;
  - a client-side check that drops files over 25 MB, or of a type the server won't take, before uploading (each with a Spanish message);
  - per-file progress, and Spanish server errors;
  - a Spanish "Elegir archivo" / "Elegir fotos" button: the browser's own control lies transparent on top, so its English text never shows.
- **Unsaved changes:** on every form page, sending another form (↑ ↓, Eliminar, an upload, "Cerrar sesión") or following a link asks before discarding typed changes. A page that came back with errors counts as unsaved.
- **Reordering:**
  - The Obras and Torn Posters lists refresh in place (Turbo morph, scroll kept).
  - The arrow you pressed gets the focus back, so a keyboard user can keep pressing it.
  - Details move on the work's page, which scrolls back to the moved detail.

## 2. Routes

All under `namespace :admin` (WP4's block of `config/routes.rb`); every one requires login. Artworks are found by **slug** (`Artwork#to_param`).

| Verb | Path | Action | Helper |
|---|---|---|---|
| GET | `/admin` | `admin/artworks#index` | `admin_root_path` |
| GET | `/admin/artworks` | `index` | `admin_artworks_path` |
| GET | `/admin/artworks/new` | `new` | `new_admin_artwork_path` |
| POST | `/admin/artworks` | `create` | |
| GET | `/admin/artworks/:slug` | `show` (redirects to edit) | `admin_artwork_path(artwork)` |
| GET | `/admin/artworks/:slug/edit` | `edit` (the work's page, with its details) | `edit_admin_artwork_path(artwork)` |
| PATCH/PUT | `/admin/artworks/:slug` | `update` (the alt texts of its details too) | |
| DELETE | `/admin/artworks/:slug` | `destroy` | |
| PATCH | `/admin/artworks/:slug/move` (`direction=up\|down`) | `move` | `move_admin_artwork_path(artwork)` |
| POST | `/admin/artworks/:slug/details` (`images[]`) | `admin/artwork_details#create` | `admin_artwork_details_path(artwork)` |
| DELETE | `/admin/artworks/:slug/details/:id` | `destroy` | `admin_artwork_detail_path(artwork, detail)` |
| PATCH | `/admin/artworks/:slug/details/:id/move` | `move` | `move_admin_artwork_detail_path(artwork, detail)` |
| GET | `/admin/torn-posters` | `admin/torn_posters#index` (the bulk table) | `admin_torn_posters_path` |
| POST | `/admin/torn-posters` (`images[]`) | `create` (bulk upload) | |
| PATCH | `/admin/torn-posters/bulk_update` (`torn_posters[<id>][…]`, `publish_all`) | `bulk_update` | `bulk_update_admin_torn_posters_path` |
| GET | `/admin/torn-posters/:id` | `show` (redirects to edit) | `admin_torn_poster_path(poster)` |
| GET | `/admin/torn-posters/:id/edit` | `edit` (replace the photo) | `edit_admin_torn_poster_path(poster)` |
| PATCH/PUT, DELETE | `/admin/torn-posters/:id` | `update`, `destroy` | |
| PATCH | `/admin/torn-posters/:id/move` | `move` | `move_admin_torn_poster_path(poster)` |
| GET, PATCH/PUT | `/admin/about`, `/admin/about/edit` | `admin/about#show` (redirects to edit), `edit`, `update` | `edit_admin_about_path` |
| GET, PATCH/PUT | `/admin/contact`, `/admin/contact/edit` | `admin/contact#…` | `edit_admin_contact_path` |
| GET, PATCH/PUT | `/admin/site-texts`, `/admin/site-texts/edit` | `admin/site_texts#…` | `edit_admin_site_texts_path` |

Outside the block:
- **Login and logout:** `resource :session` (WP1) is unchanged.
- **Direct uploads:** `POST /rails/active_storage/direct_uploads` (Rails' own route) now **requires login** (§4).
- **For WP3:** the admin-only preview notice on an unpublished artwork page can link to `edit_admin_artwork_path(artwork)`.

## 3. Screens

`bin/rails runner script/admin_screenshots.rb` (with a dev server on port 3004, or `PORT=…`) logs in as a throwaway user with a random password, never printed, and deletes it at the end.
It writes every screen at 1280 and 800 px to `tmp/screenshots/admin/`. That folder is ignored; mine are in this worktree, `/Users/eitanfuturo/develop/projects/atesoraroseta/.claude/worktrees/agent-a65654b078e098a74/tmp/screenshots/admin/`, until the worktree is removed.
Before running `bin/setup` or `bin/ci`, delete that folder (§7, issue 5).

| Screen | Screenshots (`-1280.png`, `-800.png`) |
|---|---|
| Login, and a wrong password | `01-login`, `02-login-error` |
| Obras list (cards below 900 px) | `03-obras` |
| Nueva obra, and with Spanish errors | `04-obra-nueva`, `05-obra-nueva-errores` |
| A work's page: form, main image, the 8 details of obra-01, delete | `06-obra-editar` |
| Torn Posters: upload, bulk table (cards below 1100 px) | `07-torn-posters` |
| A photo's page | `08-torn-poster-editar` |
| Sobre mí | `09-sobre-mi` |
| Contacto | `10-contacto` |
| Textos del sitio | `11-textos-del-sitio` |

**The manual pass at 1280 and 800 px found these problems; all are fixed:**
- Link-buttons such as "Nueva obra" were dark blue on black.
- The labels of invalid fields lost their bold.
- A blank title made the re-rendered form show the fallback slug "obra", which then stopped following the title.
- The browser's English "Choose File" showed.
- The hints repeated their labels on the photo page.
- The replace hint was feminine for "retrato" and "icono".

## 4. Model, CSP and shared-file changes

- **Model (the only change):** `Artwork` has `accepts_nested_attributes_for :details, reject_if: ->(attributes) { attributes[:id].blank? }`.
  - It exists so the work's form saves its details' alt texts.
  - It covers existing details only: new ones come from uploads.
  - The controller permits only `details_attributes: [[ :id, :alt ]]`, and another work's detail id is a 404 (tested).
- **CSP: no changes.** WP1's policy covers the admin. System tests record the browser console and assert there are no errors, CSP violations included, on:
  - the list;
  - new and edit work (Lexxy, its toolbar, direct uploads);
  - details uploads;
  - Torn Posters;
  - Sobre mí, including a link added through the toolbar.
- **New initializer `config/initializers/direct_uploads.rb` (shared area), a security fix:**
  - **The problem:** Rails' direct-upload endpoint was open to anyone. A visitor could create blobs and fill the disk, or get a signed id to serve files from the site.
  - **The fix:** a `to_prepare` hook includes `Authentication` into `ActiveStorage::DirectUploadsController` and answers **401** to a logged-out request.
  - It keeps Rails' own route (used by `direct_upload: true` and Lexxy), so no route clashes with WP3 or WP5.
  - **Tests:** `test/controllers/admin/direct_uploads_test.rb` checks that a logged-out POST is refused with no blob created, and that a logged-in upload returns a signed id. The system tests upload through it while logged in.
  - **Checked by hand:** against a freshly started dev server, a logged-out visitor *with a valid CSRF token* (taken from the login page) gets 401.
  - **Restart the server after pulling this:** initializers load at boot, and a server started before it existed still let the upload through.
  - WP5 reported the same issue: this is the fix.
- **`test/application_system_test_case.rb`:**
  - Chrome now keeps its console log (`logging_prefs`).
  - New helpers `browser_errors` / `assert_no_browser_errors` fail on JavaScript errors and CSP violations. They ignore failed requests (a 422 form) and Chrome's "blocked beforeunload" note.
  - The log is emptied at the start of each test.
- **`test/controllers/sessions_controller_test.rb`** (in `test/controllers/`, but it tests WP4's controller): updated for the post-login target, plus logout, the browser check and the rate limit.
  - The rate limit test swaps in a memory store: the test cache is a null store, and the limiter captured its store when the class loaded.
- **`script/admin_screenshots.rb`:** new (§3).
- **Locales:** everything is in `config/locales/admin.es.yml`.
  - WP1's `sessions.create.invalid` / `rate_limited` stay in `es.yml`, untouched.
  - Labels come from the `activerecord` names in `es.yml` (WP2).
- **JavaScript** (`app/javascript/`):
  - `application.js` starts Active Storage, configures Lexxy, and restores autofocus after Turbo morphs.
  - Three Stimulus controllers: `upload` (size and type check, per-file progress), `slug` (fills the slug from the title on new works) and `unsaved-changes`.
  - The generator's `hello_controller.js` is deleted.
  - `config/importmap.rb` is unchanged: WP1 already pinned `lexxy` and `@rails/activestorage`.

## 5. Decisions and deviations

1. **The Lexxy toolbar is the admin's own Spanish one**, with what the public pages style: bold, italic, link, undo, redo.
   - Attachments, Markdown shortcuts and colour highlights are off (`application.js`), as split with WP3: highlights write inline `style`.
   - The toolbar is rendered *before* the editor and referenced with `toolbar="<id>"`. Inside the editor it broke on Turbo renders: the editor started before its toolbar, Lexxy threw, and the description was silently not submitted.
   - Lexxy saves `<p>`, `<strong>` (bold), `<i>` (italic) and `<a href>` with no `style`, e.g. `<p><a href="…"><i><strong>Texto</strong></i></a></p>` (useful for WP3's rich-text CSS).
2. **The new-work slug is filled from the title as you type** (JS mirroring Rails' `parameterize`) until edited by hand.
   - A slug that equals the title's automatic one is treated as automatic on create, so the model adds `-2` when it is taken.
   - A slug typed by hand that is taken gets the Spanish "ya está en uso" error.
3. **Detail alt texts are saved by the work's "Guardar cambios"**: the page has a second copy of that button below the details. Uploading, moving and deleting details are immediate.
4. **"Marcar todas como publicadas" saves the table too.** It is a submit button of the bulk form, so typed changes aren't lost.
5. **Uploads of several files are partial.** The valid files are added, and each refused one is listed ("«x.txt»: Imagen tiene un formato no admitido (usa JPEG, PNG o WebP)").
   - Refused direct uploads are deleted (`purge_later`, only if unattached).
   - A valid image chosen in a form that came back with other errors is kept (hidden signed id) for the next try.
6. **Image warnings:**
   - The 1600 px rule applies to the works, details, posters and portrait.
   - The default social image (og) is checked against 1200 × 630 instead, and the favicon against 512 px and squareness. The 1600 px warning would contradict their own hints.
   - An image whose size couldn't be read gets "No se ha podido leer el tamaño…".
7. **The favicon accepts JPEG, PNG or WebP, not SVG.** The plan says "square PNG/SVG", but WP2's image rules don't accept SVG, and this libvips has no SVG loader. The hint asks for a square PNG.
8. **Admin URLs are in English** (`/admin/artworks`, `/admin/torn-posters`, `/admin/about`, `/admin/contact`, `/admin/site-texts`); public ones stay in Spanish.
9. **`show` redirects to edit** for works, posters and the three settings pages, so a reload after a failed save never 404s.
10. Optional images (portrait, social image, favicon) have "Quitar esta imagen al guardar". A new file chosen at the same time wins.

## 6. How to verify

```sh
bin/ci                                   # all green (delete tmp/screenshots/admin first, see §7)
bin/rails test test/controllers/admin test/controllers/sessions_controller_test.rb
bin/rails test:system                    # 20 admin flows in headless Chrome
bin/rails runner script/admin_screenshots.rb   # with bin/rails server -p 3004 running
```

To log in by hand:
1. copy `config/master.key` into the checkout;
2. run `bin/setup --skip-server`, whose seeds create the admin from the credentials;
3. log in at `/session/new` as `admin@atesoraroseta.com`, with the password from `bin/rails credentials:show` (never copy it anywhere).

For throwaway checks, create a user with a random password in the console instead, as the screenshot script does.

**Filling a Lexxy editor in system tests.** `<lexxy-editor id="site_about_body">` holds a contenteditable `#site_about_body-content` (role textbox, named by the field's label), and Lexxy defines its elements after a timeout:

```ruby
assert_selector "#site_about_body-content[contenteditable=true]"  # the editor has started
find("#site_about_body-content").click
find("#site_about_body-content").send_keys("Un párrafo.")
# The toolbar: click_on "Negrita" / "Cursiva" / "Enlace"; then fill_in "site_about_body-link-url", with: "https://…"; click_on "Enlazar"
page.evaluate_script("document.getElementById('site_about_body').value")  # => "<p>Un párrafo.</p>"
```

`AdminSystemTestCase` (`test/system/admin_system_test_case.rb`) has `fill_in_rich_text(editor_id, with:)` and `assert_rich_text_editor(editor_id)`.

**Other system-test notes:**
- File inputs are transparent over the Spanish button, so use `attach_file "Imagen", path, make_visible: true`.
- Admin system tests sign in with `sign_in_as users(:one)` (WP2's cookie helper). `Admin::LoginTest` uses the real form with the fixture's throwaway password.

## 7. Open issues

1. **Pasted rich text can still carry `style="text-align: …"`** (Lexical keeps a pasted paragraph's alignment). The editor itself writes no styles. As agreed, WP3 strips `style` from public rich text.
2. **Lexxy adds a `lexxy-code-language` field to every form with an editor** (its code-language picker). It is never permitted, so it is harmless, but it shows in the logs.
3. **A title with an underscore**, without JavaScript, gets a slug-format error until the slug is edited. WP2's `generate_slug` uses `parameterize`, which keeps `_`, and the format rejects it. The admin's JavaScript fills a valid slug (it turns `_` into `-`).
   - Proposed fix in the model: `title.to_s.parameterize.tr("_", "-")`.
4. **An upload that fails because the session expired** (401 from direct uploads) shows the generic "Comprueba la conexión y vuelve a intentarlo." Sessions are permanent cookies, so this is rare.
5. **`bin/setup`, and so `bin/ci`, fails while `tmp/screenshots/` contains a folder.** Rails' `tmp:screenshots:clear` uses `rm`, not `rm -r`, and the plan puts the admin screenshots in `tmp/screenshots/admin/`. Delete that folder first; the main checkout is unaffected unless someone saves screenshots into a subfolder there.
6. **A direct upload whose form is never sent leaves an unattached blob**, for example on a network failure mid-submit. Refused uploads are deleted, but nothing sweeps the others.
   - A recurring job could purge old unattached blobs (WP5's `config/recurring.yml`), keeping the "backups never delete" rule in mind.
7. **Commit `c4e3bd9` (details) was not green on its own.** Two older system tests clicked a now-ambiguous "Guardar cambios". The next commit, `f9e4bcb`, scopes them. Every other commit was run through the gate.
8. **WP3's notes are taken into account:**
   - The login page uses the admin layout, not the public one.
   - `allow_browser` has its own `block:`.
   - No admin helper is named `site`, `page_meta`, `page_title`, `current_section` or `responsive_image_tag`: they are all `admin_*`.

## 8. For the user to decide

- **The browser requirement.** `allow_browser versions: :modern`, as the plan allows, means Safari 17.2+ (iOS/iPadOS 17.2+), Chrome 120+ or Firefox 121+ for the panel and the login. An older iPad gets a Spanish "update your browser" page. Lexxy and import maps would also run on Safari 16.4+, so the requirement could be relaxed to `{ safari: 16.4, chrome: 120, firefox: 121, opera: 106, ie: false }`.
- **Formatting in the rich text.** It is limited to bold, italic and links. Lists or headings could be added to the toolbar, but the public CSS doesn't style them yet (WP3).
- **The favicon as SVG** (§5, decision 7). It would need SVG support in the image rules and in libvips.
- **After a wrong password the email field is empty again** (the generator's redirect). Keep it, or refill the email?
