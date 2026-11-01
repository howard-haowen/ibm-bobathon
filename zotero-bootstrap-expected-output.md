# Zotero Bootstrap 執行結果範例（學員預期輸出參考）

本文件提供執行 [`zotero-bootstrap.md`](zotero-bootstrap.md) 安裝流程後的**標準執行回報與預期輸出結果**，供學員對照驗證自身環境是否已正確配置。

---

## 📋 執行結果總表（Agent 回報格式）

當 Agent 完成安裝與環境檢查後，會輸出類似下方的狀態清單：

| 項目 | 狀態 | 說明 / 備註 |
| :--- | :--- | :--- |
| **`uv`** | **已就緒（跳過）** 或 **本次新裝** | 位於使用者環境（如 `~/.local/bin/uv`），提供 Python 獨立工具管理 |
| **`zotero-mcp` 與 `zotero-cli`** | **已就緒（跳過）** 或 **本次新裝** | 核心工具（如 `Zotero MCP v0.13.0`），包含 MCP 伺服器與 CLI 指令列介面 |
| **本機寫入授權** | **已就緒（跳過）** 或 **本次授權完成** | 本機寫入模式已啟用，金鑰狀態為 `held (config, reusable)` |
| **[`.bob/mcp.json`](.bob/mcp.json) 的 `zotero`** | **已就緒（跳過）** 或 **本次新增** | 已加入 `zotero` 伺服器設定，設定 `"ZOTERO_LOCAL": "true"` |
| **[`.bob/skills/zotero-cli/`](.bob/skills/zotero-cli/)** | **已就緒（跳過）** 或 **本次新裝** | 技能目錄已就緒，包含 `SKILL.md` 與 `reference.md` |
| **Bob 中 `zotero` MCP 連線** | **已連線** | `mcp__zotero__*` 系列工具已可在 Bob 中調用 |

---

## 🔍 各步驟指令驗證與預期輸出

學員可自行於終端機執行下列指令，確認各元件之詳細輸出：

### 1. 驗證 `uv` 安裝
```bash
uv --version
```
**預期輸出**：
```text
uv 0.6.x (或更高版本)
```

---

### 2. 驗證 `zotero-mcp` 與 `zotero-cli`
```bash
zotero-mcp version
zotero-cli -h
```
**預期輸出**：
```text
Zotero MCP v0.13.0 (或更高版本)
```
```text
usage: zotero-cli [-h] [-v] [--json] [--json-schema]
                  {config,search,s,get,g,annotations,ann,layout,notes,n,add,collections,coll,tags,edit,duplicates,db,library,outline,read,attach,delete,export,related,coverage,synthesize,path,batch} ...

Zotero CLI — standalone library access without an MCP server.
...
```

---

### 3. 驗證本機寫入授權（Local API Key）
```bash
zotero-mcp authorize-local --status
```
**預期輸出**：
```text
Write mode:            local — local API (writes go straight to the running Zotero)
Local mode:            yes
Zotero supports local writes: yes
Server ID:             <隨機伺服器ID>
Local API key:         held (config, reusable)
Web API credentials:   not set
```

---

### 4. 驗證 [`.bob/mcp.json`](.bob/mcp.json) 設定
檢視專案目錄下的 `.bob/mcp.json`，應包含以下區塊：
```json
{
  "mcpServers": {
    "zotero": {
      "command": "zotero-mcp",
      "env": {
        "ZOTERO_LOCAL": "true"
      }
    }
  }
}
```

---

### 5. 驗證 Skill 安裝與暫存目錄清理
```bash
# 檢查技能目錄是否存在
test -d .bob/skills/zotero-cli && echo "Skill OK"

# 檢查暫存目錄是否已刪除
test ! -e .bob/_zotero-staging && echo "Staging Cleared OK"
```
**預期輸出**：
```text
Skill OK
Staging Cleared OK
```

目錄結構應呈現：
```text
.bob/skills/zotero-cli/
├── SKILL.md
└── reference.md
```

---

## 💡 常見問題與自我檢查

1. **若本機寫入授權顯示 `not held`**：
   - 請確認 Zotero 桌面端已開啟，且在 **偏好設定 / 進階** 勾選了「允許本機其他應用程式與 Zotero 通訊」。
   - 執行 `zotero-mcp authorize-local`，並在 Zotero 彈出視窗點選 **Always Allow**。
2. **若 Bob 找不到 `zotero-mcp` 指令**：
   - 執行 `zotero-mcp setup-info` 查出完整路徑（如 `/Users/<使用者>/.local/bin/zotero-mcp`），並將完整路徑填入 [`.bob/mcp.json`](.bob/mcp.json) 的 `command` 欄位。
