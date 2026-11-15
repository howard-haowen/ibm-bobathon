# AGENTS.md

## 語言學習工作流程

當使用者要求閱讀新聞或文章來學習語言、提取生詞與文法、將筆記存入 Obsidian，或發佈 Cheatsheet HTML 頁面時，先啟用 `language-learning-workflow` 技能（[`.bob/skills/language-learning-workflow/SKILL.md`](.bob/skills/language-learning-workflow/SKILL.md)），並嚴格依其四個步驟依序執行：

1. 語料獲取（NetNewsWire / `rss-reader-mcp`，必要時用 `defuddle` 補全文）
2. 語料分析（`language-learning` 技能）
3. 知識庫寫入（`obsidian-cli`，Vault：`llm-wiki`）
4. 網頁發佈（`markdown-to-html` 技能，Cheatsheet 格式）
