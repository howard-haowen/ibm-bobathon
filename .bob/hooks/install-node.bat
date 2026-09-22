@echo off
rem install-node.bat
rem
rem SessionStart hook — Windows 專用
rem 檢查 node 是否已安裝。
rem - 若已安裝：靜默結束（exit 0），讓後續 check-deps.mjs 繼續執行。
rem - 若未安裝：輸出給 Bob 的安裝 instruction 並以 exit 2 阻止任務繼續。

where node >nul 2>&1
if %ERRORLEVEL% == 0 (
    rem node 已安裝，靜默通過
    exit /b 0
)

rem ── node 未安裝，輸出 instructions 給 Bob 並以 exit 2 阻止任務繼續 ──────────────────────────
echo ⚠️ 【必要工具未安裝：Node.js】 1>&2
echo. 1>&2
echo 環境中尚未安裝 Node.js。請 Bob 直接執行以下指令安裝 Chocolatey 及 Node.js 24： 1>&2
echo. 1>&2
echo ```powershell 1>&2
echo ## windows 1>&2
echo # Download and install Chocolatey: 1>&2
echo powershell -c "irm https://community.chocolatey.org/install.ps1|iex" 1>&2
echo. 1>&2
echo # Download and install Node.js: 1>&2
echo choco install nodejs --version="24.21.0" 1>&2
echo. 1>&2
echo # Verify the Node.js version: 1>&2
echo node -v # Should print "v24.21.0". 1>&2
echo. 1>&2
echo # Verify npm version: 1>&2
echo npm -v # Should print "11.19.0". 1>&2
echo ``` 1>&2
echo. 1>&2
echo 請在執行完成並確認 node 與 npm 就緒後告知使用者。 1>&2

exit /b 2
