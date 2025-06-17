#!/bin/bash
# 设置 UTF-8 环境
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

echo "⚙️ HOI4王座重铸模组开发环境自动配置中..."
echo "-----------------------------------------------------"

# 设置仓库 URL
REPO_URL="https://github.com/HOI4-Throne-Reforge-Team/HOI4-Throne-Reforge-mod.git"
REPO_NAME="HOI4-Throne-Reforge-mod"
SELF_HEAL_MODE=0
CONFLICT_MODE=0
MAIN_BRANCH="main"

# 检查修复模式参数
if [ "$1" = "--repair" ]; then
    SELF_HEAL_MODE=1
    echo "🔧 进入修复模式..."
fi

if [ "$1" = "--resolve-conflicts" ]; then
    CONFLICT_MODE=1
    echo "🛠️ 进入冲突解决模式..."
fi

# 检查并安装 Git（如果未安装）
if ! command -v git &> /dev/null; then
    echo "🔍 检测到未安装Git，正在引导安装..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open "https://git-scm.com/download/mac" > /dev/null 2>&1
    else
        xdg-open "https://git-scm.com/download/linux" > /dev/null 2>&1
    fi
    echo "❗ 请先安装Git，然后重新运行此脚本"
    sleep 15
    exit 1
fi

# 检查是否在仓库内
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    if [ $SELF_HEAL_MODE -eq 1 ]; then
        echo "❌ 错误：未在Git仓库中，无法执行修复"
        sleep 3
        exit 1
    fi
    
    echo "🌐 正在克隆仓库..."
    git clone "$REPO_URL" &> /dev/null || {
        echo "❌ 克隆失败！请检查："
        echo "  1. 网络连接"
        echo "  2. 仓库URL是否正确: $REPO_URL"
        sleep 10
        exit 1
    }
    cd "$REPO_NAME" || exit
fi

# 检测主分支名称
if git show-ref --verify --quiet refs/heads/main; then
    MAIN_BRANCH="main"
elif git show-ref --verify --quiet refs/heads/master; then
    MAIN_BRANCH="master"
fi

# 冲突解决模式
if [ $CONFLICT_MODE -eq 1 ]; then
    resolve_conflicts
    exit 0
fi

# 主配置函数
main_configuration() {
    echo "🔧 配置Git核心设置..."
    git config core.autocrlf false &> /dev/null
    git config core.filemode false &> /dev/null
    git config core.hooksPath .githooks &> /dev/null
    git config pull.rebase true &> /dev/null
    git config branch.autosetuprebase always &> /dev/null

    # 配置行尾符保护
    echo "🛡️ 配置行尾符保护..."
    if [ ! -f ".gitattributes" ]; then
        create_gitattributes
    else
        grep -q "* -text" .gitattributes || echo "* -text" >> .gitattributes
    fi

    # 配置 VSCode
    echo "🖌️ 配置VSCode编辑器..."
    mkdir -p .vscode &> /dev/null
    if [ ! -f ".vscode/settings.json" ]; then
        cat > .vscode/settings.json <<EOF
{
  "files.autoGuessEncoding": true,
  "git.enableSmartCommit": true,
  "git.autofetch": true,
  "git.conflictResolution": "remote"
}
EOF
    fi

    # 配置自动钩子
    echo "🔗 配置自动钩子..."
    mkdir -p .githooks &> /dev/null
    
    # pre-push 钩子（自动同步远程分支）
    if [ ! -f ".githooks/pre-push" ]; then
        cat > .githooks/pre-push <<EOF
#!/bin/sh
# 自动同步远程更改
git fetch origin &> /dev/null
git rebase origin/$MAIN_BRANCH &> /dev/null
EOF
        chmod +x .githooks/pre-push &> /dev/null
    fi
    
    # post-checkout 钩子
    if [ ! -f ".githooks/post-checkout" ]; then
        cat > .githooks/post-checkout <<EOF
#!/bin/sh
# 自动配置 Git
git config core.autocrlf false &> /dev/null
git config core.filemode false &> /dev/null
git config core.ignorecase true &> /dev/null
git config pull.rebase true &> /dev/null
EOF
        chmod +x .githooks/post-checkout &> /dev/null
    fi

    # 重置仓库状态
    echo "♻️ 清理仓库缓存..."
    git rm --cached -r . &> /dev/null
    git reset --hard &> /dev/null

    # 设置上游分支
    echo "🔄 配置分支跟踪..."
    git branch -u origin/$MAIN_BRANCH $MAIN_BRANCH &> /dev/null || true

    # 运行自检
    echo "🔍 运行自检程序..."
    self_heal_check
}

# 自检修复函数
self_heal_check() {
    echo "⚠️ 正在检查常见问题..."
    local ISSUE_FOUND=0

    # 问题1: 行尾符被修改
    if ! git diff --ignore-cr-at-eol --quiet &> /dev/null; then
        echo "❗ 检测到文件被修改（可能是行尾符问题）"
        echo "    正在尝试修复..."
        git checkout -- . &> /dev/null
        git clean -fd &> /dev/null
        ISSUE_FOUND=1
    fi

    # 问题2: 钩子未生效
    if ! git config --get core.hooksPath | grep -q ".githooks"; then
        echo "❗ 检测到钩子路径未正确配置"
        echo "    正在修复钩子配置..."
        git config core.hooksPath .githooks &> /dev/null
        ISSUE_FOUND=1
    fi

    # 问题3: 缺少必要文件
    if [ ! -f ".gitattributes" ]; then
        echo "❗ 检测到缺少.gitattributes文件"
        echo "    正在重新创建..."
        create_gitattributes
        ISSUE_FOUND=1
    fi

    # 问题4: 分支不同步
    git fetch origin &> /dev/null
    if [ -n "$(git diff --name-only $MAIN_BRANCH origin/$MAIN_BRANCH 2>/dev/null)" ]; then
        echo "❗ 检测到本地分支与远程不同步"
        echo "    正在同步分支..."
        git pull --rebase origin $MAIN_BRANCH &> /dev/null
        ISSUE_FOUND=1
    fi

    [ $ISSUE_FOUND -eq 0 ] && echo "✅ 未检测到常见问题"
}

# 冲突解决函数
resolve_conflicts() {
    echo "🚧 正在扫描冲突文件..."
    local CONFLICT_FOUND=0

    # 检查未合并路径
    if git diff --name-only --diff-filter=U | grep -q .; then
        CONFLICT_FOUND=1
        echo "❗ 检测到未解决的冲突:"
        git diff --name-only --diff-filter=U
        
        echo ""
        echo "正在尝试自动解决标准冲突..."
        
        # 尝试自动解决常见冲突
        git diff --name-only --diff-filter=U | while read -r file; do
            echo "处理 $file..."
            git checkout --ours -- "$file" &> /dev/null
            git add "$file" &> /dev/null
        done
        
        # 检查是否解决
        if git diff --check &> /dev/null; then
            echo "✅ 冲突已自动解决"
            echo "请继续提交: git commit"
        else
            echo "⚠️ 部分冲突需要手动解决"
            echo "使用以下工具:"
            echo "  - VS Code冲突编辑器"
            echo "  - 执行: git mergetool"
            echo "冲突文件列表:"
            git diff --name-only --diff-filter=U
        fi
    else
        echo "✅ 未检测到未解决冲突"
    fi

    # 检查推送冲突
    if git push --dry-run 2>&1 | grep -q "rejected"; then
        CONFLICT_FOUND=1
        echo "❗ 检测到推送冲突:"
        git push --dry-run 2>&1 | grep "rejected"
        
        echo ""
        echo "正在尝试解决..."
        
        # 获取最新更改
        git fetch origin &> /dev/null
        
        # 尝试变基
        if git rebase "origin/$MAIN_BRANCH" &> /dev/null; then
            echo "✅ 变基成功，可以安全推送: git push"
        else
            echo "⚠️ 自动解决失败，需要手动操作"
            echo "请尝试以下步骤:"
            echo "  1. 解决冲突: git mergetool"
            echo "  2. 继续变基: git rebase --continue"
            echo "  3. 推送更改: git push"
        fi
    fi

    [ $CONFLICT_FOUND -eq 0 ] && echo "✅ 未检测到冲突问题"
}

# 创建 gitattributes 函数
create_gitattributes() {
    cat > .gitattributes <<EOF
# 行尾符保护配置
* -text
*.dds binary
*.ogg binary
*.tga binary
*.bmp binary
*.ttf binary
EOF
}

# 执行主配置
if [ $SELF_HEAL_MODE -eq 0 ] && [ $CONFLICT_MODE -eq 0 ]; then
    main_configuration
fi

if [ $SELF_HEAL_MODE -eq 1 ]; then
    main_configuration
    echo "✅ 仓库修复完成！"
    sleep 3
    exit 0
fi

# 创建桌面快捷方式
echo "📌 创建桌面快捷方式..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    cat > "$HOME/Desktop/HOI4王座重铸开发.command" <<EOF
#!/bin/bash
cd "$(pwd)"
open -a "Visual Studio Code" .
EOF
    chmod +x "$HOME/Desktop/HOI4王座重铸开发.command" &> /dev/null
else
    cat > "$HOME/Desktop/HOI4王座重铸开发.desktop" <<EOF
[Desktop Entry]
Name=HOI4王座重铸开发
Exec=code $(pwd)
Icon=code
Type=Application
Categories=Development;
Path=$(pwd)
EOF
    chmod +x "$HOME/Desktop/HOI4王座重铸开发.desktop" &> /dev/null
fi

# 完成提示
echo "-----------------------------------------------------"
echo "✅ HOI4王座重铸模组开发环境配置成功！"
echo ""
echo "已应用关键配置："
echo "  - 行尾符保护系统: 已启用"
echo "  - 分支同步保护: 已启用"
echo "  - 冲突解决工具: 已集成"
echo ""
echo "智能修复工具："
echo "  常规修复: ./init-repo.sh --repair"
echo "  冲突解决: ./init-repo.sh --resolve-conflicts"
echo ""
echo "下一步操作:"
echo "1. 打开文件夹: $(pwd)"
echo "2. 使用VS Code开始开发"
echo ""
echo "💡 提示: 双击桌面快捷方式可快速进入项目"
echo "-----------------------------------------------------"

# 打开 VSCode 和文件管理器
if command -v code &> /dev/null; then
    code . &> /dev/null &
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    open . &> /dev/null
else
    xdg-open . &> /dev/null
fi