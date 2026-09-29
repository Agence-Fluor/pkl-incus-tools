#!/bin/sh
set -eu
repo=$(CDPATH='' cd "$(dirname "$0")/.." && pwd)
expected=$(pkl eval --no-project -x 'package.name + "@" + package.version' "$repo/PklProject")
if [ "$#" -gt 0 ] && [ "$1" != "$expected" ]; then
  printf 'Release tag mismatch: got %s; expected %s from PklProject.\n' "$1" "$expected" >&2
  exit 1
fi
printf '%s\n' "$expected"
