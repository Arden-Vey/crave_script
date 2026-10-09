
#!/bin/bash

set -uo pipefail

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
TARGET_RELEASE_VALUE="trunk_staging"

MANIFEST_URL="https://github.com/JBHPocong/lineage-tissot-manifest.git"
MANIFEST_BRANCH="main"

BUILD_USERNAME="Arden-Vey"
BUILD_HOSTNAME="crave"

OUT_DIR="out/target/product/${DEVICE}"
DEVICE_MK="device/xiaomi/mi89xx-mainline/tissot_mainline/device.mk"
KERNEL_DIR="kernel/mainline/msm8953-mainline"

# ============================================================
# FUNCTIONS
# ============================================================

die() {
    echo
    echo -e "${RED}${BOLD}[ERROR]${RESET} $*"
    exit 1
}

info() {
    echo -e "${CYAN}[INFO]${RESET} $*"
}

ok() {
    echo -e "${GREEN}[OK]${RESET} $*"
}

warn() {
    echo -e "${YELLOW}[WARNING]${RESET} $*"
}

section() {
    echo
    echo "============================================================"
    echo " $*"
    echo "============================================================"
}

# ============================================================
# BANNER
# ============================================================

clear

echo -e "${CYAN}${BOLD}"
cat <<'EOF'
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║            LINEAGEOS 23.2 BUILD SYSTEM                   ║
║                                                          ║
║                 TISSOT MAINLINE                          ║
║              Automated Release Builder                   ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
echo -e "${RESET}"

# ============================================================
# BUILD INFORMATION
# ============================================================

section "BUILD CONFIGURATION"

echo "ROM             : $ROM_NAME"
echo "Branch          : $ROM_BRANCH"
echo "Device          : $DEVICE"
echo "Lunch target    : $LUNCH_TARGET"
echo "Target release  : $TARGET_RELEASE_VALUE"
echo "Manifest        : $MANIFEST_URL"
echo "Manifest branch : $MANIFEST_BRANCH"
echo "Output          : $OUT_DIR"
echo "Build username  : $BUILD_USERNAME"
echo "Build hostname  : $BUILD_HOSTNAME"
echo "CPU threads     : $(nproc --all)"

# ============================================================
# SOURCE CHECK
# ============================================================

section "CHECK SOURCE DIRECTORY"

[ -d ".repo" ] || die "Jalankan script dari root source LOS."
[ -d "build/make" ] || die "Direktori build/make tidak ditemukan."
[ -f "build/envsetup.sh" ] || die "build/envsetup.sh tidak ditemukan."

ok "Root source LOS terdeteksi."

# ============================================================
# LOCAL MANIFEST
# ============================================================

section "PREPARE LOCAL MANIFEST"

mkdir -p .repo/local_manifests

# Hapus XML lama saja, jangan menghapus direktori source.
find .repo/local_manifests -maxdepth 1 -type f \
    -name '*.xml' -delete

if ! git clone \
    --depth=1 \
    --single-branch \
    -b "$MANIFEST_BRANCH" \
    "$MANIFEST_URL" \
    /tmp/lineage-tissot-manifest; then
    die "Gagal mengambil manifest Tissot."
fi

if [ ! -f /tmp/lineage-tissot-manifest/tissot.xml ]; then
    die "tissot.xml tidak ditemukan pada manifest yang diambil."
fi

cp /tmp/lineage-tissot-manifest/*.xml .repo/local_manifests/
rm -rf /tmp/lineage-tissot-manifest

ok "Local manifest disiapkan."

# ============================================================
# CRAVE SYNC
# ============================================================

section "CRAVE SOURCE SYNC"

if [ -x /opt/crave/resync.sh ]; then
    /opt/crave/resync.sh || die "Crave source sync gagal."
else
    die "/opt/crave/resync.sh tidak tersedia."
fi

ok "Crave source sync selesai."

# ============================================================
# BUILD ENVIRONMENT
# ============================================================

section "BUILD ENVIRONMENT"

export BUILD_USERNAME
export BUILD_HOSTNAME

export TARGET_RELEASE="$TARGET_RELEASE_VALUE"

export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C

echo "BUILD_USERNAME=$BUILD_USERNAME"
echo "BUILD_HOSTNAME=$BUILD_HOSTNAME"
echo "TARGET_RELEASE=$TARGET_RELEASE"
echo "BUILD_BROKEN_MISSING_REQUIRED_MODULES=$BUILD_BROKEN_MISSING_REQUIRED_MODULES"
echo "ALLOW_MISSING_DEPENDENCIES=$ALLOW_MISSING_DEPENDENCIES"

# ============================================================
# LIBJXL PATCH
# ============================================================

section "PATCH LIBJXL"

LIBJXL_BP="external/libjxl/Android.bp"

if [ -f "$LIBJXL_BP" ]; then
    if grep -q 'sdk_version: "none"' "$LIBJXL_BP"; then
        cp -n "$LIBJXL_BP" "$LIBJXL_BP.bak"
        sed -i 's/sdk_version: "none"/sdk_version: "current"/' "$LIBJXL_BP"
        ok "libjxl sdk_version diperbarui."
    else
        info "Tidak ada sdk_version none yang perlu diubah."
    fi
else
    warn "$LIBJXL_BP tidak ditemukan."
fi

# ============================================================
# DEVICE TREE CHECK
# ============================================================

section "CHECK TISSOT DEVICE TREE"

[ -f "$DEVICE_MK" ] || die "$DEVICE_MK tidak ditemukan."

[ -f device/xiaomi/mi89xx-mainline/tissot_mainline/lineage_tissot_mainline.mk ] \
    || die "Produk lineage_tissot_mainline tidak ditemukan."

[ -f device/xiaomi/mi89xx-mainline/AndroidProducts.mk ] \
    || die "AndroidProducts.mk tidak ditemukan."

ok "Device tree Tissot ditemukan."

# ============================================================
# DEVICE.MK VENDOR REFERENCE CHECK
# ============================================================

section "CHECK DEVICE.MK VENDOR REFERENCES"

if grep -nE '^[[:space:]]*[^#[:space:]].*vendor/xiaomi/msm8953-common' "$DEVICE_MK"; then
    warn "Masih ada referensi aktif ke vendor/xiaomi/msm8953-common."
    warn "Tidak mengubahnya otomatis karena bisa merusak PRODUCT_COPY_FILES."
    warn "Periksa apakah referensi tersebut memang tidak diperlukan oleh mainline."
else
    ok "Tidak ditemukan referensi vendor aktif yang cocok."
fi

# ============================================================
# OPTIONAL PRODUCT PROPERTY
# ============================================================

section "CHECK PRODUCT PROPERTIES"

PROP_FILE="device/xiaomi/mi89xx-mainline/props/product.prop"

if [ -f "$PROP_FILE" ]; then
    ok "Ditemukan: $PROP_FILE"
else
    warn "$PROP_FILE tidak ditemukan; pemeriksaan dilewati."
fi

# ============================================================
# LOAD BUILD ENVIRONMENT
# ============================================================

section "LOAD BUILD ENVIRONMENT"

source build/envsetup.sh || die "Gagal memuat build/envsetup.sh."

ok "Build environment dimuat."

# ============================================================
# LUNCH
# ============================================================

section "LUNCH TISSOT MAINLINE"

echo "Target        : $LUNCH_TARGET"
echo "Release       : $TARGET_RELEASE"

if ! lunch "$LUNCH_TARGET"; then
    die "Lunch gagal. Build dibatalkan agar tidak membuang waktu."
fi

ok "Lunch berhasil."

# ============================================================
# VERIFY BUILD VARIABLES
# ============================================================

section "VERIFY BUILD VARIABLES"

echo "TARGET_PRODUCT       : ${TARGET_PRODUCT:-unset}"
echo "TARGET_BUILD_VARIANT : ${TARGET_BUILD_VARIANT:-unset}"
echo "TARGET_RELEASE       : ${TARGET_RELEASE:-unset}"

[ "${TARGET_PRODUCT:-}" = "lineage_tissot_mainline" ] \
    || die "TARGET_PRODUCT bukan lineage_tissot_mainline."

[ "${TARGET_BUILD_VARIANT:-}" = "userdebug" ] \
    || die "Build variant bukan userdebug."

# ============================================================
# KERNEL CHECK
# ============================================================

section "CHECK MAINLINE KERNEL"

if [ -d "$KERNEL_DIR" ]; then
    ok "Kernel ditemukan: $KERNEL_DIR"
else
    warn "Direktori kernel tidak ditemukan: $KERNEL_DIR"
    warn "Periksa path kernel pada manifest sebelum melanjutkan."
fi

# ============================================================
# HIGHWAY CHECK
# ============================================================

section "CHECK EXTERNAL HIGHWAY"

if [ -f external/highway/Android.bp ]; then
    ok "external/highway/Android.bp ditemukan."
else
    warn "external/highway/Android.bp tidak ditemukan."
    warn "Ini belum membuktikan bahwa file tersebut penyebab build gagal."
fi

# ============================================================
# PRE-BUILD SUMMARY
# ============================================================

section "PRE-BUILD SUMMARY"

echo "ROM             : $ROM_NAME"
echo "Branch          : $ROM_BRANCH"
echo "Device          : $DEVICE"
echo "Lunch           : $LUNCH_TARGET"
echo "Release         : $TARGET_RELEASE"
echo "Build username  : $BUILD_USERNAME"
echo "Build hostname  : $BUILD_HOSTNAME"
echo "CPU threads     : $(nproc --all)"
echo "Output          : $OUT_DIR"

# ============================================================
# BUILD
# ============================================================

section "STARTING BUILD"

echo "Command: mka bacon"
echo

BUILD_START=$(date +%s)

# Tetap di dalam workflow build Crave.
# mka bacon hanya dijalankan setelah lunch berhasil.

mka bacon
BUILD_STATUS=$?

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

if [ "$BUILD_STATUS" -ne 0 ]; then
    section "BUILD FAILED"
    echo "Exit status : $BUILD_STATUS"
    echo "Build time  : ${BUILD_TIME} seconds"
    echo
    echo "Periksa log build yang tersedia:"
    echo "  out/error.log"
    echo "  out/verbose.log.gz"
    exit "$BUILD_STATUS"
fi

# ============================================================
# ARTIFACT CHECK
# ============================================================

section "BUILD ARTIFACTS"

if [ ! -d "$OUT_DIR" ]; then
    die "Direktori output tidak ditemukan: $OUT_DIR"
fi

echo "Output directory: $OUT_DIR"
echo

find "$OUT_DIR" -maxdepth 1 -type f \
    \( -name '*.zip' \
       -o -name '*.img' \
       -o -name '*.sha256sum' \
       -o -name '*.json' \) \
    -printf '%f\n' | sort

# ============================================================
# ROM ZIP
# ============================================================

section "ROM ZIP CHECK"

ZIP=""

while IFS= read -r FILE; do
    ZIP="$FILE"
    break
done < <(
    find "$OUT_DIR" -maxdepth 1 -type f \
        -name '*.zip' \
        ! -name '*ota*.zip' | sort
)

if [ -n "$ZIP" ]; then
    ok "ROM ZIP ditemukan: $ZIP"
else
    warn "Tidak ditemukan ROM ZIP."
fi

# ============================================================
# IMAGE CHECK
# ============================================================

section "IMAGE CHECK"

for IMAGE in boot.img vendor.img system.img init_boot.img recovery.img; do
    if [ -f "$OUT_DIR/$IMAGE" ]; then
        ok "$IMAGE"
    else
        echo -e "${YELLOW}[--]${RESET} $IMAGE"
    fi
done

# ============================================================
# SHA256
# ============================================================

section "SHA256"

if [ -n "$ZIP" ]; then
    sha256sum "$ZIP"
fi

# ============================================================
# FINAL
# ============================================================

section "BUILD COMPLETE"

echo "ROM         : $ROM_NAME"
echo "Device      : $DEVICE"
echo "Build time  : ${BUILD_TIME} seconds"
echo "Output      : $OUT_DIR"

if [ -n "$ZIP" ]; then
    echo "ROM ZIP     : $ZIP"
fi

echo
ok "Script selesai."
