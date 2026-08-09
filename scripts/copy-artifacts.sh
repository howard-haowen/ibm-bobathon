#!/usr/bin/env bash
# copy-artifacts.sh
# Syncs the local artifacts/ directory (gitignored working directory) to:
#   1. main branch  →  workshops/<slug>/artifacts/   (committed & pushed)
#   2. workshop/<slug> branch  →  artifacts/          (committed & pushed)
# Note: workshop/wNN branches are orphans — they are never merged into main.

set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────
die()  { echo "error: $*" >&2; exit 1; }
info() { echo "  $*"; }

# ── prompt for target branch ─────────────────────────────────────────────────
if [[ $# -ge 1 ]]; then
  TARGET_BRANCH="$1"
else
  printf "Enter target branch name (e.g. workshop/w01): "
  read -r TARGET_BRANCH
fi

[[ -n "$TARGET_BRANCH" ]] || die "branch name cannot be empty"

REMOTE="${2:-origin}"
SOURCE_BRANCH="main"
ARTIFACTS_DIR="artifacts"

# Derive slug from branch name (e.g. workshop/w01 → w01)
SLUG="${TARGET_BRANCH##*/}"

# ── sanity checks ─────────────────────────────────────────────────────────────
command -v git  &>/dev/null || die "git not found"
command -v node &>/dev/null || die "node not found"
git rev-parse --git-dir &>/dev/null || die "not inside a git repository"

# Verify local artifacts/ exists and has at least one HTML file
[[ -d "$ARTIFACTS_DIR" ]] || die "'$ARTIFACTS_DIR/' not found in working tree"
html_count=$(find "$ARTIFACTS_DIR" -maxdepth 1 -name '*.html' ! -name 'index.html' | wc -l)
[[ "$html_count" -gt 0 ]] || die "no HTML files found in '$ARTIFACTS_DIR/' (excluding index.html)"

# Make sure main branch exists
git rev-parse --verify "refs/heads/$SOURCE_BRANCH" &>/dev/null \
  || git rev-parse --verify "refs/remotes/$REMOTE/$SOURCE_BRANCH" &>/dev/null \
  || die "source branch '$SOURCE_BRANCH' not found locally or on remote '$REMOTE'"

# Verify working tree is clean before switching
if ! git diff --quiet || ! git diff --cached --quiet; then
  die "working tree has uncommitted changes — please commit or stash them first"
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
WORKSHOP_DEST="workshops/$SLUG/$ARTIFACTS_DIR"

info "slug    : $SLUG"
info "source  : $SOURCE_BRANCH  ($ARTIFACTS_DIR/ → $WORKSHOP_DEST)"
info "target  : $TARGET_BRANCH ($ARTIFACTS_DIR/ → $ARTIFACTS_DIR/)"
info "remote  : $REMOTE"
echo ""

# ── Step 1: update main → workshops/<slug>/artifacts/ ─────────────────────────
info "── Step 1: syncing to $SOURCE_BRANCH:$WORKSHOP_DEST ──"

# Ensure we're on main
git checkout "$SOURCE_BRANCH"

# Copy artifacts/ → workshops/<slug>/artifacts/
mkdir -p "$WORKSHOP_DEST"
rsync -a --delete "$ARTIFACTS_DIR/" "$WORKSHOP_DEST/"

# Regenerate index.html for the workshops copy
node scripts/update-index.mjs --dir "$WORKSHOP_DEST"

git add "$WORKSHOP_DEST"

if git diff --cached --quiet; then
  info "nothing to commit on $SOURCE_BRANCH — $WORKSHOP_DEST already up to date"
else
  git commit -m "chore: sync $ARTIFACTS_DIR/ → $WORKSHOP_DEST"
  info "committed on $SOURCE_BRANCH"
fi

info "pushing '$SOURCE_BRANCH' to '$REMOTE' …"
git push "$REMOTE" "$SOURCE_BRANCH"
info "done — $SOURCE_BRANCH pushed"
echo ""

# ── Step 2: update workshop/<slug> branch → artifacts/ ───────────────────────
info "── Step 2: syncing to $TARGET_BRANCH:$ARTIFACTS_DIR/ ──"

# Ensure target branch exists (track from remote if needed, else create)
if git rev-parse --verify "refs/heads/$TARGET_BRANCH" &>/dev/null; then
  info "branch '$TARGET_BRANCH' already exists locally — checking it out"
  git checkout "$TARGET_BRANCH"
elif git ls-remote --exit-code --heads "$REMOTE" "$TARGET_BRANCH" &>/dev/null; then
  info "branch '$TARGET_BRANCH' found on remote — checking out and tracking"
  git checkout --track "$REMOTE/$TARGET_BRANCH"
else
  info "branch '$TARGET_BRANCH' not found — creating from current HEAD"
  git checkout -b "$TARGET_BRANCH"
fi

# Restore artifacts/ content from main into this branch.
# git checkout <branch> -- <dir> stages ALL files even if unchanged, so we
# unstage everything and re-add only files that actually differ.
git checkout "$SOURCE_BRANCH" -- "$ARTIFACTS_DIR"
git reset HEAD "$ARTIFACTS_DIR" 2>/dev/null || true   # unstage all
git add "$ARTIFACTS_DIR"                               # re-stage only real diffs

if git diff --cached --quiet; then
  info "nothing to commit — '$ARTIFACTS_DIR/' already matches '$SOURCE_BRANCH'"
else
  git commit -m "chore: sync $ARTIFACTS_DIR/ from $SOURCE_BRANCH"
  info "committed on $TARGET_BRANCH"
fi

info "pushing '$TARGET_BRANCH' to '$REMOTE' …"
git push "$REMOTE" "$TARGET_BRANCH"
info "done — $TARGET_BRANCH pushed"
echo ""

# ── Step 3: return to original branch ────────────────────────────────────────
if [[ "$CURRENT_BRANCH" != "$TARGET_BRANCH" && "$CURRENT_BRANCH" != "HEAD" ]]; then
  git checkout "$CURRENT_BRANCH"
  info "returned to '$CURRENT_BRANCH'"
fi

echo "✔  all done"
echo "   • $REMOTE/$SOURCE_BRANCH  →  $WORKSHOP_DEST"
echo "   • $REMOTE/$TARGET_BRANCH  →  $ARTIFACTS_DIR/"
