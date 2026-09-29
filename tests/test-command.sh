#!/bin/sh
set -eu

test_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_dir=$(CDPATH= cd "$test_dir/.." && pwd)
pkl_bin=${PKL:-pkl}
state=$(mktemp -d)
trap 'rm -rf "$state"' EXIT HUP INT TERM
mkdir "$state/bin"

cat > "$state/bin/incus" <<'MOCK'
#!/bin/sh
set -eu
method=GET
body=
shift # query
if [ "${1:-}" = --wait ]; then shift; fi
if [ "${1:-}" = -X ]; then method=$2; shift 2; fi
if [ "${1:-}" = -d ]; then body=$2; shift 2; fi
uri=$1
case "$uri" in
  *'/projects'*) kind=project; name=fixture-project ;;
  *'/networks'*) kind=network; name=fixture-net ;;
  *'/profiles'*) kind=profile; name=fixture-profile ;;
  *'/storage-pools/default/volumes/custom'*) kind=volume; name=fixture-data ;;
  *'/instances'*) kind=instance; name=fixture-vm ;;
  *) echo "Unexpected API path: $uri" >&2; exit 1 ;;
esac
printf '%s %s\n' "$method" "$uri" >> "$MOCK_STATE/log"
case "$method" in
  GET)
    if [ -f "$MOCK_STATE/$kind" ]; then
      owner='iac:local:fixture-project'
      if [ -f "$MOCK_STATE/foreign" ]; then owner=foreign; fi
      printf '[{"name":"%s","config":{"user.i2s.owner":"%s"}}]\n' "$name" "$owner"
    else
      printf '[]\n'
    fi
    ;;
  POST)
    case "$body" in
      *'"user.i2s.owner": "iac:local:fixture-project"'*) : ;;
      *) echo 'Missing ownership marker in create body' >&2; exit 1 ;;
    esac
    touch "$MOCK_STATE/$kind"
    printf '{}\n'
    ;;
  PUT)
    [ -f "$MOCK_STATE/$kind" ]
    printf '{}\n'
    ;;
  DELETE)
    rm "$MOCK_STATE/$kind"
    printf '{}\n'
    ;;
  *) exit 1 ;;
esac
MOCK
chmod +x "$state/bin/incus"
export MOCK_STATE="$state"
export PATH="$state/bin:$PATH"
cd "$repo_dir/tests/consumer"

"$pkl_bin" eval local.pkl >/dev/null
"$pkl_bin" eval cluster.pkl >/dev/null
"$pkl_bin" run main.pkl --scope=full > "$state/plan"
grep -q 'apply project fixture-project' "$state/plan"
grep -q 'apply network fixture-net' "$state/plan"
grep -q 'apply profile fixture-profile' "$state/plan"
grep -q 'apply volume fixture-data' "$state/plan"
grep -q 'apply instance fixture-vm' "$state/plan"
[ ! -e "$state/log" ]

"$pkl_bin" run main.pkl --scope=full --execute > "$state/first"
grep -q '^POST local:/1.0/projects$' "$state/log"
grep -q '^POST local:/1.0/networks?project=fixture-project$' "$state/log"
grep -q '^POST local:/1.0/profiles?project=fixture-project$' "$state/log"
grep -q '^POST local:/1.0/storage-pools/default/volumes/custom?project=fixture-project$' "$state/log"
grep -q '^POST local:/1.0/instances?project=fixture-project$' "$state/log"

: > "$state/log"
"$pkl_bin" run main.pkl --scope=full --execute > "$state/second"
[ "$(grep -c '^PUT ' "$state/log")" -eq 5 ]
if grep -q '^POST ' "$state/log"; then exit 1; fi

: > "$state/log"
"$pkl_bin" run main.pkl --action=destroy --execute > "$state/remove-network"
[ ! -f "$state/network" ]
[ ! -f "$state/profile" ]
[ ! -f "$state/volume" ]
[ ! -f "$state/instance" ]
[ -f "$state/project" ]
grep -q '^DELETE local:/1.0/networks/fixture-net?project=fixture-project$' "$state/log"

"$pkl_bin" run main.pkl --action=destroy --scope=project --execute > "$state/remove-project"
[ ! -f "$state/project" ]

touch "$state/network" "$state/foreign"
: > "$state/log"
if "$pkl_bin" run main.pkl --execute > "$state/collision" 2>&1; then
  echo 'Foreign resource was adopted' >&2
  exit 1
fi
grep -q 'Refusing foreign network fixture-net' "$state/collision"
if grep -Eq '^(POST|PUT|DELETE) ' "$state/log"; then
  echo 'Foreign resource was modified' >&2
  exit 1
fi

echo 'Pkl command: plan, apply, reapply, destroy, and ownership checks passed.'
