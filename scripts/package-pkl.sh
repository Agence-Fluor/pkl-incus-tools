#!/bin/sh
set -eu

repo=$(CDPATH='' cd "$(dirname "$0")/.." && pwd)
cd "$repo"
output_path=${1:-dist/package}
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT HUP INT TERM

mkdir -p "$output_path" "$stage/lib"
cp PklProject PklProject.deps.json "$stage/"
cp -a lib/engine lib/pkl "$stage/lib/"

# The launcher is a development dependency, outside the published library.
printf 'amends "%s/PklProject"\ndependencies = super.dependencies.toMap().filter((name, _) -> name != "nixTools").toMapping()\n' "$repo" > "$stage/PklProject"
pkl project package --skip-publish-check --output-path "$output_path" "$stage"
