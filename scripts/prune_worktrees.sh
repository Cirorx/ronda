#!/usr/bin/env bash
# Removes the git worktrees whose work is already on main, with their branches, so finished
# agent worktrees (each holds a few GB of build output) don't pile up. Run it after merging, from
# any checkout of the repo:
#
#   scripts/prune_worktrees.sh          # remove what's merged
#   scripts/prune_worktrees.sh --dry    # only list it
#
# A worktree goes when its HEAD is on main, it has no uncommitted or untracked changes and it isn't
# locked. One sitting exactly at main's tip is kept: it may be a fresh worktree whose agent hasn't
# committed yet. Remove a branch you just fast-forwarded by hand (`git worktree remove`).
set -euo pipefail
cd "$(dirname "$0")/.."

dry=false
[[ "${1:-}" == "--dry" ]] && dry=true

main_tip=$(git rev-parse main)
main_dir=$(git worktree list --porcelain | sed -n '1s/^worktree //p')

prune() {
  local dir=$1 head=$2 branch=$3 locked=$4
  [[ -n "$dir" && "$dir" != "$main_dir" ]] || return 0
  if [[ "$locked" == true ]]; then
    echo "kept $dir: locked"
  elif ! git merge-base --is-ancestor "$head" main; then
    echo "kept $dir: has commits that aren't on main"
  elif [[ "$head" == "$main_tip" ]]; then
    echo "kept $dir: at main's tip (fresh, or just merged: remove by hand)"
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
