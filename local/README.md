# Local fork of ha-llmvision

This is a **public, non-fork** copy of [valentinfrlch/ha-llmvision](https://github.com/valentinfrlch/ha-llmvision)
maintained by @michaelbrooks. It carries a small stack of local-only patches on
top of a tracked upstream branch and is deployed to a personal Home Assistant
instance via HACS GitHub Releases.

The repo is public (HACS requires public repositories) but is **not** a GitHub
fork — it has no fork badge, no "forked from" header, and does not appear in
upstream's fork list. The patches in this fork are **not intended for upstream
contribution**.

## Branching model

```
upstream/v1.7.0-beta  (remote, read-only — valentinfrlch/ha-llmvision)
         │
         │  periodic: ./local/sync-upstream.sh
         ▼
origin/local (private repo default branch — michaelbrooks/ha-llmvision)
  │
  ├─ local: rename to "LLM Vision (Fork)" for HACS coexistence
  ├─ local: add maintenance scripts and documentation
  ├─ local: bump manifest version to 1.7.0.N
  └─ local: (future patches go here, as separate single-purpose commits)
```

- `local` is the only long-lived branch. It holds the stack of local patches
  rebased on top of the tracked upstream branch.
- No `main` branch, no `upstream-sync` mirror. Upstream is consulted via the
  `upstream` git remote directly.
- Each local patch is a single, well-named commit starting with `local: ` so
  they're easy to identify during rebase.

## Version and tag format

The `version` field in `custom_components/llmvision/manifest.json` uses a
**4-component format**: `MAJOR.MINOR.PATCH.LOCAL`, where `LOCAL` is a counter
that increments on every release of this fork.

- `1.7.0.1` — first local release based on upstream `v1.7.0-beta`
- `1.7.0.2` — subsequent release (same upstream base)
- `1.7.1.1` — first local release after rebasing onto a hypothetical upstream `v1.7.1`

This format is always strictly greater than `X.Y.Z` (the upstream base) and
strictly less than `X.Y.(Z+1)` (the next upstream patch). HACS's version
library (`awesomeversion`) handles 4-component versions correctly.

Git tags and GitHub Release titles use the `v`-prefix convention: `v1.7.0.1`.
The literal word "local" appears in the tag message and Release title, not in
the version string.

## Tracked upstream branch

The fork currently tracks `upstream/v1.7.0-beta` because it carries two
features we depend on:

1. Ollama provider uses `"think": false` by default, suppressing reasoning
   output from thinking-capable models (qwen3.5, qwen3-vl, etc.).
2. Ollama provider uses `/api/generate` instead of `/api/chat`, which avoids a
   response-suffix bug that required a local workaround on the previous base.

When upstream ships v1.7.0 stable (or later), the tracked branch in
`local/sync-upstream.sh` should be updated accordingly.

## Routine workflow

```bash
cd ~/ha-projects/ha-llmvision

# Periodic: pull upstream updates
./local/sync-upstream.sh

# After any change (sync, local fix, etc.):
./run_tests.sh              # verify nothing is broken
./local/bump-version.sh     # bump manifest version + commit
./local/release.sh          # tag + push + create GitHub Release

# Home Assistant's HACS will notice the new Release and offer to update.
```

Check current state at any time:

```bash
./local/check-status.sh
```

## HACS deployment

HACS on Home Assistant is configured with `michaelbrooks/ha-llmvision` as a
**custom repository** (category: Integration). Because the repo has GitHub
Releases, HACS pulls the latest Release tag — not the default branch.

Note: HACS **does not support private repositories** — this is a hard limit in
HACS's OAuth scope (`public_repo` only). The repo must remain public for HACS
deployment to work.

### Rolling back a bad release

```bash
# Delete the bad GitHub Release (and its tag)
gh release delete v1.7.0.N --yes --cleanup-tag

# On the next HACS refresh, HACS offers the prior Release as "latest"
# Click update in HACS → HA pulls the older version.
```

No branch surgery, no backup restore — Release-based rollback is the cleanest
path.

### Rolling back a bad sync

If `sync-upstream.sh` results in a broken rebase you want to abandon:

```bash
git rebase --abort            # if still mid-rebase
git reset --hard origin/local # if rebase finished but you haven't pushed
```

If you already pushed and cut a release:
```bash
gh release delete v1.7.0.N --yes --cleanup-tag
git reset --hard <previous-good-sha>
git push origin local --force-with-lease
```

## Migration history

This repo was migrated from a public fork on 2026-04-04 as part of a broader
restructuring. Key changes:

- Public fork `michaelbrooks/ha-llmvision` renamed to
  `michaelbrooks/ha-llmvision-public-oldworking`, then deleted.
- New **non-fork** repo created at `michaelbrooks/ha-llmvision` (initially
  private, later made public because HACS requires public repos).
- Default branch renamed from `main` to `local`.
- Tracked upstream branch changed from `main` to `v1.7.0-beta` (to pick up
  Ollama thinking-off-by-default and /api/generate refactor).
- Deployment mechanism changed from default-branch-tracking to GitHub Releases.
- Obsolete `<end_` suffix workaround dropped during the rebase (no longer
  needed on v1.7.0-beta's /api/generate code path).

## Files in this directory

| File | Purpose |
| --- | --- |
| `README.md` | This file |
| `sync-upstream.sh` | Fetch upstream and rebase `local` onto `upstream/v1.7.0-beta` |
| `bump-version.sh` | Increment the 4th component of `manifest.json`'s version and commit |
| `release.sh` | Tag `v<version>`, push, create GitHub Release |
| `check-status.sh` | Read-only status: upstream divergence, local patches, latest Release |
