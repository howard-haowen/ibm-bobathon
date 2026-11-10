---
name: markitdown-cli
description: Use when the user wants to convert a file (PDF, DOCX, PPTX, XLSX) to Markdown with the `markitdown` CLI, get a YouTube video transcript from a YouTube URL, or asks to install/use markitdown, "convert pdf to markdown", "docx to md", "pptx to markdown", "xlsx to markdown", or "youtube transcript".
---

# markitdown-cli

使用 `markitdown` 命令列工具，把 PDF、Word、PowerPoint、Excel 等檔案轉成 Markdown；也可以直接提供 YouTube 網址，取得該影片的逐字稿。

## Step 1 — 確認 uv 與 markitdown 已安裝

用 `execute_command` 檢查：

```bash
uv --version
markitdown --help
```

- `uv` 不存在：先安裝 uv（請依 <https://docs.astral.sh/uv/getting-started/installation/> 的官方說明，並先告知使用者）。
- `markitdown` 不存在：以 `uv tool install` 安裝（含 PDF、DOCX、PPTX、XLSX 與 YouTube 逐字稿支援）：

```bash
uv tool install 'markitdown[pdf, docx, pptx, xlsx, youtube-transcription]'
```

安裝後再執行一次 `markitdown --help` 確認可用。

## Step 2 — 轉換檔案

直接呼叫 `markitdown`（不要用 `python` 執行）。確認輸入檔路徑存在後，選擇下列其中一種方式：

```bash
# 以 shell 重新導向輸出
markitdown path-to-file.pdf > document.md

# 以 -o 指定輸出檔
markitdown path-to-file.pdf -o document.md

# 以 pipe 傳入內容
cat path-to-file.pdf | markitdown
```

- 路徑含空格時須加引號。
- 未指定輸出檔時，預設輸出到 stdout；內容很長時請務必寫入檔案（`-o`），不要直接印在終端機。
- 輸出檔名由使用者決定；未指定時，與原檔同資料夾、同檔名並使用 `.md` 副檔名，並先告知使用者。

### 取得 YouTube 逐字稿

提供 YouTube 網址即可取得逐字稿（需已安裝 `youtube-transcription` 支援）：

```bash
markitdown "https://www.youtube.com/watch?v=Lg-meK5IU8Q" -o transcript.md
```

- 網址須加引號（含 `?`、`&` 等字元）。
- 同樣建議以 `-o` 寫入檔案；輸出檔名由使用者決定，未指定時先告知使用者。
- 影片若沒有可用字幕，如實回報，不要杜撰逐字稿。

## Step 3 — 驗證結果

用 `read_file` 讀取輸出的 `.md`（可用 `range` 只看前段），確認內容非空、結構合理。若為空或亂碼（例如掃描型 PDF），如實回報，不要杜撰內容。

## 其他說明

更多選項請執行 `markitdown --help`。
