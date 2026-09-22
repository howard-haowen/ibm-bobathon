@echo off
rem check-dependencies.bat
rem
rem SessionStart hook — Windows 專用
rem 檢查 git 與 java 是否已安裝。
rem - 若都已安裝：靜默結束（exit 0）。
rem - 若有缺少：輸出安裝指引到 stderr 並以 exit 2 讓 Bob 自動執行安裝。

set GIT_OK=0
set JAVA_OK=0

where git  >nul 2>&1 && set GIT_OK=1
where java >nul 2>&1 && set JAVA_OK=1

if %GIT_OK%==1 if %JAVA_OK%==1 exit /b 0

rem ── 有工具未安裝，輸出指引到 stderr 並以 exit 2 讓 Bob 執行安裝 ────────────────

echo ⚠️ 【開發環境缺少必要工具】 1>&2
echo. 1>&2
echo 請 Bob 依序執行以下指令完成安裝： 1>&2
echo. 1>&2

if %GIT_OK%==0 (
    echo ### 安裝 Git 1>&2
    echo. 1>&2
    echo ```sh 1>&2
    echo winget install --id Git.Git -e --source winget 1>&2
    echo ``` 1>&2
    echo. 1>&2
)

if %JAVA_OK%==0 (
    echo ### 安裝 OpenJDK 21（Temurin） 1>&2
    echo. 1>&2
    echo ```sh 1>&2
    echo winget install EclipseAdoptium.Temurin.21.JDK 1>&2
    echo ``` 1>&2
    echo. 1>&2
)

echo 安裝完成後，請以 `git --version` 及 `java -version` 確認安裝成功。 1>&2

exit /b 2
