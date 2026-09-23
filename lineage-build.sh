#!/bin/bash
set -eo pipefail
# NOTE: JANGAN pakai -u (unbound variable) karena build/envsetup.sh LineageOS
# tidak kompatibel dengan set -u. Kalau tetap mau -u, lihat bagian ENVSETUP.

# ============================================================
# LINEAGEOS 23.2 - GENERIC ARM64
# ============================================================

# ============================================================
# CONFIG
# ============================================================

ROM_NAME="LineageOS 23.2"
ROM_BRANCH="lineage-23.2"

DEVICE="Generic_arm64"
BUILD_TARGET="all_images"

MANIFEST_URL="https://github.com/JBHPocong/lineage-tissot-manifest.git"
MANIFEST_BRANCH="generic"

BUILD_USERNAME="Arden-Vey"
BUILD_HOSTNAME="crave"

OUT_DIR="out/target/product/$DEVICE"

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
# FUNCTIONS
# ============================================================

section() {
    echo
    echo -e "${CYAN}${BOLD}============================================================${RESET}"
    echo -e "${CYAN}${BOLD} $1${RESET}"
    echo -e "${CYAN}${BOLD}============================================================${RESET}"
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

on_error() {
    local exit_code=$?
    local line_no=$1
    echo
    err "Build gagal di line $line_no (exit code: $exit_code)"
    echo
    echo "------------------------------------------------------------"
    echo "Build Failed: returned $exit_code"
    echo "------------------------------------------------------------"
    exit "$exit_code"
}

trap 'on_error $LINENO' ERR

# ============================================================
# BANNER
# ============================================================

# Hanya clear kalau shell interaktif (biar tidak muncul escape sequence aneh)
if [ -t 1 ]; then
    clear
fi

echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║              LINEAGEOS 23.2 GENERIC MAINLINE                 ║"
echo "║                                                              ║"
echo "║              Generic ARM64 Automated Builder                 ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# ============================================================
# CPU THREADS (safe fallback)
# ============================================================

if command -v nproc >/dev/null 2>&1; then
    CPU_THREADS="$(nproc --all 2>/dev/null || echo 1)"
else
    CPU_THREADS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"
fi

# ============================================================
# CONFIGURATION
# ============================================================

section "BUILD CONFIGURATION"

echo "ROM             : $ROM_NAME"
echo "Branch          : $ROM_BRANCH"
echo "Device          : $DEVICE"
echo "Build target    : $BUILD_TARGET"
echo "Manifest        : $MANIFEST_URL"
echo "Manifest branch : $MANIFEST_BRANCH"
echo "Output          : $OUT_DIR"
echo "CPU threads     : $CPU_THREADS"

# ============================================================
# REQUIREMENTS
# ============================================================

section "CHECKING REQUIREMENTS"

for CMD in repo git git-lfs curl; do
    if command -v "$CMD" >/dev/null 2>&1; then
        ok "$CMD"
    else
        if [ "$CMD" = "git-lfs" ]; then
            warn "$CMD tidak ditemukan (diperlukan untuk --git-lfs)."
        else
            err "$CMD tidak ditemukan."
            exit 1
        fi
    fi
done

if [ ! -x "/opt/crave/resync.sh" ]; then
    err "/opt/crave/resync.sh tidak ditemukan."
    exit 1
fi

ok "Crave resync tersedia."

# ============================================================
# CLEAN LOCAL MANIFEST
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

# Set TOP & ANDROID_BUILD_TOP sebelum source envsetup, supaya
# variabel yang dipakai envsetup sudah terdefinisi.
export TOP="$(pwd)"
export ANDROID_BUILD_TOP="$TOP"

if command -v git-lfs >/dev/null 2>&1; then
    repo init \
        -u https://github.com/LineageOS/android.git \
        -b "$ROM_BRANCH" \
        --depth=1 \
        --git-lfs
else
    warn "git-lfs tidak ada, lanjut tanpa --git-lfs."
    repo init \
        -u https://github.com/LineageOS/android.git \
        -b "$ROM_BRANCH" \
        --depth=1
fi

ok "Repo initialized."

# ============================================================
# LOCAL MANIFEST
# ============================================================

section "LOCAL MANIFEST"

git clone \
    -b "$MANIFEST_BRANCH" \
    --depth=1 \
    "$MANIFEST_URL" \
    .repo/local_manifests

ok "Generic manifest cloned."

# ============================================================
# SYNC
# ============================================================

section "SOURCE SYNC"

echo "Running:"
echo "/opt/crave/resync.sh"
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

# Pastikan TOP ter-set lagi (beberapa script bisa overwrite)
export TOP="$(pwd)"
export ANDROID_BUILD_TOP="$TOP"

echo "BUILD_USERNAME=$BUILD_USERNAME"
echo "BUILD_HOSTNAME=$BUILD_HOSTNAME"
echo "BUILD_BROKEN_MISSING_REQUIRED_MODULES=$BUILD_BROKEN_MISSING_REQUIRED_MODULES"
echo "ALLOW_MISSING_DEPENDENCIES=$ALLOW_MISSING_DEPENDENCIES"
echo "TOP=$TOP"

# ============================================================
# ENVSETUP
# ============================================================

section "LOADING LINEAGEOS BUILD ENVIRONMENT"

if [ ! -f "build/envsetup.sh" ]; then
    err "build/envsetup.sh tidak ditemukan."
    exit 1
fi

# PENTING: envsetup.sh LineageOS tidak kompatibel dengan `set -u`.
# Karena script ini tidak pakai -u, kita bisa langsung source.
# Kalau kamu nanti mau pakai -u, bungkus dengan `set +u` / `set -u`.
set +u
# shellcheck disable=SC1091
source build/envsetup.sh
set -e

ok "build/envsetup.sh loaded."

# ============================================================
# GENERIC DEVICE CHECK
# ============================================================

section "CHECKING GENERIC DEVICE TREE"

REQUIRED_DIRS=(
    "device/mainline/generic"
    "device/mainline/common"
    "hardware/mainline/common"
)

MISSING_REQUIRED=0
for DIR in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
        ok "$DIR"
    else
        err "$DIR tidak ditemukan."
        MISSING_REQUIRED=1
    fi
done

if [ "$MISSING_REQUIRED" -ne 0 ]; then
    err "Beberapa direktori wajib tidak ditemukan. Cek manifest / sync."
    exit 1
fi

# ============================================================
# GENERIC ARM64 CHECK
# ============================================================

section "CHECKING GENERIC ARM64"

if [ -d "device/mainline/generic/Generic_arm64" ]; then
    ok "device/mainline/generic/Generic_arm64"
else
    warn "Generic_arm64 directory tidak ditemukan."
fi

# ============================================================
# DEPENDENCIES
# ============================================================

section "CHECKING MAINLINE DEPENDENCIES"

OPTIONAL_DIRS=(
    "kernel/mainline/configs"
    "external/drm_hwcomposer-upstream"
    "external/libdisplay-info-upstream"
    "external/minigbm-upstream"
    "external/linux-firmware-mainline"
    "external/mesa"
    "external/tinyhal"
    "prebuilts/mesa-build-dep"
    "prebuilts/bootmgr"
)

for DIR in "${OPTIONAL_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
        ok "$DIR"
    else
        warn "$DIR missing"
    fi
done

# ============================================================
# BREAKFAST
# ============================================================

section "SELECTING GENERIC ARM64"

echo "Running:"
echo
echo "    breakfast $DEVICE"
echo

set +u
breakfast "$DEVICE"
set -e

ok "Generic ARM64 target selected."

# ============================================================
# VERIFY TARGET
# ============================================================

section "VERIFYING TARGET"

set +u
TARGET_PRODUCT="$(get_build_var TARGET_PRODUCT)"
TARGET_DEVICE="$(get_build_var TARGET_DEVICE)"
TARGET_ARCH="$(get_build_var TARGET_ARCH)"
TARGET_ARCH_VARIANT="$(get_build_var TARGET_ARCH_VARIANT)"
set -e

echo "TARGET_PRODUCT      : ${TARGET_PRODUCT:-<empty>}"
echo "TARGET_DEVICE       : ${TARGET_DEVICE:-<empty>}"
echo "TARGET_ARCH         : ${TARGET_ARCH:-<empty>}"
echo "TARGET_ARCH_VARIANT : ${TARGET_ARCH_VARIANT:-<empty>}"

if [ "${TARGET_DEVICE:-}" != "$DEVICE" ]; then
    err "TARGET_DEVICE tidak sesuai."
    echo "Expected : $DEVICE"
    echo "Detected : ${TARGET_DEVICE:-<empty>}"
    exit 1
fi

ok "Target verified."

# ============================================================
# BUILD INFO
# ============================================================

section "BUILD INFORMATION"

echo "Device       : $DEVICE"
echo "Target       : $BUILD_TARGET"
echo "Product      : ${TARGET_PRODUCT:-<empty>}"
echo "Architecture : ${TARGET_ARCH:-<empty>}"
echo "CPU threads  : $CPU_THREADS"
echo "Output       : $OUT_DIR"

# ============================================================
# BUILD
# ============================================================

section "STARTING BUILD"

echo "Command:"
echo
echo "    m $BUILD_TARGET"
echo

BUILD_START=$(date +%s)

set +u
m "$BUILD_TARGET"
set -e

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

# ============================================================
# OUTPUT CHECK
# ============================================================

section "CHECKING OUTPUT"

if [ ! -d "$OUT_DIR" ]; then
    err "Output directory tidak ditemukan:"
    echo "$OUT_DIR"
    exit 1
fi

ok "Output directory exists."

echo
echo "Output:"
echo "------------------------------------------------------------"

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
        echo -e "${YELLOW}[--]${RESET} $IMAGE"
    fi
done

# ============================================================
# BUILD TIME
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
echo "============================================================"
echo "                         DONE"
echo "============================================================"
