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

# Regenerate index.html for a specific workshops/ directory
node scripts/update-index.mjs --dir workshops/w01/artifacts

# Pull artifacts/ from a workshop branch into main (workshops/<slug>/artifacts/),
# regenerate index.html, commit & push main — requires the workshop branch to
# exist locally and the working tree to be clean
bash scripts/update-artifacts.sh workshop/w01

# Deploy is automatic — push to main with changes under workshops/**/artifacts/**
```

---

## Creating a New Workshop Branch

### Step 1 — Determine the next slug

Query the remote for existing workshop branches and pick the next available number:

```bash
git ls-remote --heads origin 'workshop/w*' | sed 's|.*refs/heads/workshop/||' | sort
```

If `workshop/w01` and `workshop/w02` already exist, the next slug is `w03`.

### Step 2 — Create the orphan workshop branch via GitHub Actions

Trigger the **Create Workshop Branch** workflow
(`.github/workflows/create-workshop-branch.yml`) via `workflow_dispatch`:

```bash
gh workflow run create-workshop-branch.yml --field slug=w03
```

The workflow:
- Creates an **orphan** branch `workshop/w03` (no shared history with `main`).
- Seeds it with: `.bob/mcp.json`, `.bob/skills/find-skills/`, `DESIGN.md`, `skills-lock.json`.
- Pushes the branch to `origin`.

Confirm the branch is live before continuing:

```bash
git ls-remote --heads origin 'workshop/w03'
```

### Step 3 — Register the new workshop (local bookkeeping)

⚠️ **Update `docs/client-url-map.md` locally** (gitignored, not committed to `main`) to record the new slug → client/URL mapping.

### Step 4 — Add HTML artifacts

Place numbered HTML files in `artifacts/` (gitignored local directory):

```
artifacts/01-topic-one.html
artifacts/02-topic-two.html
…
```

Then regenerate the local index:

```bash
node scripts/update-index.mjs
```

This updates `artifacts/index.html` — verify it looks correct in a browser.

### Step 5 — Wait for user confirmation

**Pause here.** Show the user the list of files now in `artifacts/` and the
updated `artifacts/index.html`, then wait for explicit approval before
proceeding to publish.

### Step 6 — Sync and publish

Once the artifacts are approved on the workshop branch, run the sync script from `main`:

```bash
bash scripts/update-artifacts.sh workshop/w03
```

What this does in one shot:
1. Checks out **`main`**.
2. Exports `artifacts/` from the `workshop/w03` branch (via `git checkout workshop/w03 -- artifacts/`).
3. Places the files at **`workshops/w03/artifacts/`** on `main`.
4. Regenerates `workshops/w03/artifacts/index.html` via `update-index.mjs`.
5. Commits and pushes `main` — this triggers `deploy-gh-pages.yml` automatically.
6. **Returns** to whichever branch was checked out before the script ran (typically `main`).

> **Note:** The script reads from the workshop branch directly — it does **not** read the local gitignored `artifacts/` directory and does **not** push to the workshop branch itself.

### Step 7 — Verify deployment

After the GitHub Actions deploy job completes, confirm the live URL:

```
https://howard-haowen.github.io/ibm-bobathon/workshops/w03/
```

---

## Cloning a Specific Workshop Branch

Each `workshop/wNN` branch is an orphan and can be cloned in isolation without
fetching the full history of `main`:

```bash
git clone --single-branch --branch workshop/w01 \
  https://github.com/howard-haowen/ibm-bobathon.git \
  ibm-bobathon-w01
```

Replace `w01` with the desired slug. The local directory name (`ibm-bobathon-w01`)
is a convention — change it as needed.

To clone a different workshop, adjust both the `--branch` value and the target
directory:

```bash
git clone --single-branch --branch workshop/w02 \
  https://github.com/howard-haowen/ibm-bobathon.git \
  ibm-bobathon-w02
```

> **Why `--single-branch`?** Workshop branches are orphans with no shared
> history. Cloning with `--single-branch` fetches only that branch's objects,
> keeping the clone small and fast.

---

## Adding HTML Artifacts

- Place HTML files in `artifacts/` (numbering convention: `01-slug.html`, `02-slug.html`, …).
- Run `node scripts/update-index.mjs` — it auto-updates the `<div class="card-grid">` and count in `artifacts/index.html`.
- The script extracts **eyebrow** from `.card-eyebrow`/`.hero-eyebrow`, **title** from `<h1>` or `<title>`, **desc** from first `<p>` after `<h1>`.

---

## Clone Prompt Block (Required in Every Workshop index.html)

Every `artifacts/index.html` (and the corresponding `workshops/wNN/artifacts/index.html` on `main`) **must** include a "取得本工作坊程式碼" block inside the `.hero` section. This block lets workshop participants copy a ready-made prompt and paste it into any AI Agent to clone the correct branch automatically.

### Required HTML structure

Place the following block immediately after the hero `<p>` description, before the closing `</div>` of `.hero`. Replace `wNN` with the actual workshop slug (e.g. `w01`, `w02`):

```html
<div class="clone-box">
  <div class="clone-box-header">
    <h3>取得本工作坊程式碼</h3>
    <button class="copy-btn" id="copyBtn">複製 Prompt</button>
  </div>
  <code class="prompt-text" id="promptText">請在終端機執行以下 git 指令，單獨 clone 本工作坊的 orphan 分支（workshop/wNN），不會下載 main 分支的任何歷史：

git clone --single-branch --branch workshop/wNN \
  https://github.com/howard-haowen/ibm-bobathon.git \
  ibm-bobathon-wNN

執行完成後，切換至新建立的目錄：

cd ibm-bobathon-wNN</code>
</div>
```

### Required CSS

Add the following rules to the `<style>` block (already present in `artifacts/index.html` — copy to any new index):

```css
.clone-box {
  margin-top: 40px;
  border: 1px solid #e0e0e0;
  background: #f4f4f4;
}
.clone-box-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 20px 12px;
  border-bottom: 1px solid #e0e0e0;
}
.clone-box h3 {
  font-size: 14px;
  font-weight: 600;
  letter-spacing: 0.32px;
  color: #161616;
  text-transform: uppercase;
  margin: 0;
}
.copy-btn {
  font-family: 'IBM Plex Sans', 'Helvetica Neue', Arial, sans-serif;
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.32px;
  color: #0f62fe;
  background: #ffffff;
  border: 1px solid #0f62fe;
  padding: 4px 12px;
  cursor: pointer;
  line-height: 1.5;
  white-space: nowrap;
}
.copy-btn:hover { background: #edf4ff; }
.copy-btn.copied { color: #198038; border-color: #198038; background: #defbe6; }
.clone-box .prompt-text {
  font-family: 'IBM Plex Mono', 'Courier New', monospace;
  font-size: 13px;
  color: #161616;
  background: #f4f4f4;
  padding: 16px 20px;
  line-height: 1.7;
  white-space: pre-wrap;
  word-break: break-word;
  margin: 0;
  display: block;
}
```

### Required JavaScript

Add the following `<script>` block just before `</body>` to enable the copy button:

```html
<script>
  (function () {
    var btn = document.getElementById('copyBtn');
    var txt = document.getElementById('promptText');
    btn.addEventListener('click', function () {
      navigator.clipboard.writeText(txt.innerText).then(function () {
        btn.textContent = '已複製 ✓';
        btn.classList.add('copied');
        setTimeout(function () {
          btn.textContent = '複製 Prompt';
          btn.classList.remove('copied');
        }, 2000);
      });
    });
  })();
</script>
```

### Source of truth

`artifacts/index.html` in the local working directory is the canonical reference implementation. When generating or updating any workshop index, always check that file first and replicate the clone block verbatim (with the correct `wNN` slug substituted).

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
- Card CTA link text: `開始學習` (hardcoded in `update-index.mjs`).

---

## Repository Structure (Non-Obvious)

- `artifacts/` — local working directory for staging HTML files before committing them to the workshop branch; **gitignored** (not committed to `main`). **Not** read by `update-artifacts.sh`.
- `workshops/wNN/artifacts/` — per-workshop copies committed **on `main`**; these are what trigger `deploy-gh-pages.yml` (path filter: `workshops/**/artifacts/**`).
- `workshop/wNN` orphan branches carry an `artifacts/` at their root — this is the **source** that `update-artifacts.sh` pulls from.
- `docs/`, `plans/`, and `artifacts/` are **gitignored** — local only, never committed to `main`.
- `gh-pages` branch is **fully managed by GitHub Actions** — never edit manually.
- Each `workshop/wNN` branch is an **orphan** (no git history shared with `main`).

---

## Deployment

- Triggered automatically on push to `main` when `workshops/**/artifacts/**` changes.
- Every deploy does a **full overwrite** of `gh-pages` (`keep_files: false`) — all workshops regenerated each time.
- Published URL pattern: `https://howard-haowen.github.io/ibm-bobathon/workshops/<slug>/`
