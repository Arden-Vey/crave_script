#!/bin/bash

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

DEVICE="tissot_mainline"
LUNCH_TARGET="lineage_tissot_mainline-trunk_staging-userdebug"

MANIFEST_URL="https://github.com/JBHPocong/lineage-tissot-manifest.git"
MANIFEST_BRANCH="main"

BUILD_USERNAME="Arden-Vey"
BUILD_HOSTNAME="crave"

OUT_DIR="out/target/product/$DEVICE"

DEVICE_MK="device/xiaomi/mi89xx-mainline/tissot_mainline/device.mk"

# ============================================================
# PREBUILT KERNEL CONFIG
# ============================================================

BOARD_CONFIG="device/xiaomi/mi89xx-mainline/tissot_mainline/BoardConfig.mk"

PREBUILT_KERNEL_DIR="prebuilts/kernel/tissot"
PREBUILT_KERNEL="$PREBUILT_KERNEL_DIR/Image.gz-dtb"

PREBUILT_KERNEL_PROJECT="JBHPocong/lineage-tissot-manifest"
PREBUILT_KERNEL_BRANCH="Image.gz-dtb"

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
    echo "║                  T I S S O T   M A I N L I N E                  ║"
    echo "║                Automated Release Builder                        ║"
    echo "║                                                                 ║"
    echo "╠═════════════════════════════════════════════════════════════════╣"
    echo "║  ROM        : LineageOS 23.2                                    ║"
    echo "║  Device     : tissot_mainline                                   ║"
    echo "║  Branch     : lineage-23.2                                      ║"
    echo "║  Build      : userdebug                                         ║"
    echo "║  Kernel     : PREBUILT Image.gz-dtb                             ║"
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
echo "Lunch target    : $LUNCH_TARGET"
echo "Manifest        : $MANIFEST_URL"
echo "Manifest branch : $MANIFEST_BRANCH"
echo "Kernel project  : $PREBUILT_KERNEL_PROJECT"
echo "Kernel branch   : $PREBUILT_KERNEL_BRANCH"
echo "Kernel file     : $PREBUILT_KERNEL"
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
# VERIFY MANIFEST
# ============================================================

echo
echo "============================================="
echo "           verifying manifest"
echo "============================================="

MANIFEST_FILE=".repo/local_manifests/tissot.xml"

if [ ! -f "$MANIFEST_FILE" ]; then
    echo -e "${RED}[ERROR]${RESET} Manifest tidak ditemukan:"
    echo "$MANIFEST_FILE"
    exit 1
fi

echo -e "${GREEN}[OK]${RESET} Manifest ditemukan"

# ------------------------------------------------------------
# Cek prebuilt kernel project
# ------------------------------------------------------------

if grep -q "prebuilts/kernel/tissot" "$MANIFEST_FILE"; then
    echo -e "${GREEN}[OK]${RESET} Prebuilt kernel project terdeteksi"
else
    echo -e "${RED}[ERROR]${RESET} Prebuilt kernel project tidak ditemukan"
    echo "Expected path:"
    echo "  prebuilts/kernel/tissot"
    exit 1
fi

# ------------------------------------------------------------
# Cek branch Image.gz-dtb
# ------------------------------------------------------------

if grep -q 'revision="Image.gz-dtb"' "$MANIFEST_FILE"; then
    echo -e "${GREEN}[OK]${RESET} Kernel revision: Image.gz-dtb"
else
    echo -e "${RED}[ERROR]${RESET} Revision Image.gz-dtb tidak ditemukan"
    exit 1
fi

# ------------------------------------------------------------
# Pastikan kernel source lama tidak digunakan
# ------------------------------------------------------------

if grep -q "kernel/mainline/msm8953-mainline" "$MANIFEST_FILE"; then
    echo -e "${RED}[ERROR]${RESET} Kernel source lama masih ada di manifest!"
    echo
    grep -n "kernel/mainline/msm8953-mainline" "$MANIFEST_FILE"
    exit 1
else
    echo -e "${GREEN}[OK]${RESET} Kernel source project tidak digunakan"
fi

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
# VERIFY PREBUILT KERNEL
# ============================================================

echo
echo "============================================="
echo "        verifying prebuilt kernel"
echo "============================================="

if [ ! -d "$PREBUILT_KERNEL_DIR" ]; then
    echo -e "${RED}[ERROR]${RESET} Prebuilt kernel directory tidak ditemukan:"
    echo "$PREBUILT_KERNEL_DIR"
    exit 1
fi

echo -e "${GREEN}[OK]${RESET} Kernel directory ditemukan"
echo "$PREBUILT_KERNEL_DIR"

if [ ! -f "$PREBUILT_KERNEL" ]; then
    echo -e "${RED}[ERROR]${RESET} Image.gz-dtb tidak ditemukan:"
    echo "$PREBUILT_KERNEL"
    exit 1
fi

echo -e "${GREEN}[OK]${RESET} Image.gz-dtb ditemukan"

echo
echo "Kernel information:"
echo "--------------------------------------------"

ls -lh "$PREBUILT_KERNEL"

if command -v file >/dev/null 2>&1; then
    file "$PREBUILT_KERNEL"
fi

if command -v sha256sum >/dev/null 2>&1; then
    echo
    echo "SHA256:"
    sha256sum "$PREBUILT_KERNEL"
fi

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
# PATCH LIBJXL (FIX SDK_VERSION)
# ============================================================

echo
echo "============================================="
echo "       patching external/libjxl"
echo "============================================="

if [ -f "external/libjxl/Android.bp" ]; then
    sed -i 's/sdk_version: "none"/sdk_version: "current"/' external/libjxl/Android.bp
    echo -e "${GREEN}[OK]${RESET} external/libjxl/Android.bp dipatch"
else
    echo -e "${YELLOW}[WARNING]${RESET} external/libjxl/Android.bp tidak ditemukan"
fi

# ============================================================
# PATCH: HAPUS VENDOR FIRMWARE BLOBS UNTUK MAINLINE
# ============================================================

echo
echo "============================================="
echo "   patching tissot_mainline/device.mk"
echo "============================================="

if [ -f "$DEVICE_MK" ]; then

    # ------------------------------------------------------------
    # 1. Backup file asli
    # ------------------------------------------------------------
    cp "$DEVICE_MK" "$DEVICE_MK.bak"
    echo "Backup: $DEVICE_MK.bak"

    # ------------------------------------------------------------
    # 2. Comment SEMUA baris yang mengandung vendor/xiaomi/msm8953-common
    #    (termasuk yang di dalam blok PRODUCT_COPY_FILES)
    # ------------------------------------------------------------
    sed -i 's|^\(.*vendor/xiaomi/msm8953-common.*\)$|# \1|' "$DEVICE_MK"

    # ------------------------------------------------------------
    # 3. Comment juga baris "PRODUCT_COPY_FILES += \" yang diikuti
    #    baris comment vendor/xiaomi/msm8953-common
    # ------------------------------------------------------------
    sed -i '/^PRODUCT_COPY_FILES += \\$/{N;/^# .*vendor\/xiaomi\/msm8953-common/s/^/# /}' "$DEVICE_MK"

    # ------------------------------------------------------------
    # 4. Verifikasi: cek baris AKTIF (tanpa # di depan)
    # ------------------------------------------------------------
    ACTIVE_REFS=$(grep -n "^[^#].*vendor/xiaomi/msm8953-common" "$DEVICE_MK" || true)

    if [ -n "$ACTIVE_REFS" ]; then
        echo -e "${RED}[ERROR]${RESET} masih ada referensi vendor blobs yang aktif!"
        echo
        echo "Baris aktif:"
        echo "$ACTIVE_REFS"
        echo
        echo "Semua referensi (termasuk yang di-comment):"
        grep -n "vendor/xiaomi/msm8953-common" "$DEVICE_MK"
        echo
        echo "Restore dari backup..."
        mv "$DEVICE_MK.bak" "$DEVICE_MK"
        exit 1
    else
        echo -e "${GREEN}[OK]${RESET} vendor blobs di-comment di $DEVICE_MK"
        echo -e "${GREEN}[OK]${RESET} verifikasi: tidak ada vendor blobs aktif"
    fi

    # ------------------------------------------------------------
    # 5. Cek apakah ada PRODUCT_COPY_FILES += \ yang kosong
    # ------------------------------------------------------------
    EMPTY_COPY=$(grep -n "^PRODUCT_COPY_FILES += \\\\$" "$DEVICE_MK" || true)

    if [ -n "$EMPTY_COPY" ]; then
        echo -e "${YELLOW}[WARNING]${RESET} ada PRODUCT_COPY_FILES += \\ yang kosong:"
        echo "$EMPTY_COPY"
        echo "Ini mungkin bikin error Makefile. Cek manual:"
        echo "  $DEVICE_MK"
    fi

else
    echo -e "${RED}[ERROR]${RESET} $DEVICE_MK tidak ditemukan"
    exit 1
fi

# ============================================================
# OPTIONAL DEVICE PROP
# ============================================================

PROP_FILE="device/xiaomi/mi89xx-mainline/props/product.prop"

echo
echo "============================================="
echo "       checking product properties"
echo "============================================="

if [ -f "$PROP_FILE" ]; then

    echo "Found:"
    echo "$PROP_FILE"

else

    echo -e "${YELLOW}WARNING:${RESET}"
    echo "$PROP_FILE tidak ditemukan."
    echo "Skipping property modification."

fi

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
# LUNCH
# ============================================================

echo
echo "===================="
echo "       lunch"
echo "===================="

lunch "$LUNCH_TARGET"

echo -e "${GREEN}Lunch completed.${RESET}"

# ============================================================
# DEVICE CHECK
# ============================================================

echo
echo "============================================="
echo "          checking device tree"
echo "============================================="

if [ -d "device/xiaomi/mi89xx-mainline" ]; then
    echo -e "${GREEN}[OK]${RESET} device/xiaomi/mi89xx-mainline"
else
    echo -e "${RED}[ERROR]${RESET} device/xiaomi/mi89xx-mainline"
    exit 1
fi

# ============================================================
# PREBUILT KERNEL CHECK
# ============================================================

echo
echo "============================================="
echo "       checking prebuilt mainline kernel"
echo "============================================="

if [ -f "$PREBUILT_KERNEL" ]; then
    echo -e "${GREEN}[OK]${RESET} $PREBUILT_KERNEL"
else
    echo -e "${RED}[ERROR]${RESET} $PREBUILT_KERNEL tidak ditemukan"
    exit 1
fi

# ------------------------------------------------------------
# Kernel source lama TIDAK diperlukan.
# Hanya beri informasi jika masih ada.
# ------------------------------------------------------------

if [ -d "kernel/mainline/msm8953-mainline" ]; then
    echo -e "${YELLOW}[WARNING]${RESET} kernel source lama masih ada di workspace"
    echo "Path:"
    echo "  kernel/mainline/msm8953-mainline"
    echo
    echo "Build tetap akan menggunakan:"
    echo "  $PREBUILT_KERNEL"
else
    echo -e "${GREEN}[OK]${RESET} Kernel source lama tidak ada"
fi

# ============================================================
# PATCH ONLY TISSOT MAINLINE BOARDCONFIG
# ============================================================

echo
echo "============================================="
echo "       patching tissot BoardConfig"
echo "============================================="

if [ ! -f "$BOARD_CONFIG" ]; then
    echo -e "${RED}[ERROR]${RESET} BoardConfig tidak ditemukan:"
    echo "$BOARD_CONFIG"
    exit 1
fi

echo "BoardConfig:"
echo "$BOARD_CONFIG"

# ------------------------------------------------------------
# Backup BoardConfig
# ------------------------------------------------------------

if [ ! -f "$BOARD_CONFIG.bak-prebuilt" ]; then
    cp "$BOARD_CONFIG" "$BOARD_CONFIG.bak-prebuilt"
    echo -e "${GREEN}[OK]${RESET} Backup dibuat:"
    echo "$BOARD_CONFIG.bak-prebuilt"
else
    echo -e "${YELLOW}[INFO]${RESET} Backup sudah ada:"
    echo "$BOARD_CONFIG.bak-prebuilt"
fi

# ------------------------------------------------------------
# Hapus konfigurasi kernel lama yang dapat memaksa build
# kernel source atau DTB terpisah.
#
# HANYA BoardConfig tissot_mainline yang dipatch.
# BoardConfig device lain TIDAK disentuh.
# ------------------------------------------------------------

python3 - "$BOARD_CONFIG" <<'PY'
import re
import sys

path = sys.argv[1]

with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

variables = {
    "TARGET_KERNEL_SOURCE",
    "TARGET_KERNEL_CONFIG",
    "TARGET_KERNEL_CONFIG_EXT",
    "TARGET_PREBUILT_KERNEL",
    "TARGET_FORCE_PREBUILT_KERNEL",
    "BOARD_KERNEL_IMAGE_NAME",
    "BOARD_PREBUILT_DTBIMAGE_DIR",
    "TARGET_PREBUILT_DTB",
    "BOARD_PREBUILT_DTB",
    "BOARD_KERNEL_DTB",
    "TARGET_KERNEL_DTB",
    "TARGET_KERNEL_DTBIMAGE",
    "BOARD_KERNEL_SEPARATED_DT",
}

output = []

for line in lines:
    stripped = line.lstrip()

    if stripped.startswith("#"):
        output.append(line)
        continue

    match = re.match(
        r'^\s*([A-Za-z0-9_]+)\s*(?::|\?|\+)?=\s*',
        line
    )

    if match and match.group(1) in variables:
        output.append("# PREBUILT-KERNEL: disabled old setting: " + line)
    else:
        output.append(line)

with open(path, "w", encoding="utf-8") as f:
    f.writelines(output)

PY

# ------------------------------------------------------------
# Tambahkan konfigurasi prebuilt kernel.
# Image.gz-dtb sudah mengandung DTB.
# ------------------------------------------------------------

cat >> "$BOARD_CONFIG" <<'EOF'

# ============================================================
# PREBUILT MAINLINE KERNEL
# ============================================================
#
# Image.gz-dtb already contains the DTB.
# Do NOT configure a separate dtb.img.
#

TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64

BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb

TARGET_PREBUILT_KERNEL := prebuilts/kernel/tissot/Image.gz-dtb

EOF

echo -e "${GREEN}[OK]${RESET} Prebuilt kernel configuration ditambahkan"

# ============================================================
# BOARDCONFIG VERIFICATION
# ============================================================

echo
echo "============================================="
echo "       verifying tissot BoardConfig"
echo "============================================="

echo
echo "Relevant kernel configuration:"
echo "--------------------------------------------"

grep -nE \
    'TARGET_KERNEL_ARCH|TARGET_KERNEL_HEADER_ARCH|BOARD_KERNEL_IMAGE_NAME|TARGET_PREBUILT_KERNEL|TARGET_KERNEL_SOURCE|TARGET_KERNEL_CONFIG|DTB' \
    "$BOARD_CONFIG" \
    || true

# ------------------------------------------------------------
# Pastikan TARGET_PREBUILT_KERNEL aktif.
# ------------------------------------------------------------

ACTIVE_PREBUILT=$(grep -n \
    '^[[:space:]]*TARGET_PREBUILT_KERNEL[[:space:]]*[:?+]*=' \
    "$BOARD_CONFIG" \
    | tail -n 1 \
    || true)

if [ -z "$ACTIVE_PREBUILT" ]; then
    echo -e "${RED}[ERROR]${RESET} TARGET_PREBUILT_KERNEL tidak aktif"
    exit 1
fi

echo
echo -e "${GREEN}[OK]${RESET} TARGET_PREBUILT_KERNEL aktif:"
echo "$ACTIVE_PREBUILT"

# ------------------------------------------------------------
# Pastikan target menunjuk ke Image.gz-dtb.
# ------------------------------------------------------------

if grep -q \
    '^[[:space:]]*TARGET_PREBUILT_KERNEL[[:space:]]*[:?+]*=[[:space:]]*prebuilts/kernel/tissot/Image.gz-dtb' \
    "$BOARD_CONFIG"; then

    echo -e "${GREEN}[OK]${RESET} TARGET_PREBUILT_KERNEL benar"

else

    echo -e "${RED}[ERROR]${RESET} TARGET_PREBUILT_KERNEL salah"
    exit 1

fi

# ============================================================
# POST-LUNCH KERNEL VERIFICATION
# ============================================================

echo
echo "============================================="
echo "       post-lunch kernel verification"
echo "============================================="

if [ -n "${TARGET_PREBUILT_KERNEL:-}" ]; then

    echo "TARGET_PREBUILT_KERNEL=$TARGET_PREBUILT_KERNEL"

    case "$TARGET_PREBUILT_KERNEL" in
        "$ANDROID_BUILD_TOP/prebuilts/kernel/tissot/Image.gz-dtb")
            echo -e "${GREEN}[OK]${RESET} TARGET_PREBUILT_KERNEL sesuai"
            ;;
        *)
            echo -e "${YELLOW}[WARNING]${RESET} TARGET_PREBUILT_KERNEL:"
            echo "$TARGET_PREBUILT_KERNEL"
            ;;
    esac

else

    echo -e "${YELLOW}[INFO]${RESET} TARGET_PREBUILT_KERNEL belum tersedia di environment"
    echo "BoardConfig tetap menunjuk ke:"
    echo "  prebuilts/kernel/tissot/Image.gz-dtb"

fi

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
# VENDOR COMMON VERIFICATION
# ============================================================

echo
echo "===================================="
echo "    Checking vendor/vendor-common   "
echo "===================================="

# Cek baris AKTIF (tanpa # di depan)
if grep -q "^[^#].*vendor/xiaomi/msm8953-common" "$DEVICE_MK"; then
    echo -e "${RED}[ERROR]${RESET} masih ada referensi vendor blobs yang aktif!"
    echo
    echo "Baris aktif:"
    grep -n "^[^#].*vendor/xiaomi/msm8953-common" "$DEVICE_MK"
    echo
    echo "Semua referensi (termasuk yang di-comment):"
    grep -n "vendor/xiaomi/msm8953-common" "$DEVICE_MK"
    exit 1
fi

# Cek apakah ada PRODUCT_COPY_FILES += \ yang kosong
if grep -q "^PRODUCT_COPY_FILES += \\\\$" "$DEVICE_MK"; then
    echo -e "${YELLOW}[WARNING]${RESET} ada PRODUCT_COPY_FILES += \\ yang kosong"
fi

echo -e "${GREEN}[OK]${RESET} patch berhasil"

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
echo "Kernel mode     : PREBUILT"
echo "Kernel project  : $PREBUILT_KERNEL_PROJECT"
echo "Kernel branch   : $PREBUILT_KERNEL_BRANCH"
echo "Kernel          : $PREBUILT_KERNEL"
echo "DTB             : EMBEDDED"
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
# BUILD (TANPA set -e AGAR SCRIPT TIDAK BERHENTI DI ERROR)
# ============================================================

set +e
mka bacon
BUILD_STATUS=$?
set -e

# ============================================================
# BUILD TIME
# ============================================================

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

# ============================================================
# CEK STATUS BUILD
# ============================================================

if [ $BUILD_STATUS -ne 0 ]; then

    echo
    echo "============================================================"
    echo "                    BUILD FAILED"
    echo "============================================================"

    echo
    echo -e "${RED}${BOLD}Build failed with exit status: $BUILD_STATUS${RESET}"

    echo
    echo "Build time:"
    echo "$BUILD_TIME seconds"

    echo
    echo "Cek log di:"
    echo "  out/error.log"
    echo "  out/verbose.log.gz"

    exit $BUILD_STATUS

fi

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
    exit 1

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
    vendor.img \
    system.img \
    init_boot.img \
    recovery.img
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

if command -v sha256sum >/dev/null 2>&1; then

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
echo "Kernel:"
echo "$PREBUILT_KERNEL"

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
