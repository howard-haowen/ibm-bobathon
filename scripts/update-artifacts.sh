#!/usr/bin/env bash
# update-artifacts.sh
# Uses artifacts/ from a workshop branch to replace TWO locations on main:
#   1. artifacts/               (root-level, gitignored — force-added)
#   2. workshops/<slug>/artifacts/  (GitHub Pages source — committed normally)
#
# What it does:
#   1. Validates that the workshop branch exists locally.
#   2. Checks out main (requires a clean working tree).
#   3. Exports artifacts/ from the workshop branch into both destinations.
#   4. Runs scripts/update-index.mjs for each destination.
#   5. Commits and pushes main.
#   6. Returns to the original branch.
#
# Usage:
#   bash scripts/update-artifacts.sh workshop/w01

set -euo pipefail

# ── helpers ───────────────────────────────────────────────────────────────────
die()  { echo "error: $*" >&2; exit 1; }
info() { echo "  $*"; }

# ── argument validation ───────────────────────────────────────────────────────
[[ $# -eq 1 ]] || die "usage: $0 <workshop-branch>  (e.g. workshop/w01)"

WORKSHOP_BRANCH="$1"
REMOTE="${REMOTE:-origin}"
SOURCE_BRANCH="main"
ARTIFACTS_DIR="artifacts"

# Derive slug from branch name (e.g. workshop/w01 → w01)
SLUG="${WORKSHOP_BRANCH##*/}"

# Validate branch name format
[[ "$WORKSHOP_BRANCH" == workshop/w* ]] \
  || die "branch '$WORKSHOP_BRANCH' does not match the expected format workshop/wNN"

# ── sanity checks ─────────────────────────────────────────────────────────────
command -v git  &>/dev/null || die "git not found"
command -v node &>/dev/null || die "node not found"
git rev-parse --git-dir &>/dev/null || die "not inside a git repository"

# The workshop branch MUST exist locally
git rev-parse --verify "refs/heads/$WORKSHOP_BRANCH" &>/dev/null \
  || die "branch '$WORKSHOP_BRANCH' does not exist locally — run: git checkout --track $REMOTE/$WORKSHOP_BRANCH"

# Working tree must be clean before switching branches
if ! git diff --quiet || ! git diff --cached --quiet; then
  die "working tree has uncommitted changes — please commit or stash them first"
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
ROOT_DEST="$ARTIFACTS_DIR"
WORKSHOP_DEST="workshops/$SLUG/$ARTIFACTS_DIR"

info "workshop branch  : $WORKSHOP_BRANCH"
info "slug             : $SLUG"
info "destination 1    : $ROOT_DEST/  (root-level on $SOURCE_BRANCH, gitignored)"
info "destination 2    : $WORKSHOP_DEST/  (GitHub Pages source on $SOURCE_BRANCH)"
info "remote           : $REMOTE"
echo ""

# ── Step 1: switch to main ────────────────────────────────────────────────────
info "── Step 1: checking out $SOURCE_BRANCH ──"
git checkout "$SOURCE_BRANCH"

# ── Step 2a: replace root-level artifacts/ ───────────────────────────────────
info "── Step 2a: replacing $ROOT_DEST/ from $WORKSHOP_BRANCH ──"

# Remove stale files then restore exactly what the workshop branch contains.
rm -rf "$ROOT_DEST"
git checkout "$WORKSHOP_BRANCH" -- "$ARTIFACTS_DIR"

# ── Step 2b: replace workshops/<slug>/artifacts/ ─────────────────────────────
info "── Step 2b: replacing $WORKSHOP_DEST/ from $WORKSHOP_BRANCH ──"

mkdir -p "$WORKSHOP_DEST"
rsync -a --delete "$ROOT_DEST/" "$WORKSHOP_DEST/"

# ── Step 3: regenerate index.html in both destinations ───────────────────────
info "── Step 3a: regenerating index.html in $ROOT_DEST/ ──"
node scripts/update-index.mjs --dir "$ROOT_DEST"

info "── Step 3b: regenerating index.html in $WORKSHOP_DEST/ ──"
node scripts/update-index.mjs --dir "$WORKSHOP_DEST"

# ── Step 4: commit and push main ─────────────────────────────────────────────
info "── Step 4: committing and pushing $SOURCE_BRANCH ──"
git add "$WORKSHOP_DEST"
git add -f "$ROOT_DEST"

if git diff --cached --quiet; then
  info "nothing to commit — both destinations are already up to date"
else
  git commit -m "chore: sync $SLUG artifacts from $WORKSHOP_BRANCH

  • $ROOT_DEST/ ← $WORKSHOP_BRANCH:artifacts/
  • $WORKSHOP_DEST/ ← $WORKSHOP_BRANCH:artifacts/"
  info "committed on $SOURCE_BRANCH"
fi

info "pushing '$SOURCE_BRANCH' to '$REMOTE' …"
git push "$REMOTE" "$SOURCE_BRANCH"
info "done — $SOURCE_BRANCH pushed (deploy-gh-pages.yml will trigger automatically)"
echo ""

# ── Step 5: return to original branch ────────────────────────────────────────
if [[ "$CURRENT_BRANCH" != "$SOURCE_BRANCH" && "$CURRENT_BRANCH" != "HEAD" ]]; then
  git checkout "$CURRENT_BRANCH"
  info "returned to '$CURRENT_BRANCH'"
fi

echo "✔  all done"
echo "   • $WORKSHOP_BRANCH:artifacts/  →  $REMOTE/$SOURCE_BRANCH:$ROOT_DEST/"
echo "   • $WORKSHOP_BRANCH:artifacts/  →  $REMOTE/$SOURCE_BRANCH:$WORKSHOP_DEST/"
