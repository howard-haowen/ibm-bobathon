# IBM Bob 黑客松研究助理工作區

這個 repo 是 IBM Bob AI 驅動的**期末報告研究助理**工作區，用於蒐集、整理 AI Agent 相關資料並產出 HTML 簡報。專為黑客松一日衝刺情境設計，支援多人分工協作。

## 專案結構

```
├── AGENTS.md              # Bob AI agent 指令設定（角色、工作流程、限制）
├── DESIGN.md              # HTML 輸出的視覺設計規範（色彩、字型、元件）
├── hackathon-team-plan.md # 黑客松團隊分工計劃與 Git 操作指南
├── artifacts/             # 產出的 HTML 簡報檔案
│   ├── index.html
│   ├── agentic-ai-key-concepts.html
│   └── hackathon-team-plan.html
├── youtube-k5jYwyhDMxA.md # YouTube 影片逐字稿與摘要
└── book-深入理解AIAgent.md # Apple Books 書籍摘要
```

## 工作流程

### 1. YouTube 逐字稿摘要
提供 YouTube 連結 → Bob 抓取逐字稿 → 產出繁體中文條列摘要 → 存為 `youtube-<video-id>.md`

### 2. Apple Books 書籍摘要
提供書名關鍵字 → Bob 搜尋本機 Apple Books → 讀取內容 → 產出核心論點與章節重點摘要

### 3. HTML 簡報產生
整合上述摘要資料 → Bob 依 `DESIGN.md` 規範產出單頁 HTML 簡報 → 儲存至 `artifacts/`

簡報結構：封面 → 資料來源概覽 → 各來源重點摘要 → 綜合結論與建議

## 現有研究資料

| 類型 | 主題 | 檔案 |
|------|------|------|
| YouTube 影片 | 5 Terms You Need to Know About Agentic AI | [`youtube-k5jYwyhDMxA.md`](youtube-k5jYwyhDMxA.md) |
| 書籍 | 深入理解 AI Agent：設計原理與工程實踐 | [`book-深入理解AIAgent.md`](book-深入理解AIAgent.md) |

## 相關文件

- [`AGENTS.md`](AGENTS.md) — Bob AI agent 的角色定義與工作流程指令
- [`DESIGN.md`](DESIGN.md) — HTML 輸出的完整視覺設計系統規範
- [`hackathon-team-plan.md`](hackathon-team-plan.md) — 黑客松 6 人分工計劃、BobCoins 使用策略、Git 操作教學
