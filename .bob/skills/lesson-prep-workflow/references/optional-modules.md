# 選用段落 A / B / C / E

## 選用 A — 素材匯入 (Material Import)

目標：把教師指定的文章、文獻或教育新聞轉為可用全文，供 Step 2 與 Step 3 引用。沒有素材需求時跳過。

工具：
- MCP `rss-reader`（`.bob/mcp.json` 啟用，套件 `rss-reader-mcp`）：`fetch_feed_entries`（輸入 Feed 網址，回傳標題、連結、日期、摘要）、`fetch_article_content`（輸入文章網址，回傳 Markdown 內容）。以 `bob_tool_search` / `bob_tool_describe` / `bob_tool_call` 呼叫。
- Skill `defuddle`（`.bob/skills/defuddle/SKILL.md`）：`defuddle parse <url> --md`；未安裝時依其 SKILL.md 以 `npm install -g defuddle` 安裝。
- Skill `markitdown-cli`：本機 PDF、DOCX、PPTX、XLSX 轉 Markdown（需 `uv`；`markitdown` 未安裝時須經教師同意再安裝）。
- Feed 清單：根目錄 [`teacher-feeds.opml`](../../../../teacher-feeds.opml)（教育新聞、科普、各科教學資源三類）。

流程：
1. 教師要從訂閱來源挑選：讀 `teacher-feeds.opml` 取得指定 Feed 的 `xmlUrl`，呼叫 `fetch_feed_entries` 列出最新文章供挑選。
2. 取得選定文章全文：先用 `fetch_article_content`；內容缺失或不完整（Feed 只給摘要）時，改用 `defuddle parse <url> --md`。
3. 部分 Feed（如 BBC 6 Minute English 為 Podcast、TED-Ed 為影片連結）不是文字全文；遇到時告知教師，請教師改提供文字稿或其他來源，不得編造內容。
4. 教師直接貼上文字時，以貼上的文字作為素材全文，不需抓取。
5. 記錄 `material_title`、`material_url`、`material_full_text`。

輸出：`<folder>/<topic>-material.md`（可選）；全文亦可併入教案「素材全文」章節。教案引用素材須標示來源；未取得 `material_full_text` 前，不得宣稱已閱讀該素材。

## 選用 B — Word 輸出

教師需要 `.docx` 時使用 `pandoc`（系統指令，非 Skill）：

```bash
pandoc "output/<subject>-<grade>/<topic>.md" -s -o "output/<subject>-<grade>/<topic>.docx"
```

執行前先 `pandoc --version` 確認；**未安裝時不提供 Word 輸出**，告知教師可安裝 pandoc（<https://pandoc.org/installing.html>）後再試。不處理進階 Word 排版。

## 選用 C — 行政整理

例行行政、班級管理文書或資源協尋，與主步驟無資料依賴。工具：`workspace-cli`（`.bob/skills/workspace-cli/SKILL.md`；Google Calendar、Gmail、Drive、Docs、Sheets）。

- `.bob/mcp.json` 中的 `workspacemcp` **目前為停用**。使用前須依 SKILL.md 完成：以 `uv` 安裝與啟動 `workspace-mcp`、複製 `.env.sample` 為 `.env` 並填入 Google OAuth 憑證、完成首次 OAuth 授權，並啟用 `workspacemcp`。
- 所有工具都需要教師的 Google Email（`user_google_email`）；取得前不得呼叫。
- `.env` 含敏感金鑰，已被 `.gitignore` 排除，不得提交或貼到對話中。
- 涉及學生個資（成績、聯絡資料等）的內容不得透過此流程處理。

## 選用 E — 學習圖表 (SVG)

針對學生較難理解的概念（流程、結構、比較、因果、時間軸、數量關係）產出 SVG 圖表。這是本專案**唯一**允許的視覺產出。

工具：`svg-logo-designer`（`.bob/skills/svg-logo-designer/SKILL.md`）。該 Skill 原為品牌 Logo 設計，用於教學圖表時：
- 只採用它的 **SVG 產出與規格**（可縮放、`viewBox`、色彩與可及性）；
- **跳過品牌需求收集、多概念版本與使用規範**，直接依 `diagram_needs` 產出**單張**圖表；
- 若其流程無法產出非 Logo 圖表，備案是由你直接撰寫 SVG（不使用任何圖像生成），並向教師說明。

流程：
1. `diagram_needs` 未提供時詢問教師要畫什麼。每張圖只表達一個概念；列出圖中文字與關係，請教師確認。
2. 產出 SVG：文字用繁體中文，必須含 `<title>` 與 `<desc>`，色彩對比足夠；不含學生個資；不嵌入點陣圖片。
3. 存為 `<folder>/<topic>-diagram-1.svg`（多張依序編號），並在教案 `.md` 以「學習圖表」章節註明每張圖的用途。
4. Step 4 可用內嵌 SVG 或 `<img src>` 引用同資料夾檔案。
