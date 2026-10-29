---
name: workspace-cli
description: Google Workspace MCP Server 與 workspace-cli 操作指引。涵蓋使用 uv 安裝、環境變數與 OAuth 憑證配置、以 Streamable HTTP 啟動 MCP Server、設定 .bob/mcp.json 客戶端、使用 workspace-cli list 驗證連線，以及透過 workspace-cli call list_calendars 進行 Google Calendar 日曆查詢測試。當使用者需要配置 Google Workspace MCP、使用 workspace-cli、整合 Google Calendar/Gmail/Drive、或進行相關故障排除時使用。
---

# Google Workspace MCP & workspace-cli 指南

本指南提供使用 `workspace-mcp` 與 `workspace-cli` 整合 Google Workspace（Calendar、Gmail、Drive、Docs、Sheets 等）的完整步驟。

---

## 1. 安裝 workspace-mcp 與 CLI

使用 `uv` 進行安裝與執行：

```bash
# 一次性執行 MCP Server（首次執行時自動下載最新版本）
uvx workspace-mcp --tool-tier core

# 本地持續安裝 CLI 工具（便於隨時調用 workspace-cli）
uv tool install workspace-mcp
```

### 查詢說明與說明文件 (Help Info)

使用 `--help` 或 `-h` 隨時查看 CLI 的支援命令與參數格式：

```bash
# 查看主命令說明與全域參數
workspace-cli --help

# 查看特定子命令（如 call）的用法說明
workspace-cli call --help
```

---

## 2. 設定環境變數與 Google OAuth 憑證

1. **複製範本檔案**：
   將專案中的 `.env.sample` 複製為 `.env`：
   ```bash
   cp .env.sample .env
   ```

2. **填入憑證資訊**：
   編輯 `.env` 檔案，填入從 Google Cloud Console 取得的 OAuth 2.0 Client 憑證：
   ```env
   GOOGLE_OAUTH_CLIENT_ID="your_google_oauth_client_id.apps.googleusercontent.com"
   GOOGLE_OAUTH_CLIENT_SECRET="your_google_oauth_client_secret"
   ```

> ⚠️ **注意**：`.env` 包含敏感金鑰，請確保已被加入 `.gitignore`，切勿提交至版本控制系統。

---

## 3. 啟動 MCP Server

載入環境變數後，使用現代 Streamable HTTP 傳輸協定啟動 Server：

```bash
# 載入 .env 並以 Streamable HTTP 模式啟動
export $(cat .env | xargs) && uvx workspace-mcp --transport streamable-http --tool-tier core
```

啟動後，Server 預設會監聽在 `http://localhost:8000/mcp`。

---

## 4. 設定 MCP Client (.bob/mcp.json)

在專案的 `.bob/mcp.json` 中加入 `workspacemcp` 伺服器配置：

```json
{
  "mcpServers": {
    "workspacemcp": {
      "type": "streamable-http",
      "url": "http://localhost:8000/mcp"
    }
  }
}
```

---

## 5. 測試連線與列出可用工具

使用 `workspace-cli` 確認與運行中的 MCP Server 連線正常，並列出所有已註冊的 Tools：

```bash
workspace-cli list
```

若成功連線，終端機將列出包含 `list_calendars`、`get_events`、`search_gmail_messages` 等 40 多個工具清單。

---

## 6. 引導使用者提供 Email 與測試 Google 日曆

### 步驟 A：確認使用者的 Google Email
在呼叫任何工具前，必須取得使用者的 Google 帳號 Email（例如 `user@gmail.com`）。所有工具均要求傳入必填參數 `user_google_email`。

### 步驟 B：執行日曆清單測試指令
```bash
workspace-cli call list_calendars user_google_email="<your-email>"
```

### 步驟 C：處理首次 OAuth 授權（若需要）
若該帳號為首次授權，指令將回傳授權網址：
1. 終端機或回應中會顯示 `Authorization URL: https://accounts.google.com/o/oauth2/auth?...`。
2. 引導使用者在瀏覽器中開啟該連結，登入指定的 Google 帳號並允許所有權限。
3. 授權成功後，瀏覽器會回呼至 `http://localhost:8000/oauth2callback` 並提示授權成功。
4. 授權完成後，**重新執行一次測試指令**：
   ```bash
   workspace-cli call list_calendars user_google_email="<your-email>"
   ```
5. 成功後將會回傳使用者帳號所擁有的日曆清單（如 `primary` 日曆等）。

---

## 💡 常見注意事項與技巧

- **取得說明資訊**：隨時執行 `workspace-cli --help` 或 `workspace-cli call --help` 查詢命令列語法。
- **必填參數**：所有 Google 服務工具皆須帶入 `user_google_email`。
- **參數格式**：`workspace-cli call <tool_name> key1=value1 key2=value2`（字串含空白時請加上引號）。
- **授權過期/更換帳號**：若需要重新授權，可確認 `~/.workspace-mcp/cli-tokens` 中的憑證狀態。
