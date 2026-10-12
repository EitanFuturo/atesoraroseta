# WP1: Toolchain and app skeleton

**Runs in:** the main checkout, `/Users/eitanfuturo/develop/projects/atesoraroseta`, which is not a git repo yet.
**Depends on:** the user's OK. **Next:** WP2.
**Read first:** `docs/plans/00-overview.md` (all of it) and `design/PROMPT.md` (Stack section).

## Goal

A fresh Rails 8.1.4 app on Ruby 4.0.7 in the repo root:
- every framework piece installed and configured;
- every gem from overview §4.1 in the Gemfile;
- all quality tools green;
- the design handoff and plans committed.

It has **no domain models** (WP2 adds them). The only models are the generator's `User` and `Session`.

## You own

- the generated skeleton;
- `Gemfile` and `Gemfile.lock`;
- `config/application.rb`;
- `config/initializers/content_security_policy.rb`;
- `config/locales/es.yml`;
- `.gitignore`, `.rubocop.yml`, `config/brakeman.ignore` (only if needed);
- `docs/handoff/WP1.md`.

Leave the generated auth views alone; WP4 owns them.

## Steps (commit after each one that changes the repo)

1. **Toolchain.** Don't uninstall or upgrade anything you don't need.
   - Run `brew upgrade ruby-build`, then `rbenv install 4.0.7` (skip it if already installed). The compile takes several minutes.
   - Run `brew install vips` and check that `vips --version` works.
   - Install Rails 8.1.4 under Ruby 4.0.7: `RBENV_VERSION=4.0.7 gem install rails -v 8.1.4`.
2. **Git first.** The folder already holds `design/` and `docs/`.
   - Run `git init -b main`.
   - Create `.gitignore` with only `.DS_Store` and `/.claude/` for now.
   - Commit "Add design handoff and build plans".
3. **Generate the app in place:**
   ```
   RBENV_VERSION=4.0.7 rails _8.1.4_ new . --name=atesoraroseta --database=sqlite3 --skip-jbuilder --skip-action-mailbox
   ```
   - Keep every other default: Propshaft, importmap, Turbo and Stimulus, the Solid trio, Kamal, Thruster, rubocop-rails-omakase, Brakeman, the GitHub CI workflow, and bundler-audit if the generator adds it.
   - If a prompt about existing files appears, keep the existing `design/` and `docs/`. Merge `.gitignore` so that `/.claude/` stays.
   - Make sure `.ruby-version` says `4.0.7`.
   - Commit "Generate Rails 8.1.4 app".
4. **Gems** (overview §4.1):
   - **image_processing:** first try `image_processing ~> 2.2` plus `ruby-vips`. Verify that a real Active Storage WebP variant of `design/img/obra-01.webp` processes **with alpha kept**. Use `bin/rails runner` against a throwaway blob, or a temporary test, and purge it afterwards. If that fails, use `~> 1.2` and record why.
   - **Others:** `acts_as_list`, `rails-i18n`, `lexxy` (1.0.x), and `aws-sdk-s3` (`require: false`).
   - Run `bundle install`, then commit.
5. **Installers** (commit each):
   - `bin/rails active_storage:install`.
   - `bin/rails action_text:install`, then switch the editor to **Lexxy** following https://lexxy.dev/docs/ (read the install page; it uses importmap and Propshaft). The goal is that `form.rich_textarea` / `rich_text_area` renders Lexxy, and its JS and CSS load only where a layout includes them. If Lexxy can't work, keep Trix and write down why.
   - `bin/rails generate authentication`.
   - Finish with `bin/rails db:migrate`.
6. **Configuration:**
   - **Locale:** `config.i18n.default_locale = :es` and `available_locales = [:es]`. Create `config/locales/es.yml` with any base keys you need; `rails-i18n` supplies the framework strings.
   - **Active Storage:** `config.active_storage.resolve_model_to_route = :rails_storage_proxy`, and confirm `variant_processor` is `:vips`.
   - **CSP** (`content_security_policy.rb`), exactly as in overview §4.7: a nonce generator of `->(request) { SecureRandom.base64(16) }`, and `content_security_policy_nonce_directives = %w[script-src]`.
   - **`ApplicationController`:** remove `allow_browser versions: :modern` and keep `include Authentication`. WP3 and WP4 add their own base behaviour.
   - **`User`:** add the password length validation (≥ 12 when present).
   - **Translations:** translate the generator's **controller** flash messages, and the rate-limit message, to Spanish. Views stay with WP4.
   - **Tooling excludes:** exclude `.claude/**` and `design/**` in `.rubocop.yml` (`AllCops: Exclude`, keeping the omakase inherit). Make sure Brakeman ignores `.claude` if it would scan it.
   - **No password recovery** (overview §4.7). Delete what the generator made for it:
     - `PasswordsController` and the `resources :passwords` route;
     - `app/views/passwords/`;
     - `PasswordsMailer`, its views and its preview;
     - their tests;
     - the "forgot password" link in `sessions/new`.

     Leave `ApplicationMailer` alone.
   - **Credentials:** leave `config/credentials.yml.enc` exactly as generated. After WP2, the orchestrator adds the admin entry. Never print or commit `config/master.key`.
   - Commit.
7. **Quality gate.** Run all of these, fixing generator leftovers until they're clean:
   - `bin/rails test`;
   - `bin/rails test:system` (it may say there are no tests);
   - `bin/rubocop`;
   - `bin/brakeman --no-pager`;
   - `bin/importmap audit`;
   - `bin/bundler-audit`, if it exists.

   Then start `bin/rails server -p 3001` briefly: `curl -s -o /dev/null -w '%{http_code}' localhost:3001/up` must print 200. Stop the server. Commit.
8. **AVIF check.** Run `bin/rails runner 'p Vips.get_suffixes.include?(".avif")'` and record the result in the handoff.
9. **Handoff.** Write `docs/handoff/WP1.md` covering:
   - the exact versions (`ruby -v`, `bin/rails -v`, `vips --version`, image_processing, lexxy, acts_as_list);
   - what the installers generated, and where Lexxy's JS and CSS live;
   - the CSP as written;
   - anything WP2–WP5 should know.

   Commit.

## Acceptance

- [ ] `git log --oneline` shows the steps above as separate commits on `main`, and `git status` is clean.
- [ ] In the project, `ruby -v` gives 4.0.7 and `bin/rails -v` gives 8.1.4. The Gemfile has every gem from overview §4.1.
- [ ] Active Storage, Action Text (with Lexxy, or Trix with a reason) and the auth generator are installed and migrated.
- [ ] A WebP variant keeps the alpha channel of `obra-01.webp`.
- [ ] Tests, RuboCop, Brakeman and the audits are clean, and `/up` returns 200.
- [ ] `docs/handoff/WP1.md` is written.

## Report back (your final message, at most 20 lines)

- Status (done, or blocked and why).
- Versions.
- The image_processing version you settled on, and why.
- Lexxy or Trix.
- AVIF support.
- Commit count.
- Anything the orchestrator must tell the user.
