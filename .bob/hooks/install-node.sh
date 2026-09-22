#!/usr/bin/env bash
# install-node.sh
#
# SessionStart hook — macOS / Linux 專用
# 檢查 node 是否已安裝。
# - 若已安裝：靜默結束（exit 0），讓後續 check-deps.mjs 繼續執行。
# - 若未安裝：以 exit 2 輸出給 Bob 的安裝 instruction，讓 Bob 執行指令來安裝 Node.js。

# 消費 stdin（Bob hook payload），避免 broken pipe 錯誤
read -r -d '' _ < /dev/stdin 2>/dev/null || true

if command -v node > /dev/null 2>&1; then
  # node 已安裝，靜默通過
  exit 0
fi

# ── node 未安裝，輸出 instructions 給 Bob 並以 exit 2 阻止任務繼續 ──────────────────────────
cat >&2 << 'EOF'
⚠️ 【必要工具未安裝：Node.js】

環境中尚未安裝 Node.js。請 Bob 直接執行以下指令安裝 nvm 及 Node.js 24：

```bash
## macos
# Download and install nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh | bash

# in lieu of restarting the shell
\. "$HOME/.nvm/nvm.sh"

# Download and install Node.js:
nvm install 24

# Verify the Node.js version:
node -v # Should print "v24.21.0" or latest v24.x

# Verify npm version:
npm -v # Should print "11.19.0" or latest v11.x
```

請在執行完成並確認 node 與 npm 就緒後告知使用者。
EOF

exit 2
