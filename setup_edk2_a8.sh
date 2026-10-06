#!/bin/bash
# EDK2 UEFI Build & Setup Script for Samsung Galaxy A8 (2018) [SM-A530F / jackpotlte]
# Run this inside WSL2 / Linux environment

set -e # Exit immediately if a command fails

WORKSPACE="$HOME/exynos_uefi"

echo "=== Step 1: Installing Required Build Tools & Dependencies ==="
sudo apt update
sudo apt install -y \
    build-essential uuid-dev iasl git nasm python3 python3-distutils \
    gcc-aarch64-linux-gnu device-tree-compiler android-sdk-libsparse-utils \
    adb fastboot android-sdk-platform-tools mkbootimg

echo "=== Step 2: Setting up Workspace at $WORKSPACE ==="
mkdir -p "$WORKSPACE"
cd "$WORKSPACE"

echo "=== Step 3: Cloning EDK2 Core and Exynos 7885 Repositories ==="
if [ ! -d "edk2" ]; then
    git clone https://github.com/tianocore/edk2.git --recursive --depth=1
fi

if [ ! -d "edk2-platforms" ]; then
    git clone https://github.com/tianocore/edk2-platforms.git --depth=1
fi

if [ ! -d "edk2-exynos7885" ]; then
    git clone https://github.com/sonic011gamer/edk2-exynos7885.git --depth=1
fi

echo "=== Step 4: Pulling Hardware Dump Files from Device via ADB ==="
echo "Ensure your Galaxy A8 is booted into TWRP recovery and connected via USB."
read -p "Press [ENTER] when device is ready..."

# Verify ADB connection
adb devices

echo "Extracting /proc/iomem and device tree..."
adb pull /proc/iomem "$WORKSPACE/iomem.txt" || echo "Warning: Failed to pull iomem"
adb pull /sys/firmware/fdt "$WORKSPACE/exynos7885.dtb" || echo "Warning: Failed to pull FDT"

echo "Decompiling DTB to DTS..."
if [ -f "$WORKSPACE/exynos7885.dtb" ]; then
    dtc -I dtb -O dts -o "$WORKSPACE/exynos7885.dts" "$WORKSPACE/exynos7885.dtb"
fi

echo "Pulling stock boot image..."
adb shell "dd if=/dev/block/by-name/boot of=/tmp/boot.img"
adb pull /tmp/boot.img "$WORKSPACE/stock_boot.img"

echo "=== Step 5: Setting up EDK2 Toolchain ==="
cd "$WORKSPACE/edk2-exynos7885"
if [ -f "firstrun.sh" ]; then
    chmod +x firstrun.sh build.sh
    ./firstrun.sh
fi

echo "=== Step 6: Configuring Target Device for SM-A530F ==="
CONFIG_DIR="$WORKSPACE/edk2-exynos7885/EXYNOS7885Pkg/Devices"
if [ -d "$CONFIG_DIR" ]; then
    cd "$CONFIG_DIR"
    if [ ! -f "a530f.dsc" ] && [ -f "a10.dsc" ]; then
        cp a10.dsc a530f.dsc
        # Update display resolution to 1080x2220 for A8 2018
        sed -i 's/720/1080/g' a530f.dsc
        sed -i 's/1520/2220/g' a530f.dsc
    fi
fi

echo "=== Setup Completed Successfully! ==="
echo "To compile UEFI, run:"
echo "  cd $WORKSPACE/edk2-exynos7885"
echo "  ./build.sh"
