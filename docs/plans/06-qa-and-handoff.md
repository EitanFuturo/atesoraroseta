# WP6: Integration, QA against "Done when", fixes, and the final handoff

**Runs in:** the main checkout, after WP3, WP4 and WP5 have finished on their own branches. The orchestrator gives you the branch names.
**Depends on:** everything. Read every `docs/handoff/WP*.md`; the WP3–5 notes are on their branches until you merge them.
**Read first:**
- `docs/plans/00-overview.md`;
- `design/PROMPT.md` (Quality, and How to work point 4);
- `design/DESIGN.md` ("Done when");
- `design/canvas/README.md`.

## Goal

Prove the build meets PROMPT.md and DESIGN.md, fix the defects you find, and write the README the user will start from.

You can fix bugs anywhere. You may **not** change the design or any decision in overview §4. Report those instead, each with a proposed fix.

## Steps (commit each fix separately)

0. **Integrate.**
   - With `main` clean, merge the three branches **in this order: WP5, WP3, WP4**, each with `git merge --no-ff`.
   - **Conflicts:**
     - resolve them by overview §7.2: the owning WP's version wins for files it owns;
     - for shared files (`Gemfile`/`Gemfile.lock`, `config/application.rb`, initializers, `config/routes.rb`, `config/locales/es.yml`), keep both sides' intent;
     - after merging the Gemfile, run `bundle install` to regenerate the lock file.
   - **After each merge:** run `bin/rails db:prepare`, then `bin/rails test`. Fix any breakage the merge caused in its own commit before the next merge.
   - **After the last merge:** run `bin/rails test:system` too.
   - **Clean up:** remove the agents' worktrees with `git worktree list` / `git worktree remove <path>`, but **only if they have no uncommitted changes**. Report any you left in place.
1. **Fresh start.**
   - In a clean clone of `main` (e.g. `git clone . /tmp/...` inside your scratchpad), copy `config/master.key` from the main checkout (never commit it), then run `bin/setup --skip-server`. The seeds use the key to create the admin from the credentials.
   - Confirm the dev seeds load and the variants process.
   - Run the server on port **3006**.
2. **Automated checks:**
   - `bin/rails test` and `bin/rails test:system`;
   - `bin/rubocop` and `bin/brakeman --no-pager`;
   - `bin/importmap audit`, and `bin/bundler-audit` if present.

   Every one must be clean.
3. **Visual QA.** Use `bin/screenshots` (from WP3) for every public page and the 404, plus `--reference`.
   - Compare to the canvas at **1440 and 390**.
   - Check **768 and 320**: the tool flags any sideways scroll; there must be none.
   - Look at each PNG yourself: header, type, spacing, grid geometry, labels, artwork page, details masonry, prev/next, Sobre mí and Contacto.
4. **Behaviour QA** (Selenium/CDP):
   - **Hover:** the label fades in and rises; the frame lifts 6px with a deeper shadow.
   - **Keyboard only:** Tab through every page. The focus ring is visible everywhere (2px ochre at offset 4; on tiles, a ring at offset 10 plus the label), the order is logical, and the touch targets are 44px.
   - **Touch:** under touch emulation (`hover: none`) no labels appear, and a tap opens the artwork.
   - **Reduced motion:** under `prefers-reduced-motion: reduce` nothing moves; opacity only.
   - **No layout shift:** CLS is about 0 with a throttled network, and every `<img>` has width and height.
   - **Lighthouse accessibility ≥ 95** on every public page:
     `npx lighthouse <url> --only-categories=accessibility --chrome-flags="--headless=new" --output=json`.
     Note the performance numbers too.
5. **Content-state QA.**
   - With the production seed path (an empty database plus defaults): every page renders and the hide-empty rules hold. No bracketed placeholder shows, and no empty separators or containers appear.
   - With one artwork, check that prev/next is hidden.
   - With exactly one detail, check that "Ver el detalle" appears.
   - A year range shows as `2023–2024` on the tile label, the artwork page and a poster label. In the admin, `2023-24` saves as 2023–2024 and an invalid year shows the Spanish error.
6. **Admin QA** (signed in, in the browser), checking each change on the public site:
   - create an artwork with an image and details, reorder, publish, and confirm it appears;
   - bulk-upload posters, fill them in and publish;
   - edit Sobre mí, Contacto and every site text, and confirm each change appears;
   - check the low-resolution warning, a wrong file type and the over-25 MB guard;
   - preview an unpublished artwork while logged in, and confirm a logged-out visitor gets a 404.
7. **Security QA:**
   - signed out, every `/admin` URL is unreachable;
   - the login rate limit fires;
   - the CSP header is present, and the browser logs no CSP violations on public or admin pages;
   - public responses set no cookies and contain no scripts;
   - strong params hold;
   - Brakeman is clean;
   - there are no secrets in git (`git log -p | grep -iE 'secret|password|key'` and review the hits);
   - the real admin password appears nowhere in the history or the working tree. Run `git log -p --all | grep -c -F "$(bin/rails credentials:fetch admin.password)"` and the same with `git grep`. Both counts must be 0, and never echo the value itself;
   - there is no password-recovery route or "forgot password" link.
8. **Fix what's broken**: one commit per defect, each with a test where practical. Re-run steps 2–3 at the end.
9. **`README.md`**, in English, short:
   - what this is;
   - requirements (Ruby 4.0.7, libvips, Chrome for system tests);
   - setup (`bin/setup`), running (`bin/dev`), the seeds;
   - **how to log into `/admin` locally:**
     - the email and password are in the encrypted credentials (`bin/rails credentials:show`, which needs `config/master.key`);
     - without the key, set `ADMIN_EMAIL`/`ADMIN_PASSWORD` and run `bin/rails admin:sync`;
     - how to change the password.

     **Never print the password in the README** or anywhere else.
   - running the tests;
   - a pointer to `DEPLOY.md`;
   - **content still missing:** the real artworks and their photos (2400px, cut out on transparency where possible); titles, years, medium and sizes; the optional artwork texts; detail photos; Torn Posters photos with place, city and year; the portrait and both bio paragraphs; the email; the Instagram handle; the OG image and favicon; approval of the draft copy (the Sobre mí lead, used as the default SEO description, and the 404 texts).
10. **Handoff** (`docs/handoff/WP6.md`): the checklist results with evidence (screenshot paths and Lighthouse scores), the fixes, and the open items needing the user's decision. Commit.

## Acceptance

- [ ] Every item in DESIGN.md "Done when" and PROMPT.md "Quality" is checked off, with evidence.
- [ ] All checks are clean on `main`, and the README is written.

## Report back (at most 30 lines)

- status;
- a pass/fail table for "Done when" and Quality;
- Lighthouse scores;
- the fixes made;
- open items for the user.
