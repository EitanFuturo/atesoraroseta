# WP3 handoff: public site

Status: **done**, on branch `worktree-agent-a896ebcca2f33e6d8`. The quality gate is green: `bin/ci` passes (223 runs, 1563 assertions, 0 failures; RuboCop, Brakeman, bundler-audit and the importmap audit clean; no system tests exist yet, WP4 owns them).
The five pages and the 404 match the canvas at 1440 and 390 apart from seeded text and data (section 6), and nothing scrolls sideways at 1440, 768, 390 or 320.
Lighthouse accessibility is 100 on all five pages. No gems were added.

## 1. What was built

### 1.1 Controllers (`app/controllers/`)

| Controller | Actions | Notes |
|---|---|---|
| `PublicController` | (base) | `allow_unauthenticated_access`, `layout "application"`, `helper_method :site` (`Site.current`, memoised). Nothing touches the session or the flash. |
| `ArtworksController` | `index`, `show` | `show` finds by slug. An unpublished work raises `RecordNotFound` (404) for visitors; a signed-in admin (`authenticated?`) gets the page with `@preview = true` and `Cache-Control: private, no-store`. |
| `TornPostersController` | `index` | |
| `PagesController` | `about`, `contact` | |
| `SitemapsController` | `show` (xml) | `app/views/sitemaps/show.xml.builder` |
| `RobotsController` | `show` (text) | `render plain:`, so there is no `app/views/robots`. |
| `ErrorsController` | `not_found`, `internal_error` | See 1.6. |

### 1.2 Layout and partials

- `app/views/layouts/application.html.erb` is **the public layout**: `<html lang="es">`, `<meta charset>`, viewport, title, `public/_meta`, preloads of `jost-normal-latin.woff2` and `bodoni-moda-normal-latin.woff2`, and `stylesheet_link_tag "fonts", "site", "layout"`.
  - It has no `javascript_importmap_tags`, no `csrf_meta_tags` and no `csp_meta_tag`.
  - Body: `<body class="page"><div class="container">` header, then the page.
- `app/views/public/_header.html.erb`: the wordmark (links `/`) and `<nav aria-label="Principal">` with the four menu links. The current section gets `aria-current="page"`, and Obra stays current on artwork pages.
- `app/views/public/_meta.html.erb`:
  - the description, canonical, `og:type/site_name/locale/title/description/url`;
  - with an image: `og:image` (absolute URL), its type, width, height and alt, plus `twitter:card` = `summary_large_image`;
  - favicon links only when `Site#favicon` is attached: 32 and 512 as `rel=icon`, 180 as `apple-touch-icon`.
- Views: `artworks/index` + `artworks/_tile`, `artworks/show`, `torn_posters/index`, `pages/about`, `pages/contact`, `errors/not_found`, `sitemaps/show.xml.builder`.

### 1.3 Helper API (`app/helpers/`, all public, no admin helpers)

| Helper | Methods |
|---|---|
| `SiteHelper` | `site`: the settings record for any view. Public controllers' `helper_method :site` takes precedence. It exists so `layouts/application` also renders under other controllers (the login page uses it unless WP4 sets a layout). |
| `PageMetaHelper` | `page_meta(title:, description:, canonical:, og_image:, og_image_alt:)` (each view calls it once), `page_title` ("page — wordmark"), `page_description` (falls back to `seo_description`, nil when blank), `page_canonical_url`, `page_og_image_url` (the page's own `og` variant, else `Site#og_image`, else the first published artwork's), `page_og_image_alt`, `favicon_variants` |
| `NavigationHelper` | `main_menu_items` ([label, path, section] in canvas order), `current_section` (`:work`, `:torn_posters`, `:about`, `:contact` or nil) |
| `ResponsiveImagesHelper` | `responsive_image_tag(image, sizes:, alt:, loading: :lazy, fetchpriority: nil, **html_options)`, `obra_tile_sizes(image)`, `artwork_hero_sizes(image)`, `detail_sizes`, `poster_sizes`, `portrait_sizes`, `grid_loading(index, eager:)`, `sizes_value(layout, scale:, max:)`; constants `OBRA_EAGER_TILES = 3`, `POSTER_EAGER_TILES = 4` |
| `RichTextHelper` | `public_rich_text(rich_text)`: Action Text's rendering, sanitised again without `style` attributes |

`responsive_image_tag` takes a WP2 `ResponsiveImage` and renders:
- `src` = the middle candidate (`candidates[size / 2]`);
- `srcset` = every candidate as `url_for(variant)` (proxy path) with its real width as `w`;
- `sizes`, and `width`/`height` from the original's metadata;
- `alt`, then the `class` and any other attributes passed;
- lazy images get `loading="lazy" decoding="async"`; eager ones carry no `loading` attribute (eager is the default).

Without width/height metadata, it renders the family's middle variant with no srcset or size. Obra tiles then get a `width: 100%; aspect-ratio: 4 / 5` frame.

Loading: the first 3 Obra tiles and the first 4 posters are eager; the first tile, the first poster, the artwork hero and the portrait get `fetchpriority="high"` (the hero and portrait are eager too). Everything else is lazy.

### 1.4 `sizes` strings

Content width: `min(100vw, 1440px) − 2 × clamp(20px, 4.45vw, 64px)`, i.e. 1312px from 1440 up and at most 91.1vw below.
- Every value errs slightly large: lengths are rounded up.
- Every column switch is placed ~17px after the layout's own, because a classic scrollbar narrows the layout but not the media queries. The poster grid is the exception: it switches on site.css's own media queries.
- `sizes_value` builds the strings from `[min viewport, vw, px]` segments, and also scales them (tiles) or caps them (hero, portrait).

| Image | `sizes` |
|---|---|
| Obra tile (frame at 100%) | `(max-width: 640px) 91.1vw, (min-width: 1440px) 400px, (min-width: 1100px) 27.77vw, (min-width: 720px) calc(45.55vw - 18px), 91.1vw` |
| Obra tile, narrower frame | Every term after the phone clause is × the frame share. For 93.81%: `(max-width: 640px) 91.1vw, (min-width: 1440px) 376px, (min-width: 1100px) 26.06vw, (min-width: 720px) calc(42.74vw - 16px), 85.47vw` |
| Artwork hero | Per image, capped at `min(original width, ceil(860 × w / h))` from layout `[1440: 948px] [1010: calc(86.65vw - 300px)] [0: 91.1vw]`. For obra-01 (1179×1571): `(min-width: 1092px) 646px, (min-width: 1010px) calc(86.65vw - 300px), (min-width: 710px) 646px, 91.1vw` |
| Detail photo | `(min-width: 1440px) 422px, (min-width: 1058px) calc(30.37vw - 16px), (min-width: 702px) calc(45.55vw - 12px), 91.1vw` |
| Torn poster | `(min-width: 1440px) 313px, (min-width: 1024px) calc(22.78vw - 15px), (min-width: 641px) calc(30.37vw - 13px), calc(45.55vw - 6px)` |
| Portrait | `(min-width: 1399px) 540px, (min-width: 894px) calc(42.2vw - 50px), (min-width: 593px) 540px, 91.1vw` |

Derivations:
- **Obra grid:** 3 columns from ~1081px, 2 from ~699px.
- **Hero:** beside the text column from ~993px.
- **Details masonry:** 3 columns from ~1041px, 2 from ~685px.
- **Posters:** 4/3/2 columns at 1024/641.
- **Portrait:** beside the text from ~877px, then 320px + half the free space, up to 540.

### 1.5 Stylesheets and fonts

- **`app/assets/stylesheets/site.css`** is `design/site.css` with only the demo selectors removed (`.work.is-demo …`, `.photo.is-demo`, `.hover-label.is-on`); `diff design/site.css app/assets/stylesheets/site.css` shows nothing else.
- **`app/assets/stylesheets/layout.css`**: the artboards' inline layout values as classes; canvas hex colours are written as the same tokens. Class names (also listed at the top of the file):

  | Area | Classes |
  |---|---|
  | shell | `body.page`, `.container`, `.site-header`, `.wordmark` (+layout), `.nav-list`, `.nav-link` (+layout), `.visually-hidden`, `.main-obra`, `.main-artwork`, `.main-posters`, `.main-about`, `.main-contact` (each page's `<main>` padding-top) |
  | Obra | `.work-grid`, `.work-img` (+layout), `.hover-label` (tile inset 14, padding 11/14/12) |
  | artwork | `.preview-notice`, `.back-link`, `.artwork-hero`, `.artwork-media`, `.artwork-img`, `.artwork-text`, `.artwork-title`, `.artwork-data`, `.artwork-data-row`, `.artwork-medium` (the Técnica dd's `text-wrap: pretty`), `.artwork-description`, `.details-link`, `.details`, `.details-title`, `.details-columns`, `.detail` (+layout), `.detail-img`, `.pager`, `.pager-link`, `.pager-next`, `.pager-label`, `.pager-title` |
  | Torn Posters | `.posters-intro`, `.photo` (loading background), `.photo-img`, `.photo .hover-label` (inset 12, padding 10/13/11), `.photo .hover-title` (20px) |
  | Sobre mí | `.about`, `.about-portrait`, `.about-portrait-img`, `.about-text`, `.about-lead`, `.about-body` |
  | Contacto / 404 | `.page-label`, `.contact`, `.contact-headline`, `.contact-email`, `.contact-links`, `.contact-link-group`, `.contact-handle`, `.not-found-text` |
  | shared | `.standalone-link` (Sobre mí's "Escríbeme", the 404's link), `.rich-text` |

- **Rich text** (`.rich-text` on `.artwork-description` and `.about-body`):
  - block margins are 0, with `1.5em` between blocks (24px between Sobre mí's 16px paragraphs, as in the canvas);
  - `p` has `text-wrap: pretty`;
  - links look like `.text-link`;
  - headings stay in body type at weight 500, lists are indented 1.25em, and blockquotes get a hairline;
  - `mark` is neutralised, and images are capped at 100%.
- **`app/assets/stylesheets/fonts.css`** has Google's `@font-face` rules: `font-display: swap`, Google's unicode-ranges, and URLs that Propshaft fingerprints.
- **Fonts** (`app/assets/fonts/`):
  - Bodoni Moda v28, normal and italic (wght 400–900, opsz 6–96), and Jost v20, normal (wght 100–900), latin and latin-ext, fetched 2026-10-13;
  - axes verified by reading each file's `fvar` table;
  - licences: `OFL-bodoni-moda.txt`, `OFL-jost.txt` (from google/fonts).
  - **Optical sizing works:** at 96px the hairlines are much finer than with optical sizing off (opsz 11). Screenshots: `tmp/page-screenshots/fonts/opsz-{auto,none}-96px.png`.

### 1.6 Error pages

- **`config/initializers/error_pages.rb`** sets `config.exceptions_app`, wrapped in `ActionDispatch::ContentSecurityPolicy::Middleware`:
  - **404 and 500** go through the routes (`ErrorsController`);
  - **every other status** goes to `ActionDispatch::PublicExceptions` (`public/<status>.html`, Rails' default behaviour).
  - The wrapper is needed because exceptions reach the app outside the middleware that adds the CSP header, and error pages should carry it too.
- **`errors#not_found`:**
  - in the site layout, with the Contacto structure: `p.label` "404", `h1.contact-headline` (`not_found_title`), `p.not-found-text` (`not_found_text`, hidden when blank), a `.text-link` home (`not_found_link_label`);
  - status 404, no cookie, no script;
  - non-HTML formats get an empty 404;
  - if the page itself fails (no database, say), it renders `public/404.html`.
- **`errors#internal_error`** renders `public/500.html` (status 500).
- **Static pages:** `public/400.html`, `404.html`, `422.html` and `500.html` are restyled with inline CSS:
  - the tokens and system serif fallbacks, the wordmark and the Contacto structure;
  - Spanish copy, `noindex`.

### 1.7 Locale

`config/locales/public.es.yml`:
- `public.nav.main` ("Principal"), `public.nav.other_works` ("Otras obras");
- `public.preview_notice` (the admin-only preview line).

### 1.8 `bin/screenshots`

```sh
bin/screenshots --base http://localhost:3003 [--reference] [--widths 1440,768,390,320] [--reduced-motion] [--touch] \
                [--hover CSS] [--tab N] [--run NAME] [pages…]
```

- **Pages:** `obra`, `obra-detalle`, `torn-posters`, `sobre-mi`, `contacto`, `404` (all by default; `--reference` has no 404), or any path starting with `/`.
- **Output:** full-page PNGs in **`tmp/page-screenshots/<run>/<page>-<width>.png`** (see deviation 6).
- **How it works:**
  - exact widths via CDP `Emulation.setDeviceMetricsOverride`;
  - the viewport grows to the page height so lazy images load;
  - `Page.captureScreenshot` with `captureBeyondViewport`;
  - `Emulation.setEmulatedMedia` for reduced motion, `Emulation.setTouchEmulationEnabled` for touch.
- It prints `SCROLLS SIDEWAYS: …` for any page whose `scrollWidth > clientWidth`.
- **`--hover ".work"`** hovers the first tile. **`--tab 6`** focuses the first Obra tile: wordmark, four menu links, then the tile.
- **The `404` page is shot at `/404.xhtml`:** the static file server answers `/404` and `/404/` with `public/404.html`, but `.xhtml` reaches the route (Rails reads it as HTML).

### 1.9 Deleted

`public/icon.png`, `public/icon.svg`, `public/406-unsupported-browser.html`, `public/robots.txt` (it would shadow `/robots.txt`), and the unrouted PWA scaffolding `app/views/pwa/{manifest.json.erb,service-worker.js}`, whose manifest only pointed at the deleted icon.

## 2. How to verify

```sh
bin/ci                                           # all green
bin/rails server -p 3003                         # then:
bin/screenshots --reference --run ref            # canvas renders, 1440/768/390/320
bin/screenshots --base http://localhost:3003 --run app
bin/screenshots --base http://localhost:3003 --widths 1440 --hover ".work" obra          # label + lift
bin/screenshots --base http://localhost:3003 --widths 1440 --tab 6 obra                  # focus ring + label
bin/screenshots --base http://localhost:3003 --widths 390 --touch --hover ".work" obra   # no label
bin/screenshots --base http://localhost:3003 --widths 1440 --reduced-motion --hover ".work" obra   # no lift
curl -sI localhost:3003/ | grep -i -E 'set-cookie|content-security'   # CSP only, no cookie
```

**Tests** (all mine, none depend on WP4):
- `test/integration/public_pages_test.rb`: every page with fixtures and with an empty database, the header, copy from the settings, privacy (no `Set-Cookie`, no `<script`, a CSP header), stylesheets by name, and "the only inline styles are the tile frames";
- `artworks_test.rb`: tiles, srcset/sizes/width/height, eager/lazy, hide-empty, the artwork page, details singular/plural, prev/next edges, year ranges, preview and 404s;
- `torn_posters_test.rb`, `pages_test.rb` (Sobre mí, Contacto, rich-text styles), `seo_test.rb` (titles, descriptions, canonical, og/twitter, favicons, sitemap, robots);
- `error_pages_test.rb`: the production error flow, 404/500/422/400, CSP;
- `test/helpers/responsive_images_helper_test.rb`: the sizes arithmetic and the tag.

**Screenshots** of this run are in this worktree:
- `tmp/page-screenshots/wp3-reference/` and `wp3-app/` (1440, 768, 390, 320);
- `wp3-app/diff/`: the reference with differing pixels in red;
- `wp3-hover/`, `wp3-focus/`, `wp3-touch/`, `wp3-reduced-motion/`;
- `v2-app/preview.png`: the admin preview notice.

`tmp/` is ignored, so these disappear with the worktree; regenerate them with the commands above.

**Measured:**
- **CLS** with a throttled network: about 0 on every page. Lighthouse mobile CLS is 0 to 0.0004; the 0.0004 is a font swap.
- **Lighthouse (mobile, dev server):** accessibility 100, SEO 100 and best practices 96 (see open issue 1) on all five pages. Performance: Obra 76, artwork 78, Torn Posters 99, Sobre mí 98, Contacto 100. The dev server sends uncompressed HTML and CSS; in production Thruster compresses and caches.
- **Queries:** the home page makes 17 batched queries, with no per-tile N+1.

## 3. Deviations and decisions

1. **Artwork hero sizing (CLS fix).**
   - The canvas's `width: auto; height: auto` leaves the hero with no box until the image starts arriving, so on phones the text below it jumped: Lighthouse CLS 0.36.
   - `.artwork-img` now drops `width: auto`. The `width` attribute (the original's width) sizes the box, capped by `max-width: 100%`. `height: auto` follows the attributes' ratio, capped by `max-height: 860px`. `object-fit: contain` centres a tall work in that box, with transparent sides; the drop-shadow follows the painted pixels.
   - Screenshots before and after are **pixel-identical** at 1440 and 390, a small original (300×560) stays at its natural size, and CLS is 0.
2. **`exceptions_app` is a small dispatcher in an initializer I own**, not `config.exceptions_app = routes` in `config/application.rb`. With routes alone, 400/406/422 would be empty pages, because the routes only know 404 and 500, so the restyled `422.html` would never show.
3. **The 500 renders the static `public/500.html`.** The settings have no 500 texts, and a page that already failed shouldn't need the database. `public/400.html` is restyled too, since the dispatcher serves it.
4. **The 404 page's heading:** "404" is a `p.label` and the title is the `h1`, for screen readers. It looks exactly like Contacto's structure.
5. **Placeholder-only canvas styles are not shipped:**
   - the portrait figure's padding, flex and dot-screen background (they only position the "[Retrato…]" caption);
   - the poster tiles' tint backgrounds and "Foto 01" captions.

   `.about-portrait` and `.photo` get `--surface` as their loading background, the DESIGN.md token for that.
6. **`bin/screenshots` writes to `tmp/page-screenshots/<run>/`, not `tmp/screenshots/<run>/`.**
   - Rails' `tmp:clear`, which `bin/setup` and `bin/ci` run, removes `tmp/screenshots/*` with `rm`, which fails on folders and so broke `bin/setup`. `tmp/screenshots` is also where system tests drop failure screenshots.
   - It also has extra flags beyond the plan: `--hover`, `--tab`, `--run`.
7. **`SiteHelper#site`:** the login page (`SessionsController`, WP4's) renders in `layouts/application` unless WP4 sets another layout. Without a view-level `site`, its test failed.
8. **Rich text:**
   - `style` attributes are stripped on public pages by re-sanitising Action Text's output with its own allow-lists minus `style`. Lexxy's global sanitizer config is untouched.
   - `<mark>` is shown as plain text.
9. **Social tags:**
   - `og:title` is the full `<title>`;
   - `twitter:card` is emitted only when there is an image;
   - every page without its own description (the 404, a blank intro or lead) falls back to `seo_description`.
10. **Sitemap `lastmod`:**
    - `/` takes the latest of the site row and all artworks; publishing or hiding one changes the grid, so unpublished ones count too;
    - `/torn-posters` takes the site row and posters;
    - `/sobre-mi` and `/contacto` take the site row;
    - artwork pages take the artwork's own (details touch it).
11. **No `fresh_when` ETags.** Record-based ETags don't change when a deploy changes the CSS digests, so browsers could keep HTML pointing at deleted assets. Rack::ETag's body-based ETag already gives 304s.
12. **Only Jost normal is shipped, as the plan lists.** The canvas's font URL also loads Jost italic, so an `<em>` in rich text renders as synthesised oblique.

## 4. Open issues

1. **`/favicon.ico` is a 404** until a favicon is uploaded, because no icon is linked (overview §4.3). Browsers request it anyway, which logs a console error (Lighthouse best practices 96) and renders the 404 page.
   - Proposed fix: when there is no favicon, add `<link rel="icon" href="data:,">`. It shows nothing and stops the request.
2. **Direct visits to `/404` and `/500`** return the static files with status 200, because the public file server matches `public/404.html` first. Real errors are unaffected (the exceptions app calls the routes directly).
3. **For WP4:**
   - **Login layout:** `SessionsController` renders in the public layout (header and menu, no JS) unless it sets its own layout.
   - **`allow_browser`:** `public/406-unsupported-browser.html` is deleted (overview §4.9). If `Admin::BaseController` uses `allow_browser`, give it a `block:`, because the default renders that file.
   - **Helper names:** with `include_all_helpers`, my helper method names (`site`, `page_meta`, `page_title`, `current_section`, `responsive_image_tag`, …) are visible in admin views; don't redefine them with other meanings.
4. **Attachments in rich text:** `app/views/active_storage/blobs/_blob.html.erb` is still the generator's. If an attachment ever reaches a description or the bio, the public page shows its file name and size. WP4 disables Lexxy attachments, so leave it unless that changes.
5. **Small font-swap layout shifts** (≤ 0.0006 per page) remain, mostly the italic titles, which aren't preloaded. The plan preloads only Jost and Bodoni normal.
6. **Development only:** `annotate_rendered_view_with_filenames` adds HTML comments before the doctype. Production doesn't.

## 5. Files touched outside my list (overview §7.2)

- `app/views/pwa/manifest.json.erb` and `service-worker.js` were deleted: unrouted generator files whose only content referenced the deleted icon.
- `config/initializers/error_pages.rb` is new. Initializers are "shared", and the plan allows an initializer here; no existing file was edited.
- `test/helpers/responsive_images_helper_test.rb` is new. It is a helper unit test, and `test/helpers/` has no owner.

## 6. Remaining visual differences (app vs canvas, 1440 / 768 / 390 / 320)

Heights match to the pixel on every page except the artwork page (below). Every other difference is seeded data or a placeholder:
- **Obra:** at most 0.2% of pixels, scattered speckle inside the images. The app serves the 600/1200 WebP variants while the canvas scales the originals; tile geometry, shadows and spacing are identical.
- **Artwork page:**
  - the title and year are seeded text;
  - the canvas shows both "Anterior" and "Siguiente", while the first seeded work has no previous one, so no wrap-around. That takes one pager row less on phones (80px at 390).
  - At 320 the seeded title "Obra de muestra 01" wraps onto two lines where "[Título de la obra]" fits on one, shifting everything below.
- **Torn Posters:** the canvas's "Foto 01…12" captions aren't shipped (overview §5), and the generated dot-screen images differ slightly from the canvas's CSS dot gradient.
- **Sobre mí:** the canvas's "[Retrato o foto en el taller]" caption on the placeholder portrait isn't shipped.
- **Contacto:** the email and handle are seeded text (`tu-correo@example.com`, `@usuario` vs the canvas's bracketed placeholders).

## 7. For the user to decide

- **Favicon fallback** (open issue 1): link an empty icon when none is uploaded, or keep the plain 404 for `/favicon.ico`.
- **Jost italic** (decision 12): ship it (two more files, downloaded only when italic body text appears), or keep the synthesised oblique in rich text.
- **Static error page wording:**
  - 400: "Solicitud no válida";
  - 422: "No se ha podido completar";
  - 500: "Algo ha fallado";
  - 404 static: same as the defaults.

  This is draft copy for the artist to approve. It is hard-coded because those pages can't read the database.
