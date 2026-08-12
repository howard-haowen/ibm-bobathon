#!/usr/bin/env bash
# update-artifacts.sh
# Copies artifacts/ from a workshop branch into main so the HTML files
# can be served on GitHub Pages via deploy-gh-pages.yml.
#
# What it does:
#   1. Validates that the workshop branch exists locally.
#   2. Checks out main (requires a clean working tree).
#   3. Exports artifacts/ from the workshop branch (git checkout <branch> -- artifacts/).
#   4. Places the files at:
#        • workshops/<slug>/artifacts/  (for GitHub Pages deploy)
#        • artifacts/                   (root-level copy on main)
#   5. Runs scripts/update-index.mjs --dir workshops/<slug>/artifacts if needed.
#   6. Commits and pushes main.
#   7. Returns to the original branch.
#
# Usage:
#   bash scripts/update-artifacts.sh workshop/w02

set -euo pipefail

# ── helpers ───────────────────────────────────────────────────────────────────
die()  { echo "error: $*" >&2; exit 1; }
info() { echo "  $*"; }

# ── argument validation ───────────────────────────────────────────────────────
[[ $# -eq 1 ]] || die "usage: $0 <workshop-branch>  (e.g. workshop/w02)"

WORKSHOP_BRANCH="$1"
REMOTE="${REMOTE:-origin}"
SOURCE_BRANCH="main"
ARTIFACTS_DIR="artifacts"

# Derive slug from branch name (e.g. workshop/w02 → w02)
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
WORKSHOP_DEST="workshops/$SLUG/$ARTIFACTS_DIR"

info "workshop branch : $WORKSHOP_BRANCH"
info "slug            : $SLUG"
info "destination     : $WORKSHOP_DEST  (on $SOURCE_BRANCH)"
info "remote          : $REMOTE"
echo ""

# ── Step 1: switch to main ────────────────────────────────────────────────────
info "── Step 1: checking out $SOURCE_BRANCH ──"
git checkout "$SOURCE_BRANCH"

# ── Step 2: export artifacts/ from the workshop branch ───────────────────────
info "── Step 2: exporting $ARTIFACTS_DIR/ from $WORKSHOP_BRANCH ──"

mkdir -p "$WORKSHOP_DEST"

# Remove root-level artifacts/ entirely so stale files don't linger,
# then restore exactly what the workshop branch contains.
rm -rf "$ARTIFACTS_DIR"
git checkout "$WORKSHOP_BRANCH" -- "$ARTIFACTS_DIR"

# Copy contents to workshops/<slug>/artifacts/ (GitHub Pages destination)
rsync -a --delete "$ARTIFACTS_DIR/" "$WORKSHOP_DEST/"

# ── Step 3: regenerate index.html ────────────────────────────────────────────
info "── Step 3: regenerating index.html in $WORKSHOP_DEST ──"
node scripts/update-index.mjs --dir "$WORKSHOP_DEST"

# ── Step 4: commit and push main ─────────────────────────────────────────────
info "── Step 4: committing and pushing $SOURCE_BRANCH ──"
git add "$WORKSHOP_DEST"
git add -f "$ARTIFACTS_DIR"

if git diff --cached --quiet; then
  info "nothing to commit — $WORKSHOP_DEST is already up to date"
else
  git commit -m "chore: update $WORKSHOP_DEST and $ARTIFACTS_DIR from $WORKSHOP_BRANCH"
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
echo "   • $WORKSHOP_BRANCH:$ARTIFACTS_DIR/  →  $REMOTE/$SOURCE_BRANCH:$WORKSHOP_DEST"
echo "   • $WORKSHOP_BRANCH:$ARTIFACTS_DIR/  →  $REMOTE/$SOURCE_BRANCH:$ARTIFACTS_DIR"
