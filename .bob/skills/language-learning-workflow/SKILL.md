---
name: language-learning-workflow
description: End-to-end multilingual language learning workflow. Use when the user wants to read news or articles for language study, extract vocabulary and grammar, archive notes to Obsidian, or publish cheatsheet HTML pages.
---

# Multilingual Language Learning Workflow

本技能指導多語言學習助手的完整 4 步驟執行流程，將日常外語/中文時事新聞轉化為結構化的數位語言資產與複習教材。

## 角色定位與核心原則

- **角色**：精通多語言教學的專業外語導師（Multilingual Language Tutor）與知識管理顧問。
- **繁體中文輸出**：所有解說、文法剖析、詞義翻譯與教學說明一律使用「繁體中文（台灣，zh-TW）」。
- **結構化與在地化**：例句必須自然道地，附音標/讀音、詞性、難度等級（CEFR）與繁體中文釋義。
- **工具協同（Agentic Flow）**：嚴格依順序執行四個步驟，不得跳過或亂序。

```mermaid
flowchart LR
    A["Step 1\n語料獲取\nNetNewsWire / rss-reader-mcp\n+ defuddle fallback"]
    B["Step 2\n語料分析\nlanguage-learning Skill\n（詞彙 / 文法 / 文化 / 閃卡）"]
    C["Step 3\n知識庫寫入\nobsidian-cli\n（全文 + 分析）"]
    D["Step 4\n網頁發佈\nmarkdown-to-html Skill\n（Cheatsheet 格式）"]

    A -->|"選定文章全文"| B
    B -->|"詞彙卡 + 文法剖析\n+ 文化補充 + 閃卡"| C
    C -->|"完整筆記結構"| D
```

---

## Step 1 — 語料獲取 (Source Acquisition)

**目標**：取得選定文章的完整原文，作為後續所有步驟的語料來源。

### 1.1 選擇 RSS 工具取得文章
- **環境判定**：
  - 若已安裝 NetNewsWire MCP → 使用 `mcp__netnewswire__get_articles` 列出未讀文章，選定後呼叫 `mcp__netnewswire__read_article` 取得內容。
  - 若未安裝 NetNewsWire → 使用 `rss-reader-mcp` 的 `rss_get_feed` 傳入 Feed URL（參考 [`language-learning-feeds.opml`](language-learning-feeds.opml)），選定後呼叫 `rss_get_article` 取得內容。
- **全文補齊（Fallback）**：若 RSS 僅提供摘要或全文缺失，啟用 `defuddle` 技能（`.bob/skills/defuddle/SKILL.md`）透過文章原始 URL 抓取完整網頁正文。

### 1.2 語言偵測與目標外語確認
- 偵測文章語言：
  - **原文為非中文**：將偵測到的語言設為 `article_language`，設 `article_is_chinese_source = false`。
  - **原文為中文**（繁體或簡體）：使用 `ask_followup_question` 詢問使用者欲翻譯並學習的目標外語（如 English, Japanese, French, German...），將選擇設為 `article_language`，設 `article_is_chinese_source = true`。

### 1.3 產出資料結構
確認取得全文後記錄以下變數：
- `article_title`：文章標題
- `article_url`：原始連結
- `article_date`：發布日期
- `article_language`：目標學習外語
- `article_is_chinese_source`：布林值
- `article_full_text`：原始全文
- `article_slug`：安全檔名
  - **中文來源** (`article_is_chinese_source = true`)：保留中文字元（**不得轉拼音**），標點符號與空格替換為 `-`，去除首尾及重複連字號。
  - **外語來源** (`article_is_chinese_source = false`)：轉小寫（英文），標點與空格替換為 `-`，去除首尾及重複連字號。

---

## Step 2 — 語料分析與學習材料生成 (Language Analysis)

**工具**：啟用 `language-learning` Skill（`.bob/skills/language-learning/SKILL.md`）。

### 2.0 前置翻譯（若 `article_is_chinese_source = true`）
1. 將 `article_full_text` 翻譯為 `article_language` 指定之目標外語，產出 `article_translated_text`。
2. 保持段落層次、專有名詞對齊目標語習慣、文體語氣一致，必要時於末尾附「譯者備注 (Translator's Note)」。
3. 後續 2-A 至 2-F 以 `article_translated_text` 為唯一分析對象。
4. （若 `article_is_chinese_source = false`，則 `article_translated_text = article_full_text`）。

### 2-A CEFR 層級定位
依文章文體難度判定 CEFR 級別（B1 / B2 / C1 / C2）並標示。

### 2-B 詞彙提取（8～12 個）
精選 8～12 個高學習價值詞彙，每項包含：
- **單詞 / 原形（Lemma）**
- **音標 / 讀音**（IPA / 假名 / 拼音）
- **詞性與文法特徵**（性別、動詞分類、格位等）
- **CEFR 難度**
- **繁體中文精確釋義**（含語域：正式/口語/新聞體）
- **文章原句引用 + 繁中翻譯**
- **生活化延伸例句 + 繁中翻譯**（標明場景：職場/日常/旅遊）
- **記憶鉤 (Memory Hook)**（語源/字根/諧音/視覺助記）
- **常用搭配 (Collocations)**（2～3 組）
- **易混淆提示**（近義詞、False Friends 比較）

### 2-C 文法剖析（2～3 個句型）
- **原句展示**
- **結構標記**（S+V+O、子句、修飾語、分詞）
- **句型名稱**（語言學術語）
- **文法規則說明**
- **類比句型練習 + 繁中翻譯**
- **語域與語境備註**（書面/口語/新聞體替換）

### 2-D 篇章主旨摘要
3～5 句繁中概述核心論點、文體類型、1～2 個重要背景知識。

### 2-E 文化語境補充（至少 2 項）
- **語用層次**（敬語、場合禁忌）
- **慣用語 / 成語**（直譯 + 實際意涵 + 場景）
- **文化典故 / 新聞脈絡**
- **跨語言陷阱**（中文母語者常見錯誤）

### 2-F 間隔複習閃卡
兩欄對照表（目標詞彙+音標 vs. 繁中釋義+詞性），標註當日、隔日、一週後複習。

---

## Step 3 — 知識庫寫入與關聯 (Knowledge Base Archiving)

**工具**：`obsidian-cli` Skill & CLI（`.bob/skills/obsidian-cli/SKILL.md`）；目標 Vault：`llm-wiki`。

### 3.1 寫入目標
1. **本機專案檔案**：使用 `write_file` 寫入 `output/<article_slug>.md`。
2. **Obsidian Vault**：使用 `execute_command` 透過 `obsidian-cli` 寫入 `llm-wiki` Vault 中的 `language-notes/<article_slug>.md`。

### 3.2 筆記結構規範
遵循以下 Markdown 格式：

```markdown
---
title: "[文章標題]"
date: YYYY-MM-DD
language: "[目標外語]"
source_language: "[來源語言]"
cefr_level: "[B1/B2/C1/C2]"
source_url: "[文章連結]"
tags:
  - language-learning
  - vocabulary
  - grammar
  - [目標語言小寫]
---

# [文章標題] 學習筆記

## 📰 原始文章全文 (Full Article Text)

<!-- 若原文為外語 -->
> [完整外語原文]

<!-- 若原文為中文，改用以下兩區塊 -->
<!-- ### 🇹🇼 中文原文 (Original Chinese Text) -->
<!-- > [完整中文原文] -->
<!-- ### 🌐 [目標語言] 翻譯版 (Translated Text) -->
<!-- > [外語翻譯全文] -->

---

## 🗂️ 篇章概覽 (Discourse Summary)
...

## 📚 重點生詞卡 (Vocabulary Flashcards)
...

## 🔍 文法剖析 (Grammar & Syntax Breakdown)
...

## 🌏 文化語境補充 (Cultural Context)
...

## 🔁 間隔複習閃卡 (Spaced Repetition Flashcards)
...
```

---

## Step 4 — 網頁渲染與分享 (HTML Publishing)

**工具**：`markdown-to-html` Skill（`.bob/skills/markdown-to-html/SKILL.md`）。

### 4.1 輸出要求
- 將 `output/<article_slug>.md` 轉為 `output/<article_slug>.html`。
- **Cheatsheet 風格排版**：
  - 生詞以卡片/精簡表格呈現（單詞、音標、詞性、釋義、例句）。
  - 文法剖析以 highlight box / callout 呈現核心結構與規則。
  - 完整原文收錄於頁面底部供對照。
  - 樣式自包含（Inline CSS），適配列印 (A4) 與行動裝置。
