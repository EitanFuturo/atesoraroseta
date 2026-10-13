# WP1 handoff: toolchain and app skeleton

Status: **done**. A fresh Rails 8.1.4 app on Ruby 4.0.7 in the repo root. Every gem from overview §4.1 is in the Gemfile, Active Storage, Action Text (with **Lexxy**) and the authentication generator are installed and migrated, and the whole quality gate is green. There are no domain models yet; the only models are the generator's `User`, `Session` and `Current`.

## 1. Versions

| Tool | Version |
|---|---|
| `ruby -v` | ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [arm64-darwin23] |
| `bin/rails -v` | Rails 8.1.4 |
| `vips --version` | vips-8.18.7 (**local source build, not Homebrew**: see §6) |
| Bundler | 4.0.20 |
| SQLite (bundled by the `sqlite3` gem 2.9.6) | 3.53.2 |
| Google Chrome (system tests) | 155.0.8059.40 |

| Gem | Version | Gem | Version |
|---|---|---|---|
| image_processing | **2.2.0** | ruby-vips | 2.3.0 (ffi 1.17.4) |
| lexxy | **1.0.1** | acts_as_list | 1.2.6 |
| rails-i18n | 8.1.0 | aws-sdk-s3 | 1.233.2 (`require: false`) |
| propshaft | 1.3.2 | importmap-rails | 2.2.3 |
| turbo-rails | 2.0.23 | stimulus-rails | 1.3.4 |
| solid_queue / solid_cache / solid_cable | 1.7.0 / 1.0.10 / 4.1.0 | kamal | 2.12.0 |
| thruster | 0.1.27 | puma | 8.0.2 |
| bcrypt | 3.1.22 | minitest | 6.0.6 |
| capybara / selenium-webdriver | 3.40.0 / 4.51.0 | brakeman | 8.1.0 |
| rubocop / rubocop-rails-omakase | 1.92.0 / 1.1.0 | bundler-audit | 0.9.3 |

`.ruby-version` is `4.0.7`. rbenv's global Ruby is still 3.3.0, so always run from the project root.

## 2. What was built (and the APIs other WPs use)

### 2.1 Generator and installers

- **`rails new`** (`--database=sqlite3 --skip-jbuilder --skip-action-mailbox`, every other default):
  - Propshaft, importmap, Turbo and Stimulus, and the Solid trio (`config/{queue,cache,cable,recurring}.yml`, `db/*_schema.rb`);
  - Kamal (`config/deploy.yml`, `.kamal/secrets`, `.kamal/hooks`), Thruster, the `Dockerfile` (Ruby 4.0.7 slim, apt `libvips`, jemalloc) and `bin/docker-entrypoint`;
  - RuboCop omakase, Brakeman, bundler-audit (`config/bundler-audit.yml`), the GitHub CI workflow, and `bin/ci` with `config/ci.rb` (the local CI).
- **`active_storage:install`:** the Active Storage tables migration.
- **`action_text:install`:**
  - the Action Text tables migration;
  - `app/views/active_storage/blobs/_blob.html.erb` (as generated);
  - `app/views/layouts/action_text/contents/_content.html.erb`, now `<div class="lexxy-content">`;
  - `test/fixtures/action_text/rich_texts.yml` (an empty template).

  Its Trix pins, imports and `actiontext.css` were then replaced by Lexxy (§2.2).
- **`generate authentication`:**
  - models `User` (`has_secure_password`, `has_many :sessions`, email normalisation), `Session` and `Current`;
  - `SessionsController`, `concerns/authentication.rb`, `app/views/sessions/new.html.erb` (still English; WP4 owns it) and `app/channels/application_cable/connection.rb`;
  - the users and sessions migrations, and `bcrypt`;
  - tests: `test/fixtures/users.yml` (`one`, `two`, throwaway password `password`), `test/models/user_test.rb`, `test/controllers/sessions_controller_test.rb`, and `test/test_helpers/session_test_helper.rb` (`sign_in_as(user)`, `sign_out`, included into `ActionDispatch::IntegrationTest` through `on_load`; it is **not** in system tests yet).
- **Password recovery removed** (overview §4.7): `PasswordsController` and its route, `app/views/passwords/`, `PasswordsMailer` with its views and preview, and their tests are gone, along with the "Forgot password?" link. `ApplicationMailer` stays.
- **`bin/rails db:migrate` has run.** `db/schema.rb` has `active_storage_*`, `action_text_rich_texts`, `users` and `sessions`.

### 2.2 Lexxy: where its JS and CSS live

- **On Rails 8.1, the lexxy gem aliases the Action Text helpers** (`rich_textarea`, `rich_text_area` and `rich_textarea_tag`, on both the form builder and the view helpers) to its own `<lexxy-editor>`. This is controlled by `config.lexxy.override_action_text_defaults`, which defaults to `true`. Verified output:
  ```html
  <lexxy-editor id="artwork_description" name="artwork[description]" class="lexxy-content"
    data-action-text-supports-alt="false" data-direct-upload-url="…/rails/active_storage/direct_uploads"
    data-blob-url-template="…/rails/active_storage/blobs/redirect/:signed_id/:filename">
  ```
- **JS** lives in the gem: `app/assets/javascript/lexxy.js` (1.07 MB, unminified, as the docs pin it); `lexxy.min.js` (644 KB) exists too. `config/importmap.rb` has:
  ```ruby
  pin "lexxy", to: "lexxy.js"
  pin "@rails/activestorage", to: "activestorage.esm.js"   # Lexxy imports it lazily for uploads
  ```
  - `app/javascript/application.js` imports `@hotwired/turbo-rails`, `controllers` and `lexxy`. So **any layout that calls `javascript_importmap_tags` loads Turbo, Stimulus and Lexxy**, and the public layout must not call it.
  - `lexxy.js` is self-contained: no static imports, no `eval` or `new Function`, and no external URLs.
- **CSS** lives in the gem, served by Propshaft: `lexxy.css` `@import`s `lexxy-content.css` and `lexxy-editor.css`, and both import `lexxy-variables.css`. Propshaft rewrites the imports to digested URLs.
  - Link it **by name** in the admin layout: `stylesheet_link_tag "lexxy"`.
  - It is **not** in `stylesheet_link_tag :app`, which today links only `application.css`.
- **Attachments** are on by default. In 1.0.1 the option is `attachments` (preset default `true`):
  - globally: `Lexxy.configure({ default: { attachments: false } })`;
  - per element: the attribute `attachments="false"` (the gem's own warning text says "configured with [attachments=false]").

  WP4 should confirm which form it uses.
- **Sanitizer additions** (from the gem's engine; they affect public rendering):
  - `ActionText::ContentHelper.allowed_tags` gets `video audio source embed table tbody tr th td`;
  - `allowed_attributes` gets `controls poster data-language style value start`;
  - `var` is allowed in inline CSS. See open issue 2.

### 2.3 Configuration (`config/application.rb`, initializers, locales)

- **Locale:** `config.i18n.default_locale = :es` and `config.i18n.available_locales = [ :es ]`. `rails-i18n` supplies the framework strings, e.g. `errors.messages.blank` gives "no puede estar en blanco".
- **`config/locales/es.yml` (shared):**
  - `activerecord.models.{user,session}`;
  - `activerecord.attributes.user.{email_address,password,password_confirmation}`;
  - a feminine override `activerecord.errors.models.user.attributes.password.too_short` (rails-i18n's generic text is masculine), giving "Contraseña es demasiado corta (12 caracteres mínimo)";
  - `sessions.create.invalid` and `sessions.create.rate_limited`.

  WP2 adds the domain model and attribute names here. `config/locales/en.yml` (the generator's "hello world") is untouched and unused.
- **Active Storage:** `config.active_storage.resolve_model_to_route = :rails_storage_proxy`. `variant_processor` is `:vips`, from `load_defaults 8.1`; I confirmed it at runtime, along with `ActiveStorage.variant_transformer == ActiveStorage::Transformers::Vips`.
- **`ApplicationController`:** `include Authentication` and `stale_when_importmap_changes` (the ETag includes the importmap digest). **`allow_browser` is removed**; WP4 may add it to `Admin::BaseController`.
  - Every controller requires login by default, so public controllers need `allow_unauthenticated_access`.
  - The `authenticated?` helper only *reads* the signed `session_id` cookie and writes nothing.
- **`User`:** `validates :password, length: { minimum: 12 }, allow_nil: true`, so it is checked only when a password is being set.
- **`SessionsController`:** the alerts use `t(".invalid")` / `t(".rate_limited")`, and the rate limit is now **5 attempts per 10 minutes per IP** (overview §4.7). I verified it in development: attempts 1–5 get "El correo electrónico o la contraseña no son correctos.", and attempts 6–7 get "Demasiados intentos. Espera unos minutos y vuelve a intentarlo.".
  - The limiter's store is the controller's `cache_store`, captured when the class loads: a memory store in development and a **null store in test**. So a rate-limit test must swap the store (WP4).
- **Routes** (`config/routes.rb`): `resource :session`, `get "up"` and **`root "artworks#index"`**.
  - The root route is there because the auth generator's `after_authentication_url` falls back to `root_url`. It is the route from overview §4.4, so WP2 keeps it.
  - `GET /` raises until WP3 adds `ArtworksController`.
  - WP4 changes the post-login target to `admin_root_url`.
- **Tooling:**
  - `.rubocop.yml` keeps the omakase inherit and adds `AllCops: Exclude: [".claude/**/*", "design/**/*"]` with `inherit_mode: merge: [Exclude]`, so the default, rubocop-rails and omakase excludes stay.
  - **Brakeman needs no config:** it builds its file list from `Dir.glob("*/")`, which skips dot-directories. I verified this with a deliberately vulnerable probe file under `.claude/`: no warnings, while the same file outside a dot-directory gave 2 high-confidence warnings.
  - There is no `config/brakeman.ignore`.
- **`.gitignore`:** the generator's file plus `.DS_Store` and `/.claude/`. `config/*.key` is ignored, and `config/credentials.yml.enc` is exactly as generated (no `admin` entry yet; the orchestrator adds it after WP2).
- **System tests:** Rails 8.1 creates `test/system/` and `ApplicationSystemTestCase` only for dev containers, so `bin/rails test:system` crashed.
  - Both were added from Rails' own template: `driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]`.
  - A throwaway system test (not committed) confirmed that headless Chrome loads the login page with a nonce on the importmap `<script>`, Turbo and `<lexxy-editor>` run under the CSP, and the browser console logs nothing.
  - Selenium Manager put chromedriver in `~/.cache/selenium`.
- **`bin/ci`** (`config/ci.rb`) also runs `bin/rails test:system` now. It runs setup, RuboCop, bundler-audit, importmap audit, Brakeman (`--exit-on-warn`), the tests, `RAILS_ENV=test db:seed:replant` and the system tests.

### 2.4 The CSP as written (`config/initializers/content_security_policy.rb`)

```ruby
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.script_src      :self
    # Inline styles are needed for the per-tile sizes on public pages and for the editor.
    policy.style_src       :self, :unsafe_inline
    policy.img_src         :self, :data, :blob
    policy.font_src        :self
    policy.connect_src     :self
    policy.object_src      :none
    policy.base_uri        :self
    policy.form_action     :self
    policy.frame_ancestors :none
  end

  # A fresh random nonce per request, for script-src only (the importmap and any inline script).
  # It does not come from the session, so rendering a page never writes a session cookie.
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
```

The resulting header, as seen on `GET /up`, which also has no `Set-Cookie`:
`default-src 'self'; script-src 'self' 'nonce-…'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'`

## 3. Image processing: image_processing 2.2 kept

- I used `image_processing ~> 2.2` plus `ruby-vips ~> 2.3`; the version Rails' own error message recommends is also 2.3.
- Rails 8.1.4 explicitly supports image_processing 2.x: `active_storage/vips.rb` requires `image_processing/vips` before calling `Vips.block_untrusted(true)` itself.
- **Real Active Storage variant, verified:** a throwaway blob of `design/img/obra-01.webp` (1179×1571, 4 bands) was put through `blob.variant(resize_to_limit: [ 1200, nil ], format: :webp, saver: { strip: true, quality: 82 }).processed`.
  - The result was a WebP at **1179×1571** (not upscaled), with **4 bands**, alpha from 0 to 255 and 5.8% non-opaque pixels.
  - Analysis gave `{"width"=>1179, "height"=>1571, "analyzed"=>true}`.
  - The blob, its variant and the files were purged afterwards; the development database holds no blobs.
- A 600 px transformer-level run also kept alpha and carried no EXIF, XMP or ICC fields.
- Behaviour changes in 2.x worth knowing:
  - no sharpening after resize by default;
  - `mini_magick`/`ruby-vips` must be listed in the Gemfile (done);
  - missing soft dependencies raise `LoadError`.

## 4. AVIF

`bin/rails runner 'p Vips.get_suffixes.include?(".avif")'` prints **`false`** on this Mac, because the dev libvips is built without libheif (§6). So, in development, the image rules must not accept `image/avif`.

**For WP2's AVIF gate** (and WP5's Docker check), `get_suffixes` alone is not enough:
- libvips 8.18 flags `heifload` as *untrusted* whenever libheif < 1.23.2;
- after boot, Active Storage, and image_processing 2.x too, call `Vips.block_untrusted(true)`;
- so `.avif` can be listed while every AVIF upload fails to load.

A gate that respects this. The blocked bit was tested with `ppmload`: it is blocked after boot, while `webpload`, `jpegload` and `pngload` are not.

```ruby
Vips.get_suffixes.include?(".avif") &&
  (Vips::Introspect.get_yard("heifload").flags & 32).zero?   # 32 = VIPS_OPERATION_BLOCKED; evaluate after boot
```

## 5. How to verify

```sh
ruby -v && bin/rails -v && vips --version          # 4.0.7, 8.1.4, vips-8.18.7
bin/ci                                             # all steps green (8 runs, 21 assertions; 0 system tests)
bin/rails runner 'p Vips.get_suffixes.include?(".avif")'   # false on this Mac
bin/importmap json                                 # lexxy and @rails/activestorage resolve to digested assets
```

- A fresh `git clone` **without `config/master.key`** runs `bin/setup --skip-server`, the tests, `test:system` and RuboCop green. That is the worktree situation of WP3–5.
- Boot check: `bin/rails server -p 3001`, then `curl -s -o /dev/null -w '%{http_code}' localhost:3001/up` prints `200`.

## 6. Deviations and decisions

1. **libvips is not from Homebrew.** This Mac runs macOS 14, which Homebrew 6 treats as **Tier 3: no bottles**.
   - `brew install vips` would have source-built about 37 formulae, including rust, python@3.14, python@3.15, openssl@4, glib, poppler and imagemagick, and upgraded 28 installed packages. That means hours of compiling with a real chance of failure partway.
   - The conservative alternative I took:
     - `brew install libexif`: one bottle, no other changes; it is needed for EXIF orientation;
     - built **libvips 8.18.7** (Homebrew's exact tarball, sha256-verified against the formula) with meson, against the Homebrew libraries already installed. Those are glib 2.78.4, jpeg-turbo 3.0.1, libpng 1.6.42, webp 1.3.2, libtiff 4.6.0, little-cms2 2.16, highway 1.0.7 and libexif 0.6.26, plus the system expat and zlib;
     - installed it into `~/.local/opt/vips-8.18.7`, with symlinks `~/.local/bin/{vips,vipsheader,vipsthumbnail,vipsedit}` and **`/opt/homebrew/lib/libvips.42.dylib`**, so Ruby's FFI finds it without environment variables.
   - Formats in this build: JPEG, PNG, WebP, TIFF, GIF (load only), PPM, RAD, CSV and matrix.
   - **Not in this build:** HEIF/AVIF, SVG, PDF, JPEG XL, GIF save (cgif), palette quantisation (imagequant), FFT, and **text rendering (`Vips::Image.text` needs pangocairo)**. WP2's generated seed images must use drawing and arithmetic operations, not text.
2. **HEIF/AVIF is off in the dev build because Homebrew's `libheif` 1.17.6 on this Mac is already broken.**
   - It links `libx265.199.dylib`, which disappeared when x265 4.3 was installed on 2026-08-29, before this WP.
   - Repairing it would mean source-building libheif and its codecs.
3. **Homebrew changes made by this WP:**
   - `brew upgrade ruby-build` (20241105 → 20260924), as the plan says. Homebrew also upgraded its dependencies: autoconf 2.72→2.73, m4 1.4.19→1.4.21, pkgconf 2.3.0_1→3.0.8 and readline 8.2.13→8.3.6. The sonames are unchanged.
   - Homebrew's automatic `brew cleanup` then removed superseded kegs (autoconf 2.72, gettext 0.21.1/0.22.4, m4 1.4.19, pkgconf 2.3.0_1, readline 8.2.13, x265 3.5) and some download caches. Every one had a newer version installed.
   - `brew install libexif`. Nothing else was installed, upgraded or removed.
4. **Lexxy is pinned unminified (`lexxy.js`), as its docs show.** `@rails/activestorage` is pinned now, because Lexxy imports it and WP4 needs it for direct uploads. The Trix-only `actiontext.css` was removed.
5. **The rate limit is already 5 per 10 minutes**, and the login messages are I18n keys in `es.yml` rather than inline strings; WP4 may move them to `admin.es.yml`. WP4's plan also lists the rate limit, and it is already done.
6. `root "artworks#index"` was added early, to fix the auth generator's `root_url` leftover.
7. The system-test scaffold was added, and `bin/ci` runs the system tests.

## 7. Notes for the next WPs

- **WP2**
  - es.yml is shared: add model and attribute names there, keeping the existing keys.
  - The development Active Job adapter is **`:async`**, the test adapter is `:test`, and production uses Solid Queue. In development, preprocessed variants and `AnalyzeJob` run in-process threads; in tests, run the jobs explicitly.
  - Fixture users still have the generator's throwaway password `password`. They're digests, so the 12-character validation doesn't apply; switch to a 12+ character throwaway if you like.
  - `sign_in_as` is only included in integration tests.
  - `has_secure_password` (Rails 8) still defines password-reset token helpers by default, but nothing uses them. `has_secure_password reset_token: false` would remove them; optional.
- **WP3**
  - The generated `layouts/application.html.erb` still has `csrf_meta_tags`, `csp_meta_tag`, `stylesheet_link_tag :app`, `javascript_importmap_tags` and the Rails icon links; rewrite it per §4.6.
  - `public/icon.*`, `406-unsupported-browser.html` and the default error pages are untouched (§4.9 is yours).
  - The rich-text wrapper class is `lexxy-content`; don't load Lexxy's CSS on public pages.
- **WP4**
  - Admin layout: `javascript_importmap_tags` (application.js already imports Lexxy) plus `stylesheet_link_tag "lexxy"`.
  - Start Active Storage's direct uploads yourself (`import * as ActiveStorage from "@rails/activestorage"; ActiveStorage.start()`).
  - Disable Lexxy attachments (§2.2).
  - The CSP already covers Lexxy: inline styles via `'unsafe-inline'`, previews via `blob:`, same-origin uploads.
  - `sessions/new` is still English, with inline `style="color:…"` flash divs.
- **WP5**
  - The Dockerfile already installs Debian's `libvips`. Check AVIF there with the gate in §4.
  - `config/deploy.yml` and `.kamal/secrets` are the generator's placeholders (server `192.168.0.1`, registry `localhost:5555`, `builder.arch: amd64`, volume `atesoraroseta_storage:/rails/storage`, `SOLID_QUEUE_IN_PUMA: true`).

## 8. Open issues

1. **AVIF is unsupported in development** (`false`). Production depends on the Docker image (WP5).
2. **Inline styles in rich text.** Lexxy's sanitizer allows `style` attributes, and its highlight feature writes colours as inline `style` with CSS variables. That conflicts with "on public pages, the only inline `style` attributes are the per-tile sizes". Proposed fix: WP4 disables highlighting in the editor (Lexxy's `highlight` option), and WP3 strips `style` when rendering public rich text.
3. **`brew doctor` will warn about the unbrewed `/opt/homebrew/lib/libvips.42.dylib` symlink.** A future `brew install vips` will refuse to link over it until it is removed. To switch to Homebrew's vips later (e.g. once a newer macOS gets bottles):
   ```sh
   rm /opt/homebrew/lib/libvips.42.dylib ~/.local/bin/{vips,vipsheader,vipsthumbnail,vipsedit}
   rm -r ~/.local/opt/vips-8.18.7
   brew install vips
   ```
   If a future `brew upgrade` changes the soname of one of the libraries listed in §6 and `vips --version` stops working, rebuild:
   - download the tarball from the vips formula;
   - in a venv, `pip install meson ninja`;
   - run `meson setup <build> <src> --prefix=$HOME/.local/opt/vips-8.18.7 --libdir=lib --buildtype=release --auto-features=disabled -Dcplusplus=false -Dmodules=disabled -Djpeg=enabled -Dpng=enabled -Dwebp=enabled -Dtiff=enabled -Dlcms=enabled -Dexif=enabled -Dhighway=enabled -Dzlib=enabled`, then `meson compile` and `meson install`.

## 9. For the user to decide

- **libvips on this Mac.** Keep the local build (it works and changes nothing else), or move to Homebrew's vips. The latter means either upgrading macOS to a Homebrew-supported version (bottles) or accepting a multi-hour source build of about 37 formulae.
- **libheif.** Your Homebrew `libheif` 1.17.6 is broken (its x265 is gone), which also affects anything else on this Mac that reads HEIC/AVIF through it. `brew reinstall libheif` would rebuild it from source.
