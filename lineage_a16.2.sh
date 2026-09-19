#!/bin/bash
set -e

# ============================================================
# CONFIG
# ============================================================

MANIFEST_URL="https://github.com/JBHPocong/lineage-tissot-manifest.git"
MANIFEST_BRANCH="main"

ROM_BRANCH="lineage-23.2"

DEVICE="tissot_mainline"
LUNCH_TARGET="lineage_tissot_mainline-trunk_staging-userdebug"

# ============================================================
# START
# ============================================================

echo
echo "============================================================"
echo "        LINEAGEOS 23.2 TISSOT MAINLINE BUILD"
echo "============================================================"
echo

echo "ROM Branch    : $ROM_BRANCH"
echo "Device        : $DEVICE"
echo "Lunch Target  : $LUNCH_TARGET"
echo "Manifest      : $MANIFEST_URL"
echo "Manifest Branch: $MANIFEST_BRANCH"
echo

# ============================================================
# CLEANUP LOCAL MANIFEST
# ============================================================

echo "============================================================"
echo "Cleaning local manifests"
echo "============================================================"

rm -rf .repo/local_manifests

echo "Local manifests cleaned"

# ============================================================
# REPO INIT
# ============================================================

echo
echo "============================================================"
echo "Initializing LineageOS repository"
echo "============================================================"

repo init \
    -u https://github.com/LineageOS/android.git \
    -b "$ROM_BRANCH" \
    --git-lfs \
    --depth=1

echo
echo "Repo init success"

# ============================================================
# LOCAL MANIFEST
# ============================================================

echo
echo "============================================================"
echo "Cloning Tissot local manifest"
echo "============================================================"

git clone \
    -b "$MANIFEST_BRANCH" \
    "$MANIFEST_URL" \
    .repo/local_manifests

echo
echo "Local manifest clone success"

# ============================================================
# CRAVE SYNC
# ============================================================

echo
echo "============================================================"
echo "Starting Crave repository sync"
echo "============================================================"

if [ -x /opt/crave/resync.sh ]; then
    /opt/crave/resync.sh
else
    echo "ERROR: /opt/crave/resync.sh tidak ditemukan"
    exit 1
fi

echo
echo "============================================================"
echo "SYNC SUCCESS"
echo "============================================================"

# ============================================================
# BUILD ENVIRONMENT VARIABLES
# ============================================================

echo
echo "============================================================"
echo "Exporting build environment"
echo "============================================================"

export BUILD_USERNAME="Arden-Vey"
export BUILD_HOSTNAME="crave"

export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
export ALLOW_MISSING_DEPENDENCIES=true

export LC_ALL=C

echo "BUILD_USERNAME=$BUILD_USERNAME"
echo "BUILD_HOSTNAME=$BUILD_HOSTNAME"
echo "BUILD_BROKEN_MISSING_REQUIRED_MODULES=$BUILD_BROKEN_MISSING_REQUIRED_MODULES"
echo "ALLOW_MISSING_DEPENDENCIES=$ALLOW_MISSING_DEPENDENCIES"
echo "LC_ALL=$LC_ALL"

echo
echo "Build environment variables exported"

# ============================================================
# CHECK REPO STATUS
# ============================================================

echo
echo "============================================================"
echo "Checking repository status"
echo "============================================================"

echo
echo "Manifest:"
echo "----------------------------------------"

if [ -f .repo/manifest.xml ]; then
    echo ".repo/manifest.xml found"
else
    echo "WARNING: .repo/manifest.xml tidak ditemukan"
fi

echo
echo "Local manifests:"
echo "----------------------------------------"

find .repo/local_manifests \
    -maxdepth 2 \
    -type f \
    -print \
    2>/dev/null || true

# ============================================================
# BUILD ENVIRONMENT
# ============================================================

echo
echo "============================================================"
echo "Loading Android build environment"
echo "============================================================"

source build/envsetup.sh

echo
echo "Build environment ready"

# ============================================================
# LUNCH
# ============================================================

echo
echo "============================================================"
echo "Selecting lunch target"
echo "============================================================"

lunch "$LUNCH_TARGET"

echo
echo "============================================================"
echo "LUNCH SUCCESS"
echo "============================================================"

# ============================================================
# DEBUG LIBJXL
# ============================================================

echo
echo "============================================================"
echo "Checking external/libjxl/Android.bp"
echo "============================================================"

if [ -f external/libjxl/Android.bp ]; then

    echo
    echo ">>> external/libjxl/Android.bp"
    echo "----------------------------------------"

    nl -ba external/libjxl/Android.bp | sed -n '1,80p'

else

    echo
    echo "WARNING:"
    echo "external/libjxl/Android.bp tidak ditemukan"

fi

# ============================================================
# DEBUG HIGHWAY
# ============================================================

echo
echo "============================================================"
echo "Checking external/highway/Android.bp"
echo "============================================================"

if [ -f external/highway/Android.bp ]; then

    echo
    echo ">>> external/highway/Android.bp"
    echo "----------------------------------------"

    nl -ba external/highway/Android.bp | sed -n '1,100p'

else

    echo
    echo "WARNING:"
    echo "external/highway/Android.bp tidak ditemukan"

fi

# ============================================================
# CHECK LIBJXL REFERENCES
# ============================================================

echo
echo "============================================================"
echo "Searching libjxl related properties"
echo "============================================================"

if [ -f external/libjxl/Android.bp ]; then

    grep -nE \
        'sdk_version|min_sdk_version|compile_multilib|apex_available|name:|libs:|shared_libs:|static_libs:' \
        external/libjxl/Android.bp \
        || true

fi

# ============================================================
# CHECK HIGHWAY REFERENCES
# ============================================================

echo
echo "============================================================"
echo "Searching libhwy related properties"
echo "============================================================"

if [ -f external/highway/Android.bp ]; then

    grep -nE \
        'sdk_version|min_sdk_version|compile_multilib|apex_available|name:|libs:|shared_libs:|static_libs:' \
        external/highway/Android.bp \
        || true

fi

# ============================================================
# CHECK DUPLICATE KERNEL CONFIG PATH
# ============================================================

echo
echo "============================================================"
echo "Checking kernel/mainline/configs references"
echo "============================================================"

if [ -f .repo/manifest.xml ]; then

    DUPLICATE_CONFIGS=$(
        grep -n \
            'kernel/mainline/configs' \
            .repo/manifest.xml \
            || true
    )

    if [ -n "$DUPLICATE_CONFIGS" ]; then

        echo
        echo "WARNING: ditemukan kernel/mainline/configs"
        echo
        echo "$DUPLICATE_CONFIGS"

    else

        echo "Tidak ditemukan kernel/mainline/configs"

    fi

else

    echo "WARNING: .repo/manifest.xml tidak ditemukan"

fi

# ============================================================
# CHECK DEVICE TREE
# ============================================================

echo
echo "============================================================"
echo "Checking device tree"
echo "============================================================"

if [ -d "device/xiaomi/mi89xx-mainline" ]; then

    echo "Device tree:"
    echo "device/xiaomi/mi89xx-mainline"

else

    echo "WARNING:"
    echo "device/xiaomi/mi89xx-mainline tidak ditemukan"

fi

# ============================================================
# CHECK KERNEL
# ============================================================

echo
echo "============================================================"
echo "Checking mainline kernel"
echo "============================================================"

if [ -d "kernel/mainline/msm8953-mainline" ]; then

    echo "Kernel:"
    echo "kernel/mainline/msm8953-mainline"

else

    echo "WARNING:"
    echo "kernel/mainline/msm8953-mainline tidak ditemukan"

fi

# ============================================================
# CHECK TISSOT VENDOR
# ============================================================

echo
echo "============================================================"
echo "Checking Tissot vendor"
echo "============================================================"

if [ -d "vendor/xiaomi/tissot" ]; then

    echo "Tissot vendor:"
    echo "vendor/xiaomi/tissot"

else

    echo "WARNING:"
    echo "vendor/xiaomi/tissot tidak ditemukan"

fi

# ============================================================
# CHECK MSM8953 COMMON VENDOR
# ============================================================

echo
echo "============================================================"
echo "Checking MSM8953 common vendor"
echo "============================================================"

if [ -d "vendor/xiaomi/msm8953-common" ]; then

    echo "MSM8953 common vendor:"
    echo "vendor/xiaomi/msm8953-common"

else

    echo "WARNING:"
    echo "vendor/xiaomi/msm8953-common tidak ditemukan"

fi

# ============================================================
# CHECK DEVICE COMMON
# ============================================================

echo
echo "============================================================"
echo "Checking MSM8953 common device tree"
echo "============================================================"

if [ -d "device/xiaomi/msm8953-common" ]; then

    echo "MSM8953 common device:"
    echo "device/xiaomi/msm8953-common"

else

    echo "WARNING:"
    echo "device/xiaomi/msm8953-common tidak ditemukan"

fi

# ============================================================
# CHECK HARDWARE XIAOMI
# ============================================================

echo
echo "============================================================"
echo "Checking hardware/xiaomi"
echo "============================================================"

if [ -d "hardware/xiaomi" ]; then

    echo "hardware/xiaomi found"

else

    echo "WARNING:"
    echo "hardware/xiaomi tidak ditemukan"

fi

# ============================================================
# PRE-BUILD SUMMARY
# ============================================================

echo
echo "============================================================"
echo "PRE-BUILD SUMMARY"
echo "============================================================"

echo
echo "ROM Branch:"
echo "  $ROM_BRANCH"

echo
echo "Device:"
echo "  $DEVICE"

echo
echo "Lunch Target:"
echo "  $LUNCH_TARGET"

echo
echo "Kernel:"
echo "  kernel/mainline/msm8953-mainline"

echo
echo "Device Tree:"
echo "  device/xiaomi/mi89xx-mainline"

echo
echo "Vendor:"
echo "  vendor/xiaomi/tissot"

echo
echo "Common Vendor:"
echo "  vendor/xiaomi/msm8953-common"

# ============================================================
# BUILD
# ============================================================

echo
echo "============================================================"
echo "                STARTING BUILD"
echo "============================================================"

echo
echo "Running:"
echo
echo "    mka bacon"
echo

BUILD_START=$(date +%s)

mka bacon

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

# ============================================================
# BUILD SUCCESS
# ============================================================

echo
echo "============================================================"
echo "                BUILD SUCCESS"
echo "============================================================"

echo
echo "Build completed successfully."

echo
echo "Build time:"
echo "$BUILD_TIME seconds"

# ============================================================
# FIND OUTPUT DIRECTORY
# ============================================================

OUT_DIR="out/target/product/$DEVICE"

echo
echo "============================================================"
echo "Checking build output"
echo "============================================================"

if [ -d "$OUT_DIR" ]; then

    echo
    echo "Output directory:"
    echo "$OUT_DIR"

    echo
    echo "Artifacts:"
    echo "----------------------------------------"

    find "$OUT_DIR" \
        -maxdepth 1 \
        -type f \
        \( \
            -name "*.zip" \
            -o -name "*.img" \
            -o -name "*.sha256sum" \
            -o -name "*.json" \
        \) \
        -printf '%f\n' \
        | sort

else

    echo
    echo "WARNING:"
    echo "$OUT_DIR tidak ditemukan"

fi

# ============================================================
# IMPORTANT ARTIFACT CHECK
# ============================================================

echo
echo "============================================================"
echo "Checking important artifacts"
echo "============================================================"

if [ -f "$OUT_DIR/boot.img" ]; then
    echo "[OK] boot.img"
else
    echo "[--] boot.img"
fi

if [ -f "$OUT_DIR/vendor.img" ]; then
    echo "[OK] vendor.img"
else
    echo "[--] vendor.img"
fi

if [ -f "$OUT_DIR/system.img" ]; then
    echo "[OK] system.img"
else
    echo "[--] system.img"
fi

if [ -f "$OUT_DIR/init_boot.img" ]; then
    echo "[OK] init_boot.img"
else
    echo "[--] init_boot.img"
fi

if [ -f "$OUT_DIR/recovery.img" ]; then
    echo "[OK] recovery.img"
else
    echo "[--] recovery.img"
fi

# ============================================================
# ZIP CHECK
# ============================================================

echo
echo "============================================================"
echo "Checking LineageOS ZIP"
echo "============================================================"

ZIP_COUNT=$(find "$OUT_DIR" \
    -maxdepth 1 \
    -type f \
    -name "*.zip" \
    2>/dev/null \
    | wc -l)

if [ "$ZIP_COUNT" -gt 0 ]; then

    echo
    echo "LineageOS ZIP found:"
    find "$OUT_DIR" \
        -maxdepth 1 \
        -type f \
        -name "*.zip" \
        -printf '%f\n' \
        | sort

else

    echo
    echo "WARNING: LineageOS ZIP tidak ditemukan"

fi

# ============================================================
# FINAL SUMMARY
# ============================================================

echo
echo "============================================================"
echo "                FINAL BUILD SUMMARY"
echo "============================================================"

echo
echo "ROM:"
echo "  LineageOS $ROM_BRANCH"

echo
echo "Device:"
echo "  $DEVICE"

echo
echo "Lunch:"
echo "  $LUNCH_TARGET"

echo
echo "Output:"
echo "  $OUT_DIR"

echo
echo "Build time:"
echo "  $BUILD_TIME seconds"

echo
echo "============================================================"
echo "                  BUILD FINISHED"
echo "============================================================"
echo
