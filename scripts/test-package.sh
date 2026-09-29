#!/bin/sh
set -eu

repo=$(CDPATH='' cd "$(dirname "$0")/.." && pwd)
cd "$repo"
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT HUP INT TERM

pkl format --diff-name-only lib tests/consumer PklProject
sh tests/test-command.sh
sh scripts/package-pkl.sh "$temp/dist"
sh scripts/package-pkl.sh "$temp/second"

version=$(pkl eval --no-project -x 'package.version' PklProject)
archive="$temp/dist/pkl-incus-tools@$version.zip"
test -s "$archive"
for suffix in '' '.sha256' '.zip' '.zip.sha256'; do
  cmp "$temp/dist/pkl-incus-tools@$version$suffix" "$temp/second/pkl-incus-tools@$version$suffix"
done
unzip -Z1 "$archive" > "$temp/files"
grep -qx 'lib/pkl/Command.pkl' "$temp/files"
grep -qx 'lib/engine/Engine.pkl' "$temp/files"
if grep -Ev '^lib/(pkl|engine)/[^/]+\.pkl$' "$temp/files"; then
  echo 'Package contains files outside the Pkl library' >&2
  exit 1
fi

mkdir -p "$temp/package" "$temp/consumer"
unzip -q "$archive" -d "$temp/package"
cp PklProject PklProject.deps.json "$temp/package/"
cp tests/consumer/*.pkl "$temp/consumer/"
cat > "$temp/consumer/PklProject" <<'EOF'
amends "pkl:Project"

dependencies {
  ["tools"] = import("../package/PklProject")
}

evaluatorSettings {
  moduleCacheDir = ".pkl-cache"
}
EOF

cd "$temp/consumer"
pkl project resolve >/dev/null
pkl run main.pkl --scope=full > "$temp/plan"
grep -q 'apply project fixture-project' "$temp/plan"
grep -q 'apply network fixture-net' "$temp/plan"
grep -q 'apply instance fixture-vm' "$temp/plan"
echo 'Published package import and Pkl command passed.'
