#!/bin/bash
set -e

echo "========================================="
echo "  JetKVM 本地交叉编译工具链安装脚本"
echo "========================================="

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then 
    echo "请使用 sudo 运行此脚本"
    echo "用法: sudo $0"
    exit 1
fi

echo ""
echo "[1/3] 安装系统依赖..."
apt-get update
apt-get install -y --no-install-recommends \
  iputils-ping \
  build-essential \
  device-tree-compiler \
  gperf \
  gdb-multiarch \
  libnl-3-dev \
  libdbus-1-dev \
  libelf-dev \
  libmpc-dev \
  dwarves \
  bc \
  openssl \
  flex \
  bison \
  libssl-dev \
  python3 \
  python-is-python3 \
  texinfo \
  kmod \
  cmake \
  wget \
  zstd \
  python3-venv \
  python3-kconfiglib \
  g++-multilib \
  gcc-multilib

echo ""
echo "[2/3] 下载交叉编译工具链..."
BUILDKIT_VERSION="v0.2.5"
BUILDKIT_TMPDIR=$(mktemp -d)
cd "$BUILDKIT_TMPDIR"

wget https://github.com/jetkvm/rv1106-system/releases/download/${BUILDKIT_VERSION}/buildkit.tar.zst

echo ""
echo "[3/3] 安装工具链到 /opt/jetkvm-native-buildkit..."
mkdir -p /opt/jetkvm-native-buildkit
tar --use-compress-program="unzstd --long=31" -xvf buildkit.tar.zst -C /opt/jetkvm-native-buildkit

# 清理
rm buildkit.tar.zst
cd ~
rm -rf "$BUILDKIT_TMPDIR"

echo ""
echo "========================================="
echo "  安装完成！"
echo "========================================="
echo ""
echo "验证安装："
echo "  ls -la /opt/jetkvm-native-buildkit/"
echo ""
echo "开始编译："
echo "  cd ~/NoxKVM"
echo "  make build_dev"
echo ""
