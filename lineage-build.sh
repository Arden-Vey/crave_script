#!/bin/bash
set -e

# ============================================================
# COLORS
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# ============================================================
# CONFIG
# ============================================================

ROM_NAME="LineageOS 23.2"
ROM_BRANCH="lineage-23.2"

DEVICE="Generic_arm64"
LUNCH_TARGET=""

MANIFEST_URL="https://github.com/JBHPocong/lineage-tissot-manifest.git"
MANIFEST_BRANCH="generic"

BUILD_USERNAME="Arden-Vey"
BUILD_HOSTNAME="crave"

OUT_DIR="out/target/product/$DEVICE"

# ============================================================
# BANNER
# ============================================================

banner() {
    clear

    echo -e "${CYAN}${BOLD}"
    echo "╔═════════════════════════════════════════════════════════════════╗"
    echo "║                                                                 ║"
    echo "║      ██╗     ██╗███╗   ██╗███████╗ █████╗  ██████╗ ███████╗     ║"
    echo "║      ██║     ██║████╗  ██║██╔════╝██╔══██╗██╔════╝ ██╔════╝     ║"
    echo "║      ██║     ██║██╔██╗ ██║█████╗  ███████║██║  ███╗█████╗       ║"
    echo "║      ██║     ██║██║╚██╗██║██╔══╝  ██╔══██║██║   ██║██╔══╝       ║"
    echo "║      ███████╗██║██║ ╚████║███████╗██║  ██║╚██████╔╝███████╗     ║"
    echo "║      ╚══════╝╚═╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝     ║"
    echo "║                                                                 ║"
    echo "║                    G E N E R I C   M A I N L I N E              ║"
    echo "║                    Automated Release Builder                    ║"
    echo "║                                                                 ║"
    echo "╠═════════════════════════════════════════════════════════════════╣"
    echo "║  ROM        : LineageOS 23.2                                    ║"
    echo "║  Device     : Generic ARM64 GSI                                 ║"
    echo "║  Branch     : lineage-23.2                                      ║"
    echo "║  Build      : userdebug                                         ║"
    echo "╚═════════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

banner

# ============================================================
# BUILD INFO
# ============================================================

echo
echo -e "${BLUE}${BOLD}Build configuration${RESET}"
echo "--------------------------------------------"
echo "ROM             : $ROM_NAME"
echo "ROM branch      : $ROM_BRANCH"
echo "Device          : $DEVICE"
echo "Lunch target    : AUTO"
echo "Manifest        : $MANIFEST_URL"
echo "Manifest branch : $MANIFEST_BRANCH"
echo "Output          : $OUT_DIR"
echo

# ============================================================
# CLEAN LOCAL MANIFEST
# ============================================================

echo
echo "============================================="
echo "    cleaning up previous local manifests"
echo "============================================="

rm -rf .repo/local_manifests

echo -e "${GREEN}Local manifests cleaned.${RESET}"

# ============================================================
# REPO INIT
# ============================================================

echo
echo "====================="
echo "      repo init"
echo "====================="

repo init \
    -u https://github.com/LineageOS/android.git \
    -b "$ROM_BRANCH" \
    --depth=1 \
    --git-lfs

echo -e "${GREEN}repo init completed.${RESET}"

# ============================================================
# LOCAL MANIFEST
# ============================================================

echo
echo "========================"
echo "   cloning manifest"
echo "========================"

git clone \
    -b "$MANIFEST_BRANCH" \
    --depth=1 \
    "$MANIFEST_URL" \
    .repo/local_manifests

echo -e "${GREEN}Local manifest cloned.${RESET}"

# ============================================================
# CRAVE SYNC
# ============================================================

echo
echo "==================="
echo "     repo sync"
echo "==================="

/opt/crave/resync.sh

echo -e "${GREEN}Repository sync completed.${RESET}"

# ============================================================
# BUILD ENVIRONMENT
# ============================================================

echo
echo "=============================="
echo "   build environment setup"
echo "=============================="

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
# BUILD ENV
# ============================================================

echo
echo "=============================="
echo "   loading build environment"
echo "=============================="

source build/envsetup.sh

echo -e "${GREEN}Build environment loaded.${RESET}"

# ============================================================
# GENERIC DEVICE CHECK
# ============================================================

echo
echo "============================================="
echo "       checking generic device tree"
echo "============================================="

if [ -d "device/mainline/generic" ]; then
    echo -e "${GREEN}[OK]${RESET} device/mainline/generic"
else
    echo -e "${RED}[ERROR]${RESET} device/mainline/generic"
    exit 1
fi

# ============================================================
# GENERIC COMMON CHECK
# ============================================================

echo
echo "============================================="
echo "       checking mainline common tree"
echo "============================================="

if [ -d "device/mainline/common" ]; then
    echo -e "${GREEN}[OK]${RESET} device/mainline/common"
else
    echo -e "${RED}[ERROR]${RESET} device/mainline/common"
    exit 1
fi

# ============================================================
# MAINLINE HARDWARE CHECK
# ============================================================

echo
echo "============================================="
echo "       checking mainline hardware"
echo "============================================="

if [ -d "hardware/mainline/common" ]; then
    echo -e "${GREEN}[OK]${RESET} hardware/mainline/common"
else
    echo -e "${RED}[ERROR]${RESET} hardware/mainline/common"
    exit 1
fi

# ============================================================
# KERNEL CONFIG CHECK
# ============================================================

echo
echo "============================================="
echo "       checking kernel mainline configs"
echo "============================================="

if [ -d "kernel/mainline/configs" ]; then
    echo -e "${GREEN}[OK]${RESET} kernel/mainline/configs"
else
    echo -e "${YELLOW}[WARNING]${RESET} kernel/mainline/configs missing"
fi

# ============================================================
# MAINLINE DEPENDENCIES CHECK
# ============================================================

echo
echo "============================================="
echo "       checking mainline dependencies"
echo "============================================="

for DIR in \
    external/drm_hwcomposer-upstream \
    external/libdisplay-info-upstream \
    external/minigbm-upstream \
    external/linux-firmware-mainline \
    external/mesa \
    external/tinyhal \
    prebuilts/mesa-build-dep \
    prebuilts/bootmgr
do
    if [ -d "$DIR" ]; then
        echo -e "${GREEN}[OK]${RESET} $DIR"
    else
        echo -e "${YELLOW}[WARNING]${RESET} $DIR missing"
    fi
done

# ============================================================
# AUTO DETECT LUNCH TARGET
# ============================================================

echo
echo "============================================="
echo "       detecting GSI lunch target"
echo "============================================="

PRODUCT_NAME="lineage_${DEVICE}"
BUILD_VARIANT="userdebug"

echo
echo "Product : $PRODUCT_NAME"
echo "Variant : $BUILD_VARIANT"
echo

# ------------------------------------------------------------
# METHOD 1
# Query all registered lunch combos
# ------------------------------------------------------------

echo "Searching registered lunch combinations..."

LUNCH_TARGET=""

if command -v lunch >/dev/null 2>&1; then

    AVAILABLE_LUNCHES=""

    # Modern Lineage/AOSP exposes --list.
    AVAILABLE_LUNCHES=$(lunch --list 2>/dev/null || true)

    # Search exact product + userdebug.
    if [ -n "$AVAILABLE_LUNCHES" ]; then

        LUNCH_TARGET=$(
            printf '%s\n' "$AVAILABLE_LUNCHES" |
            grep -E \
                "^${PRODUCT_NAME}(-[^[:space:]]+)?-${BUILD_VARIANT}$" |
            head -n 1 ||
            true
        )

    fi

fi

# ------------------------------------------------------------
# METHOD 2
# Search product definitions directly
# ------------------------------------------------------------

if [ -z "$LUNCH_TARGET" ]; then

    echo "Registered lunch list did not provide a match."
    echo "Searching product definitions..."

    LUNCH_TARGET=$(
        grep -RhoE \
            "${PRODUCT_NAME}(-[A-Za-z0-9_.-]+)?-${BUILD_VARIANT}" \
            device \
            vendor \
            build \
            2>/dev/null |
        sort -u |
        head -n 1 ||
        true
    )

fi

# ------------------------------------------------------------
# METHOD 3
# Search AndroidProducts.mk
# ------------------------------------------------------------

if [ -z "$LUNCH_TARGET" ]; then

    echo "Searching AndroidProducts.mk..."

    LUNCH_TARGET=$(
        grep -RhoE \
            "${PRODUCT_NAME}(-[A-Za-z0-9_.-]+)?-${BUILD_VARIANT}" \
            device \
            vendor \
            2>/dev/null |
        sort -u |
        head -n 1 ||
        true
    )

fi

# ------------------------------------------------------------
# Validate lunch target
# ------------------------------------------------------------

if [ -z "$LUNCH_TARGET" ]; then

    echo
    echo -e "${RED}[ERROR]${RESET} Unable to automatically detect lunch target."
    echo
    echo "Expected product : $PRODUCT_NAME"
    echo "Expected variant : $BUILD_VARIANT"
    echo
    echo "Available Generic products:"
    
    if command -v lunch >/dev/null 2>&1; then
        lunch --list 2>/dev/null |
            grep -i "Generic_arm64" ||
            true
    fi

    exit 1

fi

echo
echo -e "${GREEN}[OK]${RESET} Lunch target detected:"
echo
echo -e "    ${CYAN}${BOLD}$LUNCH_TARGET${RESET}"
echo

# ============================================================
# LUNCH
# ============================================================

echo
echo "===================="
echo "       lunch"
echo "===================="

lunch "$LUNCH_TARGET"

echo -e "${GREEN}Lunch completed.${RESET}"

# ============================================================
# VERIFY TARGET
# ============================================================

echo
echo "============================================="
echo "          checking build target"
echo "============================================="

echo "TARGET_PRODUCT      : $(get_build_var TARGET_PRODUCT)"
echo "TARGET_BUILD_VARIANT: $(get_build_var TARGET_BUILD_VARIANT)"
echo "TARGET_ARCH         : $(get_build_var TARGET_ARCH)"
echo "TARGET_ARCH_VARIANT : $(get_build_var TARGET_ARCH_VARIANT)"

# ============================================================
# VERIFY DEVICE
# ============================================================

echo
echo "============================================="
echo "             verifying device"
echo "============================================="

DETECTED_PRODUCT="$(get_build_var TARGET_PRODUCT)"
DETECTED_DEVICE="$(get_build_var TARGET_DEVICE)"

echo "Expected product : $PRODUCT_NAME"
echo "Detected product : $DETECTED_PRODUCT"
echo "Detected device  : $DETECTED_DEVICE"

# ============================================================
# LIBJXL DEBUG
# ============================================================

echo
echo "============================================="
echo "       checking external/libjxl"
echo "============================================="

if [ -f "external/libjxl/Android.bp" ]; then

    echo -e "${GREEN}[OK]${RESET} external/libjxl/Android.bp"

    echo
    echo "Relevant properties:"

    grep -nE \
        'sdk_version|min_sdk_version|compile_multilib|apex_available|name:|libs:|shared_libs:|static_libs:' \
        external/libjxl/Android.bp \
        || true

else

    echo -e "${YELLOW}[WARNING]${RESET} external/libjxl/Android.bp missing"

fi

# ============================================================
# HIGHWAY DEBUG
# ============================================================

echo
echo "============================================="
echo "       checking external/highway"
echo "============================================="

if [ -f "external/highway/Android.bp" ]; then

    echo -e "${GREEN}[OK]${RESET} external/highway/Android.bp"

    echo
    echo "Relevant properties:"

    grep -nE \
        'sdk_version|min_sdk_version|compile_multilib|apex_available|name:|libs:|shared_libs:|static_libs:' \
        external/highway/Android.bp \
        || true

else

    echo -e "${YELLOW}[WARNING]${RESET} external/highway/Android.bp missing"

fi

# ============================================================
# PRE-BUILD SUMMARY
# ============================================================

echo
echo "============================================================"
echo "                    PRE-BUILD SUMMARY"
echo "============================================================"

echo
echo "ROM             : $ROM_NAME"
echo "Branch          : $ROM_BRANCH"
echo "Device          : $DEVICE"
echo "Lunch           : $LUNCH_TARGET"
echo "Build username  : $BUILD_USERNAME"
echo "Build hostname  : $BUILD_HOSTNAME"
echo "CPU threads     : $(nproc --all)"
echo "Output          : $OUT_DIR"

echo
echo "============================================================"
echo "                    STARTING BUILD"
echo "============================================================"

echo
echo "Command:"
echo
echo "    mka bacon"
echo

BUILD_START=$(date +%s)

# ============================================================
# BUILD
# ============================================================

mka bacon

# ============================================================
# BUILD TIME
# ============================================================

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

# ============================================================
# BUILD SUCCESS
# ============================================================

echo
echo "============================================================"
echo "                    BUILD SUCCESS"
echo "============================================================"

echo
echo -e "${GREEN}${BOLD}Build completed successfully.${RESET}"

echo
echo "Build time:"
echo "$BUILD_TIME seconds"

# ============================================================
# ARTIFACT CHECK
# ============================================================

echo
echo "============================================================"
echo "                  BUILD ARTIFACTS"
echo "============================================================"

if [ ! -d "$OUT_DIR" ]; then

    echo -e "${RED}ERROR:${RESET}"
    echo "Output directory tidak ditemukan:"
    echo "$OUT_DIR"
    exit 1

fi

echo
echo "Output directory:"
echo "$OUT_DIR"

echo
echo "Files:"
echo "--------------------------------------------"

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

# ============================================================
# ROM ZIP
# ============================================================

echo
echo "============================================================"
echo "                    ROM ZIP CHECK"
echo "============================================================"

ZIP=$(find "$OUT_DIR" \
    -maxdepth 1 \
    -type f \
    -name "*.zip" \
    ! -name "*ota*.zip" \
    | head -n 1)

if [ -n "$ZIP" ]; then

    echo -e "${GREEN}ROM ZIP found:${RESET}"
    echo
    echo "$ZIP"

else

    echo -e "${RED}No ROM ZIP found in artifacts!${RESET}"

fi

# ============================================================
# IMAGE CHECK
# ============================================================

echo
echo "============================================================"
echo "                    IMAGE CHECK"
echo "============================================================"

for IMAGE in \
    boot.img \
    vendor_boot.img \
    system.img \
    system_ext.img \
    product.img \
    vendor.img \
    init_boot.img \
    recovery.img \
    super.img
do

    if [ -f "$OUT_DIR/$IMAGE" ]; then
        echo -e "${GREEN}[OK]${RESET} $IMAGE"
    else
        echo -e "${YELLOW}[--]${RESET} $IMAGE"
    fi

done

# ============================================================
# SHA256
# ============================================================

echo
echo "============================================================"
echo "                    SHA256"
echo "============================================================"

if [ -n "$ZIP" ] && command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$ZIP"
fi

# ============================================================
# FINAL
# ============================================================

echo
echo "============================================================"
echo "                  BUILD COMPLETE"
echo "============================================================"

echo
echo -e "${GREEN}${BOLD}ROM:${RESET} $ROM_NAME"
echo -e "${GREEN}${BOLD}DEVICE:${RESET} $DEVICE"

echo
echo "Lunch:"
echo "$LUNCH_TARGET"

echo
echo "ZIP:"
echo "$ZIP"

echo
echo "Output:"
echo "$OUT_DIR"

echo
echo "Build time:"
echo "$BUILD_TIME seconds"

echo
echo "============================================================"
echo "                       DONE"
echo "============================================================"
