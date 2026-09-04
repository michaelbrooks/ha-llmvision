#!/usr/bin/env bash
# Rebase the `local` branch onto the tracked upstream ref (branch or tag).
#
# Fetches upstream, shows what commits would be picked up, asks for
# confirmation, then runs `git rebase`. On conflict, leaves the user
# in the rebase state with instructions. On success, prints next steps.

set -euo pipefail

UPSTREAM_REF="v1.7.2"

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$current_branch" != "local" ]]; then
    echo "error: must be on 'local' branch (currently on '$current_branch')" >&2
    exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "error: working tree has uncommitted changes; commit or stash first" >&2
    exit 1
fi

echo "==> Fetching upstream..."
git fetch upstream

echo
echo "==> Tracked upstream ref: $UPSTREAM_REF"
echo "==> Upstream HEAD: $(git rev-parse --short "$UPSTREAM_REF") $(git log -1 --pretty=%s "$UPSTREAM_REF")"
echo

behind=$(git rev-list --count "local..$UPSTREAM_REF")
ahead=$(git rev-list --count "$UPSTREAM_REF..local")

if [[ "$behind" -eq 0 ]]; then
    echo "==> Already up to date with $UPSTREAM_REF. Nothing to do."
    exit 0
fi

echo "==> Commits that will be picked up from upstream ($behind commits):"
git log --oneline "local..$UPSTREAM_REF"
echo
echo "==> Local patches that will be rebased on top ($ahead commits):"
git log --oneline "$UPSTREAM_REF..local"
echo

read -r -p "Proceed with rebase? [y/N] " answer
case "$answer" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Aborted."; exit 1 ;;
esac

echo
echo "==> Rebasing local onto $UPSTREAM_REF..."
if git rebase "$UPSTREAM_REF"; then
    echo
    echo "==> Rebase complete."
    echo
    echo "Next steps:"
    echo "  1. ./run_tests.sh                 # verify nothing is broken"
    echo "  2. ./local/bump-version.sh        # bump manifest version"
    echo "  3. ./local/release.sh             # tag + push + GitHub Release"
else
    echo
    echo "==> Rebase stopped on a conflict."
    echo
    echo "Resolve the conflict:"
    echo "  git status                      # see which files conflict"
    echo "  # edit the files..."
    echo "  git add <file>"
    echo "  git rebase --continue"
    echo
    echo "Or abort:"
    echo "  git rebase --abort"
    exit 1
fi
