# MCP npx server 設定規範

編輯 `.bob/mcp.json` 中以 `npx` 啟動的 MCP server（如 `rss-reader`、`netnewswire`）時，先判斷作業系統，再套用下列規則。
原因：Bob 是 GUI 應用程式，不一定繼承 shell 的 `PATH`，只寫 `npx` 會導致 MCP 面板顯示「已中斷連線」。

## 共通

- `args` 一律包含 `-y`，避免 `npx` 等待安裝確認而卡住。
- 不要設定 `"disabled": true`，除非使用者明確要求。
- 不要把另一個作業系統的路徑寫進設定。

## macOS

- `command` 使用 `npx` 的絕對路徑，不可只寫 `npx`。
  - Apple Silicon（Homebrew）：`/opt/homebrew/bin/npx`
  - Intel（Homebrew）：`/usr/local/bin/npx`
  - 其他安裝方式（nvm、volta 等）：以 `which npx` 為準
- 加上 `env.PATH`，包含 `npx` 所在目錄，例如 `/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin`。

```json
"rss-reader": {
  "command": "/opt/homebrew/bin/npx",
  "args": ["-y", "rss-reader-mcp"],
  "env": { "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" }
}
```

## Windows

- `npx` 實為 `npx.cmd`，必須透過 `cmd /c` 呼叫：`command` 為 `cmd`，`args` 以 `"/c", "npx", "-y", ...` 開頭。
- 通常不設定 `env.PATH`（覆寫可能讓 `cmd` 找不到系統目錄）。僅在 `where npx` 找不到時，才補上 Node.js 目錄（預設 `C:\\Program Files\\nodejs`），並保留 `C:\\Windows\\System32`。JSON 內反斜線寫成 `\\`。

```json
"rss-reader": {
  "command": "cmd",
  "args": ["/c", "npx", "-y", "rss-reader-mcp"]
}
```

## netnewswire 限制

- `netnewswire`（`@jellllly/netnewswire-mcp`）只支援 macOS，且需要 NetNewsWire App 正在執行（`pgrep -x NetNewsWire` 可確認）。
- 在 Windows 上不要新增此 server；若已存在，設為 `"disabled": true` 並告知使用者原因。

## 診斷「已中斷連線」

1. 確認該 server 在 `.bob/mcp.json` 沒有被停用。
2. 確認 `npx` 位置：macOS 用 `which node npx`，Windows 用 `where node` 與 `where npx`。
3. 手動送 `initialize` 請求確認套件能啟動：
   - macOS 沒有 `timeout`，用背景程序加 `sleep` 與 `kill`：
     `echo '<initialize JSON-RPC>' | (npx -y <package> & P=$!; sleep 20; kill $P 2>/dev/null)`
   - Windows（PowerShell）：`'<initialize JSON-RPC>' | npx -y <package>`，看到回應後按 Ctrl+C。
4. 手動正常但面板仍中斷，代表問題在 Bob 的啟動環境，套用上面對應作業系統的規則。
5. 編輯後驗證 JSON 合法：macOS 用 `jq -e '.mcpServers | keys' .bob/mcp.json`，Windows 用 `Get-Content .bob\mcp.json -Raw | ConvertFrom-Json | Out-Null`。
6. 請使用者在 Bob 的 MCP 面板按重新整理（或重新載入視窗）。Agent 無法替使用者重新連線，也無法在 Bob 內驗證連線結果。

`<initialize JSON-RPC>` 為：
`{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}`
