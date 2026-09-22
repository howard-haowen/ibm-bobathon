/**
 * check-deps.mjs
 *
 * SessionStart hook — 在每次 Bob 任務啟動時自動執行。
 * 前置條件：install-node.sh / install-node.bat 已確保 node 存在。
 * 本腳本檢查 git 與 uv 是否已安裝，若缺少則由 hook 自身直接執行安裝。
 * 安裝成功後 exit 0，安裝失敗才通知 Bob。
 */

import { execSync, spawnSync } from "node:child_process";

// 讀取 hook payload（不需要內容，但需要消費 stdin 避免 pipe 報錯）
let raw = "";
for await (const chunk of process.stdin) raw += chunk;

/** 目前作業系統：'win32' | 'darwin' | 'linux' */
const OS = process.platform;
const isWindows = OS === "win32";

/**
 * 檢查指令是否可以在 PATH 中找到。
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

/**
 * 執行安裝指令，輸出過程到 stdout，回傳是否成功。
 * @param {string} cmd
 * @param {string[]} args
 * @returns {boolean}
 */
function runInstall(cmd, args) {
  const result = spawnSync(cmd, args, { stdio: "inherit", shell: true });
  return result.status === 0;
}

const failed = [];

// ── 安裝 git ─────────────────────────────────────────────────────────────────
if (!isInstalled("git")) {
  console.log("🔧 git 未安裝，正在自動安裝...");
  let ok = false;
  if (isWindows) {
    ok = runInstall("winget", ["install", "--id", "Git.Git", "-e", "--source", "winget"]);
  } else if (OS === "darwin") {
    ok = runInstall("xcode-select", ["--install"]);
    // xcode-select --install 在已安裝時也會 exit non-zero，需再次確認
    if (!ok) ok = isInstalled("git");
  } else {
    // Linux：嘗試 apt-get，其次 yum
    ok = runInstall("bash", ["-c", "apt-get install -y git || yum install -y git"]);
  }

  if (isInstalled("git")) {
    console.log("✅ git 安裝成功");
  } else {
    console.error("❌ git 安裝失敗");
    failed.push("git");
  }
}

// ── 安裝 uv ───────────────────────────────────────────────────────────────────
if (!isInstalled("uv")) {
  console.log("🔧 uv 未安裝，正在自動安裝...");
  let ok = false;
  if (isWindows) {
    ok = runInstall("powershell", [
      "-ExecutionPolicy", "ByPass",
      "-c", "irm https://astral.sh/uv/install.ps1 | iex",
    ]);
  } else {
    ok = runInstall("bash", ["-c", "curl -LsSf https://astral.sh/uv/install.sh | sh"]);
    // 安裝後更新 PATH，使當前 shell 能找到 uv
    process.env.PATH = `${process.env.HOME}/.local/bin:${process.env.HOME}/.cargo/bin:${process.env.PATH}`;
  }

  if (isInstalled("uv")) {
    console.log("✅ uv 安裝成功");
  } else {
    console.error("❌ uv 安裝失敗");
    failed.push("uv");
  }
}

// ── 結果 ───────────────────────────────────────────────────────────────────────
if (failed.length === 0) {
  // 所有工具都就緒，靜默通過
  process.exit(0);
}

// 有安裝失敗的工具，通知 Bob
console.error(
  `⚠️ 以下工具自動安裝失敗：${failed.join("、")}。` +
  `請確認網路連線與執行權限，或手動安裝後重新開啟 Bob。`
);
process.exit(2);
