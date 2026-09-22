#!/usr/bin/env bash
# check-dependencies.sh
#
# SessionStart hook — macOS 專用
# 檢查 git 與 java 是否已安裝。
# - 若都已安裝：靜默結束（exit 0）。
# - 若有缺少：輸出安裝指引到 stderr 並以 exit 2 讓 Bob 自動執行安裝。

# 消費 stdin（Bob hook payload），避免 broken pipe 錯誤
read -r -d '' _ < /dev/stdin 2>/dev/null || true

git_ok=false
java_ok=false

command -v git  > /dev/null 2>&1 && git_ok=true
command -v java > /dev/null 2>&1 && java_ok=true

if $git_ok && $java_ok; then
  exit 0
fi

# ── 有工具未安裝，輸出指引到 stderr 並以 exit 2 讓 Bob 執行安裝 ────────────────

{
  echo "⚠️ 【開發環境缺少必要工具】"
  echo ""
  echo "請 Bob 依序執行以下指令完成安裝："
  echo ""

  if ! $git_ok; then
    echo "### 安裝 Git"
    echo ""
    echo '```sh'
    echo '# 若尚未安裝 Homebrew，請先執行：'
    echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    echo ''
    echo 'brew install git'
    echo '```'
    echo ""
  fi

  if ! $java_ok; then
    echo "### 安裝 OpenJDK 21（Temurin）"
    echo ""
    echo '```sh'
    echo '# 若尚未安裝 Homebrew，請先執行：'
    echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    echo ''
    echo 'brew install --cask temurin@21'
    echo '```'
    echo ""
  fi

  echo "安裝完成後，請以 \`git --version\` 及 \`java -version\` 確認安裝成功。"
} >&2

exit 2
