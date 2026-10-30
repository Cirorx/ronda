#!/usr/bin/env bash
# Removes the git worktrees whose work is already on main, with their branches, so finished
# agent worktrees (each holds a few GB of build output) don't pile up. Run it after merging, from
# any checkout of the repo:
#
#   scripts/prune_worktrees.sh          # remove what's merged
#   scripts/prune_worktrees.sh --dry    # only list it
#
# A worktree goes when its HEAD is on main, something was committed in it, it has no uncommitted or
# untracked changes and it isn't locked. One where nothing was ever committed is kept: it may be a
# fresh worktree whose agent hasn't written anything yet, even after main moved past it.
set -euo pipefail
cd "$(dirname "$0")/.."

dry=false
[[ "${1:-}" == "--dry" ]] && dry=true

main_dir=$(git worktree list --porcelain | sed -n '1s/^worktree //p')

prune() {
  local dir=$1 head=$2 branch=$3 locked=$4
  [[ -n "$dir" && "$dir" != "$main_dir" ]] || return 0
  if [[ "$locked" == true ]]; then
    echo "kept $dir: locked"
  elif ! git merge-base --is-ancestor "$head" main; then
    echo "kept $dir: has commits that aren't on main"
  elif ! git -C "$dir" reflog --format=%gs HEAD | grep -E '^(commit|rebase|merge|cherry-pick|pull)' >/dev/null; then
    echo "kept $dir: nothing committed in it yet (may be a fresh worktree)"
  elif [[ -n "$(git -C "$dir" status --porcelain)" ]]; then
    echo "kept $dir: uncommitted changes"
  elif $dry; then
    echo "would remove $dir${branch:+ ($branch)}"
  else
    git worktree remove "$dir"
    [[ -z "$branch" ]] || git branch -q -d "$branch"
    echo "removed $dir${branch:+ ($branch)}"
  fi
}

dir='' head='' branch='' locked=false
while IFS= read -r line; do
  case "$line" in
    worktree\ *) dir=${line#worktree } ;;
    HEAD\ *) head=${line#HEAD } ;;
    branch\ *) branch=${line#branch refs/heads/} ;;
    locked*) locked=true ;;
    '')
      prune "$dir" "$head" "$branch" "$locked"
      dir='' head='' branch='' locked=false
      ;;
  esac
done < <(git worktree list --porcelain; echo)
git worktree prune
