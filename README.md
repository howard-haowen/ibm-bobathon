# IBM Bob 工作坊 Hub

> 管理 IBM Bob 工作坊教材、自動部署至 GitHub Pages 的中央 repo。
>
> 線上網站：<https://howard-haowen.github.io/ibm-bobathon/>

---

## 目錄結構

```
.
├── .github/workflows/              # GitHub Actions 自動化流程
│   ├── deploy-gh-pages.yml         # 部署工作坊至 GitHub Pages
│   └── create-workshop-branch.yml  # 建立新工作坊 branch
├── workshops/
│   └── w01/artifacts/              # w01 工作坊產出物（各工作坊為獨立孤立分支）
├── scripts/
│   ├── copy-artifacts.sh           # 將 artifacts/ 從 main 複製至指定分支
│   └── update-index.mjs            # 重新產生 artifacts/index.html 的卡片清單
├── DESIGN.md                       # 全局設計系統規範
└── skills-lock.json                # Bob AI 技能鎖定設定
```

> `docs/`、`plans/`、`artifacts/` 目錄已列入 `.gitignore`，不存在於版本庫中。`artifacts/` 為本機工作目錄，僅作為 `copy-artifacts.sh` 的來源使用。

---

## GitHub Actions 工作流程

本 repo 有兩個自動化工作流程：

### 1. `deploy-gh-pages.yml` — 部署至 GitHub Pages

**觸發條件**：任何 push 到 `main` 分支，且異動路徑符合 `workshops/**/artifacts/**`。

**執行內容**：
1. Checkout `main` 分支（完整歷史）
2. 掃描所有 `workshops/*/artifacts/` 目錄，將內容複製至 `_site/workshops/<slug>/`
3. 自動產生 `_site/index.html`（列出所有工作坊的連結清單）
4. 使用 [`peaceiris/actions-gh-pages@v4`](https://github.com/peaceiris/actions-gh-pages) 將 `_site/` 整體推送至 `gh-pages` 分支（每次部署完整覆蓋）

**結果**：GitHub Pages 自動從 `gh-pages` 分支發布，網址格式為：
```
https://howard-haowen.github.io/ibm-bobathon/workshops/<slug>/
```

---

### 2. `create-workshop-branch.yml` — 建立新工作坊分支

**觸發條件**：手動執行（`workflow_dispatch`），需傳入參數：

| 參數 | 說明 | 範例 |
|------|------|------|
| `slug` | 工作坊代號 | `w03` |

**執行內容**：
1. Checkout `main` 分支
2. 確認遠端尚未存在 `workshop/<slug>` 分支（若已存在則中止）
3. 建立 **孤立分支**（orphan branch，無共同歷史），分支名稱為 `workshop/<slug>`
4. 從 `main` 挑出以下基礎檔案並提交：
   - `.bob/mcp.json`
   - `.bob/skills/find-skills/`
   - `DESIGN.md`
   - `skills-lock.json`
5. 推送分支至遠端

---

## 本地腳本

### `scripts/copy-artifacts.sh` — 將 artifacts/ 複製至指定分支

從本機 `artifacts/` 目錄（gitignored 本機工作目錄）取出內容，套用至指定的目標工作坊分支後推送至遠端。適合在本機整理好產出物後，手動同步至對應的 `workshop/wNN` 孤立分支。

```bash
# 用法：指定目標分支名稱
bash scripts/copy-artifacts.sh workshop/w03

# 互動模式（不帶參數時提示輸入）
bash scripts/copy-artifacts.sh
```

**前置條件**：工作目錄必須是乾淨狀態（無未提交的異動）。

---

### `scripts/update-index.mjs` — 重新產生 artifacts/index.html 的卡片清單

掃描 `artifacts/*.html`（排除 `index.html`），從每個檔案萃取標題、眉標（eyebrow）與描述，自動更新 `artifacts/index.html` 中的 `<div class="card-grid">` 區塊與報告計數。

```bash
# 需要 Node.js 18+
node scripts/update-index.mjs
```

每次新增或移除 `artifacts/` 中的 HTML 頁面後，執行此腳本使首頁卡片清單保持同步。

---

## 操作流程

### 更新 `gh-pages` 分支

`gh-pages` 分支**完全由 GitHub Actions 管理**，請勿直接手動修改。

若要更新已發布的內容，流程如下：

```
修改 workshops/<slug>/artifacts/ 中的 HTML 檔案
        ↓
git add . && git commit -m "fix: update <slug> artifact"
        ↓
git push origin main
        ↓
GitHub Actions (deploy-gh-pages) 自動觸發
        ↓
_site/ 重新組合 → 推送至 gh-pages 分支
        ↓
GitHub Pages 自動發布（通常 1–2 分鐘內生效）
```

**注意事項**：
- 只有 `workshops/**/artifacts/**` 路徑下的異動才會觸發部署，修改其他路徑不會觸發。
- 每次部署會**整體覆蓋** `gh-pages` 分支（`keep_files: false`），所有工作坊重新產生。
- 可至 repo 的 **Actions** 頁面查看部署日誌，確認成功與否。

---

### 新增工作坊分支

**步驟一：登記 Slug**

在 `docs/client-url-map.md`（本機維護，未納入版控）新增一列，指定下一個 `wNN` slug（例如 `w03`），登記對應的工作坊目錄。

**步驟二：執行 Workflow 建立分支**

1. 前往 GitHub repo 的 **Actions** 頁籤
2. 選擇左側的 **Create Workshop Branch**
3. 點擊 **Run workflow**，在 `slug` 欄位填入新代號（例如 `w03`）
4. 確認執行，workflow 完成後遠端將出現 `workshop/w03` 分支

**步驟三：在分支上進行工作坊開發**

切換至新分支開發，建立 `workshops/w03/artifacts/` 目錄並加入 HTML 產出物：

```bash
git checkout workshop/w03

mkdir -p workshops/w03/artifacts

# 將工作坊 HTML 檔案放入 workshops/w03/artifacts/
# 例如：index.html、各章節頁面等

git add workshops/w03/artifacts/
git commit -m "feat(w03): add workshop artifacts"
git push origin workshop/w03
```

> ⚠️ 工作坊分支（`workshop/wNN`）為**孤立分支**，不與 `main` 共享歷史，**不應合併回 `main`**。每個工作坊分支獨立存活，`deploy-gh-pages.yml` 從 `main` 的 `workshops/wNN/artifacts/` 路徑讀取產出物進行部署。

**步驟四：將產出物同步至 `main` 並發布**

工作坊分支不合併至 `main`。請改用 `copy-artifacts.sh` 將 `artifacts/` 複製至工作坊分支，或直接在 `main` 的 `workshops/w03/artifacts/` 中新增/更新 HTML 檔案後推送：

```bash
# 直接在 main 上更新對應工作坊的 artifacts
git checkout main
# 新增或修改 workshops/w03/artifacts/ 中的檔案
git add workshops/w03/artifacts/
git commit -m "feat(w03): add workshop artifacts"
git push origin main
# deploy-gh-pages workflow 自動觸發，發布至 GitHub Pages
```

---

### Clone 單一工作坊分支

若只需取得特定工作坊的內容，可使用 `--single-branch` 搭配 `--branch` 選項，避免下載整個 repo 的所有分支歷史：

```bash
# 語法
git clone --single-branch --branch workshop/<slug> <repo-url> <本地目錄名稱（選填）>

# 範例：只 clone w03 工作坊分支
git clone --single-branch --branch workshop/w03 \
  https://github.com/howard-haowen/ibm-bobathon.git \
  ibm-bobathon-w03
```

| 選項 | 說明 |
|------|------|
| `--single-branch` | 只抓取指定分支的提交歷史，不下載其他分支 |
| `--branch workshop/<slug>` | 指定要 clone 的遠端分支名稱 |
| `<本地目錄名稱>` | 選填；省略時預設使用 repo 名稱 |

**補充**：若後續需要拉取該分支的最新異動，進入目錄後執行：

```bash
git pull origin workshop/w03
```

---

## 文件索引

| 文件 | 說明 |
|------|------|
| [`DESIGN.md`](DESIGN.md) | 全局設計系統：色彩、字型、元件規範 |
| `docs/architecture-overview.md` *(本機，未納入版控)* | Repo 架構概覽與核心概念 |
| `docs/client-url-map.md` *(本機，未納入版控)* | URL Slug 對照表 |
| `docs/contributing-materials.md` *(本機，未納入版控)* | 如何新增教學材料 |
| `docs/quick-reference.md` *(本機，未納入版控)* | 日常操作速查表 |

---

## 相關連結

- **線上工作坊 Hub**：<https://howard-haowen.github.io/ibm-bobathon/>
- **GitHub Actions**：[repo Actions 頁面](../../actions)
- **gh-pages 分支**：[gh-pages](../../tree/gh-pages)
