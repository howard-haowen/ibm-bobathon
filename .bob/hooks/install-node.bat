@echo off
rem install-node.bat
rem
rem SessionStart hook — Windows 專用
rem 檢查 node 是否已安裝。
rem - 若已安裝：靜默結束（exit 0），讓後續 check-deps.mjs 繼續執行。
rem - 若未安裝：由 hook 自身直接安裝 Chocolatey + Node.js 24，安裝成功後 exit 0。
rem             安裝失敗則以 exit 2 通知 Bob。

where node >nul 2>&1
if %ERRORLEVEL% == 0 (
    rem node 已安裝，靜默通過
    exit /b 0
)

rem ── node 未安裝，由 hook 直接執行安裝 ──────────────────────────────────────
echo 🔧 Node.js 未安裝，正在自動安裝 Chocolatey + Node.js 24...

rem 1. 安裝 Chocolatey（若尚未安裝）
where choco >nul 2>&1
if not %ERRORLEVEL% == 0 (
    echo 正在安裝 Chocolatey...
    powershell -ExecutionPolicy ByPass -c "irm https://community.chocolatey.org/install.ps1 | iex"
    if %ERRORLEVEL% neq 0 (
        echo ❌ Chocolatey 安裝失敗，請檢查網路連線或執行權限。 1>&2
        exit /b 2
    )
)

rem 2. 安裝 Node.js 24
echo 正在安裝 Node.js 24...
choco install nodejs --version="24.21.0" -y
if %ERRORLEVEL% neq 0 (
    echo ❌ Node.js 安裝失敗，請確認 Chocolatey 權限是否足夠。 1>&2
    exit /b 2
)

rem 3. 重新整理環境變數（讓 node 可在當前 session 使用）
call refreshenv >nul 2>&1

rem 4. 確認安裝成功
where node >nul 2>&1
if %ERRORLEVEL% == 0 (
    for /f "tokens=*" %%v in ('node -v') do echo ✅ Node.js 安裝成功：%%v
    exit /b 0
) else (
    echo ❌ Node.js 安裝後仍無法偵測，請重新開啟終端機後再試。 1>&2
    exit /b 2
)
