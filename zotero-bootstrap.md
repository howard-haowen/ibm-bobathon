# Zotero 工具安裝指引（給 AI Agent 的 Bootstrap 文件）

> 本文件依據官方安裝頁面撰寫：<https://stevenyuyy.com/zotero-mcp/installation.html>
> 原則：**只寫該頁面有記載的內容，不自行推測。** 頁面未說明之處，一律標示為「頁面未說明」，並交由人類確認。
> `uv` 的安裝方式取自 uv 官方文件：<https://docs.astral.sh/uv/getting-started/installation/>（來源頁面未說明 `uv` 本身如何安裝）。

本文件協助 AI Agent 在使用者的電腦（macOS 或 Windows）上安裝三項東西：

| 項目 | 說明 | 最終位置 |
| :--- | :--- | :--- |
| **Zotero MCP** | `zotero-mcp` 指令，作為 MCP Server | 設定寫入 [`.bob/mcp.json`](.bob/mcp.json) |
| **Zotero CLI** | `zotero-cli` 指令 | 由同一個套件一併安裝 |
| **Zotero Skill** | 教 Agent 使用 `zotero-cli` 的技能 | [`.bob/skills/`](.bob/skills/)（`zotero-cli/`） |

套件名稱為 PyPI 上的 `zotero-mcp-server`，安裝後同時提供 `zotero-mcp` 與 `zotero-cli` 兩個指令。

連線類型僅採用 **本機讀寫（Local, read-write）**：Agent 透過本機執行中的 Zotero 讀取與寫入資料庫，不需要 zotero.org 的 API Key。

---

## 🔁 本文件可重複執行（Idempotent）

**這份文件可以被重複叫 Agent 執行任意多次。** 每一步都遵守同一個模式：

> **先檢查 → 已完成就跳過 → 未完成才安裝 → 安裝後再驗證**

- 已經裝好的東西，**不要重裝、不要覆寫、不要重複寫入**。
- 全部都已完成時，Agent 只需做檢查、回報「全部已就緒」，然後結束。
- 遇到無法自行解決的卡點，**不要反覆重試**：停下來、說明原因、告訴人類該做什麼，人類處理完後再叫 Agent 重新執行本文件即可從中斷處繼續（因為已完成的步驟會被跳過）。

---

## 🖥️ macOS 與 Windows 通用規則（Agent 必讀）

本文件的每個步驟都分別標示了 macOS 與 Windows 的指令。執行前請先判斷作業系統，並遵守：

1. **判斷系統**：macOS 使用 Terminal（zsh/bash）；Windows 使用 **PowerShell**。**不要在 Windows 的 `cmd.exe` 執行本文件的指令**，也不要把 macOS 的指令（`command -v`、`mv`、`mkdir -p`、`rm -r`）拿到 Windows 上執行。
2. **只執行與你系統對應的那個區塊**。標示「macOS」的區塊在 Windows 不要跑，反之亦然。
3. **以「指令是否成功」判斷，不要依賴輸出文字**。本文件所有「有輸出／沒輸出」的判斷，都以指令的**結束狀態（成功或失敗）**為準，因為 macOS 與 Windows 的輸出格式不同。
4. **`zotero-mcp setup` 與 `install-skill` 的互動提示會讓 Agent 卡住**，請照步驟 1-3 的指定參數執行，不要自行省略參數。
5. **路徑一律用相對於專案根目錄的寫法**，並用 Agent 的讀檔／寫檔工具處理 `.bob/` 內的檔案（`mcp.json` 的判斷與新增），避免在 shell 指令中處理含空白的路徑。若必須在 shell 中使用含空白的路徑，請用引號包住。
6. **JSON 內的 Windows 路徑**：只有在 `.bob/mcp.json` 需要填入完整路徑（見步驟 3）時才會遇到。JSON 字串中的反斜線必須寫成 `\\`，或直接改用正斜線 `/`。

---

## ⚠️ 第一部分：人類必須先完成的事項（Agent 無法代勞）

**請使用者（人類）先確認以下事項。** Agent 開始工作前，只需詢問「尚未確認過」的項目；若人類已表示全部完成，直接進入第二部分。

### 1. 安裝並更新 Zotero 桌面版

- 本機讀取與全文：需要 **Zotero 7 或更新版本**。
- 本機寫入（本文件採用的模式）：需要 **Zotero 10 或更新版本**。
- 頁面指出：舊版本的本機 API 是唯讀的，無法使用本文件的讀寫模式。

### 2. 在 Zotero 中開啟「允許其他應用程式通訊」

Agent 無法操作 Zotero 的設定視窗，必須由人類手動完成：

1. 開啟 Zotero，進入 **Settings → Advanced**。
   - **macOS**：選單列 **Zotero → Settings**
   - **Windows**：選單列 **Edit → Settings**
2. 勾選 **Allow other applications on this computer to communicate with Zotero**。
3. **使用期間請保持 Zotero 開啟。**

### 3. 確認電腦已有 Python 3.10 以上

- 來源頁面要求 **Python 3.10 或更新版本**。

### 3-1. 同意讓 Agent 安裝 `uv`（若尚未安裝）

- 來源頁面建議以 `uv` 安裝，但**未說明如何安裝 `uv` 本身**。因此「步驟 0」的安裝方式取自 uv 官方文件。
- 官方安裝腳本會從網路下載並執行。請人類同意讓 Agent 執行（官方文件的 Tip 建議使用前可先檢視腳本內容）。
- Windows 的官方指令使用 `-ExecutionPolicy ByPass`；官方文件指出，這會允許執行來自網路的腳本。
- 若電腦已經有 `uv`，此項不適用。

### 4. 本機寫入授權（需在 Zotero 彈出視窗中點選）

若尚未授權，Agent 執行授權指令後，**Zotero 會彈出對話框，必須由人類本人點選**：

- 請選擇 **Always Allow**：金鑰會被儲存，之後不必再授權。
- 若選 **Allow**：只允許單次寫入，且**不會**儲存金鑰（下次還會需要再授權）。

請人類在 Agent 執行「步驟 2」前，先切換到 Zotero 視窗等待對話框出現。

### 5. 在 Agent 執行 Skill 安裝前的確認

Agent 會執行 `zotero-mcp install-skill`，並在 [`.bob/`](.bob/) 底下建立暫存目錄 `_zotero-staging`、最後把技能放進 [`.bob/skills/`](.bob/skills/)。Agent 會指定 `--target` 與 `--root`，**不會**寫入 `~/.claude/` 或 `AGENTS.md`。請人類同意讓 Agent 在目前專案中執行。

### 人類檢查清單

- [ ] Zotero 已安裝，版本 ≥ 10
- [ ] 已勾選 **Allow other applications on this computer to communicate with Zotero**
- [ ] Zotero 目前正開啟中
- [ ] Python ≥ 3.10 已安裝
- [ ] 若尚未安裝 `uv`，同意讓 Agent 依「步驟 0」自動安裝
- [ ] 已知道稍後要在 Zotero 彈出視窗中點選 **Always Allow**

---

## 第二部分：Agent 安裝步驟

> 所有指令請在**專案根目錄**執行。macOS 使用 Terminal，Windows 使用 PowerShell。

### 執行前：先做一次「環境總檢查」

在動手安裝前，先把下列檢查全部跑完，據此決定哪些步驟要做、哪些要跳過。

**檢查指令是否存在**（用「是否找得到」判斷，不看輸出文字）：

macOS（Terminal）：

```bash
command -v uv
command -v zotero-mcp
command -v zotero-cli
```

指令找得到會印出路徑並成功結束；找不到則沒有輸出、狀態為失敗。

Windows（PowerShell）：

```powershell
Get-Command uv -ErrorAction SilentlyContinue
Get-Command zotero-mcp -ErrorAction SilentlyContinue
Get-Command zotero-cli -ErrorAction SilentlyContinue
```

指令找得到會顯示一筆資訊；找不到則完全沒有輸出。

> **剛安裝完就找不到？** `uv` 與 `uv tool install` 安裝的指令都放在使用者目錄下的執行檔資料夾（官方文件說明該資料夾必須在 `PATH` 中）。目前這個終端機可能還沒讀到新的 `PATH`，見下方「PATH 卡關處理」。

**檢查 Python（>= 3.10）**——**必須等 `uv` 可用之後（步驟 0 完成後）才能做**

來源頁面要求 Python 3.10 以上，但 `python` 這個指令名稱在兩個系統上並不一致（macOS 通常是 `python3`；Windows 可能是 `python`、`py`，或只有 Microsoft Store 的捷徑）。**因此不要用 `python --version` 檢查**，改用 `uv`（uv 官方文件說明它會在 macOS 與 Windows 上探索系統 Python，Windows 包含 registry 與 Microsoft Store 安裝）：

```bash
uv python find ">=3.10"
```

- 成功並印出路徑 → Python 已就緒。
- 失敗（`No interpreter found`）→ uv 官方文件說明，找不到 Python 時 `uv` 預設會**自動下載**所需版本，因此通常不需要人類另外安裝。繼續步驟 1；若步驟 1-2 仍因 Python 失敗，**停止並回報人類**，不要自行安裝 Python。

**檢查專案檔案**（用讀檔工具即可，macOS 與 Windows 相同）：

- [`.bob/mcp.json`](.bob/mcp.json) 的 `mcpServers` 內是否已有 `zotero`。
- [`.bob/skills/zotero-cli/`](.bob/skills/zotero-cli/) 是否已存在。

**判斷表**：

| 檢查結果 | 動作 |
| :--- | :--- |
| `uv` 不存在 | 執行步驟 0 |
| `uv` 存在 | 跳過步驟 0 |
| `zotero-mcp` 或 `zotero-cli` 任一不存在 | 執行步驟 1 |
| `zotero-mcp` 與 `zotero-cli` 都存在 | 跳過步驟 1 |
| 步驟 2 的 `--status` 顯示本機寫入已可用 | 跳過授權 |
| `.bob/mcp.json` 已有 `zotero` 項目 | 跳過步驟 3 |
| `.bob/skills/zotero-cli/` 已存在 | 跳過步驟 4 |

**PATH 卡關處理（macOS 與 Windows 皆適用）**

剛安裝 `uv` 或 `zotero-mcp` 後，目前的終端機常常還讀不到新的 `PATH`。遇到「剛裝完卻找不到指令」時，**不要重新安裝**，依序嘗試：

1. uv 官方文件（Tool executables）說明：執行檔資料夾必須在 `PATH` 中，`uv tool update-shell` 可把它加入常見的 shell 設定檔。若 `uv` 本身可用，可執行：

   ```bash
   uv tool update-shell
   ```

   官方文件另指出安裝腳本與更新會修改 shell 設定檔，因此**設定要在新開的終端機視窗才會讀到**（官方文件未逐一說明各 shell 與 Windows 的行為，成效以重開終端機後 `uv --version` 是否成功為準）。
2. 請人類**關閉並重新開啟終端機（或重新啟動 Bob）**，再叫 Agent 重新執行本文件。
3. 若仍然找不到，執行下列指令取得執行檔資料夾位置，並請人類確認該資料夾是否在 `PATH` 中：

   ```bash
   uv tool dir --bin
   ```

   如果 `uv` 也找不到，才表示 `uv` 本身尚未安裝成功，回到步驟 0。

---

### 步驟 0：確認 `uv`，未安裝才安裝

**0-1. 檢查**（macOS 與 Windows 相同）：

```bash
uv --version
```

- 有顯示版本 → **已安裝，跳到步驟 1。**
- 找不到指令 → 依作業系統執行 0-2。

**0-2. 依系統安裝**（以下為 uv 官方文件的 standalone installer）

**macOS**（Terminal）：

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

官方文件指出：若系統沒有 `curl`，可改用 `wget`：

```bash
wget -qO- https://astral.sh/uv/install.sh | sh
```

**Windows**（PowerShell）：

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

**0-3. 驗證**

```bash
uv --version
```

- 有顯示版本 → 成功，進入步驟 1。
- 仍找不到 `uv` → 官方文件說明安裝腳本可能會修改 shell 設定檔，因此建議在**新的終端機視窗**驗證。Agent 目前的終端機可能尚未讀到新的設定。**不要重複執行安裝腳本，也不要自行修改 PATH**；請告訴人類：「請關閉並重新開啟終端機（或重新啟動 Bob），然後再叫我重新執行 `zotero-bootstrap.md`」。官方文件未提供進一步排解方式。

**其他安裝方式**（官方文件所列，僅在標準腳本無法使用、且人類同意時採用）：

| 系統 | 方式 | 指令 |
| :--- | :--- | :--- |
| macOS | Homebrew | `brew install uv` |
| Windows | WinGet | `winget install --id=astral-sh.uv -e` |
| Windows | Scoop | `scoop install main/uv` |

---

### 步驟 1：確認 Zotero MCP 與 Zotero CLI，未安裝才安裝

**1-1. 檢查**：使用「環境總檢查」中 `zotero-mcp`、`zotero-cli` 的結果。

- 兩者**都存在** → **已安裝，跳過 1-2 與 1-3**，直接執行 1-4 取得版本。
- 任一不存在 → 執行 1-2。

**1-2. 安裝**

```bash
uv tool install zotero-mcp-server
```

這一個指令會同時安裝 `zotero-mcp` 與 `zotero-cli`。基本安裝已包含搜尋、中繼資料、註解與寫入工具，不含機器學習相依套件。

**（選用）額外功能**：基本安裝即足夠本文件的目的，**除非人類明確要求，否則不要安裝 extras**。若人類需要，改用：

| Extra | 增加的功能 |
| :--- | :--- |
| `semantic` | 語意搜尋（ChromaDB、sentence-transformers、OpenAI 與 Gemini embeddings） |
| `pdf` | PDF 大綱、頁面版面與頁面圖片（PyMuPDF）、EPUB 註解支援 |
| `scite` | Scite 引用次數與撤稿警示，不需帳號 |
| `all` | 以上全部 |

```bash
uv tool install "zotero-mcp-server[all]"
```

**1-3. 執行頁面所列的設定指令（僅限本次剛完成安裝時執行一次）**

來源頁面的安裝流程是 `uv tool install zotero-mcp-server` 之後接著執行 `zotero-mcp setup`。**但直接執行 `zotero-mcp setup` 會出現互動式提問（「Would you like to configure semantic search? (y/n)」），Agent 無法輸入，會因此崩潰或卡住。** 請改用 `zotero-mcp setup --help` 列出的下列旗標，讓指令不需要互動：

```bash
zotero-mcp setup --skip-semantic-search
```

- `--skip-semantic-search`：略過語意搜尋設定（本文件不安裝 `semantic` extra，不需要此項）。
- macOS 與 Windows 的指令相同。
- 只在 1-2 剛安裝完成的那一次執行。若 1-1 判定為「已安裝」，**不要再執行**。
- 依頁面說明，`zotero-mcp setup` 會尋找電腦上所有的 `claude_desktop_config.json` 並寫入。這是 Claude Desktop 的設定，**與 Bob 無關**；Bob 的設定請依步驟 3 寫入 [`.bob/mcp.json`](.bob/mcp.json)。若人類不使用 Claude Desktop，可改用 `zotero-mcp setup --no-claude --skip-semantic-search`（`--no-claude`：略過 Claude Desktop 設定，改寫獨立設定檔）。
- 若指令仍停在提問等待輸入，**不要硬等**：中止它，並回報人類。

**1-4. 驗證**

```bash
zotero-mcp version
```

- 成功並顯示版本 → 完成。
- 找不到 `zotero-mcp` → 依上方「PATH 卡關處理」，**不要重複安裝**。

> `zotero-cli` 的驗證請用 `zotero-cli -h`（成功即可）。**不要用 `zotero-cli --version`**，該指令不支援此選項，會回報錯誤。
>
> `uv tool install` 遇到同名執行檔不是由 uv 安裝的（例如以前用 `pipx` 裝過 `zotero-mcp`）時會失敗（來源：uv 官方文件，Overwriting executables）。若發生，**不要加 `--force`**，請回報人類，由人類決定要移除舊安裝或改用 `--force`。
>
> 套件版本以 `uv tool install` 當下的最新版為準，各版本的輸出文字可能略有不同；判斷成功與否請以指令結束狀態為準。

---

### 步驟 2：確認本機寫入授權，未授權才授權（需人類在 Zotero 點選）

> 前置條件：Zotero 必須正在執行。若不確定，先請人類確認 Zotero 已開啟。

**2-1. 檢查目前的寫入狀態**

```bash
zotero-mcp authorize-local --status
```

> 來源頁面只說明此指令用來查看「現在哪種方式可以寫入」，**沒有說明輸出格式**。以下判斷依據是在實際環境執行 `zotero-mcp v0.13.0` 觀察到的欄位；不同版本的輸出文字可能不同，因此若欄位對不上，一律當作「未授權」處理。

已授權時，輸出會同時包含：

- `Write mode:` 一行，內容含 `local`（例如 `local — local API (writes go straight to the running Zotero)`）
- `Zotero supports local writes: yes`
- `Local API key:         held`

判斷：

- 三項都符合 → **已授權，跳過 2-2。**
- 任一項不符、欄位對不上，或指令失敗 → 執行 2-2。若失敗原因是連不上 Zotero，請人類先開啟 Zotero 並確認第一部分的第 2 項已勾選。

**2-2. 授權**

提醒人類切換到 Zotero，然後執行：

```bash
zotero-mcp authorize-local
```

人類須在 Zotero 彈出的對話框選擇 **Always Allow**。金鑰會存到 `~/.config/zotero-mcp/config.json`（頁面指出僅限本人可讀）。

**2-3. 驗證**

```bash
zotero-mcp authorize-local --status
```

- 若人類選的是 **Allow**（單次）而非 **Always Allow**，金鑰不會被儲存，下次重跑本文件時會再次進入 2-2。請提醒人類改選 **Always Allow**。
- 若人類未在時限內點選對話框，**不要連續重試**；請人類準備好後再叫 Agent 重新執行本文件。

其他可用選項（頁面所列，**僅在人類明確要求時使用**）：

| 指令 | 用途 |
| :--- | :--- |
| `zotero-mcp authorize-local --revoke` | 忘記已儲存的金鑰 |
| `zotero-mcp authorize-local --print` | 印出金鑰，供 `ZOTERO_LOCAL_API_KEY` 使用 |

另外，頁面也指出：在 AI 應用程式內，`zotero_authorize_local_writes` 工具會開啟同樣的對話框，`zotero_write_capabilities` 會顯示目前寫入可走的途徑。

---

### 步驟 3：確認 `.bob/mcp.json` 有 Zotero 設定，沒有才新增

**3-1. 檢查**：讀取 [`.bob/mcp.json`](.bob/mcp.json)，看 `mcpServers` 內是否已有 `zotero`。

| 狀況 | 動作 |
| :--- | :--- |
| 已有 `zotero`，且 `command` 為 `zotero-mcp`（或完整路徑）、`env.ZOTERO_LOCAL` 為 `"true"` | **已完成，跳過。不要修改、不要重複新增。** |
| 已有 `zotero`，但內容與預期不同 | **不要覆寫。** 向人類回報差異，由人類決定是否修改 |
| 沒有 `zotero` | 執行 3-2 |
| `.bob/mcp.json` 不存在 | 建立檔案，內容為 3-2 的完整 JSON |

**3-2. 新增**

在 `mcpServers` 內加入 `zotero`：

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

規則：

- 使用 Agent 的**讀檔／編輯工具**修改，不要用 shell 指令拼接 JSON（避免 macOS 與 Windows 在引號與跳脫字元上的差異）。
- 只在 `mcpServers` 內新增這一項，**保留其他既有伺服器**（如 `netnewswire`、`rss-reader`、`bob-marketplace`），不要覆寫整個檔案。**這個檔案可能同時被 Bob 自己更新**（例如 `bob-marketplace` 的連線埠會變），所以寫入前請重新讀取最新內容。
- 此設定即 `ZOTERO_LOCAL=true`；本機寫入的授權金鑰已在步驟 2 儲存，不需在此另外填寫。
- 寫入後確認 JSON 格式正確（沒有多餘逗號、括號對稱）。

**如果找不到 `zotero-mcp` 指令**：頁面指出，可改用完整路徑作為 `command`，執行下列指令可印出完整路徑（`Command:` 那一行）：

```bash
zotero-mcp setup-info
```

在 macOS 上，`Command:` 會是 `zotero-mcp` 的完整路徑（例如在 `~/.local/bin/` 底下）。Windows 的路徑含反斜線，**填入 JSON 時必須把每個 `\` 寫成 `\\`，或改用正斜線 `/`**。格式示意（`<...>` 為佔位符）：

```json
"command": "C:\\<實際路徑>\\zotero-mcp.exe"
```

**請以 `zotero-mcp setup-info` 實際印出的路徑為準，不要照抄示意。** 路徑含空白時，整個路徑仍放在同一個 JSON 字串中，不需要額外加引號。

> 先嘗試維持 `"command": "zotero-mcp"`。只有在 Bob 實際連不上、且確認是 `PATH` 造成時，才改用完整路徑。

**重新載入**：頁面未說明 Bob 如何重新載入 MCP 設定。請人類確認 Bob 的 MCP 清單中 `zotero` 伺服器已連線；若沒有，請人類依 Bob 的介面操作重新整理。

---

### 步驟 4：確認 `.bob/skills/zotero-cli/`，不存在才安裝

**4-1. 檢查**：[`.bob/skills/zotero-cli/`](.bob/skills/zotero-cli/) 是否已存在。

- 已存在 → **已完成，跳過整個步驟 4。不要再執行 `install-skill`，也不要覆寫。**
- 不存在 → 繼續 4-2。

**4-2. 為什麼不直接執行 `zotero-mcp install-skill`**

頁面說明：`install-skill` 會偵測專案內已設定的 Agent 工具，並**對每一個偵測到的目標都安裝**。**頁面的偵測清單中沒有 IBM Bob。** 先查看偵測結果：

```bash
zotero-mcp install-skill --list-targets
```

在實際執行環境中，此指令曾偵測到 `claude-user`（會寫入使用者家目錄的 `~/.claude/`）與 `agents`（會修改專案的 `AGENTS.md`）。若直接執行 `zotero-mcp install-skill`，這些**與 `.bob/skills/` 無關的檔案也會被寫入**，且 macOS 與 Windows 偵測到的目標可能不同。

- 若清單中**有明確針對 IBM Bob 的目標** → 改用 `zotero-mcp install-skill --target <該目標>`，確認結果位於 [`.bob/skills/`](.bob/skills/)，然後跳到 4-5。
- 若**沒有** → 依 4-3 安裝：先把技能安裝到**暫存目錄**，再移到 `.bob/skills/`。這是 `zotero-mcp install-skill --help` 所列的 `--target` 與 `--root` 選項（`--root`：把指定目錄視為專案根目錄），可確保只產生技能目錄，不會動到 `~/.claude/` 或 `AGENTS.md`。

**4-3. 安裝到暫存目錄，再移到 `.bob/skills/`**

暫存目錄固定為 `.bob/_zotero-staging`。開始前先檢查它是否已存在：

| 狀況 | 動作 |
| :--- | :--- |
| `.bob/_zotero-staging` 已存在 | 可能是先前執行中斷留下的。這是本文件自己建立的暫存目錄，**可以直接刪除後重來**（見下方指令） |
| 不存在 | 直接進行 |

macOS（Terminal）：

```bash
rm -rf .bob/_zotero-staging
zotero-mcp install-skill --target claude --root .bob/_zotero-staging
mkdir -p .bob/skills
mv .bob/_zotero-staging/.claude/skills/zotero-cli .bob/skills/zotero-cli
rm -r .bob/_zotero-staging
```

Windows（PowerShell）：

```powershell
if (Test-Path .bob\_zotero-staging) { Remove-Item -Recurse -Force .bob\_zotero-staging }
zotero-mcp install-skill --target claude --root .bob\_zotero-staging
New-Item -ItemType Directory -Force .bob\skills | Out-Null
Move-Item .bob\_zotero-staging\.claude\skills\zotero-cli .bob\skills\zotero-cli
Remove-Item -Recurse -Force .bob\_zotero-staging
```

說明：

- `--target claude` 是頁面所列、會安裝出「技能目錄」的目標（`.claude/skills/zotero-cli/`）；其他目標（Cursor、Windsurf、`AGENTS.md`、`GEMINI.md`）為規則檔或指標區塊，不是技能目錄。
- 安裝後技能目錄內容為 `SKILL.md` 與 `reference.md`。
- 這樣就符合「安裝後移動到 `.bob/skills/`」的目標，而且**重跑本文件也不會出問題**：步驟 4-1 已存在就跳過；中途中斷留下的暫存目錄，下次會被清掉重做。
- 若 `install-skill` 失敗，或暫存目錄內沒有 `.claude/skills/zotero-cli/` → **頁面未說明後續做法，請停止並回報人類**，不要自行推測其他方式，也不要反覆重跑。

**4-4. 驗證**

macOS：

```bash
test -d .bob/skills/zotero-cli && echo OK
```

Windows（PowerShell）：

```powershell
Test-Path .bob\skills\zotero-cli
```

應為存在（macOS 印出 `OK`；Windows 回傳 `True`）。

**4-5. 清理與檢視**

- 暫存目錄 `.bob/_zotero-staging` 在 4-3 已移除；請確認它不再存在。
- 頁面指出：不使用 `--force` 時不會覆寫使用者的修改。**因此請不要加 `--force`。**（`--force` 的說明：覆寫既有檔案，且不保留備份。）
- 請人類檢視 [`.bob/skills/zotero-cli/`](.bob/skills/zotero-cli/) 的內容。

---

### 步驟 5：回報結果

不論本次實際做了多少事，最後都用下表回報每一項是「本次新裝」、「原本已就緒（跳過）」，或「需要人類處理」：

| 項目 | 狀態（本次新裝 / 已就緒跳過 / 需人類處理） | 備註 |
| :--- | :--- | :--- |
| `uv` | | |
| `zotero-mcp` 與 `zotero-cli` | | |
| 本機寫入授權 | | |
| `.bob/mcp.json` 的 `zotero` | | |
| `.bob/skills/zotero-cli/` | | |
| Bob 中 `zotero` MCP 已連線 | 由人類確認 | |

---

## 第三部分：完成後驗證

| 檢查項目 | 指令 / 方式 | 預期結果 |
| :--- | :--- | :--- |
| `uv` 已安裝 | `uv --version` | 成功並顯示版本 |
| `zotero-mcp` 已安裝 | `zotero-mcp version` | 成功並顯示版本 |
| `zotero-cli` 已安裝 | `zotero-cli -h` | 成功並顯示說明（不要用 `--version`，不支援） |
| 本機寫入授權 | `zotero-mcp authorize-local --status` | 含 `Zotero supports local writes: yes` 與 `Local API key:         held` |
| MCP 設定 | 用讀檔工具檢視 [`.bob/mcp.json`](.bob/mcp.json) | 含 `zotero`，`ZOTERO_LOCAL` 為 `"true"` |
| Skill 位置 | macOS：`test -d .bob/skills/zotero-cli && echo OK`；Windows：`Test-Path .bob\skills\zotero-cli` | macOS 印出 `OK`；Windows 回傳 `True` |
| 暫存目錄已清除 | macOS：`test ! -e .bob/_zotero-staging && echo OK`；Windows：`-not (Test-Path .bob\_zotero-staging)` | macOS 印出 `OK`；Windows 回傳 `True` |
| MCP 連線 | 人類在 Bob 查看 MCP 清單 | `zotero` 已連線 |

---

## 第四部分：疑難排解

以下 3 項出自來源頁面：

| 症狀 | 處理方式 |
| :--- | :--- |
| 找不到結果，或無法連到文獻庫 | 確認 Zotero 正在執行，且已勾選 **Allow other applications on this computer to communicate with Zotero** |
| 本機模式寫入失敗 | Zotero 10 以上：執行 `zotero-mcp authorize-local`；以 `zotero-mcp authorize-local --status` 查看寫入途徑。舊版本的本機 API 為唯讀 |
| 找不到 `zotero-mcp` 指令 | 執行 `zotero-mcp setup-info` 取得完整路徑，填入 `.bob/mcp.json` 的 `command` |

仍無法解決，來源頁面提供：[Discussions](https://github.com/54yyyu/zotero-mcp/discussions)、[Discord](https://discord.gg/BvgjbcBUqg)、[GitHub Issues](https://github.com/54yyyu/zotero-mcp/issues)。

## 更新

**僅在人類明確要求更新時執行**（一般重跑本文件不需要更新）。頁面說明更新程式會偵測安裝方式並保留設定：

```bash
zotero-mcp update --check-only
zotero-mcp update
zotero-mcp version
```

---

## Agent 行為守則

1. 先完成「第一部分」的人類確認，再開始任何安裝。
2. **每一步先檢查、已完成就跳過、未完成才動手**；全部就緒時只回報，不做任何變更。
3. 只執行本文件列出的指令；頁面未說明之處，停下來詢問人類，**不要推測**。
4. 同一個指令失敗後**不要反覆重試**；說明原因與人類該做的事，等人類處理後重新執行本文件。
5. 修改 [`.bob/mcp.json`](.bob/mcp.json) 時只新增 `zotero` 項目，保留其他設定；已存在的項目不覆寫。
6. 遇到需要人類操作 Zotero 介面（勾選設定、點選 Always Allow）的步驟，明確提示後等待確認。
