@echo off
:: 强制UTF-8编码并启用Unicode支持
chcp 65001 > nul
setlocal enabledelayedexpansion
cls

:: 设置仓库URL
set "REPO_URL=https://github.com/HOI4-Throne-Reforge-Team/HOI4-Throne-Reforge-mod.git"
set "REPO_NAME=HOI4-Throne-Reforge-mod"
set "SELF_HEAL_MODE=0"
set "CONFLICT_MODE=0"
set "MAIN_BRANCH=main"

:: 检查参数
if "%1"=="--repair" set "SELF_HEAL_MODE=1"
if "%1"=="--resolve-conflicts" set "CONFLICT_MODE=1"

:: 检查Git安装
echo [1] 检查系统环境...
where git >nul 2>&1 || (
    echo [1] 需要安装Git | 自动打开下载页面
    start "" "https://git-scm.com/download/win"
    timeout /t 3
    exit /b 1
)

:: 检查是否在仓库内
git rev-parse --is-inside-work-tree >nul 2>&1
if %errorlevel% neq 0 (
    if %SELF_HEAL_MODE% equ 1 (
        echo [1] 错误：不在Git仓库中
        timeout /t 2
        exit /b 1
    )
    echo [1] 正在初始化仓库...
    git clone %REPO_URL% || (
        echo [1] 错误：仓库初始化失败
        timeout /t 3
        exit /b 1
    )
    cd %REPO_NAME%
)

:: 检测主分支
git show-ref --verify --quiet refs/heads/main && set "MAIN_BRANCH=main" || (
    git show-ref --verify --quiet refs/heads/master && set "MAIN_BRANCH=master"
)

:: 冲突解决模式
if %CONFLICT_MODE% equ 1 (
    echo [1] 进入冲突解决模式...
    call :resolve_conflicts
    exit /b 0
)

:: 主配置流程
call :main_configuration

if %SELF_HEAL_MODE% equ 1 (
    echo [1] 仓库修复完成
    timeout /t 2
    exit /b 0
)

:: 创建桌面快捷方式
echo [1] 创建桌面快捷方式...
(
    echo [InternetShortcut]
    echo URL=%~dp0
    echo IconIndex=0
    echo IconFile=cmd.exe
) > "%USERPROFILE%\Desktop\HOI4王座重铸开发.url" 2>nul

:: 完成提示
echo [1] 配置成功 ✓
echo [1] 位置: %CD%
echo [1] 主分支: %MAIN_BRANCH%
echo [1] 快捷方式: 桌面
timeout /t 5
start "" explorer.exe .
exit /b 0

:: ===== 主配置函数 =====
:main_configuration
echo [2] 配置仓库设置...
git config core.autocrlf false >nul
git config core.filemode false >nul
git config core.hooksPath .githooks >nul
git config pull.rebase true >nul
git config branch.autosetuprebase always >nul

:: 创建必要文件
if not exist ".gitattributes" call :create_gitattributes
if not exist ".vscode" mkdir ".vscode" >nul
if not exist ".githooks" mkdir ".githooks" >nul

:: 重置仓库状态
git rm --cached -r . >nul 2>&1
git reset --hard >nul 2>&1
git branch --set-upstream-to=origin/%MAIN_BRANCH% %MAIN_BRANCH% >nul 2>&1

:: 自检修复
call :self_heal_check
exit /b 0

:: ===== 自检修复函数 =====
:self_heal_check
set "ISSUE_FOUND=0"

git diff --ignore-cr-at-eol --quiet || (
    echo [3] 修复行尾符问题...
    git checkout -- . >nul
    git clean -fd >nul
    set "ISSUE_FOUND=1"
)

git config --get core.hooksPath | findstr ".githooks" >nul || (
    echo [3] 修复钩子配置...
    git config core.hooksPath .githooks >nul
    set "ISSUE_FOUND=1"
)

git fetch origin >nul
git diff --name-only %MAIN_BRANCH% origin/%MAIN_BRANCH% | findstr /v "" >nul && (
    echo [3] 同步分支更新...
    git pull --rebase origin %MAIN_BRANCH% >nul
    set "ISSUE_FOUND=1"
)

if %ISSUE_FOUND% equ 0 echo [3] 自检通过 ✓
exit /b 0

:: ===== 冲突解决函数 =====
:resolve_conflicts
set "CONFLICT_FOUND=0"

git diff --name-only --diff-filter=U >conflicts.tmp
if %errorlevel% equ 0 (
    set /a "CONFLICT_FOUND=1"
    echo [4] 发现冲突: %%~nxf
    
    for /f "delims=" %%f in (conflicts.tmp) do (
        git checkout --ours -- "%%f" >nul
        git add "%%f" >nul
    )
    del conflicts.tmp
    
    git diff --check >nul && (
        echo [4] 自动解决完成 ✓
    ) || (
        echo [4] 需要手动解决
    )
)

git push --dry-run 2>push_error.tmp
findstr /C:"rejected" push_error.tmp >nul && (
    set /a "CONFLICT_FOUND=1"
    echo [4] 解决推送冲突...
    
    git fetch origin >nul
    git rebase origin/%MAIN_BRANCH% >nul
    
    del push_error.tmp
    echo [4] 分支已同步 ✓
)

if %CONFLICT_FOUND% equ 0 echo [4] 无冲突 ✓
exit /b 0

:: ===== 创建gitattributes函数 =====
:create_gitattributes
> ".gitattributes" (
    echo * -text
    echo *.dds binary
    echo *.ogg binary
    echo *.tga binary
)
exit /b 0