#!/bin/bash

# ========================================
# VoiceFlow - 一次性签名证书创建向导
# ========================================
# 用途：创建持久代码签名证书，解决每次更新后辅助功能权限失效的问题

CERT_NAME="VoiceFlow Dev"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "========================================"
echo "  VoiceFlow 签名证书创建向导"
echo "========================================"
echo ""

# 检查是否已存在
if security find-identity -v | grep -q "${CERT_NAME}"; then
    echo -e "${GREEN}✅ 证书 '${CERT_NAME}' 已存在，无需重复创建${NC}"
    echo ""
    echo "现在运行 ./scripts/build-app.sh 即可使用持久证书签名"
    echo ""
    exit 0
fi

echo -e "${YELLOW}未找到证书 '${CERT_NAME}'，请按以下步骤创建（只需做一次）：${NC}"
echo ""
echo -e "${BLUE}步骤 1：${NC} 打开 Keychain Access（钥匙串访问）"
echo -e "${BLUE}步骤 2：${NC} 菜单栏 → Certificate Assistant（证书助理）→ Create a Certificate（创建证书）"
echo -e "${BLUE}步骤 3：${NC} 填写以下信息："
echo "         Name（名称）: ${CERT_NAME}"
echo "         Identity Type（身份类型）: Self Signed Root（自签名根证书）"
echo "         Certificate Type（证书类型）: Code Signing（代码签名）"
echo -e "${BLUE}步骤 4：${NC} 勾选 \"Let me override defaults\" → Continue"
echo "         将有效期改为 3650 天"
echo -e "${BLUE}步骤 5：${NC} 一路 Continue → Create（创建）"
echo ""
echo "正在打开 Keychain Access..."
open -a "Keychain Access"

echo ""
echo "完成后按回车键验证证书是否创建成功..."
read -r

if security find-identity -v | grep -q "${CERT_NAME}"; then
    echo -e "${GREEN}✅ 证书 '${CERT_NAME}' 创建成功！${NC}"
    echo ""
    echo "现在每次运行 ./scripts/build-app.sh 都会使用此证书签名"
    echo "更新应用后辅助功能权限将持续有效，无需重复授权。"
else
    echo -e "${YELLOW}⚠️  未检测到证书，请确认名称填写为：${CERT_NAME}${NC}"
    echo "创建完成后可再次运行此脚本验证"
fi
echo ""
