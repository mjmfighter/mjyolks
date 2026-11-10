# mjyolks

Docker images and Pterodactyl / Pelican eggs for the game servers I run.

The canonical image is `rust/` (built as `ghcr.io/mjmfighter/mjyolks:rust`).
`rust-new/`, `rust-test/`, and `rust-error/` were older WIP variants and have
been removed.

## Rust server GitOps sync

On boot, `rust/entrypoint.sh` shallow-clones a per-server GitHub repo and
rsyncs its contents over the live game files, then boots the server. The
live and test eggs point at different branches of the same repo (`main`
vs `dev`) and carry different fine-grained read-only PATs.

### Egg files

- `eggs/egg-rust.json` — live variant. Syncs from `main`.
- `eggs/egg-rust-test.json` — test variant. Syncs from `dev`.

Both share the same Docker image. Each server supplies its own
`GITHUB_ACCESS_TOKEN` via the panel (never committed).

### Sync-related env vars

| Variable | Purpose |
| --- | --- |
| `GITHUB_URL` | HTTPS URL of the per-server config repo. |
| `GITHUB_USERNAME` / `GITHUB_ACCESS_TOKEN` | Credentials for the clone. Token should be a GitHub fine-grained PAT, `Contents: Read`, scoped to the one repo. |
| `GITHUB_BRANCH` | Branch to clone (`main` for live, `dev` for test). |
| `GITHUB_SYNC` | Set to `0` to skip sync even when `GITHUB_URL` is set. Defaults to syncing. |
| `GITHUB_FILE_POSTFIX` | Strip this suffix from filenames in the clone before syncing (e.g. `.live` turns `Foo.json.live` into `Foo.json`). Lets one repo hold both variants. |
| `GITHUB_FILE_POSTFIX_PURGE` | Delete files ending in this suffix from the clone *before* the rename pass. Set to the *other* server's postfix so test-only files don't leak into live and vice versa. |
| `SYNC_FILES` | Space-separated list of repo-relative individual files to mirror-sync (e.g. `carbon/config.json`). Honours `<path>.ignore` sidecars for seed-only semantics. |

### Directory sync groups

Fixed in `sync_github_repo()` — not configurable per server:

- **Additive** (repo wins where it has files, server wins where it doesn't): `carbon/data`, `carbon/lang`, `carbon/modules`, `carbon/managed/modules`, `HarmonyMods_Data`, `server`.
- **Mirror with delete + `.ignore` sidecars**: `carbon/plugins`, `carbon/configs`. The GitOps pipeline relies on this behaviour — don't change it without updating the pipeline.
- **Newer-wins mirror**: `carbon/extensions`.

### `.deployed-commit`

After a successful sync, the entrypoint writes the cloned commit SHA to
`$HOME_DIR/.deployed-commit` (one 40-char line + newline). Used by the
sibling `plugin-updater` drift-check and useful for operators:

```sh
cat ~/.deployed-commit
```

If the sync fails (network, outage, revoked token), the server still
boots on the previously-synced files and `.deployed-commit` stays pointed
at the last successful deploy — which is what's actually running.
