# IBM Bob 工作坊 Hub

> 管理工作坊 HTML 教材、部署至 GitHub Pages 的中央 repo。純靜態 HTML + bash + Node.js，無建置系統。
>
> 線上網站：<https://howard-haowen.github.io/ibm-bobathon/>

---

## 常用指令

```bash
# 重新產生 artifacts/index.html 卡片清單
node scripts/update-index.mjs

# 指定特定工作坊目錄
node scripts/update-index.mjs --dir workshops/w01/artifacts

# 將本機 artifacts/ 同步至 main 與 workshop 孤立分支（需乾淨工作樹）
bash scripts/copy-artifacts.sh workshop/w01

# 部署：push main 且異動路徑符合 workshops/**/artifacts/** 即自動觸發
```

---

## 新增工作坊流程

**1. 確認下一個 slug**
```bash
git ls-remote --heads origin 'workshop/w*' | sed 's|.*refs/heads/workshop/||' | sort
```

**2. 建立孤立分支**
```bash
gh workflow run create-workshop-branch.yml --field slug=w03
git ls-remote --heads origin 'workshop/w03'  # 確認分支已建立
```

**3. 本機登記**：在 `docs/client-url-map.md`（gitignored）新增 slug → 客戶/URL 對應。

**4. 加入 HTML 教材**：將編號 HTML 檔案放入本機 `artifacts/`，再執行：
```bash
node scripts/update-index.mjs  # 更新 artifacts/index.html，於瀏覽器確認
```

**5. 等待確認**：向使用者展示 `artifacts/` 清單及預覽，取得明確同意後繼續。

**6. 同步並發布**
```bash
bash scripts/copy-artifacts.sh workshop/w03
```
此腳本一次完成：複製 `artifacts/` → `workshops/w03/artifacts/`（main）並 push、同步至孤立分支並 push、最後回到原來的分支。

**7. 確認部署**：Actions 完成後造訪：
```
https://howard-haowen.github.io/ibm-bobathon/workshops/w03/
```

---

## Clone 單一工作坊分支

```bash
git clone --single-branch --branch workshop/w01 \
  https://github.com/howard-haowen/ibm-bobathon.git \
  ibm-bobathon-w01
```

---

## 重要注意事項

- `artifacts/`、`docs/`、`plans/` 均已 gitignore，不進版本庫。
- `workshops/wNN/artifacts/` 提交在 `main`，是部署觸發的來源。
- `gh-pages` 分支完全由 GitHub Actions 管理，**勿手動修改**。
- 每次部署會**整體覆蓋** `gh-pages`（`keep_files: false`）。
- 工作坊分支為孤立分支，**不與 `main` 共享歷史，不應合併回 main**。

---

## 文件

| 文件 | 說明 |
|------|------|
| [`DESIGN.md`](DESIGN.md) | Carbon Design System 規範（色彩、字型、元件） |
| `docs/client-url-map.md` *(本機)* | Slug → 客戶/URL 對照表 |
