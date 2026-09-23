#!/bin/bash
set -e

# ============================================================
# LINEAGEOS 23.2 - GENERIC ARM64
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

ROM_NAME="LineageOS 23.2"
ROM_BRANCH="lineage-23.2"

DEVICE="Generic_arm64"
BUILD_TARGET="all_images"

MANIFEST_URL="https://github.com/JBHPocong/lineage-tissot-manifest.git"
MANIFEST_BRANCH="generic"

BUILD_USERNAME="Arden-Vey"
BUILD_HOSTNAME="crave"

OUT_DIR="out/target/product/$DEVICE"

section() {
    echo
    echo "============================================================"
    echo " $1"
    echo "============================================================"
}

ok() {
    echo -e "${GREEN}[OK]${RESET} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

err() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

echo
echo "============================================================"
echo "        LINEAGEOS 23.2 GENERIC ARM64 BUILDER"
echo "============================================================"
echo

section "BUILD CONFIGURATION"

echo "ROM             : $ROM_NAME"
echo "Branch          : $ROM_BRANCH"
echo "Device          : $DEVICE"
echo "Build target    : $BUILD_TARGET"
echo "Manifest        : $MANIFEST_URL"
echo "Manifest branch : $MANIFEST_BRANCH"
echo "Output          : $OUT_DIR"
echo "CPU threads     : $(nproc --all)"

# ============================================================
# REQUIREMENTS
# ============================================================

section "CHECKING REQUIREMENTS"

command -v repo >/dev/null 2>&1 || {
    err "repo tidak ditemukan."
    exit 1
}

command -v git >/dev/null 2>&1 || {
    err "git tidak ditemukan."
    exit 1
}

[ -x "/opt/crave/resync.sh" ] || {
    err "/opt/crave/resync.sh tidak ditemukan."
    exit 1
}

ok "Required tools available."

# ============================================================
# LOCAL MANIFEST
# ============================================================

section "CLEANING LOCAL MANIFEST"

if [ -d ".repo/local_manifests" ]; then
    rm -rf .repo/local_manifests
    ok "Old local manifests removed."
else
    ok "No old local manifests."
fi

# ============================================================
# REPO INIT
# ============================================================

section "REPO INIT"

repo init \
    -u https://github.com/LineageOS/android.git \
    -b "$ROM_BRANCH" \
    --depth=1 \
    --git-lfs

ok "Repo initialized."

# ============================================================
# MANIFEST
# ============================================================

section "CLONING GENERIC MANIFEST"

git clone \
    -b "$MANIFEST_BRANCH" \
    --depth=1 \
    "$MANIFEST_URL" \
    .repo/local_manifests

ok "Manifest cloned."

# ============================================================
# CRAVE SYNC
# ============================================================

section "SOURCE SYNC"

echo "Running /opt/crave/resync.sh ..."
echo

/opt/crave/resync.sh

ok "Source sync completed."

# ============================================================
# BUILD ENVIRONMENT
# ============================================================

section "BUILD ENVIRONMENT"

export BUILD_USERNAME="$BUILD_USERNAME"
export BUILD_HOSTNAME="$BUILD_HOSTNAME"

export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C

echo "BUILD_USERNAME=$BUILD_USERNAME"
echo "BUILD_HOSTNAME=$BUILD_HOSTNAME"
echo "BUILD_BROKEN_MISSING_REQUIRED_MODULES=$BUILD_BROKEN_MISSING_REQUIRED_MODULES"
echo "ALLOW_MISSING_DEPENDENCIES=$ALLOW_MISSING_DEPENDENCIES"

# ============================================================
# ENVSETUP
# ============================================================

section "LOADING BUILD ENVIRONMENT"

if [ ! -f "build/envsetup.sh" ]; then
    err "build/envsetup.sh tidak ditemukan."
    exit 1
fi

# IMPORTANT:
# Do NOT use "set -u" here.
# LineageOS envsetup.sh expects TOP to be unset initially.

source build/envsetup.sh

ok "build/envsetup.sh loaded."

# ============================================================
# GENERIC DEVICE TREE
# ============================================================

section "CHECKING GENERIC DEVICE TREE"

for DIR in \
    "device/mainline/generic" \
    "device/mainline/common" \
    "hardware/mainline/common"
do
    if [ -d "$DIR" ]; then
        ok "$DIR"
    else
        err "$DIR tidak ditemukan."
        exit 1
    fi
done

# ============================================================
# OPTIONAL DEPENDENCIES
# ============================================================

section "CHECKING MAINLINE DEPENDENCIES"

for DIR in \
    "kernel/mainline/configs" \
    "external/drm_hwcomposer-upstream" \
    "external/libdisplay-info-upstream" \
    "external/minigbm-upstream" \
    "external/linux-firmware-mainline" \
    "external/mesa" \
    "external/tinyhal" \
    "prebuilts/mesa-build-dep" \
    "prebuilts/bootmgr"
do
    if [ -d "$DIR" ]; then
        ok "$DIR"
    else
        warn "$DIR missing"
    fi
done

# ============================================================
# SELECT DEVICE
# ============================================================

section "SELECTING TARGET"

echo
echo "Running:"
echo
echo "    breakfast $DEVICE"
echo

breakfast "$DEVICE"

ok "Target selected."

# ============================================================
# VERIFY TARGET
# ============================================================

section "VERIFYING TARGET"

TARGET_PRODUCT="$(get_build_var TARGET_PRODUCT)"
TARGET_DEVICE="$(get_build_var TARGET_DEVICE)"
TARGET_ARCH="$(get_build_var TARGET_ARCH)"
TARGET_ARCH_VARIANT="$(get_build_var TARGET_ARCH_VARIANT)"

echo "TARGET_PRODUCT      : $TARGET_PRODUCT"
echo "TARGET_DEVICE       : $TARGET_DEVICE"
echo "TARGET_ARCH         : $TARGET_ARCH"
echo "TARGET_ARCH_VARIANT : $TARGET_ARCH_VARIANT"

if [ "$TARGET_DEVICE" != "$DEVICE" ]; then
    err "TARGET_DEVICE tidak sesuai."
    echo "Expected : $DEVICE"
    echo "Detected : $TARGET_DEVICE"
    exit 1
fi

ok "Target verified."

# ============================================================
# PRE-BUILD
# ============================================================

section "PRE-BUILD SUMMARY"

echo "ROM        : $ROM_NAME"
echo "Branch     : $ROM_BRANCH"
echo "Device     : $DEVICE"
echo "Target     : $BUILD_TARGET"
echo "Product    : $TARGET_PRODUCT"
echo "Architecture: $TARGET_ARCH"
echo "Output     : $OUT_DIR"
echo "Threads    : $(nproc --all)"

echo
echo "Build command:"
echo
echo "    m $BUILD_TARGET"
echo

# ============================================================
# BUILD
# ============================================================

section "STARTING BUILD"

BUILD_START=$(date +%s)

m "$BUILD_TARGET"

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

# ============================================================
# OUTPUT
# ============================================================

section "BUILD OUTPUT"

if [ ! -d "$OUT_DIR" ]; then
    err "Output directory tidak ditemukan:"
    echo "$OUT_DIR"
    exit 1
fi

ok "Output directory exists."

echo
find "$OUT_DIR" \
    -maxdepth 1 \
    -type f \
    \( \
        -name "*.img" \
        -o -name "*.iso" \
        -o -name "*.EFI" \
        -o -name "*.zip" \
        -o -name "*.json" \
        -o -name "*.sha256sum" \
    \) \
    -printf '%f\n' \
    | sort

# ============================================================
# IMAGE CHECK
# ============================================================

section "IMAGE CHECK"

for IMAGE in \
    boot.img \
    vendor_boot.img \
    system.img \
    system_ext.img \
    product.img \
    vendor.img \
    init_boot.img \
    recovery.img \
    super.img \
    ramdisk-all-combined.img \
    ramdisk-custom.img
do
    if [ -f "$OUT_DIR/$IMAGE" ]; then
        ok "$IMAGE"
    else
        echo "[--] $IMAGE"
    fi
done

# ============================================================
# DONE
# ============================================================

section "BUILD COMPLETE"

echo "ROM        : $ROM_NAME"
echo "Device     : $DEVICE"
echo "Target     : $BUILD_TARGET"
echo "Output     : $OUT_DIR"
echo "Build time : $BUILD_TIME seconds"

echo
echo -e "${GREEN}${BOLD}BUILD SUCCESS${RESET}"
echo
