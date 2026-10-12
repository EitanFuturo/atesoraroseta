# WP3: Public site

**Runs in:** your own git worktree and branch, in parallel with WP4 (admin) and WP5 (deploy).
**Depends on:** WP2. Read `docs/handoff/WP1.md` and `docs/handoff/WP2.md`.
**Read first:**
- `docs/plans/00-overview.md` (all; §4.3–4.7, §4.9 and §5 matter most);
- `design/PROMPT.md` (Public site);
- `design/DESIGN.md` (all);
- `design/site.css`;
- `design/canvas/README.md`;
- every desktop artboard in `design/canvas/source/`.

## Goal

The five public pages, the 404 and the SEO plumbing. They must look like the canvas at 1440 and 390, work at 768 and 320, and behave as DESIGN.md says. Every visible word comes from the `Site` record or the content records.

## You own

See overview §7.2 for the full list. In short:
- the public controllers, views, helpers, layouts and stylesheets;
- `app/assets/fonts/**`;
- `public/*.html` and the icons;
- `config/locales/public.es.yml`;
- `bin/screenshots`;
- the public controller and integration tests;
- `docs/handoff/WP3.md`.

**Don't edit** `config/routes.rb`, models, migrations or anything admin. If you need something from them, write it in your handoff and work around it.

## Steps (commit after each)

1. **Set up the worktree.**
   - Run `bin/setup --skip-server`. It bundles and prepares the database with the dev seeds.
   - Run `bin/jobs` once, or the transform jobs inline, so the seeded variants exist.
   - Start the server on port **3003**.
2. **Fonts: self-host exactly what the canvas loads.**
   - Fetch the Google Fonts CSS for the canvas URL with a current desktop Chrome user agent:
     `https://fonts.googleapis.com/css2?family=Bodoni+Moda:ital,opsz,wght@0,6..96,400..900;1,6..96,400..900&family=Jost:wght@100..900&display=swap`
   - Download the **latin** and **latin-ext** WOFF2 files: Bodoni Moda normal and italic, both variable with the **opsz** and wght axes, and Jost normal (variable wght). Store them in `app/assets/fonts/`.
   - Write `fonts.css` with the same `@font-face` rules: `font-display: swap`, Google's `unicode-range`s, and local URLs that Propshaft fingerprints. Check the compiled CSS.
   - Add the OFL licence texts. Get them from `github.com/google/fonts` (`ofl/bodonimoda/OFL.txt`, `ofl/jost/OFL.txt`).
   - Preload the latin Jost and Bodoni (normal) files.
   - Verify in a screenshot that the wordmark and titles render in Bodoni Moda, with optical sizing working: hairlines at 96px are finer than at 21px.
3. **Stylesheets:**
   - **`site.css`:** copy `design/site.css` verbatim, then delete only the demo selectors (`.is-demo`, `.hover-label.is-on`), keeping the rest of each selector list.
   - **`layout.css`:** turn every inline layout value from the artboards (DESIGN.md "Components" and overview §5) into classes, with names you choose and document. Include the container, header, nav, the visually hidden h1, per-page `main` padding, the Obra grid and tile, both hover-label insets, the artwork page parts, the Torn Posters intro and photo image, Sobre mí, Contacto, the admin-preview notice and the 404.
   - Keep the canvas values exactly: clamps, gaps, line-heights, letter-spacing, `text-wrap`.
   - `body { margin: 0 }`, with `.page`'s background, colour and font on `body`. No global reset.
   - Style the rich text that Action Text/Lexxy renders so it matches the canvas:
     - Sobre mí: paragraphs at 16/1.75, `text-wrap: pretty`, 24px between paragraphs.
     - Artwork text: 15/1.75 in Ink 2.
     - Links inside both use `.text-link` styling.
   - Link the stylesheets **by name** in the public layout (overview §4.6).
4. **Layout and shared partials:**
   - `<html lang="es">`;
   - `<title>` "page — wordmark", meta description, canonical, Open Graph and Twitter `summary_large_image` tags with absolute URLs;
   - the favicon `<link>`s only when `Site#favicon` is attached;
   - font preloads and the three stylesheets. **No JavaScript tags, no `csrf_meta_tags`.**
   - Header partial: the wordmark links to `/`; `<nav aria-label>` comes from `public.es.yml`; `aria-current="page"` marks the current section, and **Obra** stays current on artwork pages, as in the canvas.
   - Delete the Rails default `public/icon.*` files, `406-unsupported-browser.html` and `public/robots.txt`, plus any references to them. The static robots file would shadow the dynamic `/robots.txt` route.
5. **Controllers:**
   - `ArtworksController#index/#show`, `TornPostersController#index`, `PagesController#about/#contact`, `SitemapsController#show`, `RobotsController#show`, `ErrorsController#not_found/#internal_error`.
   - Give them a common public base (e.g. `PublicController`) with `allow_unauthenticated_access`, the public layout and a `site` helper.
   - Set `config.exceptions_app = routes` in `config/application.rb`, or in an initializer you own if that's cleaner.
   - **Unpublished artwork:** visitors get a 404; a logged-in admin (`authenticated?`) sees the page with the admin-only notice. Send `Cache-Control: private, no-store` on previews.
   - Never write the session on public requests.
   - Optionally, `fresh_when` ETags built from the `Site` and record `updated_at`s.
6. **Views, page by page, against the artboards:**
   - **Obra (`/`):** the hidden h1 is `nav_work_label`. Then the grid of `a.work > figure.work-frame > img.work-img + figcaption.hover-label`:
     - the frame's inline style is `width: <frame_width_percent>%; aspect-ratio: <W> / <H>`, from `ResponsiveImage`;
     - the label holds the title and "years · medium", following the hide-empty rules. Years always render through `years_label` (`2024` or `2023–2024`), here and on every page.
   - **Artwork (`/obra/:slug`):**
     - the back link;
     - the hero image (eager, `fetchpriority="high"`, the hero drop-shadow);
     - the text column: h1, then `dl` rows (Año, Técnica, Medidas, each hidden when empty), then the description, then the "Ver los N detalles" link, using `view_detail_one_label` when N = 1;
     - the details section (lazy, flat, `figure.detail` on `--surface`);
     - prev/next with the arrows, hiding a missing side.
   - **Torn Posters:**
     - the hidden h1, then the intro paragraph;
     - `.photo-grid` of `figure.photo#poster-<id>`, each with an `<img>` (`width:100%; height:100%; object-fit:cover`) and the label (place, then "city · years").
     - No "Foto 01" captions.
   - **Sobre mí:**
     - the portrait (4:5 crop variants), hidden without an image;
     - the `.label` h1, the lead, the rich-text body, and the contact link labelled `about_contact_link_label`.
   - **Contacto:**
     - the `.label` h1, the headline, and the email `mailto:` link when set;
     - the Instagram row when a handle exists: `instagram_label` above "@handle", linking to the profile.
   - **404:** the same structure as Contacto. `.label` "404", a Bodoni headline (`not_found_title`), body text (`not_found_text`), and a text link to `/` (`not_found_link_label`). Status 404.
   - **Static fallbacks:** restyle `public/404.html`, `500.html` and `422.html` with inline CSS that uses the tokens and system serif fallbacks. They can't use the database.
7. **Responsive images helper** (e.g. `responsive_image_tag`):
   - It takes a `ResponsiveImage`, `sizes:`, `alt:`, `loading:`, `fetchpriority:` and `class:`.
   - It renders `src` (a middle candidate), `srcset` from `candidates` with `w` descriptors, `sizes`, and `width`/`height` from the metadata, using `url_for(variant)` (proxy route).
   - **Derive `sizes` from the layout math:**
     - content width is `min(100vw, 1440px) − 2·clamp(20px, 4.45vw, 64px)`;
     - the grids use their auto-fill and gap formulas;
     - the artwork hero is capped at 860px tall, so make its `sizes` **per image** with the 860 × W/H cap;
     - the details masonry is 1, 2 or 3 columns;
     - posters are 2, 3 or 4 columns;
     - the portrait is at most 540px wide.

     Err slightly large, and document the strings.
   - **Loading:** follow overview §4.5.
8. **SEO** (overview §4.9):
   - per-page meta descriptions and og:image;
   - `sitemap.xml`: static pages plus published artworks, with `lastmod`;
   - `robots.txt`: disallow `/admin` and `/session`, and give the sitemap URL from the request host.
9. **`bin/screenshots`.** A Ruby tool using selenium-webdriver from the test group:
   - `bin/screenshots --base http://localhost:3003 [--reference] [--widths 1440,768,390,320] [--reduced-motion] [--touch] [pages…]`.
   - It saves **full-page** PNGs to `tmp/screenshots/<run>/<page>-<width>.png`.
   - It uses CDP `Emulation.setDeviceMetricsOverride` for exact widths (window sizing can't go below ~500px), `Page.captureScreenshot` with `captureBeyondViewport`, and `Emulation.setEmulatedMedia` for reduced motion.
   - It prints any page whose `scrollWidth` is greater than `clientWidth`.
   - `--reference` shoots `design/canvas/reference/*.html` instead, so you can compare side by side.
10. **Visual pass.**
    - Shoot reference and app at **1440 and 390** for all five pages, open the PNGs and compare region by region: header, spacing, type sizes, grid geometry, label insets, the artwork page columns, details, prev/next, Sobre mí and Contacto.
    - Fix differences until only the seeded text differs.
    - Then check **768 and 320**: nothing scrolls sideways, and the menu may wrap at 320 (overview §4.9).
    - Hover a tile with Selenium actions and screenshot the label. Tab to a tile and screenshot the focus ring and label.
11. **Tests** (integration tests; they must not depend on WP4 code):
    - **Status:** every page returns 200 with fixtures, **and with an empty database** (all records and the `Site` row deleted).
    - **Preview:** an unpublished artwork gives 404 to a visitor and 200 with the notice to `sign_in_as` an admin.
    - **Hide-empty:** every rule in overview §4.9.
    - **Header:** `aria-current` per page, and the wordmark link.
    - **Tiles:** markup, inline style values, `srcset`/`sizes`/`width`/`height`, the first 3 tiles eager and the rest lazy.
    - **Artwork page:** `dl` rows; the singular and plural details link; prev/next at the edges.
    - **Year ranges:** an artwork and a poster with a range show `2023–2024` (en dash) in the tile label, the `dl` and the poster label.
    - **Copy:** changing a `Site` field changes the page.
    - **Meta:** titles, meta description, og tags and canonical.
    - **Sitemap and robots:** the sitemap lists only published artworks; check the robots body.
    - **404:** it renders in the site layout with status 404.
    - **Privacy:** public responses have **no `Set-Cookie`**, there are **no `<script` tags** in public HTML, and the CSP header is present.
12. **Quality gate and handoff:**
    - the full suite, RuboCop, Brakeman and the audits are clean;
    - `docs/handoff/WP3.md` lists the class names, the `sizes` strings, the helper API, the screenshot-tool usage, where the reference and app screenshots live, and the remaining visual differences with their reasons.

    Commit.

## Acceptance

- [ ] All five pages and the 404 match the canvas at 1440 and 390, apart from seeded text. There are no sideways scrolls at 768 or 320.
- [ ] The labels show on hover and keyboard focus, are absent on touch (`hover: none`), and use opacity only under reduced motion. This comes from `site.css`; verify it isn't broken.
- [ ] Every image has width, height, srcset and sizes; the first row is eager and the rest lazy; there is no layout shift while images load.
- [ ] The public pages contain no JavaScript, set no cookies and have no hard-coded copy, apart from screen-reader-only strings in `public.es.yml`.
- [ ] Tests, RuboCop and Brakeman are clean, and every step is committed on your branch.

## Report back (at most 25 lines)

- status;
- branch name and last commit;
- test counts;
- files touched outside your ownership, if any, and why;
- the remaining visual differences;
- anything the user must decide.
