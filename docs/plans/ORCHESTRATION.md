# Orchestrating the atesoraroseta build

You are the **orchestrator**: the main Claude Code session in `/Users/eitanfuturo/develop/projects/atesoraroseta`. Your job is to run the work packages (WP1–WP6) in `docs/plans/` as subagents, not to write the app yourself.

The user approved these plans on 2026-10-12. **The user's orchestration prompt is the go-ahead**, so don't ask for approval again.

## Ground rules

- **Read little.** Read only this file and `00-overview.md` §1–3. The agents read the rest. Your context should grow only by agent reports and short verification output (`| tail -n 5`), never by diffs, code or full logs.
- **Spawning agents:**
  - Use the Agent tool with `subagent_type: "general-purpose"` and `effort: "max"`. The user explicitly asked for max effort on every work package.
  - WP1, WP2 and WP6 run in the main checkout, without isolation.
  - WP3, WP4 and WP5 run with `isolation: "worktree"`, all three launched **in one message** so they run in parallel.
  - Before launching them, `git status` on `main` must be clean, because worktrees branch from the last commit.
- **Agents run in the background** and you are notified when each one finishes. Don't poll, don't sleep, and never invent or predict a result.
- **The real admin password** is given only in the user's prompt. Never write it to a file, commit, plan, handoff, memory, agent prompt or message. Pass it only through an environment variable to the one command in step 3, and never echo it.
- **Keep the user posted** with one short line when each phase starts and ends. Collect non-blocking questions from the agents' reports for the final message. Stop and ask only when a phase is truly blocked.
- **Don't redo an agent's work yourself.** If a WP fails, relaunch it, or launch a fix agent with a prompt that names the problem and points at its handoff note.

## Sequence

1. **WP1: toolchain and skeleton.**
   - Launch it in the main checkout.
   - When it finishes, verify: `ruby -v` (4.0.7), `bin/rails -v` (8.1.4), `git log --oneline | head -3`, and `bin/rails test 2>&1 | tail -n 3`.
   - If it reports a toolchain blocker (Homebrew, compile errors), tell the user exactly what's needed.
2. **WP2: domain, images core and seeds.** Launch it in the main checkout, then verify:
   - the test tail;
   - `bin/rails db:seed:replant 2>&1 | tail -n 3`;
   - `bin/rails runner 'p [Artwork.count, ArtworkDetail.count, TornPoster.count, Site.count]'`, which should print `[9, 8, 12, 1]`.
3. **Admin credentials.** Do this yourself; it's a single command.
   - Run WP2's `bin/rails admin:credentials` non-interactively, with `ADMIN_EMAIL=admin@atesoraroseta.com` and `ADMIN_PASSWORD=<password from the user's prompt>` set only on that command line. If WP2 named the task differently, its handoff says so.
   - Then run `bin/rails admin:sync`.
   - Verify by printing **only the email**: `bin/rails runner 'puts Rails.application.credentials.dig(:admin, :email)'`.
   - Commit `config/credentials.yml.enc` with the message "Add admin credentials (encrypted)". `config/master.key` stays ignored.
4. **WP3, WP4 and WP5 in parallel**, three Agent calls in one message, each with `isolation: "worktree"`.
   - Note each report's **branch name** and last commit.
   - If one of them is blocked, relaunch it alone. The others don't wait.
5. **WP6: integrate, QA and README.** Launch it in the main checkout with the three branch names in its prompt. It merges them first, then runs QA.
   - Verify: `git log --oneline | head -5`, the test tail, and that `README.md` exists.
6. **Final message to the user**, following PROMPT.md "How to work" point 4:
   - how to run the site locally;
   - how to log into `/admin` (the email is `admin@atesoraroseta.com`; the password comes from the credentials and is never printed);
   - what content is still missing (from WP6's report);
   - what's needed to deploy: the droplet IP and size, the registry name, the Spaces region and bucket, and pointing the DNS at the droplet;
   - open decisions from all handoffs, plus this one, if the user hasn't answered it: does the droplet already run anything on ports 80/443? kamal-proxy needs them, so an existing site would move behind it.

## Agent prompt template

> You are a fresh subagent executing **WP{n}: {title}** of the atesoraroseta build, at maximum effort. Project root: `/Users/eitanfuturo/develop/projects/atesoraroseta`. Read `docs/plans/00-overview.md` in full, then `docs/plans/{file}`, and do exactly what it says, including the handoff note and the report format at the end. You can't ask the user anything: take the conservative option and report it. Never write the real admin password anywhere. {extra}

`{extra}` per WP:
- **WP3, WP4, WP5:** "You are in your own git worktree. Copy `config/master.key` from the project root above into it (never commit it), commit only on your branch, and report the branch name."
- **WP6:** "First merge these branches into `main`: {wp3}, {wp4}, {wp5}, as described in your plan's step 0."

| WP | Title | Plan file |
|---|---|---|
| 1 | Toolchain and app skeleton | `01-toolchain-and-skeleton.md` |
| 2 | Domain models, image pipeline core and seeds | `02-domain-and-content.md` |
| 3 | Public site | `03-public-site.md` |
| 4 | Back office at /admin | `04-admin.md` |
| 5 | Deployment and off-server backups | `05-deploy-and-backups.md` |
| 6 | Integration, QA and the final handoff | `06-qa-and-handoff.md` |
