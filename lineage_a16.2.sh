#!/bin/bash

# ============================================================
# LINEAGEOS 23.2 TISSOT MAINLINE
# PREBUILT Image.gz-dtb BUILD SCRIPT
# ============================================================

# ============================================================
# SAFETY
# ============================================================

set -o pipefail

# ============================================================
# COLORS
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
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

# ============================================================
# PREBUILT KERNEL
# ============================================================

PREBUILT_KERNEL_PROJECT="JBHPocong/lineage-tissot-manifest"
PREBUILT_KERNEL_BRANCH="Image.gz-dtb"

PREBUILT_KERNEL_DIR="prebuilts/kernel/tissot"

PREBUILT_KERNEL_NAME="Image.gz-dtb"

PREBUILT_KERNEL="$PREBUILT_KERNEL_DIR/$PREBUILT_KERNEL_NAME"


# ============================================================
# BUILD IDENTITY
# ============================================================

BUILD_USERNAME="Arden-Vey"
BUILD_HOSTNAME="crave"


# ============================================================
# OUTPUT
# ============================================================

OUT_DIR="out/target/product/$DEVICE"


# ============================================================
# DEVICE TREE
# ============================================================

DEVICE_DIR="device/xiaomi/mi89xx-mainline"

DEVICE_MK="$DEVICE_DIR/tissot_mainline/device.mk"


# ============================================================
# BACKUP DIRECTORY
# ============================================================

PATCH_BACKUP_DIR="$DEVICE_DIR/.prebuilt-kernel-backup"


# ============================================================
# BANNER
# ============================================================

banner() {

    clear

    echo -e "${CYAN}${BOLD}"

    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                    ║"
    echo "║      ██╗     ██╗███╗   ██╗███████╗ █████╗  ██████╗ ███████╗       ║"
    echo "║      ██║     ██║████╗  ██║██╔════╝██╔══██╗██╔════╝ ██╔════╝       ║"
    echo "║      ██║     ██║██╔██╗ ██║█████╗  ███████║██║  ███╗█████╗         ║"
    echo "║      ██║     ██║██║╚██╗██║██╔══╝  ██╔══██║██║   ██║██╔══╝         ║"
    echo "║      ███████╗██║██║ ╚████║███████╗██║  ██║╚██████╔╝███████╗       ║"
    echo "║      ╚══════╝╚═╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝       ║"
    echo "║                                                                    ║"
    echo "║                    T I S S O T   M A I N L I N E                  ║"
    echo "║                                                                    ║"
    echo "║                  PREBUILT KERNEL BUILDER                          ║"
    echo "║                                                                    ║"
    echo "╠════════════════════════════════════════════════════════════════════╣"
    echo "║  ROM        : LineageOS 23.2                                      ║"
    echo "║  Device     : tissot_mainline                                     ║"
    echo "║  Kernel     : Image.gz-dtb                                       ║"
    echo "║  Kernel     : PREBUILT                                            ║"
    echo "║  Build      : userdebug                                           ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"

    echo -e "${RESET}"
}


# ============================================================
# LOG FUNCTIONS
# ============================================================

log_info() {

    echo -e "${CYAN}[INFO]${RESET} $1"

}


log_ok() {

    echo -e "${GREEN}[OK]${RESET} $1"

}


log_warn() {

    echo -e "${YELLOW}[WARNING]${RESET} $1"

}


log_error() {

    echo -e "${RED}[ERROR]${RESET} $1"

}


die() {

    log_error "$1"

    exit 1

}


# ============================================================
# BANNER
# ============================================================

banner


# ============================================================
# BUILD INFO
# ============================================================

echo

echo -e "${BLUE}${BOLD}Build configuration${RESET}"

echo "------------------------------------------------------------"

echo "ROM                  : $ROM_NAME"
echo "ROM branch           : $ROM_BRANCH"
echo "Device               : $DEVICE"
echo "Lunch target         : $LUNCH_TARGET"
echo "Manifest             : $MANIFEST_URL"
echo "Manifest branch      : $MANIFEST_BRANCH"
echo "Kernel repository    : $PREBUILT_KERNEL_PROJECT"
echo "Kernel branch        : $PREBUILT_KERNEL_BRANCH"
echo "Kernel file          : $PREBUILT_KERNEL"
echo "Output               : $OUT_DIR"

echo


# ============================================================
# BASIC REQUIREMENTS
# ============================================================

echo
echo "============================================================"
echo "                 CHECKING REQUIREMENTS"
echo "============================================================"
echo


command -v git >/dev/null 2>&1 \
    || die "git tidak ditemukan"

command -v repo >/dev/null 2>&1 \
    || die "repo tidak ditemukan"

command -v sed >/dev/null 2>&1 \
    || die "sed tidak ditemukan"

command -v grep >/dev/null 2>&1 \
    || die "grep tidak ditemukan"

command -v find >/dev/null 2>&1 \
    || die "find tidak ditemukan"

command -v awk >/dev/null 2>&1 \
    || die "awk tidak ditemukan"

command -v file >/dev/null 2>&1 \
    || log_warn "file command tidak ditemukan"


log_ok "Basic tools tersedia"


# ============================================================
# CRAVE CHECK
# ============================================================

if [ ! -x "/opt/crave/resync.sh" ]; then

    log_warn "/opt/crave/resync.sh tidak ditemukan"

    log_warn "Script akan tetap lanjut sampai tahap sync."

else

    log_ok "Crave resync ditemukan"

fi


# ============================================================
# CLEAN LOCAL MANIFEST
# ============================================================

echo

echo "============================================================"
echo "              CLEANING LOCAL MANIFEST"
echo "============================================================"
echo


if [ -d ".repo/local_manifests" ]; then

    log_info "Menghapus local manifests lama..."

    rm -rf ".repo/local_manifests"

    log_ok "Local manifests lama dihapus"

else

    log_ok "Tidak ada local manifests lama"

fi


# ============================================================
# REPO INIT
# ============================================================

echo

echo "============================================================"
echo "                       REPO INIT"
echo "============================================================"
echo


repo init \
    -u https://github.com/LineageOS/android.git \
    -b "$ROM_BRANCH" \
    --depth=1 \
    --git-lfs

if [ $? -ne 0 ]; then

    die "repo init gagal"

fi


log_ok "repo init completed"


# ============================================================
# LOCAL MANIFEST
# ============================================================

echo

echo "============================================================"
echo "                  CLONING LOCAL MANIFEST"
echo "============================================================"
echo


git clone \
    -b "$MANIFEST_BRANCH" \
    --depth=1 \
    "$MANIFEST_URL" \
    ".repo/local_manifests"

if [ $? -ne 0 ]; then

    die "Gagal clone local manifest"

fi


log_ok "Local manifest cloned"


# ============================================================
# VERIFY MANIFEST
# ============================================================

echo

echo "============================================================"
echo "                 VERIFYING MANIFEST"
echo "============================================================"
echo


MANIFEST_FILE=".repo/local_manifests/tissot.xml"


if [ ! -f "$MANIFEST_FILE" ]; then

    die "Manifest tidak ditemukan: $MANIFEST_FILE"

fi


log_ok "Manifest ditemukan"


# ============================================================
# VERIFY PREBUILT PROJECT
# ============================================================

if ! grep -q "JBHPocong/lineage-tissot-manifest" "$MANIFEST_FILE"; then

    die "Project prebuilt kernel tidak ditemukan di manifest"

fi


if ! grep -q 'revision="Image.gz-dtb"' "$MANIFEST_FILE"; then

    die "Branch Image.gz-dtb tidak ditemukan di manifest"

fi


log_ok "Prebuilt kernel project terdeteksi"


# ============================================================
# VERIFY OLD KERNEL PROJECT IS GONE
# ============================================================

if grep -q "msm8953-mainline/linux" "$MANIFEST_FILE"; then

    log_error "Manifest masih mengandung kernel source project!"

    grep -n "msm8953-mainline/linux" "$MANIFEST_FILE" || true

    die "Hapus kernel source project dari manifest"

fi


log_ok "Kernel source project tidak digunakan"


# ============================================================
# CRAVE SYNC
# ============================================================

echo

echo "============================================================"
echo "                     CRAVE SYNC"
echo "============================================================"
echo


if [ -x "/opt/crave/resync.sh" ]; then

    /opt/crave/resync.sh

    SYNC_STATUS=$?

else

    log_warn "/opt/crave/resync.sh tidak tersedia"

    log_info "Mencoba resync menggunakan environment yang tersedia..."

    if command -v crave >/dev/null 2>&1; then

        crave resync

        SYNC_STATUS=$?

    else

        die "Crave resync tidak tersedia"

    fi

fi


if [ "$SYNC_STATUS" -ne 0 ]; then

    die "Repository sync gagal"

fi


log_ok "Repository sync completed"


# ============================================================
# VERIFY PREBUILT KERNEL DIRECTORY
# ============================================================

echo

echo "============================================================"
echo "              CHECKING PREBUILT KERNEL"
echo "============================================================"
echo


if [ ! -d "$PREBUILT_KERNEL_DIR" ]; then

    die "Direktori prebuilt kernel tidak ditemukan: $PREBUILT_KERNEL_DIR"

fi


log_ok "Prebuilt kernel directory ditemukan"


# ============================================================
# LOCATE Image.gz-dtb
# ============================================================

echo

echo "Searching Image.gz-dtb..."

FOUND_KERNELS=$(find "$PREBUILT_KERNEL_DIR" \
    -type f \
    -name "Image.gz-dtb" \
    2>/dev/null)


KERNEL_COUNT=$(printf '%s\n' "$FOUND_KERNELS" | \
    sed '/^$/d' | wc -l)


if [ "$KERNEL_COUNT" -eq 0 ]; then

    log_error "Image.gz-dtb tidak ditemukan!"

    echo

    echo "Isi directory:"

    find "$PREBUILT_KERNEL_DIR" \
        -maxdepth 3 \
        -type f \
        -printf '%p\n' \
        2>/dev/null \
        | head -100

    echo

    die "Prebuilt Image.gz-dtb tidak tersedia"

fi


if [ "$KERNEL_COUNT" -gt 1 ]; then

    log_warn "Ditemukan lebih dari satu Image.gz-dtb:"

    echo "$FOUND_KERNELS"

    die "Ambiguous prebuilt kernel"

fi


FOUND_KERNEL=$(printf '%s\n' "$FOUND_KERNELS" | sed '/^$/d')


log_ok "Image.gz-dtb ditemukan:"
echo "      $FOUND_KERNEL"


# ============================================================
# NORMALIZE PREBUILT LOCATION
# ============================================================

if [ "$FOUND_KERNEL" != "$PREBUILT_KERNEL" ]; then

    log_info "Memindahkan Image.gz-dtb ke lokasi standar..."

    cp "$FOUND_KERNEL" "$PREBUILT_KERNEL"

    if [ $? -ne 0 ]; then

        die "Gagal menyalin Image.gz-dtb"

    fi

    log_ok "Image.gz-dtb disiapkan di:"
    echo "      $PREBUILT_KERNEL"

fi


# ============================================================
# VERIFY KERNEL FILE
# ============================================================

echo

echo "============================================================"
echo "               PREBUILT KERNEL INFO"
echo "============================================================"
echo


if [ ! -f "$PREBUILT_KERNEL" ]; then

    die "Final prebuilt kernel tidak ditemukan"

fi


KERNEL_SIZE=$(du -h "$PREBUILT_KERNEL" | awk '{print $1}')


echo "Path : $PREBUILT_KERNEL"
echo "Size : $KERNEL_SIZE"


if command -v file >/dev/null 2>&1; then

    echo

    echo "File information:"

    file "$PREBUILT_KERNEL"

fi


# ============================================================
# DEVICE TREE CHECK
# ============================================================

echo

echo "============================================================"
echo "                  DEVICE TREE CHECK"
echo "============================================================"
echo


if [ ! -d "$DEVICE_DIR" ]; then

    die "Device tree tidak ditemukan: $DEVICE_DIR"

fi


log_ok "Device tree ditemukan"


# ============================================================
# FIND BOARDCONFIG
# ============================================================

echo

echo "============================================================"
echo "                 SEARCHING BOARDCONFIG"
echo "============================================================"
echo


BOARDCONFIGS=$(find "$DEVICE_DIR" \
    -type f \
    -name "BoardConfig.mk" \
    2>/dev/null)


BOARD_COUNT=$(printf '%s\n' "$BOARDCONFIGS" \
    | sed '/^$/d' \
    | wc -l)


if [ "$BOARD_COUNT" -eq 0 ]; then

    die "BoardConfig.mk tidak ditemukan di $DEVICE_DIR"

fi


echo "BoardConfig files ditemukan:"

echo "$BOARDCONFIGS"


# ============================================================
# BACKUP DEVICE TREE
# ============================================================

echo

echo "============================================================"
echo "                BACKING UP BOARD CONFIG"
echo "============================================================"
echo


mkdir -p "$PATCH_BACKUP_DIR"


while IFS= read -r BOARD; do

    [ -z "$BOARD" ] && continue

    SAFE_NAME=$(echo "$BOARD" | sed 's|/|_|g')

    BACKUP="$PATCH_BACKUP_DIR/$SAFE_NAME"

    cp "$BOARD" "$BACKUP"

    log_ok "Backup:"
    echo "      $BOARD"
    echo "      -> $BACKUP"

done <<< "$BOARDCONFIGS"


# ============================================================
# PATCH BOARDCONFIG FUNCTION
# ============================================================

patch_boardconfig() {

    local BOARD="$1"

    echo
    echo "------------------------------------------------------------"
    echo "Patching:"
    echo "$BOARD"
    echo "------------------------------------------------------------"


    # --------------------------------------------------------
    # Remove old TARGET_PREBUILT_KERNEL definitions
    # --------------------------------------------------------

    sed -i \
        '/^[[:space:]]*TARGET_PREBUILT_KERNEL[[:space:]]*[:+?]*=/d' \
        "$BOARD"


    # --------------------------------------------------------
    # Remove kernel source configuration
    # --------------------------------------------------------

    sed -i \
        '/^[[:space:]]*TARGET_KERNEL_SOURCE[[:space:]]*[:+?]*=/d' \
        "$BOARD"


    # --------------------------------------------------------
    # Remove old kernel config definitions
    # --------------------------------------------------------

    sed -i \
        '/^[[:space:]]*TARGET_KERNEL_CONFIG[[:space:]]*[:+?]*=/d' \
        "$BOARD"


    # --------------------------------------------------------
    # Remove kernel build output directory configuration
    # --------------------------------------------------------

    sed -i \
        '/^[[:space:]]*TARGET_KERNEL_ARCH[[:space:]]*[:+?]*=/d' \
        "$BOARD"


    # --------------------------------------------------------
    # Remove old TARGET_KERNEL_CLANG_COMPILE
    # --------------------------------------------------------

    sed -i \
        '/^[[:space:]]*TARGET_KERNEL_CLANG_COMPILE[[:space:]]*[:+?]*=/d' \
        "$BOARD"


    # --------------------------------------------------------
    # Remove old TARGET_KERNEL_CROSS_COMPILE_PREFIX
    # --------------------------------------------------------

    sed -i \
        '/^[[:space:]]*TARGET_KERNEL_CROSS_COMPILE_PREFIX[[:space:]]*[:+?]*=/d' \
        "$BOARD"


    # --------------------------------------------------------
    # Remove old TARGET_KERNEL_BINARIES
    # --------------------------------------------------------

    sed -i \
        '/^[[:space:]]*TARGET_KERNEL_BINARIES[[:space:]]*[:+?]*=/d' \
        "$BOARD"


    # --------------------------------------------------------
    # Remove old KERNEL_DEFCONFIG
    # --------------------------------------------------------

    sed -i \
        '/^[[:space:]]*KERNEL_DEFCONFIG[[:space:]]*[:+?]*=/d' \
        "$BOARD"


    # --------------------------------------------------------
    # Remove old BOARD_KERNEL_IMAGE_NAME
    # --------------------------------------------------------

    sed -i \
        '/^[[:space:]]*BOARD_KERNEL_IMAGE_NAME[[:space:]]*[:+?]*=/d' \
        "$BOARD"


    # --------------------------------------------------------
    # Remove duplicate comments created by previous runs
    # --------------------------------------------------------

    sed -i \
        '/^[[:space:]]*#.*PREBUILT KERNEL.*$/d' \
        "$BOARD"


    # --------------------------------------------------------
    # Add prebuilt kernel configuration
    # --------------------------------------------------------

    cat >> "$BOARD" <<EOF

# ============================================================
# PREBUILT MAINLINE KERNEL
# ============================================================

# Automatically injected by prebuilt kernel build script.
# Kernel source compilation is intentionally disabled.

TARGET_PREBUILT_KERNEL := $PREBUILT_KERNEL

EOF


    log_ok "BoardConfig patched"

}


# ============================================================
# PATCH ALL BOARDCONFIG FILES
# ============================================================

while IFS= read -r BOARD; do

    [ -z "$BOARD" ] && continue

    patch_boardconfig "$BOARD"

done <<< "$BOARDCONFIGS"


# ============================================================
# VERIFY BOARDCONFIG
# ============================================================

echo

echo "============================================================"
echo "                VERIFYING BOARDCONFIG"
echo "============================================================"
echo


BOARD_VERIFY_FAILED=0


while IFS= read -r BOARD; do

    [ -z "$BOARD" ] && continue

    echo
    echo "Checking:"
    echo "$BOARD"


    if grep -q \
        "TARGET_PREBUILT_KERNEL.*$PREBUILT_KERNEL" \
        "$BOARD"; then

        log_ok "TARGET_PREBUILT_KERNEL aktif"

    else

        log_error "TARGET_PREBUILT_KERNEL tidak ditemukan"

        BOARD_VERIFY_FAILED=1

    fi


    if grep -qE \
        "^[[:space:]]*TARGET_KERNEL_SOURCE[[:space:]]*[:+?]*=" \
        "$BOARD"; then

        log_error "TARGET_KERNEL_SOURCE masih aktif"

        BOARD_VERIFY_FAILED=1

    else

        log_ok "TARGET_KERNEL_SOURCE tidak aktif"

    fi


done <<< "$BOARDCONFIGS"


if [ "$BOARD_VERIFY_FAILED" -ne 0 ]; then

    die "BoardConfig verification gagal"

fi


# ============================================================
# DEVICE.MK BACKUP
# ============================================================

echo

echo "============================================================"
echo "                 PATCHING DEVICE.MK"
echo "============================================================"
echo


if [ ! -f "$DEVICE_MK" ]; then

    die "device.mk tidak ditemukan: $DEVICE_MK"

fi


cp "$DEVICE_MK" "$DEVICE_MK.bak.prebuilt-kernel"


log_ok "device.mk backup dibuat"


# ============================================================
# REMOVE XIAOMI VENDOR BLOBS
# ============================================================

sed -i \
    's|^\(.*vendor/xiaomi/msm8953-common.*\)$|# \1|' \
    "$DEVICE_MK"


sed -i \
    '/^PRODUCT_COPY_FILES += \\$/{N;/^# .*vendor\/xiaomi\/msm8953-common/s/^/# /}' \
    "$DEVICE_MK"


# ============================================================
# DEVICE.MK VERIFICATION
# ============================================================

ACTIVE_VENDOR_REFS=$(grep \
    -n \
    "^[^#].*vendor/xiaomi/msm8953-common" \
    "$DEVICE_MK" \
    || true)


if [ -n "$ACTIVE_VENDOR_REFS" ]; then

    log_error "Vendor Xiaomi reference masih aktif!"

    echo "$ACTIVE_VENDOR_REFS"

    mv "$DEVICE_MK.bak.prebuilt-kernel" "$DEVICE_MK"

    die "device.mk gagal dipatch"

fi


log_ok "Vendor Xiaomi blobs tidak aktif"


# ============================================================
# LIBJXL PATCH
# ============================================================

echo

echo "============================================================"
echo "                   PATCHING LIBJXL"
echo "============================================================"
echo


if [ -f "external/libjxl/Android.bp" ]; then

    sed -i \
        's/sdk_version: "none"/sdk_version: "current"/g' \
        external/libjxl/Android.bp

    log_ok "external/libjxl patched"

else

    log_warn "external/libjxl/Android.bp tidak ditemukan"

fi


# ============================================================
# PRODUCT PROPS CHECK
# ============================================================

PROP_FILE="$DEVICE_DIR/props/product.prop"


echo

echo "============================================================"
echo "               PRODUCT PROPERTY CHECK"
echo "============================================================"
echo


if [ -f "$PROP_FILE" ]; then

    log_ok "Product properties ditemukan:"
    echo "      $PROP_FILE"

else

    log_warn "product.prop tidak ditemukan"

fi


# ============================================================
# PREBUILT KERNEL FINAL CHECK
# ============================================================

echo

echo "============================================================"
echo "              FINAL KERNEL VERIFICATION"
echo "============================================================"
echo


if [ ! -f "$PREBUILT_KERNEL" ]; then

    die "Image.gz-dtb hilang sebelum build"

fi


echo "Kernel:"
echo "$PREBUILT_KERNEL"

echo

echo "Size:"
du -h "$PREBUILT_KERNEL"


echo

echo "SHA256:"

sha256sum "$PREBUILT_KERNEL"


# ============================================================
# SOURCE KERNEL CHECK
# ============================================================

echo

echo "============================================================"
echo "               KERNEL SOURCE CHECK"
echo "============================================================"
echo


if [ -d "kernel/mainline/msm8953-mainline" ]; then

    log_warn "Kernel source directory masih ada:"
    echo "      kernel/mainline/msm8953-mainline"

    log_warn "Tetapi manifest sudah tidak menggunakannya."

else

    log_ok "Kernel source tidak disync"

fi


# ============================================================
# BUILD ENVIRONMENT
# ============================================================

echo

echo "============================================================"
echo "              BUILD ENVIRONMENT SETUP"
echo "============================================================"
echo


export BUILD_USERNAME="$BUILD_USERNAME"
export BUILD_HOSTNAME="$BUILD_HOSTNAME"

export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
export ALLOW_MISSING_DEPENDENCIES=true

export LC_ALL=C


# ------------------------------------------------------------
# Explicit prebuilt kernel environment
# ------------------------------------------------------------

export TARGET_PREBUILT_KERNEL="$PWD/$PREBUILT_KERNEL"


echo "BUILD_USERNAME=$BUILD_USERNAME"
echo "BUILD_HOSTNAME=$BUILD_HOSTNAME"
echo "BUILD_BROKEN_MISSING_REQUIRED_MODULES=$BUILD_BROKEN_MISSING_REQUIRED_MODULES"
echo "ALLOW_MISSING_DEPENDENCIES=$ALLOW_MISSING_DEPENDENCIES"

echo

echo "TARGET_PREBUILT_KERNEL:"
echo "$TARGET_PREBUILT_KERNEL"


# ============================================================
# LOAD BUILD ENVIRONMENT
# ============================================================

echo

echo "============================================================"
echo "              LOADING BUILD ENVIRONMENT"
echo "============================================================"
echo


source build/envsetup.sh


if [ $? -ne 0 ]; then

    die "Gagal load build/envsetup.sh"

fi


log_ok "Build environment loaded"


# ============================================================
# LUNCH
# ============================================================

echo

echo "============================================================"
echo "                         LUNCH"
echo "============================================================"
echo


lunch "$LUNCH_TARGET"


if [ $? -ne 0 ]; then

    die "Lunch gagal: $LUNCH_TARGET"

fi


log_ok "Lunch completed"


# ============================================================
# POST-LUNCH KERNEL VARIABLE
# ============================================================

echo

echo "============================================================"
echo "             POST-LUNCH KERNEL VERIFICATION"
echo "============================================================"
echo


echo "TARGET_PREBUILT_KERNEL=$TARGET_PREBUILT_KERNEL"


# ============================================================
# DEVICE CHECK
# ============================================================

echo

echo "============================================================"
echo "                  DEVICE TREE CHECK"
echo "============================================================"
echo


if [ -d "$DEVICE_DIR" ]; then

    log_ok "$DEVICE_DIR"

else

    die "Device tree tidak ditemukan"

fi


# ============================================================
# BOARDCONFIG FINAL CHECK
# ============================================================

echo

echo "============================================================"
echo "               BOARDCONFIG FINAL CHECK"
echo "============================================================"
echo


while IFS= read -r BOARD; do

    [ -z "$BOARD" ] && continue

    echo
    echo "BoardConfig:"
    echo "$BOARD"

    grep -n \
        "TARGET_PREBUILT_KERNEL" \
        "$BOARD" \
        || true

done <<< "$BOARDCONFIGS"


# ============================================================
# PRE-BUILD SUMMARY
# ============================================================

echo

echo "============================================================"
echo "                    PRE-BUILD SUMMARY"
echo "============================================================"

echo

echo "ROM                 : $ROM_NAME"
echo "Branch              : $ROM_BRANCH"
echo "Device              : $DEVICE"
echo "Lunch               : $LUNCH_TARGET"

echo

echo "Kernel mode         : PREBUILT"
echo "Kernel              : Image.gz-dtb"
echo "Kernel path         : $PREBUILT_KERNEL"

echo

echo "Manifest            : $MANIFEST_URL"
echo "Manifest branch     : $MANIFEST_BRANCH"

echo

echo "Build username      : $BUILD_USERNAME"
echo "Build hostname      : $BUILD_HOSTNAME"

echo

echo "CPU threads         : $(nproc --all)"

echo

echo "Output              : $OUT_DIR"

echo

echo "TARGET_PREBUILT_KERNEL:"
echo "$TARGET_PREBUILT_KERNEL"

echo

echo "============================================================"
echo "                 STARTING BUILD"
echo "============================================================"

echo

echo "Kernel source compilation: DISABLED"
echo "Prebuilt kernel          : ENABLED"

echo

echo "Command:"
echo

echo "    mka bacon"

echo


# ============================================================
# BUILD START
# ============================================================

BUILD_START=$(date +%s)


# ============================================================
# BUILD
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
# BUILD FAILURE
# ============================================================

if [ "$BUILD_STATUS" -ne 0 ]; then

    echo

    echo "============================================================"
    echo "                    BUILD FAILED"
    echo "============================================================"

    echo

    log_error "Build failed with exit status: $BUILD_STATUS"

    echo

    echo "Build time:"
    echo "$BUILD_TIME seconds"

    echo

    echo "Important files:"

    echo "  out/error.log"

    echo "  out/verbose.log.gz"

    echo

    echo "Prebuilt kernel:"
    echo "$PREBUILT_KERNEL"

    echo

    exit "$BUILD_STATUS"

fi


# ============================================================
# BUILD SUCCESS
# ============================================================

echo

echo "============================================================"
echo "                    BUILD SUCCESS"
echo "============================================================"

echo

log_ok "Build completed successfully."


echo

echo "Build time:"
echo "$BUILD_TIME seconds"


# ============================================================
# OUTPUT DIRECTORY
# ============================================================

echo

echo "============================================================"
echo "                  BUILD ARTIFACTS"
echo "============================================================"


if [ ! -d "$OUT_DIR" ]; then

    die "Output directory tidak ditemukan: $OUT_DIR"

fi


echo

echo "Output directory:"
echo "$OUT_DIR"


echo

echo "Files:"
echo "------------------------------------------------------------"


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
# BOOT IMAGE CHECK
# ============================================================

echo

echo "============================================================"
echo "                    BOOT IMAGE CHECK"
echo "============================================================"
echo


BOOT_IMG="$OUT_DIR/boot.img"


if [ -f "$BOOT_IMG" ]; then

    log_ok "boot.img ditemukan"

    echo

    echo "boot.img:"
    echo "$BOOT_IMG"

    echo

    echo "Size:"
    du -h "$BOOT_IMG"

else

    log_warn "boot.img tidak ditemukan"

fi


# ============================================================
# OTHER IMAGE CHECK
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

        log_ok "$IMAGE"

    else

        echo -e "${YELLOW}[--]${RESET} $IMAGE"

    fi

done


# ============================================================
# ROM ZIP
# ============================================================

echo

echo "============================================================"
echo "                    ROM ZIP CHECK"
echo "============================================================"
echo


ZIP=$(find "$OUT_DIR" \
    -maxdepth 1 \
    -type f \
    -name "*.zip" \
    ! -name "*ota*.zip" \
    | head -n 1)


if [ -n "$ZIP" ]; then

    log_ok "ROM ZIP found:"

    echo
    echo "$ZIP"

else

    log_warn "ROM ZIP tidak ditemukan"

fi


# ============================================================
# SHA256
# ============================================================

echo

echo "============================================================"
echo "                       SHA256"
echo "============================================================"
echo


if [ -n "$ZIP" ]; then

    sha256sum "$ZIP"

fi


if [ -f "$BOOT_IMG" ]; then

    echo

    echo "boot.img SHA256:"

    sha256sum "$BOOT_IMG"

fi


# ============================================================
# FINAL KERNEL INFO
# ============================================================

echo

echo "============================================================"
echo "                  FINAL KERNEL INFO"
echo "============================================================"
echo


echo "Prebuilt kernel:"
echo "$PREBUILT_KERNEL"

echo

echo "Kernel SHA256:"
sha256sum "$PREBUILT_KERNEL"


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
echo "  PREBUILT Image.gz-dtb"

echo

echo "Kernel source compilation:"
echo "  DISABLED"

echo

if [ -n "$ZIP" ]; then

    echo "ZIP:"
    echo "$ZIP"

fi


if [ -f "$BOOT_IMG" ]; then

    echo

    echo "BOOT:"
    echo "$BOOT_IMG"

fi


echo

echo "Output:"
echo "$OUT_DIR"

echo

echo "Build time:"
echo "$BUILD_TIME seconds"

echo

echo "============================================================"
echo "                         DONE"
echo "============================================================"

echo
