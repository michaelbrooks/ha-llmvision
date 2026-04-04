#!/usr/bin/env bash
# Increment the 4th component of the version in manifest.json and commit.
#
# Handles two starting formats:
#   "1.7.0"    -> "1.7.0.1"   (add 4th component)
#   "1.7.0.3"  -> "1.7.0.4"   (increment existing 4th component)
#
# Refuses any other format to avoid corrupting the manifest.

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

MANIFEST="custom_components/llmvision/manifest.json"

if [[ ! -f "$MANIFEST" ]]; then
    echo "error: $MANIFEST not found" >&2
    exit 1
fi

current="$(jq -r .version "$MANIFEST")"
echo "==> Current version: $current"

if [[ "$current" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    # 3-component: add .1
    new="${current}.1"
elif [[ "$current" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    # 4-component: increment last
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    patch="${BASH_REMATCH[3]}"
    local_rev="${BASH_REMATCH[4]}"
    new="${major}.${minor}.${patch}.$((local_rev + 1))"
else
    echo "error: version '$current' does not match MAJOR.MINOR.PATCH[.LOCAL] format" >&2
    echo "       refusing to bump automatically; edit $MANIFEST manually" >&2
    exit 1
fi

echo "==> New version:     $new"

# Surgically replace only the version line using sed, preserving the rest of
# the file's formatting exactly (including any compact-array formatting that
# upstream uses). A full jq round-trip would reformat compact arrays into
# multi-line form, producing noisy diffs.
sed -i -E 's/("version"[[:space:]]*:[[:space:]]*)"[^"]*"/\1"'"$new"'"/' "$MANIFEST"

# Verify the change took effect by reading it back with jq.
written="$(jq -r .version "$MANIFEST")"
if [[ "$written" != "$new" ]]; then
    echo "error: version update failed — manifest still reads '$written'" >&2
    exit 1
fi

echo "==> Updated $MANIFEST"

git add "$MANIFEST"
git commit -m "local: bump manifest version to $new"

echo
echo "==> Commit created:"
git log -1 --oneline
echo
echo "Next: ./local/release.sh"
