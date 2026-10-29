# Zotero MCP Server 環境適配與路徑設定指南 (Agent 指引)

本文件專為 AI Agent 設計，說明如何動態偵測並設定使用者的本地環境，將 [`.bob/mcp.json`](.bob/mcp.json) 中的 `zotero` 服務指向正確的執行檔路徑。

---

## 🎯 目標

每個使用者的系統環境不同（例如使用者帳號名稱、Python/uv 安裝位置），[`.bob/mcp.json`](.bob/mcp.json) 中的 `zotero.command` 必須設置為該系統上可執行的 `zotero-mcp` 絕對路徑或可直接運行的執行檔名稱，並帶上 `args: ["serve"]`。

---

## 🛠️ Agent 自動適配標準作業流程 (SOP)

### 步驟 1：偵測系統上的 `zotero-mcp` 執行檔路徑

AI Agent 應先透過終端機指令依序搜尋 `zotero-mcp` 的實際路徑：

```bash
# 優先嘗試 which / where
which zotero-mcp 2>/dev/null || find ~/.local ~/.cargo ~/.nvm /opt /usr/local -name "zotero-mcp" 2>/dev/null
```

> **常見路徑範例**：
> - `~/.local/bin/zotero-mcp`（展開為完整絕對路徑，如 `/Users/<username>/.local/bin/zotero-mcp` 或 `/home/<username>/.local/bin/zotero-mcp`）
> - `~/.local/share/uv/tools/zotero-mcp-server/bin/zotero-mcp`
> - 若使用 pip/pipx 安裝：`/usr/local/bin/zotero-mcp` 或 `~/.local/pipx/venvs/zotero-mcp/bin/zotero-mcp`

---

### 步驟 2：驗證執行檔可用性與安裝狀態

找到路徑後，執行以下指令驗證：

```bash
<找到的路徑> setup-info
```

- 若輸出包含 `Installation Details` 及 `Local API key: held`，表示本地環境已授權並可正常讀寫。
- 若提示需要授權本地寫入權限，可告知使用者於桌面端確認，或執行 `<找到的路徑> authorize-local`。

---

### 步驟 3：更新 [`.bob/mcp.json`](.bob/mcp.json) 配置

讀取現有的 [`.bob/mcp.json`](.bob/mcp.json)，將 `zotero` 區塊更新為動態偵測到的絕對路徑與標準參數：

```json
{
  "mcpServers": {
    "zotero": {
      "command": "<動態取得的 zotero-mcp 絕對路徑>",
      "args": [
        "serve"
      ],
      "env": {
        "ZOTERO_LOCAL": "true"
      }
    }
  }
}
```

> ⚠️ **注意事項**：
> 1. **切勿覆寫其他 MCP 服務**：更新時請保留 `netnewswire`、`rss-reader`、`workspacemcp` 等其他既有服務。
> 2. **參數必須帶上 `args: ["serve"]`**：`zotero-mcp` 啟動 MCP 服務需要 `serve` 子命令。
> 3. **環境變數 `ZOTERO_LOCAL: "true"`**：確保優先連線至本機 Zotero 桌面端資料庫。

---

### 步驟 4：連線驗證

配置存檔後，呼叫 Zotero MCP 工具（例如 `mcp__zotero__zotero_search_items` 或 `mcp__zotero__zotero_get_recent`）進行連線測試：

- 測試查詢：搜尋任一常見作者或關鍵字。
- 若成功回傳文獻清單，即代表 Zotero MCP Server 已成功對接該使用者的本地環境。
