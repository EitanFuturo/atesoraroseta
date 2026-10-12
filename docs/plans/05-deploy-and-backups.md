# WP5: Deployment (Kamal → a shared DigitalOcean droplet) and off-server backups

**Runs in:** your own git worktree and branch, in parallel with WP3 and WP4.
**Depends on:** WP2. Read `docs/handoff/WP1.md` and `docs/handoff/WP2.md`.
**Read first:**
- `docs/plans/00-overview.md` (§4.1, 4.5, **4.7, 4.8** and 7.4 matter most);
- `design/PROMPT.md` (Deployment).

## Goal

Make the app deployable to one DigitalOcean droplet with Kamal: HTTPS on **`atesoraroseta.com`** (with `www.` redirecting to it), persistent data, and off-server backups that have actually been restored once.

The droplet will also host **the user's other projects, on other domains**. Set this app up as one good neighbour among several Kamal apps behind the shared kamal-proxy (overview §4.8).

`DEPLOY.md` must be good enough for someone who has never used Kamal.

**What isn't known yet:** the droplet IP (placeholder `<DROPLET_IP>`), the registry name and the Spaces region and bucket. DNS for the domain doesn't point at the droplet yet. Use clearly named placeholders and never invent credentials.

## You own

See overview §7.2 for the full list. In short:
- `Dockerfile`, `.dockerignore`, `bin/docker-entrypoint`, `config/deploy.yml`, `.kamal/**`;
- `config/litestream.yml`, `config/environments/production.rb`, `config/storage.yml`, `config/recurring.yml`;
- `app/jobs/backup_*`, `lib/tasks/backup.rake`;
- `DEPLOY.md`;
- the tests for those;
- `docs/handoff/WP5.md`.

## Decisions already made (overview §4.7–4.8)

- Kamal 2 with kamal-proxy and automatic Let's Encrypt. Routing is **by host name**, so other projects on the same droplet can't collide with this one.
- **DigitalOcean Container Registry.**
- Volume `atesoraroseta_storage` is mounted at `/rails/storage`.
- **Litestream v0.5.x as a Kamal accessory** replicates `production.sqlite3` to `db/` in **this project's own bucket**.
- A **nightly Solid Queue recurring job** copies new Active Storage files to `uploads/<key>`. It is copy-only and never deletes.
- **Secrets are in Rails encrypted credentials:** `admin.*`, `kamal.registry_password`, `spaces.access_key_id`, `spaces.secret_access_key`.
  - `.kamal/secrets` uses `bin/rails credentials:fetch`. Only `config/master.key` must be kept safe.
  - The non-secret Spaces settings (bucket, region, endpoint) are plain environment variables in `deploy.yml`.
  - Environment variables override the credentials, for CI and the rehearsal.
- **No email and no SMTP.** There is no password recovery; the admin password lives in the credentials.

If something here can't work, implement the closest workable thing and report it.

## Steps (commit after each)

1. **Production config** (`config/environments/production.rb`):
   - **Host:** `APP_HOST` (`atesoraroseta.com`) drives `config.hosts` (the apex plus `www.`), the default URL options and the canonical host.
   - **www:** redirect `www.atesoraroseta.com` to the apex with a 301, in a tiny Rack middleware or route constraint you own.
   - **SSL:** keep `assume_ssl` and `force_ssl`, and exclude `/up` from the SSL redirect if the health check needs that.
   - **Jobs:** Solid Queue runs in Puma (`SOLID_QUEUE_IN_PUMA`). Keep the Rails defaults for caching and logging, and remove any mailer SMTP stub.
2. **Boot hook.** `bin/docker-entrypoint` runs `./bin/rails admin:sync` right after `db:prepare`, using WP2's task. It must stay quiet and non-fatal when no admin credentials exist.
3. **Docker image:**
   - Make sure libvips is installed. Find out whether AVIF and HEIF decoding works (`vips -l | grep heif`); if a missing libheif plugin package is the only obstacle, add it.
   - Add `.dockerignore` entries for `/design`, `/docs`, `/test`, `/tmp/screenshots` and `/.claude`.
   - Keep jemalloc and Thruster.
   - Droplets are **amd64** and this Mac is arm64. Configure the builder, either a remote builder on the droplet over SSH or local emulation, and document the trade-off.
4. **Kamal** (`config/deploy.yml` and `.kamal/secrets`):
   - **Service and image:** service `atesoraroseta`; image `registry.digitalocean.com/<REGISTRY_NAME>/atesoraroseta`; servers `web: [<DROPLET_IP>]`.
   - **Proxy:**
     - `ssl: true` and `hosts: [atesoraroseta.com, www.atesoraroseta.com]`;
     - health check `/up`;
     - `response_timeout` ≥ 60 s;
     - `buffering.max_request_body` ≥ 30 MB, because direct uploads send one file of up to 25 MB per request. Justify your number.
     - Set only **per-app** proxy options; never change the server-wide proxy configuration, which the other projects share.
   - **Volume:** `atesoraroseta_storage:/rails/storage`.
   - **Clear env:** `APP_HOST`, `SOLID_QUEUE_IN_PUMA`, `SPACES_BUCKET`, `SPACES_REGION`, `SPACES_ENDPOINT`.
   - **Secret env:** `RAILS_MASTER_KEY`, plus `SPACES_ACCESS_KEY_ID` and `SPACES_SECRET_ACCESS_KEY` for the Litestream accessory.
   - **`.kamal/secrets`:**
     - `RAILS_MASTER_KEY=$(cat config/master.key)`;
     - `KAMAL_REGISTRY_PASSWORD=$(bin/rails credentials:fetch kamal.registry_password)`;
     - the two Spaces keys through `credentials:fetch`.

     It contains **no literal secret** and no admin password (the app reads that from the credentials itself).
   - **Accessory `litestream`:** the pinned image `litestream/litestream:0.5.17` (or the newest 0.5.x), `cmd: replicate`, the config via `files:`, the same volume, and the Spaces credentials. It publishes no ports.
5. **`config/litestream.yml`:**
   - Use the **0.5.x** syntax. Check the docs and the binary you pin, because 0.5 changed the format from 0.3.
   - The database is `/rails/storage/production.sqlite3`; the replica is S3-compatible on Spaces (`https://<region>.digitaloceanspaces.com`) under `db`.
   - Retention gives at least 7 days of point-in-time restore. Document what you set.
6. **Uploads backup:**
   - **Job:** `BackupUploadsJob` copies every `ActiveStorage::Blob` whose key isn't yet in the bucket to `uploads/<key>`.
     - It uses `Aws::S3::Client` with the Spaces endpoint, and lists existing keys efficiently.
     - It never deletes, and it covers originals and variants.
     - Its log line reports the counts.
     - Its Spaces settings come from the credentials, overridden by `SPACES_*` environment variables.
   - **Schedule:** a production recurring entry in `config/recurring.yml`, daily at about 03:30 Europe/Madrid.
   - **Tasks:**
     - `bin/rails backup:uploads` runs it now;
     - `bin/rails backup:restore_uploads` downloads every missing blob into the Disk service path;
     - `bin/rails backup:status` prints the counts and, if obtainable, the latest Litestream position.
   - **Tests:** stub the S3 client (`stub_responses: true`) and check both directions, idempotency and that nothing is ever deleted.
7. **Local rehearsal.** Start Docker Desktop with `open -a Docker` and wait for `docker info`.
   - **Setup:**
     - build the production image;
     - run a MinIO container as the S3 stand-in;
     - run the app container with a test volume, using the real `config/master.key` for `RAILS_MASTER_KEY` but `ADMIN_EMAIL`/`ADMIN_PASSWORD` **overrides with throwaway values**, plus `SPACES_*` overrides pointing at MinIO;
     - run the Litestream container pointed at MinIO.
   - **Rehearse:**
     1. log in, or use `bin/rails runner`, to create an artwork with an image;
     2. run `backup:uploads`;
     3. confirm the replica and the upload objects exist;
     4. **wipe the volume**;
     5. restore the database with `litestream restore` and the files with `backup:restore_uploads`;
     6. boot the app and confirm the artwork and its image are back.

   Record the exact commands; they become DEPLOY.md's restore section. If Docker can't run, validate the config with `bin/kamal config` instead and say plainly that you didn't rehearse.
8. **`DEPLOY.md`**, with exact commands. Placeholders are `<LIKE_THIS>`.

   **Part A, the shared server (done once, for all projects):**
   - creating the droplet: Ubuntu LTS; 2 GB for this site plus one small app, 4 GB for several; a region near Spain such as AMS3, FRA1 or LON1; an SSH key; a Cloud Firewall allowing 22/80/443; optional droplet backups;
   - how kamal-proxy routes several domains to several apps;
   - the rule that everything on the server deploys through Kamal;
   - which commands are server-wide, such as `kamal proxy reboot`, and affect every project;
   - the registry, including that its free tier holds one repository, so several projects need the paid tier or GitHub's registry.

   **Part B, this app:**
   1. **DNS:** A records for `@` and `www` pointing at `<DROPLET_IP>`. Lower the TTL first if the domain points somewhere else today. **This must resolve before the first deploy**, because Let's Encrypt can't issue the certificate until it does. Show how to check propagation.
   2. **Secrets:**
      - which credential keys to add with `bin/rails credentials:edit` (exact YAML shape);
      - backing up `config/master.key` in a password manager, and that losing it means losing every secret;
      - where each secret ends up.
   3. **Bucket:** creating this project's Spaces bucket and an access key scoped to it.
   4. **First deploy:** `bin/kamal setup`, then the checks: HTTPS on both hosts, `www` redirects, `/admin` login works, and Litestream logs replication.
   5. **Daily operation:** `bin/kamal deploy`, rollback, logs, the console and `kamal app exec`.
   6. **Admin password:**
      - it comes from the credentials and is synced on every boot;
      - to change it, edit the credentials and run `bin/kamal deploy`, which also signs out every session;
      - in an emergency, run `bin/kamal app exec -i --reuse "bin/rails admin:sync"`.
   7. **Backups:** what is backed up and when, how to check them, and **restoring** the database and uploads, both on the same droplet and on a brand-new one. On a new droplet, restore *before* the first app boot so `db:prepare` doesn't create an empty database.
   8. **Troubleshooting:** certificates, DNS, disk space and image builds on Apple Silicon.

   **Part C, adding another project to this server later:** the minimum it needs (a unique service name, volume and domain), with a short `deploy.yml` sketch.
9. **Quality gate and handoff:**
   - the full suite, RuboCop and Brakeman are clean, and `bin/kamal config` renders with dummy values;
   - `docs/handoff/WP5.md` lists every credential key and environment variable, the rehearsal result, and everything the user must provide: the droplet IP and size, the registry name, the Spaces region and bucket, and the DNS change.

   Commit.

## Acceptance

- [ ] `bin/kamal config` renders. The image builds, or the reason it couldn't be tested is stated.
- [ ] The setup is safe on a shared server: unique names, no host ports, no global proxy changes.
- [ ] The admin password is synced from the credentials on boot, and no secret or password is in any committed file.
- [ ] Litestream config and accessory are present, and the uploads backup job, tasks and tests are in place.
- [ ] A restore from backup was rehearsed end to end, or it is clearly reported as not rehearsed, with the reason.
- [ ] `DEPLOY.md` covers every bullet PROMPT.md lists, plus Parts A and C.

## Report back (at most 25 lines)

- status;
- branch name and last commit;
- the rehearsal result;
- AVIF support in the image;
- the values the user must provide;
- shared files you touched.
