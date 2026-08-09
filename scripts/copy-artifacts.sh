#!/usr/bin/env bash
# copy-artifacts.sh
# Copies the artifacts/ directory from the main branch into a target branch,
# then pushes the result to the remote.

set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────
die()  { echo "error: $*" >&2; exit 1; }
info() { echo "  $*"; }

# ── prompt for target branch ─────────────────────────────────────────────────
if [[ $# -ge 1 ]]; then
  TARGET_BRANCH="$1"
else
  printf "Enter target branch name: "
  read -r TARGET_BRANCH
fi

[[ -n "$TARGET_BRANCH" ]] || die "branch name cannot be empty"

REMOTE="${2:-origin}"
SOURCE_BRANCH="main"
ARTIFACTS_DIR="artifacts"

# ── sanity checks ─────────────────────────────────────────────────────────────
command -v git &>/dev/null || die "git not found"
git rev-parse --git-dir &>/dev/null  || die "not inside a git repository"

# Make sure the source branch exists
git rev-parse --verify "refs/heads/$SOURCE_BRANCH" &>/dev/null \
  || git rev-parse --verify "refs/remotes/$REMOTE/$SOURCE_BRANCH" &>/dev/null \
  || die "source branch '$SOURCE_BRANCH' not found locally or on remote '$REMOTE'"

# Verify working tree is clean before switching
if ! git diff --quiet || ! git diff --cached --quiet; then
  die "working tree has uncommitted changes — please commit or stash them first"
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

info "source  : $SOURCE_BRANCH"
info "target  : $TARGET_BRANCH"
info "remote  : $REMOTE"
info "current : $CURRENT_BRANCH"
echo ""

# ── ensure target branch exists (create if needed) ───────────────────────────
if git rev-parse --verify "refs/heads/$TARGET_BRANCH" &>/dev/null; then
  info "branch '$TARGET_BRANCH' already exists locally — checking it out"
  git checkout "$TARGET_BRANCH"
else
  # If the branch exists on the remote, track it; otherwise create it fresh
  if git ls-remote --exit-code --heads "$REMOTE" "$TARGET_BRANCH" &>/dev/null; then
    info "branch '$TARGET_BRANCH' found on remote — checking out and tracking"
    git checkout --track "$REMOTE/$TARGET_BRANCH"
  else
    info "branch '$TARGET_BRANCH' not found — creating from current HEAD"
    git checkout -b "$TARGET_BRANCH"
  fi
fi

# ── copy artifacts/ from main ─────────────────────────────────────────────────
info "restoring '$ARTIFACTS_DIR/' from '$SOURCE_BRANCH' …"
git checkout "$SOURCE_BRANCH" -- "$ARTIFACTS_DIR"

# ── commit ────────────────────────────────────────────────────────────────────
if git diff --cached --quiet; then
  info "nothing to commit — '$ARTIFACTS_DIR/' already matches '$SOURCE_BRANCH'"
else
  git commit -m "chore: sync $ARTIFACTS_DIR/ from $SOURCE_BRANCH"
  info "committed"
fi

# ── push ─────────────────────────────────────────────────────────────────────
info "pushing '$TARGET_BRANCH' to '$REMOTE' …"
git push "$REMOTE" "$TARGET_BRANCH"

echo ""
echo "done — '$ARTIFACTS_DIR/' from '$SOURCE_BRANCH' is now on '$REMOTE/$TARGET_BRANCH'"

# ── return to original branch (optional) ─────────────────────────────────────
if [[ "$CURRENT_BRANCH" != "$TARGET_BRANCH" && "$CURRENT_BRANCH" != "HEAD" ]]; then
  git checkout "$CURRENT_BRANCH"
  info "returned to '$CURRENT_BRANCH'"
fi
