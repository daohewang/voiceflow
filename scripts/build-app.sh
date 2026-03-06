#!/bin/bash

# ========================================
# VoiceFlow App Builder
# ========================================
# 用法: ./scripts/build-app.sh [--dmg]
# --dmg: 同时创建 DMG 安装包

set -e

# ----------------------------------------
# 配置
# ----------------------------------------

APP_NAME="VoiceFlow"
BUNDLE_ID="com.voiceflow.mac"
VERSION="1.0.0"
BUILD_DIR=".build"
RELEASE_DIR="release"
APP_BUNDLE="${APP_NAME}.app"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ----------------------------------------
# 打印函数
# ----------------------------------------

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ----------------------------------------
# 检查环境
# ----------------------------------------

check_environment() {
    log_info "检查构建环境..."

    if ! command -v swift &> /dev/null; then
        log_error "Swift 未安装，请先安装 Xcode"
        exit 1
    fi

    SWIFT_VERSION=$(swift --version | head -1)
    log_info "Swift 版本: $SWIFT_VERSION"
}

# ----------------------------------------
# 构建 Release 版本
# ----------------------------------------

build_release() {
    log_info "构建 Release 版本..."

    swift build -c release

    log_success "构建完成"
}

# ----------------------------------------
# 创建 App Bundle 结构
# ----------------------------------------

create_app_bundle() {
    log_info "创建 App Bundle 结构..."

    # 清理旧的发布目录
    rm -rf "${RELEASE_DIR}"
    mkdir -p "${RELEASE_DIR}"

    # 创建 App Bundle 目录结构
    mkdir -p "${RELEASE_DIR}/${APP_BUNDLE}/Contents/MacOS"
    mkdir -p "${RELEASE_DIR}/${APP_BUNDLE}/Contents/Resources"

    log_success "目录结构创建完成"
}

# ----------------------------------------
# 复制可执行文件
# ----------------------------------------

copy_executable() {
    log_info "复制可执行文件..."

    EXECUTABLE_PATH="${BUILD_DIR}/apple/Products/Release/${APP_NAME}"

    if [ ! -f "${EXECUTABLE_PATH}" ]; then
        # 尝试另一种路径
        EXECUTABLE_PATH="${BUILD_DIR}/x86_64-apple-macosx/release/${APP_NAME}"
    fi

    if [ ! -f "${EXECUTABLE_PATH}" ]; then
        # 尝试 arm64 路径
        EXECUTABLE_PATH="${BUILD_DIR}/arm64-apple-macosx/release/${APP_NAME}"
    fi

    if [ ! -f "${EXECUTABLE_PATH}" ]; then
        log_error "找不到可执行文件: ${EXECUTABLE_PATH}"
        log_info "正在查找可执行文件..."
        find "${BUILD_DIR}" -name "${APP_NAME}" -type f 2>/dev/null || true
        exit 1
    fi

    cp "${EXECUTABLE_PATH}" "${RELEASE_DIR}/${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
    chmod +x "${RELEASE_DIR}/${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

    log_success "可执行文件复制完成"
}

# ----------------------------------------
# 复制 Info.plist
# ----------------------------------------

copy_info_plist() {
    log_info "复制 Info.plist..."

    cp "Resources/Info.plist" "${RELEASE_DIR}/${APP_BUNDLE}/Contents/Info.plist"

    log_success "Info.plist 复制完成"
}

# ----------------------------------------
# 生成 App Icon
# ----------------------------------------

generate_app_icon() {
    log_info "生成应用图标..."

    ICON_DIR="${RELEASE_DIR}/${APP_BUNDLE}/Contents/Resources/AppIcon.iconset"
    mkdir -p "${ICON_DIR}"

    # 使用 SF Symbols 生成图标 (需要 macOS 12+)
    # 创建一个简单的图标生成脚本
    if command -v sips &> /dev/null; then
        # 创建临时 PNG 图标
        TEMP_ICON="/tmp/voiceflow_icon.png"

        # 使用 Swift 生成图标
        cat > /tmp/generate_icon.swift << 'SWIFT_EOF'
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// 创建一个简单的渐变图标
let size = CGSize(width: 1024, height: 1024)
let colorSpace = CGColorSpaceCreateDeviceRGB()
let context = CGContext(
    data: nil,
    width: Int(size.width),
    height: Int(size.height),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
)!

// 绘制圆角矩形背景
let rect = CGRect(origin: .zero, size: size)
let path = CGPath(
    roundedRect: rect,
    cornerWidth: 200,
    cornerHeight: 200,
    transform: nil
)

// 创建渐变
let colors = [
    CGColor(red: 0.925, green: 0.278, blue: 0.6, alpha: 1.0),  // #ec4899
    CGColor(red: 0.545, green: 0.361, blue: 0.965, alpha: 1.0) // #8b5cf6
]
let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 1])!

context.addPath(path)
context.clip()

context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: size.width, y: size.height),
    options: []
)

// 保存为 PNG
let url = URL(fileURLWithPath: "/tmp/voiceflow_icon_base.png")
guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    exit(1)
}
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
CGImageDestinationFinalize(destination)
SWIFT_EOF

        swift /tmp/generate_icon.swift 2>/dev/null || true

        # 生成各种尺寸的图标
        if [ -f "/tmp/voiceflow_icon_base.png" ]; then
            for size in 16 32 64 128 256 512 1024; do
                sips -z $size $size "/tmp/voiceflow_icon_base.png" --out "${ICON_DIR}/icon_${size}x${size}.png" 2>/dev/null || true
            done

            # 创建 icns
            iconutil -c icns "${ICON_DIR}" -o "${RELEASE_DIR}/${APP_BUNDLE}/Contents/Resources/AppIcon.icns" 2>/dev/null || {
                log_warn "无法创建 icns 文件，将使用默认图标"
            }
        else
            log_warn "无法生成图标，将使用默认图标"
        fi
    else
        log_warn "sips 不可用，跳过图标生成"
    fi

    # 清理
    rm -rf "${ICON_DIR}" 2>/dev/null || true

    log_success "图标处理完成"
}

# ----------------------------------------
# 签名应用 (可选)
# ----------------------------------------

sign_app() {
    log_info "签名应用..."

    # 使用 ad-hoc 签名 (无需开发者账户)
    codesign --force --deep --sign - "${RELEASE_DIR}/${APP_BUNDLE}" 2>/dev/null || {
        log_warn "签名失败，应用可能需要手动授权"
    }

    log_success "应用签名完成"
}

# ----------------------------------------
# 创建 DMG 安装包
# ----------------------------------------

create_dmg() {
    log_info "创建 DMG 安装包..."

    DMG_NAME="${APP_NAME}-${VERSION}.dmg"
    DMG_PATH="${RELEASE_DIR}/${DMG_NAME}"

    # 创建临时目录
    DMG_TEMP="${RELEASE_DIR}/dmg_temp"
    rm -rf "${DMG_TEMP}"
    mkdir -p "${DMG_TEMP}"

    # 复制应用到临时目录
    cp -R "${RELEASE_DIR}/${APP_BUNDLE}" "${DMG_TEMP}/"

    # 创建 Applications 快捷方式
    ln -s /Applications "${DMG_TEMP}/Applications"

    # 创建 DMG
    hdiutil create -volname "${APP_NAME}" \
        -srcfolder "${DMG_TEMP}" \
        -ov -format UDZO \
        "${DMG_PATH}"

    # 清理临时目录
    rm -rf "${DMG_TEMP}"

    log_success "DMG 创建完成: ${DMG_PATH}"
}

# ----------------------------------------
# 验证应用
# ----------------------------------------

verify_app() {
    log_info "验证应用..."

    APP_PATH="${RELEASE_DIR}/${APP_BUNDLE}"

    if [ -d "${APP_PATH}" ]; then
        log_success "App Bundle 创建成功"
        log_info "路径: ${APP_PATH}"
        log_info "大小: $(du -sh "${APP_PATH}" | cut -f1)"
    else
        log_error "App Bundle 创建失败"
        exit 1
    fi
}

# ----------------------------------------
# 打印完成信息
# ----------------------------------------

print_completion() {
    echo ""
    echo "========================================"
    log_success "构建完成！"
    echo "========================================"
    echo ""
    echo "应用位置: ${RELEASE_DIR}/${APP_BUNDLE}"
    if [ "$CREATE_DMG" = true ]; then
        echo "DMG 位置: ${RELEASE_DIR}/${APP_NAME}-${VERSION}.dmg"
    fi
    echo ""
    echo "测试命令:"
    echo "  open ${RELEASE_DIR}/${APP_BUNDLE}"
    echo ""
}

# ----------------------------------------
# 主流程
# ----------------------------------------

main() {
    echo ""
    echo "========================================"
    echo "  ${APP_NAME} v${VERSION} - App Builder"
    echo "========================================"
    echo ""

    # 解析参数
    CREATE_DMG=false
    if [ "$1" = "--dmg" ]; then
        CREATE_DMG=true
    fi

    check_environment
    build_release
    create_app_bundle
    copy_executable
    copy_info_plist
    generate_app_icon
    sign_app
    verify_app

    if [ "$CREATE_DMG" = true ]; then
        create_dmg
    fi

    print_completion
}

main "$@"
