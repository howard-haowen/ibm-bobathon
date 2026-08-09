# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Project Overview

IBM Bob 工作坊 Hub — 管理工作坊 HTML 教材、部署至 GitHub Pages 的中央 repo。
Live site: <https://howard-haowen.github.io/ibm-bobathon/>

**No build system, no package manager, no test runner.** Pure static HTML + bash + Node.js scripts.

---

## Key Commands

```bash
# Regenerate artifacts/index.html card grid after adding/removing HTML files
node scripts/update-index.mjs

# Copy local artifacts/ into a workshop branch (requires clean working tree)
bash scripts/copy-artifacts.sh workshop/w03

# Deploy is automatic — push to main with changes under workshops/**/artifacts/**
```

---

## Creating a New Workshop Branch

1. Check `workshops/` to find the next available slug (e.g., if `w01` and `w02` exist, use `w03`).
2. Run the GitHub Actions workflow **Create Workshop Branch** (`.github/workflows/create-workshop-branch.yml`) via `workflow_dispatch` with the `slug` input (e.g., `w03`).
   - The workflow creates an **orphan** branch `workshop/w03` (no shared history with `main`).
   - It seeds only: `.bob/mcp.json`, `.bob/skills/find-skills/`, `DESIGN.md`, `skills-lock.json`.
3. ⚠️ **Update `docs/client-url-map.md` locally** (not tracked by git) to register the new slug → client/URL mapping.
4. Add HTML artifacts to `artifacts/` in the new branch.
5. Run `node scripts/update-index.mjs` after adding/removing HTML files in `artifacts/`.
6. Run `bash scripts/copy-artifacts.sh workshop/wNN` if you need to sync `artifacts/` from `main` into the branch.

---

## Adding HTML Artifacts

- Place HTML files in `artifacts/` (numbering convention: `01-slug.html`, `02-slug.html`, …).
- Run `node scripts/update-index.mjs` — it auto-updates the `<div class="card-grid">` and count in `artifacts/index.html`.
- The script extracts **eyebrow** from `.card-eyebrow`/`.hero-eyebrow`, **title** from `<h1>` or `<title>`, **desc** from first `<p>` after `<h1>`.

---

## HTML Artifact Design System

All artifacts follow the **Carbon Design System** spec defined in `DESIGN.md`. Non-obvious rules:

- **Font**: `'IBM Plex Sans', 'Helvetica Neue', Arial, sans-serif` — load via Google Fonts with weights 300, 400, 600.
- **Display headlines (42–76px)**: `font-weight: 300` (IBM's signature light display — do NOT use 700).
- **Body `letter-spacing: 0.16px`** — Carbon precision detail; do not remove.
- **Zero border-radius** on all containers, cards, buttons — the system is flat/square.
- **No shadows** — card hierarchy via `1px solid #e0e0e0` hairlines and surface background, never `box-shadow`.
- **Single accent color**: IBM Blue `#0f62fe` only (links, primary CTA). No second brand color.
- **Color tokens**:
  - `#161616` ink / `#525252` ink-muted / `#8c8c8c` ink-subtle
  - `#f4f4f4` surface-1 / `#e0e0e0` hairline / `#ffffff` canvas
  - Footer inverts to `#161616` background with white text.
- **Standard page chrome**: utility-bar (32px, `#f4f4f4`) → top-nav (48px, `#ffffff`) → `.page-content` (max-width: 1056px, centered).
- **`lang="zh-TW"`** on `<html>` — content is Traditional Chinese.
- Card CTA link text: `閱讀報告` (hardcoded in `update-index.mjs`).

---

## Repository Structure (Non-Obvious)

- `artifacts/` — local working directory for the current workshop's HTML files; **gitignored** (not committed to `main`). Used as the source for `scripts/copy-artifacts.sh`.
- `workshops/wNN/artifacts/` — per-workshop copies committed on each `workshop/wNN` orphan branch; only these trigger `deploy-gh-pages.yml` (path filter: `workshops/**/artifacts/**`).
- `docs/`, `plans/`, and `artifacts/` are **gitignored** — local only, never committed to `main`.
- `gh-pages` branch is **fully managed by GitHub Actions** — never edit manually.
- Each `workshop/wNN` branch is an **orphan** (no git history shared with `main`).

---

## Deployment

- Triggered automatically on push to `main` when `workshops/**/artifacts/**` changes.
- Every deploy does a **full overwrite** of `gh-pages` (`keep_files: false`) — all workshops regenerated each time.
- Published URL pattern: `https://howard-haowen.github.io/ibm-bobathon/workshops/<slug>/`
