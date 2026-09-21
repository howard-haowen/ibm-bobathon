/**
 * check-deps.mjs
 *
 * SessionStart hook — 在每次 Bob 任務啟動時自動執行。
 * 檢查 git、npx（Node.js）、uv（Python 工具鏈）是否已安裝。
 * 若有缺少，輸出繁體中文的逐步安裝說明，讓 Bob 轉達給使用者。
 */

import { execSync } from "node:child_process";

// 讀取 hook payload（不需要內容，但需要消費 stdin 避免 pipe 報錯）
let raw = "";
for await (const chunk of process.stdin) raw += chunk;

/** 目前作業系統：'win32' | 'darwin' | 'linux' */
const OS = process.platform;
const isWindows = OS === "win32";

/**
 * 檢查指令是否可以在 PATH 中找到。
 * macOS/Linux 用 `which`，Windows 用 `where`（兩者皆為內建指令）。
 * @param {string} cmd
 * @returns {boolean}
 */
function isInstalled(cmd) {
  try {
    const checker = isWindows ? `where ${cmd}` : `which ${cmd}`;
    execSync(checker, { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

const missing = [];

if (!isInstalled("git")) missing.push("git");
if (!isInstalled("node") || !isInstalled("npx")) missing.push("npx");
if (!isInstalled("uv")) missing.push("uv");

if (missing.length === 0) {
  // 所有工具都已就緒，不輸出任何內容（避免打擾正常對話）
  process.exit(0);
}

// ── 組裝安裝說明 ──────────────────────────────────────────────────────────────

const lines = [];

lines.push("⚠️  【環境設定提醒】");
lines.push(
  `Bob 偵測到以下必要工具尚未安裝：${missing.join("、")}。` +
  `請依照下方步驟完成安裝，之後就不需要再做了。`
);
lines.push("");

// ── git ──────────────────────────────────────────────────────────────────────
if (missing.includes("git")) {
  lines.push("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  lines.push("📦 安裝 Git（版本管理工具）");
  lines.push("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  lines.push("Git 用來追蹤檔案的修改歷史，Skills 與工具更新時也會用到。");
  lines.push("");
  lines.push("▸ macOS（推薦方式）：");
  lines.push("  1. 開啟 Terminal（按 ⌘ + 空白鍵，輸入「Terminal」後按 Enter）");
  lines.push("  2. 貼上以下指令並按 Enter：");
  lines.push("     xcode-select --install");
  lines.push("  3. 跳出的視窗點「安裝」，等待完成即可。");
  lines.push("");
  lines.push("▸ Windows：");
  lines.push("  1. 前往 https://git-scm.com/download/win");
  lines.push("  2. 下載安裝程式並執行，全部選項保持預設，點「Next」直到完成。");
  lines.push("");
}

// ── npx / Node.js ─────────────────────────────────────────────────────────────
if (missing.includes("npx")) {
  lines.push("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  lines.push("📦 安裝 Node.js（包含 npx）");
  lines.push("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  lines.push("Node.js 是執行 MCP Server（新聞閱讀工具）所必須的環境。");
  lines.push("npx 是 Node.js 內建的工具執行程式，安裝 Node.js 後就會自動擁有。");
  lines.push("");

  if (isWindows) {
    lines.push("▸ Windows（推薦使用 nvm-windows）：");
    lines.push("  1. 前往 https://github.com/coreybutler/nvm-windows/releases");
    lines.push("  2. 下載最新的「nvm-setup.exe」並執行安裝（全部保持預設）");
    lines.push("  3. 安裝完成後，開啟「命令提示字元」或「PowerShell」");
    lines.push("  4. 貼上以下指令安裝最新 LTS 版本：");
    lines.push("     nvm install lts");
    lines.push("     nvm use lts");
    lines.push("");
    lines.push("▸ 或直接下載安裝包（較簡單）：");
    lines.push("  前往 https://nodejs.org，點擊「LTS」版本下載並執行安裝程式。");
  } else {
    lines.push("▸ macOS / Linux（推薦使用 nvm）：");
    lines.push("  1. 開啟 Terminal（按 ⌘ + 空白鍵，輸入「Terminal」後按 Enter）");
    lines.push("  2. 貼上以下指令並按 Enter：");
    lines.push("     curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash");
    lines.push("  3. 關閉並重新開啟 Terminal");
    lines.push("  4. 貼上以下指令安裝最新 LTS 版本：");
    lines.push("     nvm install --lts");
    lines.push("");
    lines.push("▸ 或直接下載安裝包（較簡單但不易切換版本）：");
    lines.push("  前往 https://nodejs.org，點擊「LTS」版本下載並安裝。");
  }
  lines.push("");
}

// ── uv ────────────────────────────────────────────────────────────────────────
if (missing.includes("uv")) {
  lines.push("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  lines.push("📦 安裝 uv（Python 快速工具鏈）");
  lines.push("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  lines.push("uv 是安裝與執行 Python 類 Skills（如 defuddle）所需的工具。");
  lines.push("");
  lines.push("▸ macOS / Linux：");
  lines.push("  1. 開啟 Terminal");
  lines.push("  2. 貼上以下指令並按 Enter：");
  lines.push("     curl -LsSf https://astral.sh/uv/install.sh | sh");
  lines.push("  3. 依照提示重新載入 shell，或直接關閉後重開 Terminal。");
  lines.push("");
  lines.push("▸ Windows（PowerShell）：");
  lines.push("  1. 開啟「PowerShell」（按 ⊞ + X，選「Windows PowerShell」）");
  lines.push("  2. 貼上以下指令並按 Enter：");
  lines.push("     powershell -ExecutionPolicy ByPass -c \"irm https://astral.sh/uv/install.ps1 | iex\"");
  lines.push("");
}

lines.push("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
lines.push("✅ 安裝完成後，請重新啟動 Bob（關閉再開），工具就會自動生效！");
lines.push(
  "如果過程中遇到任何問題，直接把錯誤訊息告訴 Bob，我會幫你排除。"
);

process.stdout.write(lines.join("\n") + "\n");
process.exit(0);
