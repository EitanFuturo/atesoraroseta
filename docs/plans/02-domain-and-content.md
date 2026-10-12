# WP2: Domain models, image pipeline core and seeds

**Runs in:** the main checkout. **Depends on:** WP1 (read `docs/handoff/WP1.md`).
**Next:** WP3, WP4 and WP5 start in parallel from your final commit, so your handoff note is their contract. Make it precise.
**Read first:**
- `docs/plans/00-overview.md`, especially §4.2–4.5, §4.9 and §6;
- `design/PROMPT.md` (Back office and Seeds);
- `design/DESIGN.md` (Content model and Images);
- `design/canvas/README.md`.

## Goal

Everything below the views:
- the models with validations, ordering, attachments, variants and metadata;
- the settings singleton and its defaults;
- routes;
- admin-user creation;
- development and production seeds;
- fixtures and model tests.

Also a small, tested **image API** that the public views (WP3) and the admin (WP4) both use.

## You own

- `app/models/**` (including concerns and plain Ruby objects);
- `db/**`;
- `config/site_defaults.yml` (or an equivalent single source);
- the initial `config/routes.rb`;
- `lib/tasks/admin.rake`;
- `test/models/**`, `test/fixtures/**`, `test/test_helper.rb`, `test/lib/**`;
- `docs/handoff/WP2.md`.

## Steps (commit after each)

1. **Migrations and models**, exactly as in overview §4.2: `Artwork`, `ArtworkDetail`, `TornPoster`, `Site`.
   - **Constraints:** add null constraints, defaults, a unique index on `artworks.slug`, and FK and position indexes.
   - **Validations** in Spanish, through `rails-i18n` plus `config/locales/es.yml` for the model and attribute names. The attribute names are the admin labels from §4.3, e.g. `title` → "Título", `medium` → "Técnica", `dimensions` → "Medidas".
   - **Behaviour:**
     - slug generation and dedupe;
     - the **year-range concern** (overview §4.2 "Year ranges"): `year` / `year_end` validation, the `years` virtual attribute with its parser, and `years_label` with an en dash;
     - the `published` and `ordered` scopes;
     - `previous` / `next` without wrap-around;
     - the alt fallbacks;
     - Instagram handle normalisation and email format.
   - **Settings:** `Site.current` (unsaved defaults when there is no row) and `Site.first_or_create!` for the admin.
2. **Image concern**, shared by all four models:
   - **Validation:** content type and 25 MB limit. AVIF is accepted only when vips supports it.
   - **Variants:** the named variants from §4.5, with `preprocessed: true` on the public ones.
   - **Synchronous analysis** right after attach. Write a test that `metadata["width"]` and `metadata["height"]` exist right after `save`.
   - **Helpers:** `low_resolution?`, plus width, height and aspect ratio.
   - **Model-specific variants:**
     - poster squares;
     - portrait 4:5 crops;
     - the `og` JPEG at 1200×630, contained and padded on `#222221` with any alpha flattened;
     - favicon PNGs.
3. **Image API for views.** A plain Ruby object (e.g. `ResponsiveImage`) built from an attachment and a variant family (`:width`, `:square`, `:portrait`). It exposes:
   - `width` and `height` from the original's metadata;
   - `candidates`: the existing variants and their **actual** pixel widths (deduped, never upscaled, plus the original width when it is smaller than the largest variant);
   - for artworks, `frame_width_percent`: `min(100, 125 × w / h)` rounded to 2 decimals (1179×1571 gives 93.81), and `aspect_ratio_css` (`"1179 / 1571"`).

   It must **not** build URLs or HTML; WP3 does that with Rails helpers. Unit-test it with the sample sizes in `design/canvas/README.md`, e.g. 300×560 gives 66.96, 620×480 gives 100 (the canvas writes `100%`), and 460×600 gives 95.83.
4. **Routes:** the public and auth routes plus the empty admin root, exactly as in overview §4.4. Routes may point at controllers that don't exist yet (WP3 and WP4 add them). Make sure `bin/rails routes` works.
5. **Admin user** (overview §4.7).
   - **`bin/rails admin:sync`:**
     - reads `admin.email` / `admin.password` from `Rails.application.credentials`; the `ADMIN_EMAIL` / `ADMIN_PASSWORD` environment variables override them when set;
     - creates the user, or updates its password only when it differs (`authenticate` first);
     - **deletes all that user's sessions when the password changed**;
     - prints what happened, **never the password**;
     - when neither source exists, prints a warning and exits 0.
   - Put the logic in a model or class method so the seeds and WP5's Docker entrypoint reuse it.
   - Test it with stubbed credentials and env: create, update, unchanged, sessions deleted on change, and missing.
   - **`bin/rails admin:credentials`** writes `admin.email` and `admin.password` into `config/credentials.yml.enc` (overview §4.7).
     - **Interactive:** it prompts for the email (default: the current one, or `admin@atesoraroseta.com`) and the password twice, with no echo (`IO#noecho`). It requires at least 12 characters.
     - **Non-interactive:** when `ADMIN_EMAIL` and `ADMIN_PASSWORD` are set, it uses them without prompting.
     - Write through `Rails.application.credentials` (`ActiveSupport::EncryptedConfiguration#read` / `#write`). Keep the existing content and its comments, and replace an existing `admin:` block.
     - It prints "Guardado. Despliega para aplicarlo en producción." and never prints the password.
     - Test the core logic against a **temporary** encrypted file and key, never the real credentials. In this WP, don't run it against the real `config/credentials.yml.enc`; the orchestrator does that after you finish.
   - Never put the real password in any file. Tests use throwaway values.
6. **Seeds**, organised so production safety is testable, e.g. `db/seeds.rb` delegating to `db/seeds/{all,development}.rb` or to a class in `lib/`.
   - **All environments:**
     - create the `Site` record with the production defaults (§4.3);
     - run the admin sync from step 5. With no credentials or environment variables, it warns and continues, so neither `bin/setup` nor the first production boot fails.
   - **Development only:**
     - the sample content from overview §6, built from `design/img/*`: canvas order, canvas alt texts, obra-01's 8 details in canvas order, and the bracketed texts;
     - 12 tinted 1600×1600 dot-screen posters and the placeholder portrait, generated with ruby-vips into temporary files at seed time. Don't commit binaries.
     - All sample records are `published: true`.
     - Give one stand-in artwork and one poster a year range (e.g. 2023–2024), so the range display shows in development.
   - **Idempotency:** running the seeds twice must not duplicate anything (use `find_or_create_by` on slug or title).
7. **Fixtures and helpers:**
   - Small fixture images in `test/fixtures/files/`: copy `obra-01.webp` and one detail JPG from `design/img`, generate one image under 1600px, and add one non-image file.
   - Active Storage fixtures (`test/fixtures/active_storage/{blobs,attachments}.yml`) whose blobs carry **analyzed metadata** (width and height), so views can render without analysis.
   - Model fixtures: published and unpublished artworks, details, posters, and a site row.
   - Make the generator's `SessionTestHelper#sign_in_as` available to integration and system tests.
8. **Tests** (`test/models/**`, `test/lib/**`):
   - every validation, including type, size, AVIF gating and required images;
   - year ranges: every accepted input form, including `2023-24`, blank and the invalid cases with the Spanish error; `year_end > year`; display; ordering by `COALESCE(year_end, year)`;
   - slug generation, collisions and editing;
   - ordering and acts_as_list moves;
   - `previous` / `next` at the edges and with unpublished works in between;
   - the alt fallbacks;
   - `low_resolution?`;
   - Instagram normalisation;
   - `Site.current` without a row;
   - `ResponsiveImage`;
   - that one real variant (from a fixture file) processes and keeps alpha;
   - **production seeds** (or the production path called directly): no artworks, posters or details; no `[` in any `Site` field; the admin is created only through the credentials/env sync.
9. **Quality gate:** `bin/rails db:seed:replant` works in development, then the tests, RuboCop, Brakeman and the audits are all clean. Commit.
10. **Handoff** (`docs/handoff/WP2.md`): the contract for WP3, WP4 and WP5.
    - the schema;
    - every model method and scope meant for views or the admin;
    - the variant names per attachment;
    - the `ResponsiveImage` API with an example;
    - `Site` fields and how defaults load;
    - the routes and their helper names;
    - fixtures available to tests, and how to sign in in tests;
    - how the admin sync works and how to log in locally (credentials via the master key; never write the password down);
    - anything left for others.

    Commit.

## Acceptance

- [ ] `bin/rails db:reset` (or `db:seed:replant`) gives:
  - 9 published artworks in canvas order;
  - obra-01 with 8 details in canvas order;
  - 12 posters;
  - a `Site` row with the defaults;
  - the seeds calling the admin sync, which warns and skips while the credentials have no `admin` entry; the orchestrator adds it after you.

  Running the seeds twice changes nothing.
- [ ] After processing, every seeded image has width and height metadata and its preprocessed variants. Check with `bin/jobs`, or by running the transform jobs inline.
- [ ] The production seed path creates only the `Site` defaults and the env-based admin, with no bracketed text.
- [ ] Model and lib tests cover everything in step 8, and the full suite, RuboCop and Brakeman are clean.
- [ ] `docs/handoff/WP2.md` is precise enough that WP3 and WP4 can work without reading your code first.

## Report back (at most 20 lines)

Status, commit range, the test counts (runs, assertions, failures), any deviation from overview §4, and anything the user must decide.
