#!/usr/bin/env bash
# Tag the current HEAD with v<version> from manifest.json, push it, and
# create a GitHub Release.
#
# Prerequisites:
#   - `gh` CLI installed and authenticated
#   - Working tree clean
#   - On `local` branch
#   - Version tag does not already exist

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

MANIFEST="custom_components/llmvision/manifest.json"
UPSTREAM_REF_LABEL="upstream v1.7.1-beta"

# Parse owner/repo from origin remote URL so `gh` calls explicitly target
# the fork even when multiple remotes exist (origin + upstream).
origin_url="$(git remote get-url origin)"
origin_repo="$(echo "$origin_url" | sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##')"

# --- Preflight checks ---

if ! command -v gh >/dev/null 2>&1; then
    echo "error: gh CLI not found in PATH" >&2
    exit 1
fi

current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$current_branch" != "local" ]]; then
    echo "error: must be on 'local' branch (currently on '$current_branch')" >&2
    exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "error: working tree has uncommitted changes" >&2
    exit 1
fi

version="$(jq -r .version "$MANIFEST")"
tag="v$version"

if [[ -z "$version" || "$version" == "null" ]]; then
    echo "error: could not read version from $MANIFEST" >&2
    exit 1
fi

echo "==> Version: $version"
echo "==> Tag:     $tag"

# Check tag doesn't exist locally
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    echo "error: tag $tag already exists locally" >&2
    exit 1
fi

# Check tag doesn't exist on origin
if git ls-remote --exit-code --tags origin "$tag" >/dev/null 2>&1; then
    echo "error: tag $tag already exists on origin" >&2
    exit 1
fi

# Check GitHub Release doesn't exist
if gh release view "$tag" --repo "$origin_repo" >/dev/null 2>&1; then
    echo "error: GitHub Release $tag already exists on $origin_repo" >&2
    exit 1
fi

# --- Confirmation ---

echo
echo "==> Current HEAD: $(git rev-parse --short HEAD) $(git log -1 --pretty=%s)"
echo "==> Will create:"
echo "      1. annotated tag $tag pointing at HEAD"
echo "      2. push branch 'local' and tag '$tag' to origin"
echo "      3. GitHub Release '$tag' with auto-generated notes"
echo

read -r -p "Proceed? [y/N] " answer
case "$answer" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted."; exit 1 ;;
esac

# --- Execute ---

echo
echo "==> Creating annotated tag..."
git tag -a "$tag" -m "local release $version (based on $UPSTREAM_REF_LABEL)"

echo "==> Pushing branch and tag to origin..."
git push origin local --follow-tags

echo "==> Creating GitHub Release on $origin_repo..."
gh release create "$tag" \
    --repo "$origin_repo" \
    --title "$tag — local rev of $UPSTREAM_REF_LABEL" \
    --notes "Local release $version based on $UPSTREAM_REF_LABEL. See commit history for details." \
    --latest

echo
echo "==> Release created:"
gh release view "$tag" --repo "$origin_repo" --json url --jq .url
