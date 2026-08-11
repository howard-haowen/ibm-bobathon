# w02 工作坊教材

IBM Bob 工作坊教材與成品。

## 📂 本分支追蹤的檔案

```
workshop/w02/
├── README.md                    # 本檔案（繁體中文指南）
├── AGENTS.md                    # AI agents 指南
│
├── DESIGN.md                    # IBM Carbon 設計系統完整規範
├── .gitignore                   # Git 忽略規則
├── skills-lock.json             # Bob 技能依賴版本鎖定
├── .bob/
│   ├── mcp.json                # Model Context Protocol 配置
│   └── skills/
│       └── find-skills/SKILL.md # 技能發現工具定義
│
└── artifacts/                   # 教材成品（發布內容）
    ├── 01-ibm-bob-basic-usage.html
    ├── 02-cobol-documentation.html
    ├── 03-wasdb2mq-ansible-ops.html
    └── index.html              # 首頁卡片導覽
```

## 🎯 檔案說明

### 核心教材

- **`artifacts/01-ibm-bob-basic-usage.html`** — IBM Bob 基礎使用
- **`artifacts/02-cobol-documentation.html`** — COBOL 文檔生成
- **`artifacts/03-wasdb2mq-ansible-ops.html`** — 運維自動化指南
- **`artifacts/index.html`** — 首頁卡片導覽

### 設計與配置

- **`DESIGN.md`** — IBM Carbon Design System 規範
- **`.gitignore`** — Git 忽略規則
- **`skills-lock.json`** — Bob 技能依賴鎖定
- **`.bob/mcp.json`** — MCP 伺服器配置
- **`.bob/skills/find-skills/SKILL.md`** — 技能發現工具

## 🚀 快速開始

### 檢視教材

本分支的教材發布在：
https://howard-haowen.github.io/ibm-bobathon/workshops/w02/（GitHub Pages）

### 編輯教材

```bash
# 確認在 workshop/w02 分支
git checkout workshop/w02

# 編輯 artifacts/ 中的 HTML 檔案
git add artifacts/
git commit -m "fix(w02): 修正教材內容"
git push origin workshop/w02
```

### 發布教材

當準備發布時，從 `main` 分支執行：

```bash
git checkout main
git checkout workshop/w02 -- artifacts/
git commit -m "feat(w02): publish workshop artifacts"
git push origin main
```

自動部署至 GitHub Pages（1-2 分鐘內完成）。

## 📖 設計系統

本專案所有教材都嚴格遵循 IBM Carbon Design System（見 `DESIGN.md`）。

### 設計原則

✅ **必須遵守**：
- 方角設計（`border-radius: 0px`）
- IBM Blue（`#0f62fe`）作為唯一品牌色
- IBM Plex Sans 字型（顯示用 weight 300，本文用 weight 400）
- 4px 基礎網格間距
- 無陰影、無漸層（企業簡潔風格）

❌ **禁止使用**：
- 圓角按鈕或卡片
- 多種品牌色
- 投影或漸層效果
- 所有大寫且間距緊密的眉毛文字

### 色彩系統

| 用途 | 顏色 | 十六進制 |
|------|------|---------|
| 主色 / 連結 / CTA | IBM Blue | `#0f62fe` |
| 標題 / 本文 | 炭灰 | `#161616` |
| 頁面背景 | 白色 | `#ffffff` |
| 替代區段 | 淡灰 | `#f4f4f4` |
| 成功 | 綠色 | `#24a148` |
| 警告 | 黃色 | `#f1c21b` |
| 錯誤 | 紅色 | `#da1e28` |

## 🔄 工作流程

### 新增教材

1. 在 `artifacts/` 建立新的 `.html` 檔案
2. 遵循 `DESIGN.md` 規範進行設計
3. 提交並推送至 `workshop/w02`
4. 執行 `node scripts/update-index.mjs`（若可用）更新首頁
5. 準備就緒後合併至 `main` 發布

### 修改現有教材

```bash
# 編輯檔案
vi artifacts/01-ibm-bob-basic-usage.html

# 驗證 HTML 有效性
# 測試響應式設計（320px, 672px, 1056px, 1312px, 1584px 寬度）

# 提交
git add artifacts/01-ibm-bob-basic-usage.html
git commit -m "fix(w02): 修正 IBM Bob 基礎使用教材"
git push origin workshop/w02
```

## 📋 約束與注意

- 本分支只包含 w02 工作坊的教材文件
- 所有 HTML 必須符合 Carbon Design System
- 不含外部 script 標籤（inline CSS/JS only）
- 圖片使用 data: URI 或本地檔案
- 提交訊息應遵循 conventional commits：`type(w02): subject`

## 🔗 相關連結

- **發布 URL**：https://howard-haowen.github.io/ibm-bobathon/workshops/w02/
- **GitHub Actions**：https://github.com/howard-haowen/ibm-bobathon/actions
- **主分支**：`main`（發布聚合點）
- **設計規範**：`DESIGN.md`（必讀）

---

**分支**：`workshop/w02`
**狀態**：Active
**上次更新**：2026-08
