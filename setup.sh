#!/bin/bash

# Launchpad 项目设置脚本
# 这个脚本会帮助您正确配置 Launchpad 项目

echo "🚀 Launchpad 项目设置脚本"
echo "=========================="

# 检查是否在正确的目录
if [ ! -f "LaunchpadApp.swift" ]; then
    echo "❌ 错误: 请在项目根目录运行此脚本"
    exit 1
fi

echo "✅ 项目文件检查完成"

# 检查 Xcode 是否安装
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 错误: 未找到 Xcode，请先安装 Xcode"
    exit 1
fi

echo "✅ Xcode 已安装"

# 检查项目文件
echo "📁 检查项目文件..."
files=("LaunchpadApp.swift" "ContentView.swift" "AppManager.swift" "DraggableAppGrid.swift" "SettingsView.swift")
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ 缺少文件: $file"
    fi
done

echo ""
echo "🔧 项目设置说明:"
echo "1. 在 Xcode 中打开 Launchpad.xcodeproj"
echo "2. 将以下 Swift 文件添加到项目中:"
echo "   - LaunchpadApp.swift"
echo "   - ContentView.swift"
echo "   - AppManager.swift"
echo "   - DraggableAppGrid.swift"
echo "   - SettingsView.swift"
echo "3. 确保所有文件都添加到 Launchpad target"
echo "4. 编译并运行项目"

echo ""
echo "📋 添加文件的步骤:"
echo "1. 在 Xcode 中右键点击项目导航器中的 Launchpad 文件夹"
echo "2. 选择 'Add Files to Launchpad'"
echo "3. 选择上述 Swift 文件"
echo "4. 确保 'Add to target' 中选中了 'Launchpad'"
echo "5. 点击 'Add'"

echo ""
echo "🎯 功能特性:"
echo "- 应用网格显示"
echo "- 智能搜索"
echo "- 分类管理"
echo "- 拖拽重排"
echo "- 设置面板"
echo "- 现代化 UI 设计"

echo ""
echo "📖 更多信息请查看 README.md"
echo "🔗 GitHub: https://github.com/yourusername/launchpad"

echo ""
echo "✨ 设置完成！现在可以在 Xcode 中编译和运行项目了。" 