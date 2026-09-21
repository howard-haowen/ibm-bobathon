#!/usr/bin/env node
/**
 * check-dependencies.mjs
 * SessionStart hook — checks whether git and java are installed and,
 * if not, tells the agent exactly how to install them for the user's OS.
 *
 * Output (stdout, exit 0) is injected as model context so the agent
 * can guide the user through installation at the start of each session.
 */

import { spawnSync } from "node:child_process";
import { platform } from "node:os";

// ── helpers ────────────────────────────────────────────────────────────────

function isInstalled(command) {
  const result = spawnSync(command, ["--version"], {
    stdio: "pipe",
    encoding: "utf8",
    shell: true,
  });
  return result.status === 0;
}

function detectOs() {
  const p = platform();
  if (p === "darwin") return "macos";
  if (p === "win32") return "windows";
  if (p === "linux") {
    // Try to detect distro family
    const lsb = spawnSync("lsb_release", ["-is"], {
      stdio: "pipe",
      encoding: "utf8",
      shell: true,
    });
    const distro = (lsb.stdout || "").trim().toLowerCase();
    if (distro.includes("ubuntu") || distro.includes("debian")) return "debian";
    const osRelease = spawnSync("cat", ["/etc/os-release"], {
      stdio: "pipe",
      encoding: "utf8",
    });
    const content = (osRelease.stdout || "").toLowerCase();
    if (content.includes("ubuntu") || content.includes("debian")) return "debian";
    if (content.includes("fedora") || content.includes("rhel") || content.includes("centos")) return "rhel";
    if (content.includes("arch")) return "arch";
    return "linux";
  }
  return p;
}

// ── install instructions ───────────────────────────────────────────────────

const INSTRUCTIONS = {
  git: {
    macos: `brew install git
# 若尚未安裝 Homebrew，請先執行：
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`,
    debian: `sudo apt-get update && sudo apt-get install -y git`,
    rhel: `sudo dnf install -y git   # 或 sudo yum install -y git`,
    arch: `sudo pacman -S --noconfirm git`,
    linux: `# 請使用您的發行版套件管理器安裝 git，例如：
sudo apt-get install -y git   # Debian/Ubuntu
sudo dnf install -y git       # Fedora/RHEL`,
    windows: `# 方法一（winget）：
winget install --id Git.Git -e --source winget

# 方法二：從官網下載安裝程式
# https://git-scm.com/download/win`,
  },
  java: {
    macos: `# 安裝 Temurin 21 LTS（推薦）：
brew install --cask temurin@21

# 或透過 SDKMAN（版本管理更彈性）：
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java 21-tem`,
    debian: `# 安裝 OpenJDK 21：
sudo apt-get update && sudo apt-get install -y openjdk-21-jdk

# 或透過 SDKMAN：
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java 21-tem`,
    rhel: `# 安裝 OpenJDK 21：
sudo dnf install -y java-21-openjdk-devel

# 或透過 SDKMAN：
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java 21-tem`,
    arch: `sudo pacman -S --noconfirm jdk21-openjdk`,
    linux: `# 透過 SDKMAN（跨發行版推薦方式）：
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install java 21-tem

# 或使用您的發行版套件管理器，例如：
sudo apt-get install -y openjdk-21-jdk   # Debian/Ubuntu`,
    windows: `# 方法一（winget）：
winget install EclipseAdoptium.Temurin.21.JDK

# 方法二：從 Adoptium 官網下載安裝程式
# https://adoptium.net/temurin/releases/?version=21

# 安裝後請確認 JAVA_HOME 環境變數已設定`,
  },
};

// ── main ───────────────────────────────────────────────────────────────────

let raw = "";
for await (const chunk of process.stdin) raw += chunk;
// payload is available if needed for future expansion
// const payload = JSON.parse(raw);

const os = detectOs();
const gitOk = isInstalled("git");
const javaOk = isInstalled("java");

if (gitOk && javaOk) {
  // Everything is installed — emit nothing so we don't pollute context
  process.exit(0);
}

const lines = [
  "## 🔧 開發環境檢查",
  "",
  `偵測到的作業系統：**${os}**`,
  "",
];

if (!gitOk) {
  const cmd = INSTRUCTIONS.git[os] ?? INSTRUCTIONS.git.linux;
  lines.push(
    "### ❌ Git 尚未安裝",
    "",
    "請協助使用者執行以下指令來安裝 Git：",
    "",
    "```sh",
    cmd,
    "```",
    "",
  );
}

if (!javaOk) {
  const cmd = INSTRUCTIONS.java[os] ?? INSTRUCTIONS.java.linux;
  lines.push(
    "### ❌ Java 尚未安裝",
    "",
    "請協助使用者執行以下指令來安裝 Java（Temurin 21 LTS）：",
    "",
    "```sh",
    cmd,
    "```",
    "",
  );
}

lines.push(
  "---",
  "安裝完成後，請重新開啟終端機或執行 `source ~/.zshrc`（macOS/Linux）",
  "以使環境變數生效，然後以 `git --version` 及 `java -version` 確認安裝成功。",
);

process.stdout.write(lines.join("\n") + "\n");
process.exit(0);
