#!/usr/bin/env bash
# Fetch every component at the commit pinned in components.lock into
# ./components/<name>, and build the example UAPF package into ./packages.
# Safe to re-run: existing checkouts are moved to the pinned commit.
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p components packages
grep -vE '^\s*(#|$)' components.lock | while read -r name repo commit; do
  dir="components/$name"
  if [ ! -d "$dir/.git" ]; then
    echo "==> cloning $name"
    git clone --quiet "$repo" "$dir"
  fi
  echo "==> $name @ ${commit:0:12}"
  git -C "$dir" fetch --quiet origin
  git -C "$dir" -c advice.detachedHead=false checkout --quiet "$commit"
done

# Example process package (UAPF-IP, MIT): document intake classified by AI,
# routed by a DMN decision table, announced as an event.
src="components/uapf-ip/examples/opendms-document-intake"
tmp="$(mktemp -d)"
cp -r "$src/." "$tmp/"
# The reference engine discovers the manifest only under the name uapf.yaml.
[ -f "$tmp/uapf.yaml" ] || cp "$tmp/process.uapf.yaml" "$tmp/uapf.yaml"
rm -f packages/document-intake.uapf
(cd "$tmp" && zip -qr - .) > packages/document-intake.uapf
rm -rf "$tmp"
echo "==> packages/document-intake.uapf built"
