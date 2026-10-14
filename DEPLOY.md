# Deploying atesoraroseta.com

This guide takes the site from this folder on your Mac to **https://atesoraroseta.com** on a DigitalOcean droplet, with off-server backups. It assumes no Kamal experience. Every command runs **on your Mac, from this project's folder**, unless it says otherwise.

> **Off-server backups are off** (the user's decision on 2026-10-14: no new costs for now). The databases and the uploaded images live only in the `atesoraroseta_storage` volume on the droplet. If the droplet or that volume is lost, so is the content. The Spaces and Litestream parts of this guide (B2's `spaces` block, B3, the backup checks in B4, B7) apply only after [Turning backups on](#turning-backups-on).

- [What runs where](#what-runs-where)
- [Values you must provide](#values-you-must-provide)
- [Part A: the shared server (once, for all your projects)](#part-a-the-shared-server-once-for-all-your-projects)
- [Part B: this app](#part-b-this-app)
- [Part C: adding another project to the server](#part-c-adding-another-project-to-the-server)

## What runs where

```
visitor ── https ──▶ droplet :443 ── kamal-proxy (one per server, shared by every project)
                                        ├─▶ atesoraroseta-web-<version>   Thruster → Rails (Puma) + Solid Queue jobs
                                        │       └─ volume atesoraroseta_storage at /rails/storage:
                                        │            SQLite databases + uploaded images
                                        │                ▲
                                        │       atesoraroseta-litestream ── continuous copy of the database ─┐
                                        └─▶ your other projects (other domains)                             ▼
                                                              Spaces bucket <SPACES_BUCKET>: db/ (Litestream)
                                                                                            uploads/ (nightly job)
```

- **[Kamal](https://kamal-deploy.org)** (version 2.12, bundled with the app: always run `bin/kamal`, never a global `kamal`) builds a Docker image of the app on your Mac, hands it to the droplet over SSH through a temporary registry on your Mac (no registry account, see A5), and starts it there.
- **kamal-proxy** listens on ports 80 and 443, gets a free **Let's Encrypt** certificate for each host name, and sends every request to the app that owns its host name. `www.atesoraroseta.com` is answered by the app with a permanent redirect to `atesoraroseta.com`.
- **Data** lives in one Docker volume, `atesoraroseta_storage`: the databases (`production*.sqlite3`) and the uploaded files.
- **Backups** go to this project's own private **Spaces** bucket:
  - the database is copied continuously by **[Litestream](https://litestream.io)** (`db/`), with any moment of the last 7 days restorable;
  - the uploaded images (originals and resized versions) are copied **every night at 03:30, Madrid time** (`uploads/`). That copy never deletes anything.
- **Secrets** are all in `config/credentials.yml.enc`, encrypted with `config/master.key`. That key is the only thing you must keep safe.
- **No email** is sent by the site, so there is nothing to configure for it, and there is no "forgot password" (see [Admin password](#b6-admin-password)).

## Values you must provide

| Placeholder | What it is | Where it goes |
|---|---|---|
| `<SPACES_BUCKET>` | the backups bucket's name (suggested: `atesoraroseta-backups`) | `config/deploy.yml` |
| `<SPACES_REGION>` | the bucket's region, such as `ams3` or `fra1` | `config/deploy.yml` (twice) |
| `<SPACES_ACCESS_KEY_ID>`, `<SPACES_SECRET_ACCESS_KEY>` | an access key for the backups bucket only | encrypted credentials |

The droplet is already filled in: **165.22.43.43**, the droplet this app shares with perishables. There is no registry to set up (A5), and with backups off the Spaces values below aren't needed.

In this guide, `<LIKE_THIS>` always means "replace with your value". After editing `config/deploy.yml`, this must print nothing:

```sh
grep -n "<[A-Z_]*>" config/deploy.yml
```

---

## Part A: the shared server (once, for all your projects)

This app runs on the existing droplet **165.22.43.43**, which also runs perishables (deployed with Kamal 2.2.2; see A4 about keeping Kamal versions aligned). A1 is only needed for a new server.

### A1. Create the droplet

In the [DigitalOcean control panel](https://cloud.digitalocean.com): **Create → Droplets**.

1. **Region:** one near Spain, for example **Amsterdam (AMS3)**, **Frankfurt (FRA1)** or **London (LON1)**. Use the same region for the Spaces bucket (B3).
2. **Image:** the most recent **Ubuntu LTS** (x64).
3. **Size:** Basic, Regular. **2 GB RAM** is enough for this site plus one more small app; choose **4 GB** for several apps. (This app uses about 0.5–0.7 GB, more for a moment while it resizes a large upload.)
4. **Authentication:** **SSH key**. If you don't have one yet, create it on your Mac with `ssh-keygen -t ed25519`, then paste the contents of `~/.ssh/id_ed25519.pub` into DigitalOcean.
5. **Backups (optional):** DigitalOcean's weekly or daily droplet backups add an extra safety net for the whole server, at 20–30% of the droplet's price. The app's own backups (Part B) don't depend on them.
6. Create it, and note its **IPv4 address**: it replaces 165.22.43.43 in `config/deploy.yml` and in DNS.

Then **Networking → Firewalls → Create Firewall**, applied to the droplet:

| Inbound | Port | Why |
|---|---|---|
| SSH | 22 | Kamal connects over SSH |
| HTTP | 80 | Let's Encrypt checks, and the redirect to HTTPS |
| HTTPS | 443 | the sites |

Leave outbound rules at "all". Then check that you can log in (type `yes` the first time):

```sh
ssh root@165.22.43.43 "uname -a"
```

Kamal installs Docker on the server by itself the first time (`bin/kamal setup`).

### A2. How one server hosts several sites

- Every project is its **own Kamal app**, deployed from its own folder, to the **same IP**.
- Kamal runs **one** `kamal-proxy` container per server, on ports 80 and 443. The first project you deploy starts it; the others find it running and only register their host names with it.
- kamal-proxy looks at the host name of each request (`atesoraroseta.com`, `otro-proyecto.example`…) and passes it to the app that registered it, with that name's own Let's Encrypt certificate. A host name nobody registered gets a "404 Not Found" from the proxy.
- So each app needs: a **unique service name**, its **own volume** (if it stores data), its **own domain(s)**, and **no published ports**. This app uses the service `atesoraroseta`, the volume `atesoraroseta_storage` and the accessory `atesoraroseta-litestream`.

### A3. The rule: everything on this server goes through Kamal

- Don't install nginx, Apache, Caddy or anything else that listens on ports 80 or 443: kamal-proxy needs them.
- A static site or a non-Rails app is deployed as its **own small container with Kamal** too (Part C).
- **If the droplet already serves a site on ports 80/443**, kamal-proxy can't start. Move that site behind kamal-proxy first (as its own Kamal app), then deploy this one. To check what is listening:

  ```sh
  ssh root@165.22.43.43 "ss -tlnp | grep -E ':(80|443) ' || echo 'ports 80 and 443 are free'"
  ```

### A4. Commands that affect every project on the server

Most `bin/kamal` commands touch only this app's containers. These don't; run them only when you mean it:

| Command | Effect on every site |
|---|---|
| `bin/kamal proxy reboot` | restarts kamal-proxy (to upgrade it, for example): every site is down for a few seconds |
| `bin/kamal proxy stop` / `remove` | stops or removes the proxy: every site is down |
| `bin/kamal server bootstrap` | installs Docker if it is missing (harmless when it is there) |
| a `proxy:` → `run:` section in **any** project's `deploy.yml` | changes how the shared proxy is started; this project deliberately has none |
| `docker system prune -a` on the server | can delete other projects' rollback images and stopped containers |
| rebooting the droplet, changing its firewall | obvious |

**Keep all projects on the same Kamal version.** Kamal 2.12 needs kamal-proxy **v0.9.2** or newer. If another project, deployed with an older Kamal, started an older proxy, `bin/kamal setup` stops with "kamal-proxy version … is too old"; then run `bin/kamal proxy reboot` once from this project (every site blinks for a few seconds).

### A5. No container registry

Kamal 2.12 deploys without a registry account (`registry: server: localhost:5555` in `config/deploy.yml`). During `bin/kamal setup` and `bin/kamal deploy` it:

1. starts a registry container on your Mac, `kamal-docker-registry`, listening only on `127.0.0.1:5555`;
2. builds the image and pushes it there;
3. forwards that port over the deploy's SSH connection, so the droplet pulls the image from its own `localhost:5555`.

There is nothing to sign up for, no token to renew and no registry storage to clean up.

- Deploys need this Mac, or another computer with the project and `config/master.key`, which was already the case.
- The droplet keeps the running image and the three before it for rollbacks (`retain_containers: 3`).
- On a brand-new droplet, `bin/kamal setup` sends the image again; nothing has to be downloaded from a registry.

Other projects on the server can use the same setup, or any registry they already have.

---

## Part B: this app

You need, on your Mac:

- this project, set up (`bin/setup` has run);
- `config/master.key` (it is not in git; see B2);
- **Docker Desktop running**: `open -a Docker`, then wait until `docker info` answers. In Docker Desktop's settings, **"Use Rosetta for x86_64/amd64 emulation on Apple Silicon"** should be on: the droplet is amd64 (Intel/AMD) and this Mac is arm64, so the image is built under emulation. A first build takes a few minutes, later ones much less;
- your SSH key loaded: `ssh-add ~/.ssh/id_ed25519` (or the key you gave DigitalOcean).

### B1. DNS

At the company that manages the domain's DNS:

| Type | Name | Value | TTL |
|---|---|---|---|
| A | `@` (atesoraroseta.com) | `165.22.43.43` | 300 |
| A | `www` | `165.22.43.43` | 300 |

- If the domain points somewhere else today, first **lower the TTL of the existing records to 300 seconds** and wait a day, so the switch takes minutes instead of hours.
- **Delete any AAAA (IPv6) records** that point elsewhere: Let's Encrypt tries IPv6 first and would fail.
- If the DNS is at Cloudflare, set both records to **"DNS only"** (grey cloud).

**These records must resolve to the droplet before the first deploy.** kamal-proxy asks Let's Encrypt for the certificates on the first HTTPS visit, and Let's Encrypt only issues them after checking that the names point at this server. Failed checks count against Let's Encrypt's limit of 5 failures per name per hour. Check that both answer `165.22.43.43`, also from public resolvers:

```sh
dig +short atesoraroseta.com A
dig +short www.atesoraroseta.com A
dig +short atesoraroseta.com A @1.1.1.1
dig +short atesoraroseta.com A @8.8.8.8
dig +short atesoraroseta.com AAAA      # should print nothing
```

### B2. Secrets

Every secret lives in **`config/credentials.yml.enc`**, an encrypted file that *is* in git. **`config/master.key`** decrypts it and is *not* in git.

**Back up `config/master.key` now** in a password manager (for example as a secure note "atesoraroseta: config/master.key"; it is one line). If it is lost, nothing in the credentials can be read any more. You would have to start new credentials (`rm config/credentials.yml.enc`, then `bin/rails credentials:edit`), create a new Spaces key, and set the admin password again. The backups in Spaces aren't encrypted with it, so they stay usable.

Open the credentials (they open decrypted in your editor and are encrypted again when you close it; `EDITOR="code --wait"` works too):

```sh
EDITOR="nano" bin/rails credentials:edit
```

With backups on, add the `spaces` block (without them, there is nothing to add). Keep the `secret_key_base` and `admin` entries that are already there (the admin block is written by `bin/rails admin:credentials`, see B6):

```yaml
secret_key_base: …already there, don't change it…

admin:
  email: admin@atesoraroseta.com
  password: …already there…

spaces:
  access_key_id: <SPACES_ACCESS_KEY_ID>
  secret_access_key: <SPACES_SECRET_ACCESS_KEY>
```

Check that every key is there, without printing any value:

```sh
bin/rails runner 'c = Rails.application.credentials; puts({ admin: c.admin&.keys, spaces: c.spaces&.keys }.inspect)'
# {admin: [:email, :password], spaces: [:access_key_id, :secret_access_key]}
```

Then **commit `config/credentials.yml.enc`**: Kamal builds the image from your last commit, and the image carries the encrypted file.

Where each secret ends up:

| Secret | Stored in | Used by |
|---|---|---|
| `config/master.key` | your Mac and your password manager; on the server, only in the app container's environment (`RAILS_MASTER_KEY`) | the app, to decrypt the credentials |
| `admin.email`, `admin.password` | the credentials | the app: it creates or updates the admin user on every boot |
| `spaces.access_key_id`, `spaces.secret_access_key` | the credentials | the app reads them itself (uploads backup); Kamal also passes them to the Litestream container |

`.kamal/secrets` contains no secret: it only reads them from `config/master.key` and the credentials (`bin/rails credentials:fetch …`) when Kamal needs them. On the server, Kamal keeps them in env files under `~/.kamal/apps/atesoraroseta/env/` that only root can read.

### B3. The backups bucket (only with backups on)

In the control panel: **Spaces Object Storage → Create Bucket**.

- **Region:** the droplet's, for example AMS3: its slug (`ams3`) is `<SPACES_REGION>`.
- **Name:** `atesoraroseta-backups`, or another if that one is taken: that is `<SPACES_BUCKET>`.
- **File listing:** Restricted (private). No CDN.
- Add no lifecycle (expiry) rules: Litestream manages the age of its own files, and the uploads copy must keep everything.

Then **Spaces Object Storage → Access Keys → Create Access Key**:

- **Limited Access**, only to this bucket, with **Read/Write/Delete** permission (Litestream deletes database backup files older than 8 days; the uploads copy never deletes anything).
- Copy the **Access Key ID** and the **Secret Key** (shown only once) into the credentials (B2).

Spaces costs $5/month for the account, including 250 GiB of storage. Your other projects get their own buckets and keys.

#### Turning backups on

Everything that does the backups is still in the app (`BackupUploadsJob`, `bin/rails backup:*`, `config/litestream.yml`); only the deploy settings were removed. To turn them on:

1. Create the bucket and its key (above), and add the `spaces` block to the credentials (B2).
2. In `config/deploy.yml`, add the bucket's settings to `env: clear:`, and add the Litestream accessory at the end:

   ```yaml
   env:
     clear:
       # …the existing variables…
       SPACES_BUCKET: atesoraroseta-backups
       SPACES_REGION: nyc3
       SPACES_ENDPOINT: https://nyc3.digitaloceanspaces.com

   accessories:
     litestream:
       image: litestream/litestream:0.5.17
       roles:
         - web
       cmd: replicate
       files:
         - config/litestream.yml:/etc/litestream.yml:ro
       volumes:
         - "atesoraroseta_storage:/rails/storage"
       options:
         user: "1000:1000"
       env:
         clear:
           SPACES_BUCKET: atesoraroseta-backups
           SPACES_REGION: nyc3
           SPACES_ENDPOINT: https://nyc3.digitaloceanspaces.com
         secret:
           - SPACES_ACCESS_KEY_ID
           - SPACES_SECRET_ACCESS_KEY
   ```
3. In `.kamal/secrets`, add:

   ```sh
   SPACES_ACCESS_KEY_ID=$(bin/rails credentials:fetch spaces.access_key_id)
   SPACES_SECRET_ACCESS_KEY=$(bin/rails credentials:fetch spaces.secret_access_key)
   ```
4. In `config/recurring.yml`, uncomment `backup_uploads` (the nightly copy at 03:30 Madrid time).
5. Update the tests that check backups are off (`test/deploy/kamal_config_test.rb`, `test/jobs/backup_uploads_job_test.rb`), commit, then `bin/kamal deploy` and `bin/kamal accessory boot litestream`.
6. Copy everything uploaded so far right away: `bin/kamal app exec --reuse "bin/rails backup:uploads"`, then check with `backup:status` (B7).

A cheaper safety net without Spaces: DigitalOcean's droplet backups (the droplet's **Backups** tab, 20–30% of the droplet's price) snapshot the whole server weekly or daily, with no change to the app.

### B4. First deploy

First check `config/deploy.yml`: `grep -n "<[A-Z_]*>" config/deploy.yml` must print nothing (with backups off there are no placeholders left), and **commit**. Kamal always deploys the last commit; uncommitted changes are not deployed. `bin/kamal config` shows the result (it prints no secret values here, but don't paste its output publicly).

Then:

```sh
bin/kamal setup
```

It takes a few minutes. Kamal:

1. installs Docker on the droplet if it is missing;
2. builds the image on your Mac (for amd64), pushes it to the local registry and has the droplet pull it over SSH (A5);
3. starts kamal-proxy if no other project has;
4. with backups on, starts the Litestream container (`atesoraroseta-litestream`);
5. starts the app, which prepares the databases on the first boot (the site's default texts and the admin user), and switches kamal-proxy to it as soon as `/up` answers.

With backups on, during the first 30 seconds Litestream logs `timeout waiting for db initialization` warnings, because the database doesn't exist yet. That is expected; after that it replicates.

**Checks:**

```sh
curl -sI https://atesoraroseta.com | head -1                      # HTTP/2 200
curl -sI http://atesoraroseta.com | grep -i location               # https://atesoraroseta.com/
curl -sI https://www.atesoraroseta.com/sobre-mi | grep -i location # https://atesoraroseta.com/sobre-mi
curl -svo /dev/null https://atesoraroseta.com 2>&1 | grep -E "issuer|expire date"   # Let's Encrypt
# only with backups on:
bin/kamal accessory logs litestream --lines 20                     # "replicating to … bucket=…", "compaction complete"
bin/kamal app exec --reuse "bin/rails backup:status"
```

Then open **https://atesoraroseta.com/admin**: it asks you to log in. Use `admin@atesoraroseta.com` and the password from the credentials (`bin/rails credentials:show` shows it on your Mac; never paste it anywhere). There is no separate step to create the admin user: the first boot created it from the credentials.

### B5. Daily operation

| To… | Run |
|---|---|
| deploy your latest commit (no downtime) | `bin/kamal deploy` |
| see which versions exist on the server | `bin/kamal app containers` |
| go back to an earlier version (a git commit id) | `bin/kamal rollback <VERSION>` |
| follow the app's log | `bin/kamal logs` |
| read the last hour of log | `bin/kamal app logs --since 1h` |
| the proxy's log (all sites' requests) | `bin/kamal proxy logs` |
| the Litestream log | `bin/kamal accessory logs litestream` |
| a Rails console in the running app | `bin/kamal console` |
| a shell in the running app | `bin/kamal shell` |
| the database's SQL console | `bin/kamal dbc` |
| one command in the running app | `bin/kamal app exec --reuse "bin/rails backup:status"` |
| one command in a fresh container | `bin/kamal app exec "bin/rails about"` |
| what is running | `bin/kamal details` |
| disk space on the droplet | `bin/kamal server exec "df -h /"` and `bin/kamal server exec "docker system df"` |
| apply a change to `config/litestream.yml` or upgrade Litestream (the image tag in `deploy.yml`) | `bin/kamal accessory reboot litestream` |

Notes:

- `bin/kamal deploy` starts the new version next to the old one and switches traffic once `/up` answers (within 30 seconds), so visitors notice nothing. A version that doesn't boot is never switched to: the old one keeps serving.
- A rollback runs older code against the current database; database migrations are not undone.
- Kamal keeps the running version and the 3 before it on the droplet, for rollbacks, and removes older ones to spare the disk other projects share.
- The `console`, `shell`, `logs` and `dbc` shortcuts are the `aliases` in `config/deploy.yml`.

### B6. Admin password

- The admin login comes from the encrypted credentials (`admin.email`, `admin.password`). **On every boot the app creates the admin user, or updates its password** if the credentials changed (`bin/rails admin:sync`), so the first deploy creates it and there is nothing else to run. There is no "forgot password" and no email.
- **To change the password:**

  ```sh
  bin/rails admin:credentials        # asks for the email and the new password (twice, not shown)
  git add config/credentials.yml.enc && git commit -m "Change the admin password"
  bin/kamal deploy
  ```

  When the new version boots, the password changes and **every open session is signed out**. Passwords need at least 12 characters.
- **In an emergency**, for example if you can't log in after a database restore, re-apply the password of the version that is running:

  ```sh
  bin/kamal app exec -i --reuse "bin/rails admin:sync"
  ```

  It prints one line: `Admin: contraseña de admin@atesoraroseta.com actualizada; 2 sesiones cerradas.` when it had to change the password (which also signs every session out), or `Admin: admin@atesoraroseta.com sin cambios.` It can only apply the password of the deployed image, so a *new* password always needs a commit and a deploy. (Every boot does the same, including `bin/kamal app start`.)
- **To sign everyone out** without changing the password: `bin/kamal app exec --reuse "bin/rails runner 'Session.delete_all'"`.
- Forgot the password? It is in the credentials: `bin/rails credentials:show` on your Mac.
- The login allows 5 attempts per 10 minutes from one IP address.

### B7. Backups (only with backups on)

**What is backed up, and when:**

| What | How | When | Kept |
|---|---|---|---|
| the main database (`storage/production.sqlite3`) | Litestream → `db/` in the bucket | continuously, within a second or two of each change | any moment of the last **7 days** can be restored (snapshots are kept 8 days) |
| the uploaded files: originals and resized versions | the `BackupUploadsJob` → `uploads/<key>` | **every night at 03:30, Madrid time** | forever: the copy never deletes, so an older database always finds its images |
| the cache, job queue and Action Cable databases | not backed up | | recreated empty after a restore (jobs that hadn't run are lost; a resized image that wasn't made yet is made on its first view) |

Images uploaded since the last 03:30 are not in the bucket yet. After a big upload session you can copy them right away:

```sh
bin/kamal app exec --reuse "bin/rails backup:uploads"
# Copia de seguridad de los archivos subidos: 12 copiados a Spaces (31,4 MB), 240 ya estaban allí, 0 sin archivo en el disco, 0 con errores.
```

**Check the backups:**

```sh
bin/kamal app exec --reuse "bin/rails backup:status"
# Archivos subidos: 252 en la base de datos, 252 en el disco (0 faltan), 252 en Spaces (uploads/), 0 sin copia en Spaces.
# Base de datos (Litestream, db/): 41 archivos; última transacción 00000000000003e2, subida el 2026-11-02 18:04:11 UTC; última instantánea: 2026-11-02 00:00:03 UTC.
bin/kamal accessory logs litestream --lines 20
```

Now and then, test that the database really restores (into a throwaway container; nothing on the server changes):

```sh
bin/kamal accessory exec litestream "restore -integrity-check full -o /tmp/check.sqlite3 /rails/storage/production.sqlite3"
# … msg="post-restore integrity check passed"
```

Times in the commands below are in **UTC**, written like `2026-11-02T17:30:00Z`. Madrid is UTC+1 in winter and UTC+2 in summer: 18:30 in Madrid on 2 November is `2026-11-02T17:30:00Z`. To see what a restore would fetch without writing anything, add `-dry-run`.

#### Restore on the same droplet (undo a mistake, or a damaged database)

For example, works were deleted in the admin by mistake at about 18:40 Madrid time, and you want the site as it was at 18:30:

```sh
bin/kamal app stop                          # the site is offline until "app start"
bin/kamal accessory stop litestream
bin/kamal accessory exec litestream "restore -force -timestamp 2026-11-02T17:30:00Z /rails/storage/production.sqlite3"
bin/kamal accessory start litestream
bin/kamal app start
bin/kamal app exec --reuse "bin/rails backup:restore_uploads"
```

- `-force` replaces the current database (and its `-wal`/`-shm` files). Nothing is lost: the state you replaced stays in the backup history and can be restored with a later timestamp.
- To restore the **latest** state instead (a damaged database file), leave out `-timestamp …`.
- `backup:restore_uploads` downloads the images that the restored database needs and the disk no longer has. It overwrites nothing:

  ```
  Restauración de los archivos subidos: 5 descargados de Spaces (2,02 MB), 0 ya estaban en el disco, 0 no están en Spaces, 0 con errores.
  ```
- After the restore Litestream continues the same history, so later restores include the restored state and everything after it.

#### Restore on a brand-new droplet (the old one is gone)

**Restore the database before the app boots for the first time.** Otherwise the app creates an empty database and Litestream starts replicating it. Nothing would be lost even then, because the history keeps the old data: restore it as on the same droplet, with `-timestamp` set just before that first boot.

1. Create the droplet and its firewall (A1), point both DNS records at the new IP (B1), put the new IP in `config/deploy.yml`, and commit.
2. Then:

   ```sh
   bin/kamal server bootstrap                  # installs Docker
   bin/kamal accessory boot litestream         # uploads its configuration and keys, and creates the volume
   bin/kamal accessory stop litestream
   # The new volume belongs to root; the app and Litestream run as the user 1000:
   bin/kamal server exec "docker run --rm --user 0:0 --entrypoint chown --volume atesoraroseta_storage:/rails/storage litestream/litestream:0.5.17 1000:1000 /rails/storage"
   bin/kamal accessory exec litestream "restore -if-replica-exists /rails/storage/production.sqlite3"
   bin/kamal accessory start litestream
   bin/kamal setup                             # builds, starts the proxy and the app; the database is already there
   bin/kamal app exec --reuse "bin/rails backup:restore_uploads"
   ```

3. Run the checks of B4.

Without the `chown` step, the restore stops with `permission denied`. `-if-replica-exists` makes the restore succeed quietly when there is no backup at all yet.

#### What the restore rehearsal proved

Before this guide was written, both restores were rehearsed on a Mac with the production image (amd64), MinIO standing in for Spaces, Litestream 0.5.17 and kamal-proxy v0.9.2, using the same container options Kamal uses. An artwork with its image was created and backed up. Then the volume was wiped and everything was restored with the commands above; the image came back byte for byte at the same address. On the same volume, an accidental deletion was rolled back. See `docs/handoff/WP5.md` for the details.

### B8. Troubleshooting

**The certificate isn't issued** (the browser warns, or `curl https://…` fails):

- `dig` (B1) must show `165.22.43.43` for both names and no AAAA record.
- The firewall must allow ports 80 and 443 (A1).
- `bin/kamal proxy logs | grep -i -E "acme|certificate|tls"` shows Let's Encrypt's answer. After several failures, Let's Encrypt refuses for an hour; fix DNS, wait, and visit the site again.

**DNS:** changes can take up to the old TTL to reach everyone. `dig @1.1.1.1` and `dig @8.8.8.8` show what the public resolvers see.

**Deploy fails ("container is unhealthy", "target failed to become healthy"):**

- `bin/kamal app logs --lines 200` shows why the new version didn't boot. The old one keeps serving.
- `ActiveSupport::MessageEncryptor::InvalidMessage`: `config/master.key` doesn't match `config/credentials.yml.enc` (B2).
- The droplet can't pull the image: the local registry isn't running (A5). Docker Desktop must be running, and `docker ps` on your Mac must show `kamal-docker-registry`; `bin/kamal registry setup` starts it again.
- "kamal-proxy version … is too old": see A4.

**Disk space:**

- `bin/kamal server exec "df -h /"` and `bin/kamal server exec "docker system df"`.
- Kamal removes this app's old containers and images on every deploy, keeping the running version and the 3 before it. Versions share most of their layers, so each costs only some tens of MB. Each container's log is capped at 10 MB.
- Don't run `docker system prune -a` on the shared server; it removes other projects' rollback images too.

**Building the image on Apple Silicon:**

- Docker Desktop must be running (`open -a Docker`, then `docker info`).
- "exec format error", or very slow builds: turn on **Use Rosetta for x86_64/amd64 emulation** in Docker Desktop's settings.
- If builds are still too slow, Kamal can build on the droplet itself, natively: add `remote: ssh://root@165.22.43.43` under `builder:` in `config/deploy.yml`. It is faster, but every build then takes CPU, memory and disk from the server your other projects share; that is why it is off.

**Backups:**

- `backup:status` says Spaces isn't configured ("Faltan los datos del bucket de copias en Spaces: …"): a `SPACES_*` value is missing in `config/deploy.yml` (bucket, region, endpoint) or in the credentials (keys).
- Litestream logs `AccessDenied` or `InvalidAccessKeyId`: the Spaces key is wrong, or doesn't have Read/Write/Delete on this bucket (B3).
- After changing the Spaces keys in the credentials: commit `config/credentials.yml.enc`, run `bin/kamal deploy` (the app reads them from the image), then `bin/kamal accessory reboot litestream` (Litestream gets them when it boots).

**Uploads:** the app accepts images up to 25 MB. The proxy refuses any request over 30 MiB.

---

## Part C: adding another project to the server

Each new project is its own Kamal app, in its own folder, deployed to the same `165.22.43.43`. It needs:

- a **unique service name** (it also names its containers);
- its **own volume**, named after the service, if it stores anything;
- its **own domain(s)** in `proxy.hosts`, with DNS pointing at the droplet;
- for backups, its own Spaces bucket and key (no registry is needed, A5);
- **no published ports** and **no `proxy:` → `run:` section**.

A minimal `config/deploy.yml`:

```yaml
service: otro-proyecto
image: otro-proyecto

servers:
  web:
    - 165.22.43.43

proxy:
  ssl: true
  hosts:
    - otro-proyecto.example
    - www.otro-proyecto.example
  app_port: 80              # the port the app listens on inside its container
  healthcheck:
    path: /up               # any path that answers 200 when the app is ready

registry:
  server: localhost:5555

volumes:
  - "otro-proyecto_storage:/data"

builder:
  arch: amd64
```

A static site works the same way: a tiny image (for example nginx serving the files on port 80) with this kind of `deploy.yml`. Its `bin/kamal setup` finds kamal-proxy already running and only adds its own host names. Check the droplet's memory (`bin/kamal server exec "free -m"`) before adding apps to a 2 GB droplet.
