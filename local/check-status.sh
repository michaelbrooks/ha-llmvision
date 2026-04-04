#!/usr/bin/env bash
# Read-only status report for the fork.
# Safe to run anytime — only reads remotes, never modifies anything.

set -euo pipefail

UPSTREAM_REF="upstream/v1.7.0-beta"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

MANIFEST="custom_components/llmvision/manifest.json"

# Parse owner/repo from origin remote URL so `gh` calls explicitly target
# the fork even when multiple remotes exist (origin + upstream).
origin_url="$(git remote get-url origin)"
origin_repo="$(echo "$origin_url" | sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##')"

echo "==> Fetching remotes..."
git fetch upstream --quiet 2>/dev/null || echo "  (upstream fetch failed, continuing)"
git fetch origin --quiet 2>/dev/null || echo "  (origin fetch failed, continuing)"

echo
echo "==> Current branch: $(git rev-parse --abbrev-ref HEAD)"
echo "==> HEAD:           $(git rev-parse --short HEAD) $(git log -1 --pretty=%s)"
echo

echo "==> Tracked upstream: $UPSTREAM_REF"
if git rev-parse --verify "$UPSTREAM_REF" >/dev/null 2>&1; then
    behind=$(git rev-list --count "local..$UPSTREAM_REF" 2>/dev/null || echo "?")
    ahead=$(git rev-list --count "$UPSTREAM_REF..local" 2>/dev/null || echo "?")
    echo "    Behind upstream: $behind commit(s)"
    echo "    Local patches:   $ahead commit(s)"
else
    echo "    (ref not found — is the upstream remote configured?)"
fi
echo

if git rev-parse --verify "$UPSTREAM_REF" >/dev/null 2>&1; then
    echo "==> Commits behind upstream:"
    git log --oneline "local..$UPSTREAM_REF" | sed 's/^/    /' || echo "    (none)"
    echo
    echo "==> Local patches (on top of $UPSTREAM_REF):"
    git log --oneline "$UPSTREAM_REF..local" | sed 's/^/    /' || echo "    (none)"
    echo
fi

echo "==> Manifest version: $(jq -r .version "$MANIFEST" 2>/dev/null || echo 'unknown')"
echo

if command -v gh >/dev/null 2>&1; then
    echo "==> Latest GitHub Release on $origin_repo:"
    latest=$(gh release list --repo "$origin_repo" --limit 1 --json tagName,name,publishedAt,isLatest 2>/dev/null || echo "")
    if [[ -n "$latest" && "$latest" != "[]" ]]; then
        echo "$latest" | jq -r '.[] | "    \(.tagName)   \(.name)   (\(.publishedAt))"'

        last_tag=$(echo "$latest" | jq -r '.[0].tagName')
        if [[ -n "$last_tag" && "$last_tag" != "null" ]]; then
            echo
            echo "==> Commits since last release ($last_tag):"
            if git rev-parse --verify "refs/tags/$last_tag" >/dev/null 2>&1; then
                git log --oneline "$last_tag..HEAD" | sed 's/^/    /' || echo "    (none — HEAD is at the release tag)"
            else
                echo "    (tag not found locally; run: git fetch origin --tags)"
            fi
        fi
    else
        echo "    (no releases yet)"
    fi
else
    echo "==> gh CLI not installed — skipping Release status"
fi
