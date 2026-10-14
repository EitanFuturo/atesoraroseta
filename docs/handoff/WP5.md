# WP5 handoff: deployment (Kamal → a shared DigitalOcean droplet) and off-server backups

Status: **done, deployable once the user provides the values in section 6.** Branch `worktree-agent-ae9a9e4e54ecb7ece`, commits `3f691b8` to the commit that adds this note.
`bin/ci` is green: RuboCop (87 files), bundler-audit, importmap audit, Brakeman (0 warnings), 206 tests and 1,145 assertions (163 before WP5), the seeds, and system tests (none in this branch). `CI=1 bin/rails test` (eager loading) and `bin/rails zeitwerk:check` pass too.
A restore from backup was **rehearsed end to end** (section 4), as was a same-droplet rollback. The production image decodes **AVIF**.

## 1. What was built

| Step | Files | Commit |
|---|---|---|
| Production config: `APP_HOST`, SSL, the www redirect | `config/environments/production.rb`, `lib/www_redirect.rb` | `3f691b8` |
| Boot hook: `admin:sync` after `db:prepare` | `bin/docker-entrypoint` | `6d38686` |
| Docker image: excludes, AVIF checked | `.dockerignore`, `Dockerfile` (comment only) | `57b8707` |
| Litestream 0.5 config | `config/litestream.yml` | `da6d482` |
| Kamal | `config/deploy.yml`, `.kamal/secrets` | `d46452b`, `4a33330` |
| Uploads backup: job, schedule, tasks | `app/jobs/backup_{bucket,uploads,uploads_job}.rb`, `config/recurring.yml`, `lib/tasks/backup.rake` | `c50f7f5` |
| The guide | `DEPLOY.md` | `5971842` |

Tests: `test/deploy/{production_environment,docker_entrypoint,kamal_config,litestream_config}_test.rb`, `test/lib/www_redirect_test.rb`, `test/jobs/backup_{bucket,uploads,uploads_job}_test.rb`, `test/lib/tasks/backup_tasks_test.rb`, and the helper `test/test_helpers/fake_spaces.rb`.

**Shared files touched: none.** The Gemfile, `config/application.rb`, the initializers and `es.yml` are unchanged. Two new files sit outside WP5's list in overview §7.2, with no overlap with other WPs: `lib/www_redirect.rb` (the plan asks for "a tiny Rack middleware … you own") and `test/test_helpers/fake_spaces.rb`.

### 1.1 Production (`config/environments/production.rb`)

- **`APP_HOST`** (`atesoraroseta.com`, set in `deploy.yml`) drives:
  - `config.hosts = [APP_HOST, "www.#{APP_HOST}"]`, with `host_authorization` excluding `/up`. kamal-proxy's health checks address the container, not the domain;
  - the **`WwwRedirect`** middleware, inserted right after `ActionDispatch::SSL`, so its 301 carries HSTS too. `www.<APP_HOST>/any/path?q` → `301 https://<APP_HOST>/any/path?q` for any method; the target is always the configured host, never the request's;
  - `Rails.application.routes.default_url_options` and `action_mailer.default_url_options` = `{ host: APP_HOST, protocol: "https" }`, for URLs built outside a request. Inside a request, URL helpers use the request's host, which is the apex once www is redirected. **WP3's canonical and og URLs therefore come out as `https://atesoraroseta.com/…`.**
  - Without `APP_HOST` (a one-off container), any host is accepted and nothing is redirected.
- `assume_ssl` and `force_ssl` stay on. **`/up` needs no SSL-redirect exclusion:** with `assume_ssl` every request counts as HTTPS, which was tested.
- The mailer SMTP stub is gone (nothing sends email). Caching and logging keep the Rails defaults. Solid Queue runs in Puma (`SOLID_QUEUE_IN_PUMA`, already in `config/puma.rb`).
- `lib/www_redirect.rb` is `require_relative`d from `production.rb`, because environment files run before any autoloader is set up (checked in railties 8.1.4). Zeitwerk then skips the already-defined constant; in development and test it is autoloaded normally.

### 1.2 Boot hook (`bin/docker-entrypoint`)

When the command is `… ./bin/rails server`: `./bin/rails db:prepare`, then `./bin/rails admin:sync || echo "…admin:sync failed; starting the server anyway." >&2`, then the server. WP2's task already only warns (exit 0) without credentials. The `||` also keeps an unexpected failure from taking the site down. The cost is one extra Rails boot, about 1 s. Other commands (`kamal app exec`) skip both steps.

### 1.3 Image

- Debian 13 (trixie) under `ruby:4.0.7-slim`: **libvips 8.16.1** and **libheif 1.23.4**, whose decoder plugins (`libheif-plugin-dav1d` for AVIF, `-libde265` for HEIC) are hard dependencies in Debian 13. So **no package was missing**, and the Dockerfile only gained a comment.
- AVIF inside the amd64 image: `.avif` is in `Vips.get_suffixes`, `heifload` is not blocked (flags 0; libvips 8.16 doesn't mark it untrusted, and `magickload` is blocked as it should be), and **`ImageAttachments.avif_supported?` → `true`**. A real AVIF (encoded in a throwaway Debian container with aomenc) decoded and produced a WebP variant through image_processing. So production accepts AVIF uploads, while development on this Mac doesn't (WP1 §4).
- `.dockerignore` adds `/design`, `/docs`, `/test`, `/tmp/screenshots`, `/.claude`. Nothing at runtime reads them (`lib/seeds/sample_content.rb` only builds a path to `design/img`, and only in development). The image has no `master.key`, no Kamal files, and runs as uid 1000.
- Size: 812 MB on disk, about 210 MB compressed (what the registry stores). Each deploy changes only the app layer (90 MB uncompressed). A cold amd64 build took about 100 s of build steps under Docker Desktop's Rosetta emulation, and an incremental one about 8 s.

### 1.4 Kamal (`config/deploy.yml`, `.kamal/secrets`)

- `service: atesoraroseta`; `image: <REGISTRY_NAME>/atesoraroseta` with `registry.server: registry.digitalocean.com`, which gives `registry.digitalocean.com/<REGISTRY_NAME>/atesoraroseta`; `servers: web: [<DROPLET_IP>]`.
- **Per-app proxy options only, and no `proxy/run`:**
  - `ssl: true`, both hosts, health check `/up`;
  - `response_timeout: 60`;
  - `buffering.max_request_body: 31457280` (**30 MiB**). The largest request is a direct upload of one image of at most 25 MiB (`ImageAttachments::MAX_BYTES`) sent as the raw body; the 5 MiB of headroom covers a multipart form carrying one such file. A 25–30 MiB file still reaches the app and gets its Spanish size error.
- **`HTTP_WRITE_TIMEOUT: 60`** (Thruster). Thruster's default of 30 s would otherwise cut every response at 30 s, whatever the proxy allows.
- Volume `atesoraroseta_storage:/rails/storage`; `asset_path` kept; `retain_containers: 3` (Kamal's default is 5): three stopped versions besides the running one.
- **Builder: local, `arch: amd64`**, built under Docker Desktop's emulation (Rosetta, about half native speed). The shared droplet then never spends CPU, memory or disk on builds. The remote builder (`remote: ssh://root@<ip>`) is documented as the alternative.
- Registry login: per DigitalOcean's docs, the username is the account email (`<DIGITALOCEAN_EMAIL>`) and the password an API token (`KAMAL_REGISTRY_PASSWORD`).
- The non-secret Spaces settings sit in one YAML anchor (`x-spaces`, which Kamal accepts as an extension key), shared by the app and the accessory.
- **Accessory `litestream`:**
  - `litestream/litestream:0.5.17` (the newest 0.5.x, released 2026-08-31), `roles: [web]`, `cmd: replicate`;
  - `files: config/litestream.yml:/etc/litestream.yml:ro`, the same volume, and `options: user: "1000:1000"` (the app's user, so whatever Litestream writes next to the database stays the app's);
  - env: the Spaces settings in clear, the keys as secrets;
  - no ports.
- **`.kamal/secrets`** holds only command substitutions: `RAILS_MASTER_KEY=$(cat config/master.key)`, plus `KAMAL_REGISTRY_PASSWORD`, `SPACES_ACCESS_KEY_ID` and `SPACES_SECRET_ACCESS_KEY` through `bin/rails credentials:fetch`. There is no literal secret and nothing admin-related.
- `bin/kamal config` renders both as committed (placeholders) and with dummy values. `test/deploy/kamal_config_test.rb` loads the file through Kamal itself and guards the shared-server rules: unique names, no published ports, no `proxy/run`, the options above, and the accessory. It substitutes dummy values only for placeholders still present, so it keeps passing once real values are filled in.

### 1.5 Litestream (`config/litestream.yml`, 0.5 syntax)

- One database, `/rails/storage/production.sqlite3`, with a single `replica:` (0.5 allows one): `type: s3`, `path: db`, and bucket, endpoint, region and keys all from `${SPACES_*}`. Litestream expands environment variables in its config; the keys are quoted.
- **Retention:** `snapshot: interval: 24h, retention: 192h`. In 0.5 the snapshot retention sets the cutoff for every compaction level, so 8 days of history give **any moment of the last 7 days**, plus a day's margin for the snapshot a restore starts from. Litestream's default is 24h. The config parses with the 0.5.17 binary (`litestream databases`).
- The cache, queue and cable databases are not replicated.
- No automatic `restore-if-db-not-exists`. On a new droplet the app could race it to create the database, so the restore steps are explicit and synchronous instead (section 4, DEPLOY.md).

### 1.6 Uploads backup

| | |
|---|---|
| `BackupBucket` | The Spaces bucket. Settings come from the credentials `spaces.{bucket,region,endpoint,access_key_id,secret_access_key}`, each overridden by `SPACES_*` (blank values are ignored); unreadable credentials count as missing. `#keys(prefix)` / `#objects(prefix)` list in pages of 1,000 (`list_objects_v2`). There are `#upload` (with `Content-MD5`) and `#download`, and **no delete method at all**. The client uses path-style requests and checksums `"when_required"`, which suits Spaces and any S3-compatible store; aws-sdk-s3 is required lazily. Without settings it raises `BackupBucket::NotConfigured`, naming the missing variables. |
| `BackupUploads` | `#backup`: lists `uploads/` once, then copies every `ActiveStorage::Blob` whose key is missing (**originals and variants**, which are blobs too) via `blob.open`, which verifies the checksum, to `uploads/<key>`. A missing local file counts as `missing`; any error counts as `failed` and is logged, and the rest goes on. `#restore`: downloads each blob the disk lacks and the bucket has, through `blob.service.upload(key, io, checksum:)`, which verifies it and removes it on a mismatch; it never overwrites. `#status`: the counts on both sides plus **Litestream's latest position**, read from the bucket (`db/<level>/<min>-<max>.ltx`: highest TXID, newest upload time, newest snapshot from level `0009`). Results are a `Summary` (`counts`, `bytes`, `message`) with Spanish messages. |
| `BackupUploadsJob` | `retry_on BackupUploads::Incomplete, wait: 15.minutes, attempts: 3`. It logs the summary, and raises when anything failed. |
| `config/recurring.yml` | `backup_uploads: class BackupUploadsJob, schedule "every day at 3:30am Europe/Madrid"`, which Fugit/Solid Queue reads as `30 3 * * * Europe/Madrid`. The app stays on UTC, so the zone is part of the schedule; 03:30 falls in neither DST gap. |
| `bin/rails backup:uploads` | The same copy, now. Prints the summary, and exits 1 on failures or missing settings. |
| `bin/rails backup:restore_uploads` | Prints the summary; exits 1 on failures. |
| `bin/rails backup:status` | Two lines, for example: `Archivos subidos: 5 en la base de datos, 5 en el disco (0 faltan), 5 en Spaces (uploads/), 0 sin copia en Spaces.` / `Base de datos (Litestream, db/): 10 archivos; última transacción 0000000000000008, subida el 2026-10-13 21:28:00 UTC; última instantánea: ninguna todavía.` |

Tests use aws-sdk-s3's own stubbed client (`stub_responses`) over a Hash, injected directly or, for the job and the tasks, through `Aws.config` together with `SPACES_*` (so real credentials are never used). They cover:
- both directions, byte for byte, including a variant;
- idempotency: a second run only lists;
- objects already in the bucket left untouched;
- missing and damaged local files, and damaged or absent objects;
- pagination;
- "nothing is ever deleted": only `list_objects_v2`, `put_object` and `get_object` are ever called, and a purged blob stays in the bucket;
- the status lines, the job's retry (15–18 min later, with jitter), the schedule in summer and winter, and the tasks' output and exit codes.

## 2. Credential keys and environment variables

**Credential keys** (`config/credentials.yml.enc`):

| Key | State today | Read by |
|---|---|---|
| `secret_key_base` | present (Rails) | the app |
| `admin.email`, `admin.password` | present (orchestrator, step 3) | the app (`admin:sync` on every boot) |
| `kamal.registry_password` | **missing: the user adds it** (DEPLOY.md B2) | `.kamal/secrets` → Kamal |
| `spaces.access_key_id`, `spaces.secret_access_key` | **missing: the user adds them** | the app (uploads backup); `.kamal/secrets` → the Litestream accessory |
| `spaces.bucket`, `spaces.region`, `spaces.endpoint` | optional fallbacks, not needed | the app; `deploy.yml` sets them as env |

Checked without printing values: `{admin: [:email, :password], kamal: nil, spaces: nil}`.

**Environment:**

| Variable | Where | Value |
|---|---|---|
| `APP_HOST` | app (clear) | `atesoraroseta.com` |
| `SOLID_QUEUE_IN_PUMA` | app (clear) | `true` |
| `HTTP_WRITE_TIMEOUT` | app (clear, Thruster) | `60` |
| `SPACES_BUCKET`, `SPACES_REGION`, `SPACES_ENDPOINT` | app and accessory (clear) | `<SPACES_BUCKET>`, `<SPACES_REGION>`, `https://<SPACES_REGION>.digitaloceanspaces.com` |
| `RAILS_MASTER_KEY` | app (secret) | `config/master.key` |
| `SPACES_ACCESS_KEY_ID`, `SPACES_SECRET_ACCESS_KEY` | accessory (secret); also override the credentials in the app | from the credentials |
| `KAMAL_REGISTRY_PASSWORD` | Kamal only (registry login) | from the credentials |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | optional overrides (CI, rehearsal; WP2) | not set in production |

## 3. How to verify

```sh
bin/ci
bin/rails test test/deploy test/jobs test/lib/www_redirect_test.rb test/lib/tasks/backup_tasks_test.rb
bin/kamal config                              # renders; prints no secret
grep -n "<[A-Z_]*>" config/deploy.yml         # the 6 placeholder lines (5 values, the region twice)
open -a Docker   # then:
docker buildx build --builder desktop-linux --platform linux/amd64 --load -t atesoraroseta:check .
docker run --rm --platform linux/amd64 -e SECRET_KEY_BASE_DUMMY=1 -e RAILS_LOG_LEVEL=fatal atesoraroseta:check \
  ./bin/rails runner 'p ImageAttachments.avif_supported?'      # true
```

## 4. The rehearsal (local, Docker Desktop, amd64 image)

**Set-up.**
- Images: the production image (amd64); MinIO as the S3 stand-in; `litestream/litestream:0.5.17`; and **`basecamp/kamal-proxy:v0.9.2`**, the version Kamal 2.12 runs, added to test the proxy options too.
- Everything ran on one Docker network, with the **exact `docker run` / `kamal-proxy deploy` arguments Kamal generates**. I printed them with Kamal's Ruby API on a copy of `deploy.yml` filled with dummy values; nothing connected to a server.
- **MinIO:** `minio/minio` no longer exists on Docker Hub, and `quay.io/minio/minio` requires a login, so I used `bitnamilegacy/minio:latest` (MinIO DEVELOPMENT.2025-05-24).
- The app got the real `config/master.key` through a git-ignored env file (mode 600, deleted afterwards; the way Kamal hands it over on the server), throwaway `ADMIN_EMAIL`/`ADMIN_PASSWORD`, and `SPACES_*` pointing at MinIO.

**Result: passed.**

1. **First boot, in `kamal setup`'s order.** The Litestream accessory starts first and creates the volume: empty, owned by root. Creating the app container then copies the image's `/rails/storage` and its uid 1000 ownership into the empty volume (Docker's copy-up, verified separately). The app reached Puma in **about 6 s**:
   - `db:prepare` created the databases and seeded the settings and the admin;
   - `admin:sync` printed "sin cambios";
   - Solid Queue started with `recurring_schedule: ["backup_uploads", "clear_solid_queue_finished_jobs"]`.

   Litestream waited, logging the expected `timeout waiting for db initialization` warnings for 30 s, then replicated. 6 s is well inside Kamal's default `deploy_timeout` of 30 s, so it is unchanged.
2. **Through kamal-proxy** with Kamal's options (without `--tls`; Let's Encrypt can't run locally):
   - `/up` 200; `www.…/obra/…?a=1` → 301 `https://atesoraroseta.com/obra/…?a=1`; another host name → the proxy's 404;
   - HSTS, the CSP, and a `secure; httponly; samesite=lax` session cookie on the login page;
   - Rails logged the client address kamal-proxy saw, not the proxy's or Thruster's, so the per-IP login limit sees visitors;
   - **a 30 MiB body passed, 30 MiB + 1 byte got 413**.
3. **An artwork with an image** (`design/img/obra-01.webp`, 1179×1571, with alpha) created with `bin/rails runner`: analysed at once, and **4 preprocessed variants built by Solid Queue in Puma**. No failed jobs.
4. **`bin/rails backup:uploads`:** 5 files (2.02 MB) to `uploads/`; a rerun copied 0. The bucket held Litestream's `db/0000…0003/*.ltx` (TXIDs up to 8, including the artwork). `backup:status` printed both lines.
5. **Wiped** both containers and the volume.
6. **New-droplet restore** (DEPLOY.md's commands, as docker commands):
   - boot, then stop, the accessory;
   - the restore **without** the `chown` step fails with `permission denied` (Litestream writes `production.sqlite3.tmp`, then renames it). With `chown` it succeeded in under 1 s, and the restored database passed `PRAGMA integrity_check`;
   - start the accessory; the app booted on it in 6 s, without reseeding;
   - `backup:restore_uploads` restored 5 files, and a rerun restored 0.

   The image at the **same Active Storage URL through kamal-proxy came back byte-identical** (SHA-256 `1ac5e4f9…` before and after, equal to the source file). A variant was served from its restored file with no new transform.
7. **Same-droplet rollback.** The artwork was deleted (its files purged from disk; the bucket kept them), then: app stop, accessory stop, `restore -force -timestamp <before the deletion>`, accessory start, app start, `backup:restore_uploads`.
   - `-force` replaced the database and **removed the stale `-wal`/`-shm`** the stopped app had left. Litestream's old local state directory caused no trouble.
   - The artwork and its image were back, and `admin:sync` ran again on start.
   - Afterwards "latest" in the bucket was the rolled-back state plus a later edit: the history continues, and the deleted state is still reachable by TXID.
8. **Lab findings with the 0.5.17 binary:**
   - a fresh, empty database replicated over an existing replica becomes "latest" (Litestream logs "detected database behind replica" and continues the TXID sequence), while the old data stays restorable by `-txid`/`-timestamp`. Hence DEPLOY.md's "restore before the first boot", and the documented way out if that order is missed;
   - point-in-time restores were exact to the second.

Not exercised: Kamal's SSH side (bootstrap, uploading the accessory's files and env files) against a real host, Let's Encrypt, and real Spaces. No server exists yet. The docker commands those steps run were rehearsed.

## 5. Deviations and decisions

1. **The www redirect is a Rack middleware in `lib/`**, required explicitly by `production.rb` (section 1.1). The plan allows a middleware or a route constraint; `config/routes.rb` isn't WP5's.
2. **No `/up` SSL exclusion** (not needed with `assume_ssl`), but a host-authorization exclusion for `/up` (needed).
3. **`HTTP_WRITE_TIMEOUT=60`** for Thruster, so that `response_timeout: 60` actually holds.
4. **`retain_containers: 3`** instead of 5, to spare disk on a shared server.
5. **A local amd64 build, not a remote builder**: no load on the shared droplet. Builds under Rosetta are practical. The trade-off is in `deploy.yml` and DEPLOY.md.
6. **An extra placeholder, `<DIGITALOCEAN_EMAIL>`** (the registry username, per DigitalOcean's docs). **The bucket name is a placeholder too** (`<SPACES_BUCKET>`; the plan lists it as unknown), with `atesoraroseta-backups` suggested.
7. **Litestream runs as uid 1000.** That keeps every file next to the database the app's. The price is a one-off `chown` of the volume before a restore on a brand-new droplet: documented and rehearsed. A first `kamal setup` needs nothing, because of Docker's copy-up (verified).
8. **No auto-restore in the accessory** (`restore-if-db-not-exists`). Explicit, synchronous restore steps avoid racing the app's first boot.
9. **The backup code is three classes in `app/jobs/backup_*`**, because §7.2 gives WP5 that pattern. `backup:uploads` runs the copy directly, so a failure exits non-zero instead of scheduling the job's retry.
10. **Task and log messages are in Spanish**, like WP2's `admin:sync`. DEPLOY.md is in English, like the README WP6 writes.
11. **The rehearsal used `bitnamilegacy/minio`** (MinIO itself, a 2025 build), because the official images are gone.
12. **Commit trailers:** I kept the overview's single `Co-Authored-By` line (§7.1), the user's own rule for these lines, so the later commits match the earlier ones.

## 6. What the user must provide or decide

**Provide** (all are placeholders in `config/deploy.yml` or the credentials; DEPLOY.md, "Values you must provide"):
- **The droplet:** its IP (`<DROPLET_IP>`) and size: **2 GB** for this site plus one small app, **4 GB** for several. A region near Spain: AMS3, FRA1 or LON1.
- **The registry:** its name (`<REGISTRY_NAME>`), the account email (`<DIGITALOCEAN_EMAIL>`), an API token with registry read/write → `kamal.registry_password`, and the plan. The free plan holds one repository; with several projects, take **Basic**.
- **The Spaces bucket:** its region (`<SPACES_REGION>`) and name (`<SPACES_BUCKET>`, suggested `atesoraroseta-backups`), and an access key **limited to that bucket, with Read/Write/Delete** (Litestream prunes its own old files) → `spaces.access_key_id`, `spaces.secret_access_key`.
- **The DNS change:** A records for `@` and `www` → the droplet IP. Lower the TTL first if the domain points elsewhere, and remove any AAAA records. It must resolve before the first deploy.
- **A copy of `config/master.key` in a password manager.**

**Decide:**
- **Does the droplet already serve anything on ports 80/443?** kamal-proxy needs them, so an existing site must move behind it first (DEPLOY.md A3 has a one-line check).
- **The uploads backup runs nightly (03:30)**, as planned. Images uploaded since the last run aren't off-server until then; DEPLOY.md suggests running `backup:uploads` after big upload sessions. Hourly would also be cheap: one listing per run.
- Optional: DigitalOcean's own droplet backups, as a second safety net.

## 7. Open issues and notes for WP6

1. **Direct uploads are open to anonymous visitors (a Rails default).** `ActiveStorage::DirectUploadsController` doesn't inherit `ApplicationController`, so the admin login doesn't guard `POST /rails/active_storage/direct_uploads`. Only CSRF does, and the login page hands out a session and a token. An anonymous visitor could therefore create blobs and upload files of up to 30 MiB each, filling the disk; the backup would copy them too.
   - Proposed fix (WP4/WP6): require a signed-in admin for direct uploads. For example, a `config.to_prepare` that adds a `before_action` (using `Authentication`) to `ActiveStorage::DirectUploadsController`, or the admin's own subclass and route.
2. **kamal-proxy v0.9.2 and `Expect: 100-continue`.** For requests that carry this header (curl sends it with bodies over 1 MB), an error response reaches the client as `100 Continue` and then `200 OK`, with the error page as the body. For example, a 422 from Rails. Thruster and Puma, asked directly, answer correctly (`100`, then `422`), so it is in the proxy. **Browsers don't send `Expect: 100-continue`**, so admin uploads are unaffected. Worth reporting upstream; it only matters to scripts.
3. **Abandoned direct uploads leave unattached blobs.** They also get copied to `uploads/`. That is harmless, but a periodic purge of old unattached blobs could be added later; the bucket copy would stay, by design.
4. **Unverified details** (no DigitalOcean account was available):
   - the exact names of the registry token's scopes (DEPLOY.md says "Container Registry read and write");
   - Spaces' limited-access key permission labels;
   - the behaviour of real Spaces with the client settings (path-style requests, checksums only when required). These were chosen for compatibility, and Litestream 0.5.17 lists Spaces with its defaults.
5. **`/` raises in this branch** (`ArtworksController` comes with WP3). After the merge, DEPLOY.md's first check (`curl -sI https://atesoraroseta.com` → 200) applies.
6. **After merging**, WP6 can rerun `test/deploy` and `test/jobs`. The production-environment test boots `RAILS_ENV=production` in a subprocess and needs no database. If WP3 sets `config.exceptions_app = routes`, the test's 403 for a foreign host comes from `HostAuthorization` before routing, so it should still hold.

## 8. Lab clean-up

Removed when the rehearsal was over:
- the rehearsal containers (app, Litestream, kamal-proxy, MinIO), the `wp5lab` network and the volumes;
- the images built for the lab;
- the `tmp/wp5-lab/` files, including the env file with the master key.

The `buildx_buildkit_kamal-local-docker-container0` builder container predates WP5 and was left alone. Docker Desktop, which WP5 started, was quit.
