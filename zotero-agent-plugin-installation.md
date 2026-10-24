# Zotero Agent 外掛安裝指南規劃

## 概述 (Top-Level Overview)

本規劃旨在建立一份針對 AI Agent 的指引文件（命名為 `zotero-agent-plugin-install.md`），指導 AI Agent 如何引導及協助安裝 **Zotero Agent 外掛（Zotero Plugin `zotero-agent.xpi`）**。
本文件參考官方來源：[Zotero MCP Agent Installation](https://stevenyuyy.com/zotero-mcp/agent/#install)。

文件核心要求：
1. **明確劃分權責**：區分「AI Agent 可自動執行的 CLI 與下載任務」與「人類使用者必須手動在 Zotero GUI 操作的步驟」。
2. **安裝與提取流程**：
   - **安裝前先確認是否已安裝**：執行 `uv tool list` 檢查 `zotero-mcp-server` 是否已存在，若已安裝則跳過，不重複執行 `uv tool install`。
   - 確保 `zotero-cli` 已透過 `uv tool install zotero-mcp-server` 安裝。
   - 透過 `zotero-cli plugin --reveal` 取得 `zotero-agent.xpi` 路徑並在檔案管理員中開啟。
   - **外掛安裝前先確認是否已啟用**：透過 `zotero-cli plugin --list` 確認 `zotero-agent` 是否已出現於外掛清單，若已存在則跳過整個 GUI 安裝流程。
   - 若 `zotero-cli` 回報檔案遺失，自動從 `https://github.com/54yyyu/zotero-mcp/releases/latest/download/zotero-agent.xpi` 下載 fallback。
   - 由於 Zotero 無法透過命令列靜默安裝外掛，Agent 需明確指示人類使用者於 Zotero 介面進行「Tools > Plugins > 齒輪圖示 > Install Plugin From File」手動掛載該 `.xpi` 檔案。

---

## 子任務規劃 (Sub-Tasks)

### Sub-Task 1: 建立 Zotero Agent 外掛安裝指引文件
- **Intent**: 建立結構化 Markdown 文件，供 Agent 與人類共同協作完成 Zotero Agent 外掛安裝。
- **Expected Outcomes**: 
  - 專案根目錄新增 `zotero-agent-plugin-install.md`。
  - 內容嚴格遵循專案規範（繁體中文說明、明確的責任邊界、精確的命令列與 GUI 指引）。
- **Todo List**:
  1. 標註參考來源 `https://stevenyuyy.com/zotero-mcp/agent/#install`。
  2. 定義「人類手動步驟（Human-only Actions）」與「AI Agent 自動步驟（Agent Automation）」區塊。
  3. 編寫 Agent 自動化指令，每個步驟執行前須先確認是否已完成，避免重複安裝：
     - 執行 `uv tool list` 確認 `zotero-mcp-server` 是否已安裝，未安裝才執行 `uv tool install zotero-mcp-server`。
     - 執行 `zotero-cli plugin --list` 確認 `zotero-agent` 外掛是否已載入，已載入則跳過後續 GUI 步驟。
     - 執行 `zotero-cli plugin --reveal`，備用下載 URL 邏輯。
  4. 編寫人類 GUI 操作指引（Zotero -> Tools -> Plugins -> ⚙️ -> Install Plugin From File）。
  5. 整合驗證檢查清單。
- **Relevant Context**:
  - `zotero-bootstrap.md`
- **Status**: `[ ] pending`

---

## 驗證與檢查條件 (Verification Criteria)

1. 文件開頭或參考來源段落明確標記參考自 `https://stevenyuyy.com/zotero-mcp/agent/#install`。
2. 文件中清楚載明 `uv tool install zotero-mcp-server` 與 `zotero-cli plugin --reveal`。
3. 包含 fallback 下載連結：`https://github.com/54yyyu/zotero-mcp/releases/latest/download/zotero-agent.xpi`。
4. 每個安裝步驟前須有「已安裝則跳過」的判斷邏輯：`uv tool list` 檢查 CLI 工具，`zotero-cli plugin --list` 檢查外掛狀態。
5. 清楚標明 Zotero 無法透過 CLI 自動載入外掛，必須由人類進行 GUI 操作（`Tools > Plugins > ⚙️ > Install Plugin From File`）。
6. 語言符合繁體中文規範，語意清晰。
