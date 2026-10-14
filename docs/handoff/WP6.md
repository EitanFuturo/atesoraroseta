# WP6 handoff: integration, QA and the final handoff

Status: **done.** WP5, WP3 and WP4 are merged into `main`, every check is clean, and the README is written. Every item of DESIGN.md "Done when" and PROMPT.md "Quality" passes; the evidence is below.
The fixes are small: no defect needed a design change, and every decision in overview §4 stands. Six open items need the user's decision (section 6).

Final gate on `main` (`bin/ci`):
- RuboCop: 145 files, no offenses;
- bundler-audit and importmap audit: clean;
- Brakeman: 0 warnings;
- **349 tests** (2,444 assertions) and **22 system tests** (136 assertions), all passing;
- the test seeds load.

`bin/rails zeitwerk:check` and `CI=1 bin/rails test` (eager loading) pass too.

## 1. Integration

### 1.1 Merges

Each branch was merged with `git merge --no-ff`, in the plan's order. After each merge I ran `db:prepare` and the tests; after the last, the system tests too.

| Order | Branch | Merge commit | Tests after it |
|---|---|---|---|
| 1 | WP5 `worktree-agent-ae9a9e4e54ecb7ece` (9bb0c63) | `d3b928c` | 206 green |
| 2 | WP3 `worktree-agent-a896ebcca2f33e6d8` (fa05c0c) | `39f8fd8` | 266 green |
| 3 | WP4 `worktree-agent-a65654b078e098a74` (c1cc216) | `5b727b7` | 347 green, plus 20 system tests |

- **No textual conflicts:** no two branches touched the same file.
- **The Gemfile is unchanged**, so `bundle install` had nothing to do.
- **Worktrees:** all three were clean (ignored files only) and have been removed. **The three branches are kept**, all fully merged; `git branch -d <name>` deletes them.

### 1.2 The five integration points

1. **Login page.** The merged `SessionsController` uses WP4's `layout "admin"`.
   - No test, view or controller relied on WP3's public-layout login. The only public-layout user outside the public site was that login.
   - WP3's view-level `SiteHelper#site` stays as a harmless fallback; only its comment was out of date (`5ef93fe`).
2. **`tmp/screenshots/`.** `script/admin_screenshots.rb` now writes to `tmp/page-screenshots/admin/`, next to `bin/screenshots`' runs (`c308296`). `bin/setup`/`bin/ci`'s `tmp:clear` no longer trips on it.
3. **Direct uploads.** Checked against a server started after the merge (the fresh clone's):
   - a logged-out `POST /rails/active_storage/direct_uploads` *with a valid CSRF token* gets **401**, and no blob is created;
   - without a token it gets 422;
   - logged in, the full upload works: a signed id, then `PUT` of the bytes (204), with the file stored.
4. **Lexxy inline styles.** Pasted HTML never puts a `style` attribute in public HTML, for two independent reasons:
   - Lexxy 1.0.1's own sanitiser keeps only `color` and `background-color` in `style`, and with highlights off (WP4) it drops those too. **Pasted `text-align` and colours are never even saved:** the stored HTML is plain `<p>…</p>`.
   - WP3's `public_rich_text` strips any `style` that is stored anyway (WP3's `public_pages_test` covers this).

   A new system test pastes styled HTML into both editors, saves, and checks both public pages (`6153aa3`, `test/system/rich_text_paste_test.rb`). WP4's "pasted text can carry text-align" is therefore not what reaches the database with Lexxy 1.0.1.
5. **Deleted files.** No merged code points at `406-unsupported-browser.html`, `app/views/pwa/*`, the default icons or `public/robots.txt`; the only mention is a comment explaining the `block:`.
   - An old Safari (iOS 15) gets WP4's Spanish 406 page on `/session/new`, and `/admin` still redirects it to the login.
   - Public pages answer 200, with no browser gate.
   - `/robots.txt` is served by `robots#show`.

## 2. QA results and evidence

All evidence is in the main checkout's `tmp/`, which git ignores, so it stays on this Mac only:
- screenshots: `tmp/page-screenshots/wp6-*`;
- Lighthouse reports: `tmp/lighthouse/*.json`;
- the final CI log: `tmp/wp6-final-ci.log`;
- the QA scripts I wrote: `tmp/wp6-qa/`. They are not committed; their paths point at the deleted clone and port 3006, so adjust those before reusing them.

### 2.1 DESIGN.md "Done when"

| Item | Result | Evidence |
|---|---|---|
| The home page shows only the header and the grid | **Pass** | `wp6-app/obra-*.png`; `<main>` holds only the hidden h1 and the grid |
| Labels on hover and keyboard focus, never on touch | **Pass** | Hover: opacity 0→1, `translateY(8px)`→none, 60 ms delay, frame −6 px, shadow rest→lift. Focus: every tile shows its label and the ochre ring at offset 10. Touch (`hover: none`): every label is `display: none` |
| Every tile links to its artwork page, which shows every detail photo | **Pass** | 10/10 tiles match the published works in order, all 200; obra-01 shows 8 of 8 details |
| Each page matches the canvas at 1440 and 390 | **Pass** | `wp6-app/` vs `wp6-reference/`, diff images in `wp6-diff/`, side-by-side crops in `wp6-crops/`; see 2.3 |
| Nothing scrolls sideways at 320 | **Pass** | None at 1440, 768, 390 or 320, on any page or the 404 |
| No layout shift as images load | **Pass** | Every `<img>` has width and height. On a throttled network the worst CLS is **0.0135**, all of it font swap; images shift nothing. Lighthouse CLS is 0 |
| Lighthouse accessibility ≥ 95 | **Pass** | **100** on all five pages (2.4) |
| Reduced motion is respected | **Pass** | Under `prefers-reduced-motion: reduce`: no transform at rest or on hover, and only `opacity` transitions, on tiles, frames, images, labels and posters |

### 2.2 PROMPT.md "Quality"

| Item | Result |
|---|---|
| Model validation tests | **Pass** (WP2, plus the new slug test) |
| Public pages render with and without content | **Pass** (WP3's integration tests); also checked live in production mode on an empty database (2.5) |
| The admin requires login | **Pass** (WP4's tests); also checked live on every route (2.7) |
| System tests: an artwork with images, uploading details, reordering, editing Sobre mí | **Pass** (WP4's 20, plus 2 new) |
| `bin/rubocop` and `bin/brakeman` clean | **Pass** |
| "Done when" at 1440, 768, 390 and 320, keyboard only, reduced motion on | **Pass**: every page tabbed at all four widths with reduced motion emulated; see 2.4 for the touch targets |

### 2.3 Visual QA (step 3)

`bin/screenshots --reference` and `bin/screenshots --base http://localhost:3006`, at 1440, 768, 390 and 320; I looked at every PNG.
- **Page heights** match the canvas to the pixel everywhere except the artwork page on phones.
- **Pixels that differ** (`tmp/wp6-qa/diff.rb`, a threshold of 24 per channel), for Obra, the artwork page at 1440/768/390, Sobre mí and Contacto: **0.07–0.74%**. That is image resampling (the app serves the WebP variants) and seeded text: a real email instead of `[tu-correo@dominio.com]`, a real year instead of `[Año]`.
- **Torn Posters, 4.3–4.9%:**
  - the canvas's "Foto 01…" captions, which overview §5 says not to ship;
  - the seed images' fainter dot screen.

  The grid geometry is identical.
- **The artwork page on phones:**
  - at 390 it is 80 px shorter, because the first work has no "Anterior" (no wrap-around), where the canvas shows both links;
  - at 320 (45% differ) the seeded title "Obra de muestra 01" wraps onto two lines where "[Título de la obra]" fits on one, which shifts everything below it.

  Everything else is identical (`wp6-crops/obra-detalle-320-top-pair.png`).
- **At 320 the menu wraps onto two rows**, as in the canvas (overview §4.9, accepted).
- **Re-run on the final `main`** (`wp6-final/`, `wp6-final-diff/`): identical numbers and heights.

### 2.4 Behaviour QA (step 4)

**Keyboard**, on all six pages at all four widths, with reduced motion on:
- the order is wordmark, the four menu links, then the page's content in reading order;
- **every stop shows the 2px ochre ring** (offset 4px; on tiles, offset 10px around the frame, plus the label).

**Touch targets** below 44 px, both coming from the canvas's own values:
- the **wordmark** is **43 px** tall below a ~1190 px viewport (27 px type plus 2 × 8 px padding);
- the **Contacto email link** is **27.6–29.6 px** tall up to tablet widths (Bodoni at `clamp(24px…)` / 1.15, with no padding).

Everything else is ≥ 44 px. Both pass WCAG 2.2 AA's 24 px minimum and are wide; see section 6, item 1.

**Touch**: under touch emulation, a tap on the first tile opens its artwork page.

**CLS** on a throttled network (150 ms latency, 1.6 Mbit/s, cache off, scrolling through the page; `tmp/wp6-qa/cls.rb`):

| Page | 390 | 1440 |
|---|---|---|
| Obra | 0.0003 | 0.0002 |
| Artwork | 0.0007 | 0.0006 |
| Torn Posters | 0.0003 | 0.0002 |
| Sobre mí | 0.0112 | 0.0016 |
| Contacto | 0.0014 | 0.0017 |
| 404 | 0.0016 | 0.0135 |

Every shift is web-font swap text (the Bodoni lead and headlines); none comes from an image.

**Lighthouse 13.5.0** (mobile, simulated throttling, against the dev server, which serves uncompressed HTML and CSS):

| Page | Accessibility | Performance | Best practices | SEO | LCP | CLS |
|---|---|---|---|---|---|---|
| Obra | **100** | 76 | 96 | 100 | 7.2 s | 0 |
| Artwork (obra-01) | **100** | 78 | 96 | 100 | 5.9 s | 0 |
| Torn Posters | **100** | 99 | 96 | 100 | 2.0 s | 0 |
| Sobre mí | **100** | 99 | 96 | 100 | 2.3 s | 0 |
| Contacto | **100** | 100 | 96 | 100 | 1.5 s | 0 |

- **Every page:** FCP 1.1–1.3 s and TBT 0 ms.
- **Best practices is 96** only because of the `/favicon.ico` 404 (section 6, item 2).
- **The LCP on Obra and the artwork page** is the sample cut-out's 1200 px WebP variant, 586 KB at quality 82 (section 6, item 4).
- **The 404 page can't be audited:** Lighthouse refuses any 404 response. It uses Contacto's structure, which scores 100.

`npx` failed here with `EACCES`, because `~/.npm` holds root-owned files. I ran Lighthouse with a private cache (`npm_config_cache=/tmp/… npx …`) and deleted it afterwards. To fix your cache: `sudo chown -R 501:20 ~/.npm`.

### 2.5 Content states (step 5)

The clone ran in production mode on port 3007, with an empty database prepared by `db:prepare`, which runs the production seeds.
- **Every public page renders** with only the defaults:
  - no bracketed text and no empty element in `<main>`;
  - Obra has only the hidden h1 (no empty grid), and Torn Posters only the intro;
  - Sobre mí shows the lead and "Escríbeme" (no portrait, no body);
  - Contacto shows the headline only (no email link, no Instagram row);
  - unknown URLs get the site 404 with the CSP;
  - no cookies and no scripts anywhere.
- **400 and 422** render the restyled static pages with the CSP.
- **One artwork with exactly one detail:**
  - no previous/next nav, and the link reads "Ver el detalle";
  - **`2023–2024`** appears on the tile label ("2023–2024 · Técnica"), the artwork page and a poster label ("Madrid · 2023–2024");
  - the og image is a real 1200×630 JPEG.

  Screenshots: `wp6-production-one-artwork/`.
- **In the admin:** `2023-24` saves and reads back as `2023–2024`, and "hacia 2020" gets "Escribe un año (2024) o un periodo (2023–2024)".

### 2.6 Admin QA (step 6)

Done in a browser as a throwaway user (created in the clone's development database, then deleted) against the fresh clone's server. Every change was checked on the public site as a logged-out visitor. Script: `tmp/wp6-qa/admin_qa.rb`; screenshots: `wp6-admin/01…12`. 58 of 59 checks passed; the one failure was in my script, not the app (below).
- **A new artwork:** image, alt text, description, `2023-24` and unpublished.
  - The size (460 × 600 px) and the low-resolution warning show.
  - While logged in, the preview notice shows; a logged-out visitor gets **404** and the grid doesn't list it.
- **Two details uploaded at once**, with their alt texts saved and then reordered. After publishing and moving the work down one place, it is second on the grid, with the right label, "Ver los 2 detalles", the details in the new order, its description and alt text, and Anterior/Siguiente.
- **Wrong files:**
  - a `.txt` and a 26 MB file are refused before uploading, with Spanish messages;
  - a PDF renamed `documento.jpg` is refused by the server ("Imagen tiene un formato no admitido").
- **Two posters bulk-uploaded:** unpublished at the top, then filled in and published with "Marcar todas como publicadas". Their labels ("Calle de Atocha Madrid · 2023–2024", "Lisboa · 2019") and alt text show.
  - The single failed check was on this step: "two unpublished posters at the top". The data was right; my script compared `TornPoster.count` twice inside `bin/rails runner`, where the query cache answered the second count from the first.
- **Sobre mí:** the lead, body, link label and portrait with its alt all show, and the meta description follows the lead.
- **Contacto:** headline, email (as a mailto link), Instagram label, and a pasted profile URL stored as the handle `estudio.qa`.
- **Every one of the 18 site texts** was changed and found where it belongs:
  - the menu, wordmark and page titles;
  - the hidden h1s, back link and Sobre mí/Contacto h1s;
  - the posters intro;
  - the details, data and previous/next labels;
  - "Ver los %{count}…" and the one-detail label;
  - the SEO description and the 404 texts.
- **The social image and favicon uploads:** og:image becomes the uploaded JPEG, the three icon links appear, and each upload gets its own warning (size, squareness).
- **The admin's browser console** logged no errors and no CSP violations.

### 2.7 Security QA (step 7)

| Check | Result |
|---|---|
| Signed out, every `/admin` route unreachable | **Pass.** All 34 routes, with real ids: GETs redirect to `/session/new`; other verbs get 422 without a token and a redirect to the login with a valid token. The database was unchanged |
| The login rate limit fires | **Pass.** Attempts 1–5 get "El correo electrónico o la contraseña no son correctos.", and 6–7 get "Demasiados intentos…". Checked in development (memory store) and in production mode (Solid Cache) |
| CSP header present; no CSP violations | **Pass.** On public pages, admin pages and error pages; both browsers' consoles were clean |
| Public pages: no cookies, no scripts | **Pass.** No `Set-Cookie` and no `<script>` on any public page or the 404 |
| Strong params | **Pass.** Every `permit` is an explicit list. A forged PATCH with `position`, `year`, `year_end`, `created_at` and `id` changed only the permitted fields, and the site-texts form can't change the Contacto email |
| Brakeman | **Pass** (0 warnings) |
| No secrets in git | **Pass.** `git log -p` gives 903 matching lines (706 unique added ones). I filtered them for literal values assigned to secret-like names and for token shapes (private keys, AWS/DigitalOcean/GitHub tokens), then reviewed every hit: all are test throwaways (`contraseña-de-prueba-1`, `old-password-123`…) or labels. No key or `.env` file was ever committed, and none is tracked |
| The real admin password nowhere | **Pass.** `git log -p --all`: **0**; `git grep`: **0**; the working tree's text files, untracked and ignored ones included (`log/`, `tmp/`; not `.git` or `storage/`, which holds only the databases and uploads): **0**; the clone and my temp files: **0**. The value was only ever in a shell variable, never printed |
| No password recovery | **Pass.** No password routes (`/passwords/new` is 404), no controller, mailer or views, and no "olvidado"/"forgot" link |

In production mode the login page sets `secure; httponly; samesite=lax` and sends HSTS.

### 2.8 Beyond the plan: the merged production image

WP5 rehearsed the image before WP3 and WP4 existed (`/` raised then), so I built the merged image once: `docker buildx build --builder desktop-linux --platform linux/amd64`, which took 1m41s.
- **Boot:** with a throwaway `SECRET_KEY_BASE` and no master key, it booted in about 6 s. `db:prepare` seeded the defaults, and `admin:sync` warned and skipped.
- **Routes:** every public page answers 200; an unknown page gets the site 404; `/admin` redirects to the login.
- **Thruster:** HTML is gzipped, the CSP is present and no cookie is set. Fingerprinted CSS and fonts get a year-long cache.
- **Images:** `ImageAttachments.avif_supported?` is `true` (libvips 8.16.1).

The container and the image were removed, and Docker Desktop, which was not running before, was stopped again.

## 3. Fixes (one commit each)

| Commit | What |
|---|---|
| `c308296` | `script/admin_screenshots.rb` writes to `tmp/page-screenshots/admin/` (integration point 2) |
| `6153aa3` | System test: pasted rich-text styles never reach the public pages (integration point 4; no code change was needed) |
| `5ef93fe` | `SiteHelper`'s comment no longer says the login renders in the public layout (integration point 1) |
| `d734d97` | **Underscores in a title become hyphens in its slug** (WP4's open issue 3) |
| `7e0e20b` | The README |

About `d734d97`:
- **The bug:** `parameterize` keeps `_`, which `SLUG_FORMAT` refuses. A title like "obra_azul" therefore made a blank or cleared slug invalid wherever the JavaScript didn't fill it, for example when clearing the slug of an existing work.
- **The fix:** the new `Artwork.slug_from(title)` is used by the model and by the admin's check for an automatic slug, so a taken automatic slug gets `-2` there as well.
- **Tests:** a model test and a controller test, both failing before the fix.

## 4. How to verify

```sh
bin/ci                                             # all green
bin/rails server -p 3006                           # then, in another terminal:
bin/screenshots --reference --run ref              # the canvas
bin/screenshots --base http://localhost:3006 --run check   # prints any sideways scroll
npx lighthouse http://localhost:3006/ --only-categories=accessibility --chrome-flags="--headless=new" --output=json --output-path=tmp/lh.json
bin/rails admin:sync                               # "Admin: admin@atesoraroseta.com sin cambios."
```

## 5. Deviations and decisions

1. **Production-mode checks.** The clone also ran briefly in production mode on **port 3007** (besides 3006), with an empty database, for the production seed path, the error pages and the rate limit with Solid Cache. It was stopped afterwards.
2. **The Docker image build** (2.8) is beyond the plan. I did it because the merged image had never been built, and cleaned up after it.
3. **Clean-up:**
   - the fresh clone at `/tmp/wp6-fresh`, its copied `master.key`, the throwaway password file, the cookie jars and the private npm cache are deleted;
   - the throwaway QA user was deleted;
   - the main checkout's development database was not modified.
4. **The merged branches are kept**, since the plan only asks to remove the worktrees.
5. **Not fixed, reported instead** (section 6), because each one touches design values or needs a decision.

## 6. Open items for the user

New from WP6:
1. **Touch targets** (2.4): at most viewport widths the wordmark is 43 px tall, and on phones and tablets the Contacto email link is 28–30 px. Both come from the canvas. To reach 44 px without moving anything, enlarge only the tappable area:
   - email: `padding-block: 8px; margin-block: -8px`;
   - wordmark: `padding-block: 8.5px`, which shifts the header by 1 px.

   **Keep the canvas values, or apply this?**
2. **`/favicon.ico` is a 404 until a site icon is uploaded** (WP3's open issue 1). It costs Lighthouse best practices 4 points. Uploading the icon in Textos del sitio fixes it. Otherwise, WP3 proposes `<link rel="icon" href="data:,">` when no icon exists.
3. **A plain text file renamed `.jpg` passes the type check.** Active Storage identifies content with no recognisable bytes by its name; PDFs, SVGs, GIFs and HTML disguised as images are refused. It needs deliberate renaming, and ends with the admin's "No se ha podido leer el tamaño…" warning and a broken image. Proposed fix: check the JPEG/PNG/WebP/AVIF signature bytes in `ImageAttachments`. Low priority.
4. **Mobile performance on Obra and the artwork pages (Lighthouse 76/78)** is image-bound. The 1200 px WebP of a 1200–2400 px cut-out weighs about 0.6 MB at quality 82 (WP2's `WEBP_QUALITY`). The options:
   - lower the quality of the large variants;
   - add a ~900 px variant (a change to overview §4.5);
   - accept it.

   Judge with the real photos.
5. **Font-swap shifts** (CLS ≤ 0.014 on slow connections, from the Bodoni headlines) are well under the 0.1 "good" limit. Preloading the italic file or size-adjusted fallback fonts would remove them. Optional.
6. **The merged `worktree-agent-*` branches** can be deleted (`git branch -d`).

Still open from earlier handoffs; details in each note:
- **WP1:** libvips on this Mac (the local build, or Homebrew), and Homebrew's broken `libheif`.
- **WP2:** favicon/og sizing, the sRGB conversion, WebP/JPEG quality, the 17 required labels, and the old user left working after an admin email change.
- **WP3:** the favicon fallback (item 2), Jost italic, and the wording of the static 400/422/500 pages. Also:
  - direct visits to `/404` and `/500` return the static files with status 200;
  - the development-only view annotations.
- **WP4:**
  - the `allow_browser :modern` requirement (Safari 17.2+) for the admin;
  - rich text limited to bold, italic and links;
  - an SVG favicon;
  - the email field emptied after a wrong password;
  - unattached blobs from abandoned uploads, which a periodic purge could remove.
- **WP5, values to provide before deploying:**
  - the droplet's IP and size, and its region;
  - the registry name, account email and token, and plan;
  - the Spaces region, bucket and scoped keys;
  - the DNS A records;
  - a copy of `config/master.key` in a password manager.
- **WP5, decisions:**
  - **does the droplet already serve anything on ports 80/443?**
  - nightly or hourly uploads backup;
  - DigitalOcean droplet backups as a second net.
- **WP5, notes:** the kamal-proxy `Expect: 100-continue` quirk affects scripts only, and some DigitalOcean labels are unverified.
