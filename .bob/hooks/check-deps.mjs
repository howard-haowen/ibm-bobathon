/**
 * check-deps.mjs
 *
 * SessionStart hook — 在每次 Bob 任務啟動時自動執行。
 * 前置條件：install-node.sh / install-node.bat 已確保 node 存在。
 * 本腳本只檢查 git 與 uv 是否已安裝。
 * 若有缺少，輸出繁體中文的安裝 instructions 給 Bob 執行。
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
if (!isInstalled("uv")) missing.push("uv");

if (missing.length === 0) {
  // 所有工具都已就緒，不輸出任何內容（避免打擾正常對話）
  process.exit(0);
}

// ── 組裝給 Bob 的安裝 instruction ──────────────────────────────────────────

const lines = [];

lines.push("⚠️ 【環境依賴未齊全】");
lines.push(
  `Bob 偵測到以下必要工具尚未安裝：${missing.join("、")}。` +
  `請 Bob 直接協助執行以下指令來完成安裝：`
);
lines.push("");

// ── git ──────────────────────────────────────────────────────────────────────
if (missing.includes("git")) {
  lines.push("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  lines.push("📦 安裝 Git（版本管理工具）");
  lines.push("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  if (!isWindows) {
    lines.push("▸ macOS / Linux：請 Bob 執行以下指令：");
    lines.push("```bash");
    lines.push("xcode-select --install");
    lines.push("```");
  } else {
    lines.push("▸ Windows：請 Bob 執行以下指令：");
    lines.push("```powershell");
    lines.push("winget install --id Git.Git -e --source winget");
    lines.push("```");
  }
  lines.push("");
}

// ── uv ────────────────────────────────────────────────────────────────────────
if (missing.includes("uv")) {
  lines.push("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  lines.push("📦 安裝 uv（Python 快速工具鏈）");
  lines.push("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  if (!isWindows) {
    lines.push("▸ macOS / Linux：請 Bob 執行以下指令：");
    lines.push("```bash");
    lines.push("curl -LsSf https://astral.sh/uv/install.sh | sh");
    lines.push("```");
  } else {
    lines.push("▸ Windows（PowerShell）：請 Bob 執行以下指令：");
    lines.push("```powershell");
    lines.push('powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"');
    lines.push("```");
  }
  lines.push("");
}

lines.push("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
lines.push("請 Bob 在協助執行完畢並確認依賴就緒後，向使用者回報狀態。");

process.stdout.write(lines.join("\n") + "\n");
process.exit(0);
