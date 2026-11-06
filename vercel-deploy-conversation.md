---
title: "使用者與 AI Agent 對話紀錄：將 artifacts/ 部署到 Vercel"
date: 2026-11-06
agent: Bob
mode: Agent
workspace: /Users/haowen_jiang/ibm-bobathon
tags:
  - conversation-log
  - vercel
  - deploy-to-vercel
---

# 使用者與 AI Agent 對話紀錄：將 `artifacts/` 部署到 Vercel

> 本紀錄完整保存使用者的輸入；AI Agent 的回覆與動作僅保留摘要重點。

---

## 第 1 輪

### 👤 使用者

`````text
/deploy-to-vercel

把 artifacts/ 部署到 vercel，完成後給我 URL
`````

### 🤖 AI Agent（摘要）

- 依 skill 的 Step 1 檢查專案狀態：有 git remote（`git@github.com:howard-haowen/ibm-bobathon.git`）、無 `.vercel/` 連結、Vercel CLI 未安裝（`vercel: command not found`）；`artifacts/` 內有 4 個 HTML 檔（含 `index.html`）。
- 因 CLI 未安裝且未登入，採用 skill 的 **no-auth fallback**：`npx -y vercel@latest deploy artifacts --temporary -y`。
- 部署成功（Ready in 5s），結果：
  - 部署 URL：https://fast-monsoon-2i1jdpz.tmp.now
  - 臨時部署，**60 分鐘後過期**；可透過 claim 連結認領以保留（claim 連結不可分享）。
  - 副作用：工作目錄產生 `.vercel/` 資料夾。
