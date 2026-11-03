#!/usr/bin/env bash
# Lists, and with --stop ends, the local servers a batch of work leaves running: Firebase emulators,
# functions-framework workers, `flutter run` / `flutter test` and the Chrome that `flutter run -d
# chrome` opens. Only processes started from this repo, its worktrees or a sibling `ronda-*`
# checkout count. From any checkout of the repo:
#
#   scripts/release_resources.sh                    # list them, with age and memory
#   scripts/release_resources.sh --stop --here      # end only this checkout's (an agent's batch)
#   scripts/release_resources.sh --stop             # end every checkout's (TERM, then KILL after 5 s)
#   scripts/release_resources.sh --stop --android   # also end running Android emulators
#
# Parallel sessions each run their own emulators, so an agent ends only its own, with --here; the
# owner clears the rest.
# It never touches the Claude app or its MCP helpers, the Dart tooling daemon or DevTools, the iOS
# Simulator services, or anything started outside these folders. Android emulators have no folder
# to tell whose they are, so they are listed apart and only stopped with --android.
set -euo pipefail
# --here means the checkout the caller stands in, so read it before moving to the script's own.
caller=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$(dirname "$0")/.."

stop=false
android=false
here=false
for arg in "$@"; do
  case "$arg" in
    --stop) stop=true ;;
    --android) android=true ;;
    --here) here=true ;;
    *)
      echo "Usage: scripts/release_resources.sh [--stop] [--here] [--android]" >&2
      exit 64
      ;;
  esac
done

# The folder that holds this checkout and its `ronda-*` siblings; worktrees live under the main one.
main=$(cd "$(git rev-parse --git-common-dir)/.." && pwd)
parent=$(dirname "$main")
# What counts as ours: every ronda folder, or with --here only this checkout.
scope="$parent/ronda"
if $here; then
  scope=$caller
fi

# What a leftover from this repo looks like on the command line.
servers='functions-framework|cloud-firestore-emulator|cloud-storage-rules|firebase-tools.*emulators|firebase emulators|emulators:(start|exec)|flutter_tester|flutter_tools\.snapshot (run|test|drive)|flutter_tools_chrome_device'
android_pattern='qemu-system|emulator64-crash-service'

ours() {
  local pid=$1 command=$2 cwd
  cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
  # The main checkout holds the worktrees under it: with --here, theirs aren't its.
  if $here && [[ "$command $cwd" == *"$scope"/.claude/worktrees/* ]]; then
    return 1
  fi
  case "$command" in
    *"$scope"*) return 0 ;;
  esac
  case "$cwd" in
    "$scope"*) return 0 ;;
  esac
  # The Chrome `flutter run -d chrome` opens lives in a temp profile, not under any checkout.
  ! $here && [[ "$command" == *flutter_tools_chrome_device* ]]
}

found=()
android_found=()
while read -r pid etime rss command; do
  [[ "$pid" == "$$" ]] && continue
  if [[ "$command" =~ $android_pattern ]]; then
    android_found+=("$pid")
    printf '%-7s %-12s %6s MB  android emulator  %s\n' "$pid" "$etime" "$((rss / 1024))" "${command:0:90}"
  elif [[ "$command" =~ $servers ]] && ours "$pid" "$command"; then
    found+=("$pid")
    printf '%-7s %-12s %6s MB  %s\n' "$pid" "$etime" "$((rss / 1024))" "${command:0:110}"
  fi
done < <(ps -axo pid=,etime=,rss=,command= | grep -v -e 'release_resources' -e ' grep ')

if [[ ${#found[@]} -eq 0 && ${#android_found[@]} -eq 0 ]]; then
  echo "Nothing left running."
  exit 0
fi

if ! $stop; then
  echo "${#found[@]} left from this repo, ${#android_found[@]} Android emulator(s). --stop ends the first; add --android for the second."
  exit 0
fi

targets=("${found[@]+"${found[@]}"}")
if $android; then
  targets+=("${android_found[@]+"${android_found[@]}"}")
fi
if [[ ${#targets[@]} -eq 0 ]]; then
  echo "Nothing to stop without --android."
  exit 0
fi

kill -TERM "${targets[@]}" 2>/dev/null || true
for _ in 1 2 3 4 5; do
  alive=()
  for pid in "${targets[@]}"; do
    kill -0 "$pid" 2>/dev/null && alive+=("$pid")
  done
  [[ ${#alive[@]} -eq 0 ]] && break
  sleep 1
done
if [[ ${#alive[@]} -gt 0 ]]; then
  kill -KILL "${alive[@]}" 2>/dev/null || true
fi
echo "Stopped ${#targets[@]} process(es)."
