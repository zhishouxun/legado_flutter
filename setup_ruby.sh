#!/bin/bash

# 解决 Ruby gem 权限问题的脚本

echo "正在检查 Homebrew Ruby..."

# 检查是否已安装 Homebrew Ruby
if command -v brew &> /dev/null; then
    # 检查 Homebrew Ruby
    if [ -f "/opt/homebrew/bin/ruby" ] || [ -f "/usr/local/bin/ruby" ]; then
        echo "✓ Homebrew Ruby 已安装"
        RUBY_PATH=$(which ruby)
        echo "当前 Ruby 路径: $RUBY_PATH"
    else
        echo "正在安装 Homebrew Ruby..."
        brew install ruby
        
        # 更新 PATH（针对 Apple Silicon Mac）
        if [ -d "/opt/homebrew" ]; then
            echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"' >> ~/.zshrc
            export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
        # 针对 Intel Mac
        elif [ -d "/usr/local" ]; then
            echo 'export PATH="/usr/local/opt/ruby/bin:$PATH"' >> ~/.zshrc
            export PATH="/usr/local/opt/ruby/bin:$PATH"
        fi
    fi
else
    echo "错误: 未找到 Homebrew，请先安装 Homebrew"
    echo "访问: https://brew.sh"
    exit 1
fi

# 安装 CocoaPods
echo ""
echo "正在安装 CocoaPods..."
gem install cocoapods

# 验证安装
if command -v pod &> /dev/null; then
    echo ""
    echo "✓ CocoaPods 安装成功！"
    pod --version
else
    echo ""
    echo "警告: CocoaPods 可能未添加到 PATH"
    echo "请运行: source ~/.zshrc"
    echo "或手动添加 gem bin 目录到 PATH"
fi

