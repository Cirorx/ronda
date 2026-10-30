#!/usr/bin/env bash
# Deploys to Firebase what changed on main since the last deploy, then records it with one git tag
# per area (deploy/<project>/<area>), so the next run, on any machine, knows what is live
# (docs/STACK.md § Deploying). From the repo root:
#
#   scripts/deploy.sh --status    # what's on main but not live, without deploying anything
#   scripts/deploy.sh             # deploy what's pending to ronda-uy
#   scripts/deploy.sh <project>   # another project
#
# Hosting builds the production web app (predeploy), which needs the Web Push public key in
# FCM_VAPID_KEY (environment or the git-ignored .env); without it hosting stays pending.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "$*" >&2
  exit 1
}

status_only=false
if [[ "${1:-}" == "--status" ]]; then
  status_only=true
  shift
fi
project="${1:-ronda-uy}"

# area|deploy target|paths that change what that target ships (functions/tests is in firebase.json's
# functions ignore list, so it never ships)
areas=(
  "rules|firestore:rules|firestore.rules"
  "indexes|firestore:indexes|firestore.indexes.json"
  "storage|storage|storage.rules"
  "functions|functions|functions :(exclude)functions/tests solver/ronda_solver packages/ronda_ui/assets/fonts"
  "hosting|hosting|hosting lib web packages pubspec.yaml pubspec.lock firebase.json scripts/build_web.sh"
)

git fetch -q origin "refs/tags/deploy/$project/*:refs/tags/deploy/$project/*" 2>/dev/null || true

pending=()
for entry in "${areas[@]}"; do
  IFS='|' read -r area target paths <<<"$entry"
  tag="deploy/$project/$area"
  # shellcheck disable=SC2086 # paths is a space-separated list on purpose
  if ! git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    echo "$area: never deployed by this script"
    pending+=("$area|$target")
  elif ! git diff --quiet "$tag" HEAD -- $paths; then
    echo "$area: changed since $(git log -1 --format='%h %cs' "$tag"):"
    git log --format='  %h %s' "$tag"..HEAD -- $paths | head -10
    pending+=("$area|$target")
  else
    echo "$area: live at $(git log -1 --format='%h %cs' "$tag")"
  fi
done

# Functions in the code but not deployed, and deployed but gone from the code.
code=$(python3 - <<'EOF'
import ast
tree = ast.parse(open("functions/main.py").read())
for node in tree.body:
    if isinstance(node, ast.FunctionDef):
        for d in node.decorator_list:
            f = d.func if isinstance(d, ast.Call) else d
            if isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name) and f.value.id.endswith("_fn"):
                print(node.name)
EOF
)
if live=$(firebase functions:list --project "$project" --json 2>/dev/null |
  python3 -c 'import json, sys; [print(f["id"]) for f in json.load(sys.stdin)["result"]]'); then
  new=$(comm -23 <(sort <<<"$code") <(sort <<<"$live") | paste -sd ' ' -)
  gone=$(comm -13 <(sort <<<"$code") <(sort <<<"$live") | paste -sd ' ' -)
  [[ -z "$new" ]] || echo "functions not live yet: $new"
  [[ -z "$gone" ]] || echo "live functions no longer in the code: $gone"
else
  echo "Couldn't list the live functions (firebase login?)."
fi

$status_only && exit 0
((${#pending[@]})) || { echo "Nothing to deploy."; exit 0; }

[[ "$(git rev-parse --abbrev-ref HEAD)" == main ]] || fail "Deploy from main."
git fetch -q origin main
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || fail "main isn't in sync with origin/main."
[[ -z "$(git status --porcelain -- functions solver firestore.rules storage.rules firestore.indexes.json hosting lib web packages)" ]] ||
  fail "Uncommitted changes in deployed paths."

if [[ -z "${FCM_VAPID_KEY:-}" && -f .env ]]; then
  FCM_VAPID_KEY=$(sed -nE 's/^FCM_VAPID_KEY=//p' .env | tail -1)
  export FCM_VAPID_KEY
fi

targets=() deployed=()
for entry in "${pending[@]}"; do
  IFS='|' read -r area target <<<"$entry"
  if [[ "$area" == hosting && -z "${FCM_VAPID_KEY:-}" ]]; then
    echo "hosting: skipped, no FCM_VAPID_KEY (it stays pending)."
    continue
  fi
  targets+=("$target")
  deployed+=("$area")
done
((${#targets[@]})) || { echo "Nothing deployable."; exit 0; }

only=$(IFS=,; echo "${targets[*]}")
echo "Deploying $only to $project."
firebase deploy --only "$only" --project "$project" --non-interactive

for area in "${deployed[@]}"; do
  git tag -f "deploy/$project/$area" HEAD >/dev/null
  git push -q -f origin "refs/tags/deploy/$project/$area"
done
echo "Recorded $(git log -1 --format='%h' HEAD) as live for: ${deployed[*]}."
