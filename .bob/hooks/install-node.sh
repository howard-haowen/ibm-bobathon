#!/usr/bin/env bash
# install-node.sh
#
# SessionStart hook — macOS / Linux 專用
# 檢查 node 是否已安裝。
# - 若已安裝：靜默結束（exit 0），讓後續 check-deps.mjs 繼續執行。
# - 若未安裝：由 hook 自身直接安裝 nvm + Node.js 24，安裝成功後 exit 0。
#             安裝失敗則以 exit 2 通知 Bob。

# 消費 stdin（Bob hook payload），避免 broken pipe 錯誤
read -r -d '' _ < /dev/stdin 2>/dev/null || true

if command -v node > /dev/null 2>&1; then
  # node 已安裝，靜默通過
  exit 0
fi

# ── node 未安裝，由 hook 直接執行安裝 ────────────────────────────────────────
echo "🔧 Node.js 未安裝，正在自動安裝 nvm + Node.js 24..."

# 1. 安裝 nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh | bash

# 2. 載入 nvm（不重啟 shell）
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# 3. 確認 nvm 已載入
if ! command -v nvm > /dev/null 2>&1; then
  echo "❌ nvm 載入失敗，請檢查網路連線或手動安裝 Node.js。" >&2
  exit 2
fi

# 4. 安裝 Node.js 24
nvm install 24

# 5. 確認安裝成功
if command -v node > /dev/null 2>&1; then
  NODE_VER=$(node -v)
  echo "✅ Node.js 安裝成功：${NODE_VER}"
  exit 0
else
  echo "❌ Node.js 安裝後仍無法偵測，請手動確認。" >&2
  exit 2
fi
