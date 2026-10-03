#!/bin/bash

# ============================================================
# TISSOT MAINLINE - AUTO DETECT & AUTO FIX BUILD SCRIPT
# ============================================================
# Berdasarkan script Arden-Vey
# Menambahkan modul auto-detect dan auto-fix untuk error dtb.img
# ============================================================

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

BUILD_USERNAME="Arden-Vey"
BUILD_HOSTNAME="crave"

OUT_DIR="out/target/product/$DEVICE"

DEVICE_MK="device/xiaomi/mi89xx-mainline/tissot_mainline/device.mk"

BOARD_CONFIG="device/xiaomi/mi89xx-mainline/tissot_mainline/BoardConfig.mk"

PREBUILT_KERNEL_DIR="prebuilts/kernel/tissot"
PREBUILT_KERNEL="$PREBUILT_KERNEL_DIR/Image.gz-dtb"
PREBUILT_DTB="$PREBUILT_KERNEL_DIR/dtb.img"

PREBUILT_KERNEL_PROJECT="JBHPocong/lineage-tissot-manifest"
PREBUILT_KERNEL_BRANCH="Image.gz-dtb"

LOG_DIR="build_logs"
AUTOFIX_LOG="$LOG_DIR/autofix.log"
mkdir -p "$LOG_DIR"

# ============================================================
# HELPER FUNCTIONS
# ============================================================

log() {
    echo -e "$1" | tee -a "$AUTOFIX_LOG"
}

section() {
    echo
    echo "============================================================" | tee -a "$AUTOFIX_LOG"
    echo "  $1" | tee -a "$AUTOFIX_LOG"
    echo "============================================================" | tee -a "$AUTOFIX_LOG"
}

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
    echo "║          Automated Release Builder + AUTO DETECT/FIX            ║"
    echo "║                                                                 ║"
    echo "╠═════════════════════════════════════════════════════════════════╣"
    echo "║  ROM        : LineageOS 23.2                                    ║"
    echo "║  Device     : tissot_mainline                                   ║"
    echo "║  Branch     : lineage-23.2                                      ║"
    echo "║  Build      : userdebug                                         ║"
    echo "║  Kernel     : PREBUILT Image.gz-dtb                             ║"
    echo "║  Auto-Fix   : ENABLED (dtb.img)                                 ║"
    echo "╚═════════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

banner

# ============================================================
# INIT AUTOFIX LOG
# ============================================================

echo "=== AUTOFIX LOG $(date) ===" > "$AUTOFIX_LOG"

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

section "CLEANING UP PREVIOUS LOCAL MANIFESTS"

rm -rf .repo/local_manifests
echo -e "${GREEN}Local manifests cleaned.${RESET}"

# ============================================================
# REPO INIT
# ============================================================

section "REPO INIT"

repo init \
    -u https://github.com/LineageOS/android.git \
    -b "$ROM_BRANCH" \
    --depth=1 \
    --git-lfs

echo -e "${GREEN}repo init completed.${RESET}"

# ============================================================
# LOCAL MANIFEST
# ============================================================

section "CLONING MANIFEST"

git clone \
    -b "$MANIFEST_BRANCH" \
    --depth=1 \
    "$MANIFEST_URL" \
    .repo/local_manifests

echo -e "${GREEN}Local manifest cloned.${RESET}"

# ============================================================
# VERIFY MANIFEST
# ============================================================

section "VERIFYING MANIFEST"

MANIFEST_FILE=".repo/local_manifests/tissot.xml"

if [ ! -f "$MANIFEST_FILE" ]; then
    echo -e "${RED}[ERROR]${RESET} Manifest tidak ditemukan: $MANIFEST_FILE"
    exit 1
fi
echo -e "${GREEN}[OK]${RESET} Manifest ditemukan"

if grep -q "prebuilts/kernel/tissot" "$MANIFEST_FILE"; then
    echo -e "${GREEN}[OK]${RESET} Prebuilt kernel project terdeteksi"
else
    echo -e "${RED}[ERROR]${RESET} Prebuilt kernel project tidak ditemukan"
    exit 1
fi

if grep -q 'revision="Image.gz-dtb"' "$MANIFEST_FILE"; then
    echo -e "${GREEN}[OK]${RESET} Kernel revision: Image.gz-dtb"
else
    echo -e "${RED}[ERROR]${RESET} Revision Image.gz-dtb tidak ditemukan"
    exit 1
fi

if grep -q "kernel/mainline/msm8953-mainline" "$MANIFEST_FILE"; then
    echo -e "${RED}[ERROR]${RESET} Kernel source lama masih ada di manifest!"
    grep -n "kernel/mainline/msm8953-mainline" "$MANIFEST_FILE"
    exit 1
else
    echo -e "${GREEN}[OK]${RESET} Kernel source project tidak digunakan"
fi

# ============================================================
# CRAVE SYNC
# ============================================================

section "REPO SYNC"

/opt/crave/resync.sh
echo -e "${GREEN}Repository sync completed.${RESET}"

# ============================================================
# VERIFY PREBUILT KERNEL
# ============================================================

section "VERIFYING PREBUILT KERNEL"

if [ ! -d "$PREBUILT_KERNEL_DIR" ]; then
    echo -e "${RED}[ERROR]${RESET} Prebuilt kernel directory tidak ditemukan: $PREBUILT_KERNEL_DIR"
    exit 1
fi
echo -e "${GREEN}[OK]${RESET} Kernel directory ditemukan"

if [ ! -f "$PREBUILT_KERNEL" ]; then
    echo -e "${RED}[ERROR]${RESET} Image.gz-dtb tidak ditemukan: $PREBUILT_KERNEL"
    exit 1
fi
echo -e "${GREEN}[OK]${RESET} Image.gz-dtb ditemukan"

ls -lh "$PREBUILT_KERNEL"
command -v file >/dev/null 2>&1 && file "$PREBUILT_KERNEL"
command -v sha256sum >/dev/null 2>&1 && sha256sum "$PREBUILT_KERNEL"

# ============================================================
# BUILD ENVIRONMENT
# ============================================================

section "BUILD ENVIRONMENT SETUP"

export BUILD_USERNAME="$BUILD_USERNAME"
export BUILD_HOSTNAME="$BUILD_HOSTNAME"
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C

echo "BUILD_USERNAME=$BUILD_USERNAME"
echo "BUILD_HOSTNAME=$BUILD_HOSTNAME"

# ============================================================
# PATCH LIBJXL
# ============================================================

section "PATCHING external/libjxl"

if [ -f "external/libjxl/Android.bp" ]; then
    sed -i 's/sdk_version: "none"/sdk_version: "current"/' external/libjxl/Android.bp
    echo -e "${GREEN}[OK]${RESET} external/libjxl/Android.bp dipatch"
else
    echo -e "${YELLOW}[WARNING]${RESET} external/libjxl/Android.bp tidak ditemukan"
fi

# ============================================================
# PATCH: HAPUS VENDOR FIRMWARE BLOBS
# ============================================================

section "PATCHING tissot_mainline/device.mk"

if [ -f "$DEVICE_MK" ]; then
    cp "$DEVICE_MK" "$DEVICE_MK.bak"
    echo "Backup: $DEVICE_MK.bak"

    sed -i 's|^\(.*vendor/xiaomi/msm8953-common.*\)$|# \1|' "$DEVICE_MK"
    sed -i '/^PRODUCT_COPY_FILES += \\$/{N;/^# .*vendor\/xiaomi\/msm8953-common/s/^/# /}' "$DEVICE_MK"

    ACTIVE_REFS=$(grep -n "^[^#].*vendor/xiaomi/msm8953-common" "$DEVICE_MK" || true)

    if [ -n "$ACTIVE_REFS" ]; then
        echo -e "${RED}[ERROR]${RESET} masih ada referensi vendor blobs aktif!"
        echo "$ACTIVE_REFS"
        mv "$DEVICE_MK.bak" "$DEVICE_MK"
        exit 1
    else
        echo -e "${GREEN}[OK]${RESET} vendor blobs di-comment"
    fi
else
    echo -e "${RED}[ERROR]${RESET} $DEVICE_MK tidak ditemukan"
    exit 1
fi

# ============================================================
# BUILD ENV
# ============================================================

section "LOADING BUILD ENVIRONMENT"

source build/envsetup.sh
echo -e "${GREEN}Build environment loaded.${RESET}"

# ============================================================
# LUNCH
# ============================================================

section "LUNCH"

lunch "$LUNCH_TARGET"
echo -e "${GREEN}Lunch completed.${RESET}"

# ============================================================
# DEVICE CHECK
# ============================================================

section "CHECKING DEVICE TREE"

if [ -d "device/xiaomi/mi89xx-mainline" ]; then
    echo -e "${GREEN}[OK]${RESET} device/xiaomi/mi89xx-mainline"
else
    echo -e "${RED}[ERROR]${RESET} device/xiaomi/mi89xx-mainline tidak ditemukan"
    exit 1
fi

# ============================================================
# PATCH BOARDCONFIG
# ============================================================

section "PATCHING TISSOT BOARDCONFIG"

if [ ! -f "$BOARD_CONFIG" ]; then
    echo -e "${RED}[ERROR]${RESET} BoardConfig tidak ditemukan: $BOARD_CONFIG"
    exit 1
fi

if [ ! -f "$BOARD_CONFIG.bak-prebuilt" ]; then
    cp "$BOARD_CONFIG" "$BOARD_CONFIG.bak-prebuilt"
    echo -e "${GREEN}[OK]${RESET} Backup dibuat: $BOARD_CONFIG.bak-prebuilt"
else
    echo -e "${YELLOW}[INFO]${RESET} Backup sudah ada"
fi

# Hapus konfigurasi kernel lama
python3 - "$BOARD_CONFIG" <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()

variables = {
    "TARGET_KERNEL_SOURCE", "TARGET_KERNEL_CONFIG", "TARGET_KERNEL_CONFIG_EXT",
    "TARGET_PREBUILT_KERNEL", "TARGET_FORCE_PREBUILT_KERNEL",
    "BOARD_KERNEL_IMAGE_NAME", "BOARD_PREBUILT_DTBIMAGE_DIR",
    "TARGET_PREBUILT_DTB", "BOARD_PREBUILT_DTB", "BOARD_KERNEL_DTB",
    "TARGET_KERNEL_DTB", "TARGET_KERNEL_DTBIMAGE", "BOARD_KERNEL_SEPARATED_DT",
    "BOARD_KERNEL_DTBIMAGE", "BOARD_DTB_IMAGE", "BOARD_INCLUDE_DTB_IN_BOOTIMG",
}

output = []
for line in lines:
    stripped = line.lstrip()
    if stripped.startswith("#"):
        output.append(line)
        continue
    match = re.match(r'^\s*([A-Za-z0-9_]+)\s*(?::|\?|\+)?=\s*', line)
    if match and match.group(1) in variables:
        output.append("# PREBUILT-KERNEL: disabled old setting: " + line)
    else:
        output.append(line)

with open(path, "w", encoding="utf-8") as f:
    f.writelines(output)
PY

# Tambahkan konfigurasi prebuilt kernel (TANPA DTB terpisah)
cat >> "$BOARD_CONFIG" <<'EOF'

# ============================================================
# PREBUILT MAINLINE KERNEL (AUTO-FIX)
# ============================================================
# Image.gz-dtb sudah mengandung DTB.
# JANGAN configure dtb.img terpisah.

TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64

BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb

TARGET_PREBUILT_KERNEL := prebuilts/kernel/tissot/Image.gz-dtb

# Pastikan DTB terpisah tidak dibuat
BOARD_KERNEL_SEPARATED_DT := false
BOARD_INCLUDE_DTB_IN_BOOTIMG := false
EOF

echo -e "${GREEN}[OK]${RESET} Prebuilt kernel configuration ditambahkan"

# ============================================================
# ★★★ AUTO-DETECT & AUTO-FIX MODULE ★★★
# ============================================================

section "AUTO-DETECT: KERNEL & DTB CONFIGURATION"

# ------------------------------------------------------------
# DETEKSI 1: Cek apakah BoardConfig punya konfigurasi DTB terpisah
# ------------------------------------------------------------
echo
echo "[DETEKSI 1] Memeriksa konfigurasi DTB terpisah..."

DTB_ACTIVE=$(grep -nE '^[[:space:]]*(BOARD_KERNEL_SEPARATED_DT|BOARD_PREBUILT_DTB|BOARD_KERNEL_DTB|TARGET_PREBUILT_DTB|BOARD_KERNEL_DTBIMAGE|BOARD_DTB_IMAGE)[[:space:]]*[:?+]*=[[:space:]]*true' "$BOARD_CONFIG" || true)

if [ -n "$DTB_ACTIVE" ]; then
    echo -e "${YELLOW}[DETEKSI]${RESET} Ditemukan konfigurasi DTB aktif:"
    echo "$DTB_ACTIVE"
    echo
    echo -e "${CYAN}[AUTO-FIX]${RESET} Menonaktifkan konfigurasi DTB terpisah..."

    sed -i -E 's/^([[:space:]]*)(BOARD_KERNEL_SEPARATED_DT|BOARD_PREBUILT_DTB|BOARD_KERNEL_DTB|TARGET_PREBUILT_DTB|BOARD_KERNEL_DTBIMAGE|BOARD_DTB_IMAGE)([[:space:]]*[:?+]*=[[:space:]]*)true/\1# AUTO-FIX: \2\3false/' "$BOARD_CONFIG"

    echo -e "${GREEN}[AUTO-FIX OK]${RESET} Konfigurasi DTB terpisah dinonaktifkan"
else
    echo -e "${GREEN}[OK]${RESET} Tidak ada konfigurasi DTB terpisah yang aktif"
fi

# ------------------------------------------------------------
# DETEKSI 2: Cek apakah TARGET_PREBUILT_DTB menunjuk ke file yang tidak ada
# ------------------------------------------------------------
echo
echo "[DETEKSI 2] Memeriksa TARGET_PREBUILT_DTB..."

PREBUILT_DTB_REF=$(grep -nE '^[[:space:]]*TARGET_PREBUILT_DTB[[:space:]]*[:?+]*=' "$BOARD_CONFIG" || true)

if [ -n "$PREBUILT_DTB_REF" ]; then
    DTB_PATH=$(echo "$PREBUILT_DTB_REF" | sed -E 's/.*=[[:space:]]*//' | tr -d '"' | tr -d "'")

    if [ ! -f "$DTB_PATH" ]; then
        echo -e "${YELLOW}[DETEKSI]${RESET} TARGET_PREBUILT_DTB menunjuk ke file yang tidak ada:"
        echo "  $DTB_PATH"
        echo
        echo -e "${CYAN}[AUTO-FIX]${RESET} Meng-comment TARGET_PREBUILT_DTB..."

        sed -i -E 's/^([[:space:]]*TARGET_PREBUILT_DTB[[:space:]]*[:?+]*=.*)/# AUTO-FIX (file not found): \1/' "$BOARD_CONFIG"

        echo -e "${GREEN}[AUTO-FIX OK]${RESET} TARGET_PREBUILT_DTB di-comment"
    else
        echo -e "${GREEN}[OK]${RESET} TARGET_PREBUILT_DTB menunjuk ke file yang valid"
    fi
else
    echo -e "${GREEN}[OK]${RESET} TARGET_PREBUILT_DTB tidak digunakan"
fi

# ------------------------------------------------------------
# DETEKSI 3: Cek apakah ada referensi dtb.img di BoardConfig
# ------------------------------------------------------------
echo
echo "[DETEKSI 3] Memeriksa referensi dtb.img di BoardConfig..."

DTB_IMG_REF=$(grep -nE 'dtb\.img' "$BOARD_CONFIG" || true)

if [ -n "$DTB_IMG_REF" ]; then
    echo -e "${YELLOW}[DETEKSI]${RESET} Ditemukan referensi dtb.img:"
    echo "$DTB_IMG_REF"
    echo
    echo -e "${CYAN}[AUTO-FIX]${RESET} Meng-comment referensi dtb.img..."

    sed -i -E 's/^([[:space:]]*[^#].*dtb\.img.*)$/# AUTO-FIX (dtb.img ref): \1/' "$BOARD_CONFIG"

    echo -e "${GREEN}[AUTO-FIX OK]${RESET} Referensi dtb.img di-comment"
else
    echo -e "${GREEN}[OK]${RESET} Tidak ada referensi dtb.img di BoardConfig"
fi

# ------------------------------------------------------------
# DETEKSI 4: Cek apakah Image.gz-dtb ada dan valid
# ------------------------------------------------------------
echo
echo "[DETEKSI 4] Memeriksa Image.gz-dtb..."

if [ -f "$PREBUILT_KERNEL" ]; then
    KERNEL_SIZE=$(stat -c%s "$PREBUILT_KERNEL" 2>/dev/null || stat -f%z "$PREBUILT_KERNEL" 2>/dev/null || echo "0")

    if [ "$KERNEL_SIZE" -lt 1000000 ]; then
        echo -e "${RED}[DETEKSI]${RESET} Image.gz-dtb terlalu kecil ($KERNEL_SIZE bytes)!"
        echo "Kemungkinan file corrupt atau LFS tidak di-pull."
        echo
        echo -e "${CYAN}[AUTO-FIX]${RESET} Mencoba git lfs pull..."

        if [ -d "$PREBUILT_KERNEL_DIR/.git" ]; then
            (cd "$PREBUILT_KERNEL_DIR" && git lfs pull 2>/dev/null) || true
        fi

        if [ -f "$PREBUILT_KERNEL" ]; then
            KERNEL_SIZE=$(stat -c%s "$PREBUILT_KERNEL" 2>/dev/null || echo "0")
            if [ "$KERNEL_SIZE" -lt 1000000 ]; then
                echo -e "${RED}[ERROR]${RESET} Image.gz-dtb masih kecil setelah lfs pull"
                exit 1
            fi
            echo -e "${GREEN}[AUTO-FIX OK]${RESET} Image.gz-dtb sudah valid ($KERNEL_SIZE bytes)"
        fi
    else
        echo -e "${GREEN}[OK]${RESET} Image.gz-dtb valid ($KERNEL_SIZE bytes)"
    fi
else
    echo -e "${RED}[ERROR]${RESET} Image.gz-dtb tidak ditemukan"
    exit 1
fi

# ------------------------------------------------------------
# DETEKSI 5: Cek apakah kernel.mk masih memaksa build kernel
# ------------------------------------------------------------
echo
echo "[DETEKSI 5] Memeriksa kernel.mk force build..."

if [ -f "vendor/lineage/build/tasks/kernel.mk" ]; then
    if grep -qE 'TARGET_KERNEL_SOURCE' "$BOARD_CONFIG"; then
        FORCE_KERNEL=$(grep -nE '^[[:space:]]*TARGET_KERNEL_SOURCE[[:space:]]*[:?+]*=' "$BOARD_CONFIG" || true)
        if [ -n "$FORCE_KERNEL" ]; then
            echo -e "${YELLOW}[DETEKSI]${RESET} TARGET_KERNEL_SOURCE masih aktif:"
            echo "$FORCE_KERNEL"
            echo
            echo -e "${CYAN}[AUTO-FIX]${RESET} Meng-comment TARGET_KERNEL_SOURCE..."

            sed -i -E 's/^([[:space:]]*TARGET_KERNEL_SOURCE[[:space:]]*[:?+]*=.*)/# AUTO-FIX (force build): \1/' "$BOARD_CONFIG"

            echo -e "${GREEN}[AUTO-FIX OK]${RESET} TARGET_KERNEL_SOURCE di-comment"
        fi
    fi
    echo -e "${GREEN}[OK]${RESET} kernel.mk tidak akan memaksa build kernel"
else
    echo -e "${YELLOW}[WARNING]${RESET} vendor/lineage/build/tasks/kernel.mk tidak ditemukan"
fi

# ------------------------------------------------------------
# DETEKSI 6: Cek prebuilt dtb.img di out directory
# ------------------------------------------------------------
echo
echo "[DETEKSI 6] Memeriksa dtb.img di output directory..."

if [ -f "$OUT_DIR/dtb.img" ]; then
    echo -e "${YELLOW}[DETEKSI]${RESET} dtb.img sudah ada di output:"
    ls -lh "$OUT_DIR/dtb.img"
else
    echo -e "${GREEN}[OK]${RESET} dtb.img tidak ada di output (akan di-skip)"
fi

# ------------------------------------------------------------
# DETEKSI 7: Cek apakah BoardConfig punya BOARD_PREBUILT_DTBIMAGE_DIR
# ------------------------------------------------------------
echo
echo "[DETEKSI 7] Memeriksa BOARD_PREBUILT_DTBIMAGE_DIR..."

DTB_DIR_REF=$(grep -nE '^[[:space:]]*BOARD_PREBUILT_DTBIMAGE_DIR[[:space:]]*[:?+]*=' "$BOARD_CONFIG" || true)

if [ -n "$DTB_DIR_REF" ]; then
    DTB_DIR_PATH=$(echo "$DTB_DIR_REF" | sed -E 's/.*=[[:space:]]*//' | tr -d '"' | tr -d "'")

    if [ ! -d "$DTB_DIR_PATH" ]; then
        echo -e "${YELLOW}[DETEKSI]${RESET} BOARD_PREBUILT_DTBIMAGE_DIR menunjuk ke direktori yang tidak ada:"
        echo "  $DTB_DIR_PATH"
        echo
        echo -e "${CYAN}[AUTO-FIX]${RESET} Meng-comment BOARD_PREBUILT_DTBIMAGE_DIR..."

        sed -i -E 's/^([[:space:]]*BOARD_PREBUILT_DTBIMAGE_DIR[[:space:]]*[:?+]*=.*)/# AUTO-FIX (dir not found): \1/' "$BOARD_CONFIG"

        echo -e "${GREEN}[AUTO-FIX OK]${RESET} BOARD_PREBUILT_DTBIMAGE_DIR di-comment"
    else
        echo -e "${GREEN}[OK]${RESET} BOARD_PREBUILT_DTBIMAGE_DIR valid"
    fi
else
    echo -e "${GREEN}[OK]${RESET} BOARD_PREBUILT_DTBIMAGE_DIR tidak digunakan"
fi

# ------------------------------------------------------------
# VERIFIKASI AKHIR
# ------------------------------------------------------------
echo
echo "[VERIFIKASI] Konfigurasi kernel final:"
echo "--------------------------------------------"
grep -nE \
    'TARGET_KERNEL_ARCH|TARGET_KERNEL_HEADER_ARCH|BOARD_KERNEL_IMAGE_NAME|TARGET_PREBUILT_KERNEL|TARGET_KERNEL_SOURCE|TARGET_KERNEL_CONFIG|DTB|dtb' \
    "$BOARD_CONFIG" \
    || true

echo
echo -e "${GREEN}${BOLD}[AUTO-DETECT & AUTO-FIX SELESAI]${RESET}"

# ============================================================
# PRE-BUILD SUMMARY
# ============================================================

section "PRE-BUILD SUMMARY"

echo "ROM             : $ROM_NAME"
echo "Branch          : $ROM_BRANCH"
echo "Device          : $DEVICE"
echo "Lunch           : $LUNCH_TARGET"
echo "Build username  : $BUILD_USERNAME"
echo "Build hostname  : $BUILD_HOSTNAME"
echo "CPU threads     : $(nproc --all)"
echo "Kernel mode     : PREBUILT"
echo "Kernel          : $PREBUILT_KERNEL"
echo "DTB             : EMBEDDED in Image.gz-dtb"
echo "Output          : $OUT_DIR"

# ============================================================
# BUILD
# ============================================================

section "STARTING BUILD"

echo "Command: mka bacon"
echo

BUILD_START=$(date +%s)

set +e
mka bacon 2>&1 | tee -a "$LOG_DIR/build.log"
BUILD_STATUS=${PIPESTATUS[0]}
set -e

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

# ============================================================
# ★★★ POST-BUILD AUTO-FIX MODULE ★★★
# ============================================================

if [ $BUILD_STATUS -ne 0 ]; then

    section "BUILD FAILED - ANALYZING ERROR"

    echo -e "${RED}${BOLD}Build failed with exit status: $BUILD_STATUS${RESET}"
    echo "Build time: $BUILD_TIME seconds"

    # ------------------------------------------------------------
    # DETEKSI ERROR: dtb.img missing
    # ------------------------------------------------------------
    echo
    echo "[ANALISIS] Memeriksa error dtb.img..."

    DTB_ERROR=$(grep -E "dtb\.img.*missing and no known rule" "$LOG_DIR/build.log" || true)

    if [ -n "$DTB_ERROR" ]; then
        echo -e "${RED}[DETEKSI]${RESET} Ditemukan error dtb.img:"
        echo "$DTB_ERROR"
        echo

        section "AUTO-FIX: dtb.img MISSING"

        # ------------------------------------------------------------
        # FIX 1: Pastikan TARGET_PREBUILT_KERNEL aktif
        # ------------------------------------------------------------
        echo "[FIX 1] Memastikan TARGET_PREBUILT_KERNEL aktif..."

        if ! grep -qE '^[[:space:]]*TARGET_PREBUILT_KERNEL[[:space:]]*[:?+]*=[[:space:]]*prebuilts/kernel/tissot/Image\.gz-dtb' "$BOARD_CONFIG"; then
            echo -e "${CYAN}[AUTO-FIX]${RESET} Menambahkan TARGET_PREBUILT_KERNEL..."

            # Hapus dulu jika ada versi salah
            sed -i -E '/^[[:space:]]*TARGET_PREBUILT_KERNEL[[:space:]]*[:?+]*=/d' "$BOARD_CONFIG"

            cat >> "$BOARD_CONFIG" <<'EOF'

# AUTO-FIX: TARGET_PREBUILT_KERNEL
TARGET_PREBUILT_KERNEL := prebuilts/kernel/tissot/Image.gz-dtb
EOF
            echo -e "${GREEN}[AUTO-FIX OK]${RESET} TARGET_PREBUILT_KERNEL ditambahkan"
        else
            echo -e "${GREEN}[OK]${RESET} TARGET_PREBUILT_KERNEL sudah benar"
        fi

        # ------------------------------------------------------------
        # FIX 2: Comment semua DTB terpisah
        # ------------------------------------------------------------
        echo
        echo "[FIX 2] Menonaktifkan semua konfigurasi DTB terpisah..."

        sed -i -E 's/^([[:space:]]*)(BOARD_KERNEL_SEPARATED_DT|BOARD_PREBUILT_DTB|BOARD_KERNEL_DTB|TARGET_PREBUILT_DTB|BOARD_KERNEL_DTBIMAGE|BOARD_DTB_IMAGE|BOARD_PREBUILT_DTBIMAGE_DIR|TARGET_KERNEL_DTB|TARGET_KERNEL_DTBIMAGE)([[:space:]]*[:?+]*=)/\1# AUTO-FIX (dtb.img): \2\3/' "$BOARD_CONFIG"

        echo -e "${GREEN}[AUTO-FIX OK]${RESET} Konfigurasi DTB terpisah dinonaktifkan"

        # ------------------------------------------------------------
        # FIX 3: Tambahkan setting untuk skip DTB generation
        # ------------------------------------------------------------
        echo
        echo "[FIX 3] Menambahkan setting skip DTB generation..."

        if ! grep -q "BOARD_KERNEL_SEPARATED_DT := false" "$BOARD_CONFIG"; then
            cat >> "$BOARD_CONFIG" <<'EOF'

# AUTO-FIX: Skip DTB generation
BOARD_KERNEL_SEPARATED_DT := false
BOARD_INCLUDE_DTB_IN_BOOTIMG := false
EOF
            echo -e "${GREEN}[AUTO-FIX OK]${RESET} Setting skip DTB ditambahkan"
        else
            echo -e "${GREEN}[OK]${RESET} Setting skip DTB sudah ada"
        fi

        # ------------------------------------------------------------
        # FIX 4: Buat dummy dtb.img di output (sebagai fallback)
        # ------------------------------------------------------------
        echo
        echo "[FIX 4] Membuat fallback dtb.img di output directory..."

        mkdir -p "$OUT_DIR"

        if [ ! -f "$OUT_DIR/dtb.img" ]; then
            # Buat file kosong sebagai placeholder
            touch "$OUT_DIR/dtb.img"
            echo -e "${GREEN}[AUTO-FIX OK]${RESET} Placeholder dtb.img dibuat di $OUT_DIR"
        else
            echo -e "${GREEN}[OK]${RESET} dtb.img sudah ada di output"
        fi

        # ------------------------------------------------------------
        # FIX 5: Pastikan Image.gz-dtb ada
        # ------------------------------------------------------------
        echo
        echo "[FIX 5] Memverifikasi Image.gz-dtb..."

        if [ ! -f "$PREBUILT_KERNEL" ]; then
            echo -e "${RED}[ERROR]${RESET} Image.gz-dtb tidak ditemukan, tidak bisa lanjut"
            exit 1
        fi        echo -e "${GREEN}[OK]${RESET} Image.gz-dtb ada"

        # ------------------------------------------------------------
        # VERIFIKASI
        # ------------------------------------------------------------
        echo
        echo "[VERIFIKASI] BoardConfig setelah auto-fix:"
        echo "--------------------------------------------"
        grep -nE \
            'TARGET_KERNEL_ARCH|TARGET_KERNEL_HEADER_ARCH|BOARD_KERNEL_IMAGE_NAME|TARGET_PREBUILT_KERNEL|TARGET_KERNEL_SOURCE|DTB|dtb' \
            "$BOARD_CONFIG" \
            || true

        # ------------------------------------------------------------
        # REBUILD OTOMATIS
        # ------------------------------------------------------------
        section "AUTO-REBUILD"

        echo -e "${CYAN}${BOLD}Melakukan rebuild otomatis...${RESET}"
        echo

        # Bersihkan output yang bermasalah
        echo "Membersihkan output bermasalah..."
        rm -f "$OUT_DIR/dtb.img" 2>/dev/null || true

        # Re-lunch untuk memuat konfigurasi baru
        echo "Re-lunch..."
        lunch "$LUNCH_TARGET" >/dev/null 2>&1

        # Rebuild
        echo "Rebuild..."
        set +e
        mka bacon 2>&1 | tee -a "$LOG_DIR/build.log"
        BUILD_STATUS=${PIPESTATUS[0]}
        set -e

        BUILD_END=$(date +%s)
        BUILD_TIME=$((BUILD_END - BUILD_START))

        if [ $BUILD_STATUS -eq 0 ]; then
            echo -e "${GREEN}${BOLD}[AUTO-REBUILD SUCCESS]${RESET} Build berhasil setelah auto-fix!"
        else
            echo -e "${RED}${BOLD}[AUTO-REBUILD FAILED]${RESET} Build masih gagal setelah auto-fix"
            echo "Cek log di: $LOG_DIR/build.log"
            exit $BUILD_STATUS
        fi

    else
        # ------------------------------------------------------------
        # Error lain, bukan dtb.img
        # ------------------------------------------------------------
        echo -e "${YELLOW}[INFO]${RESET} Error bukan dtb.img, mencoba deteksi error lain..."

        # Cek error umum lain
        OTHER_ERRORS=$(grep -E "FAILED:|error:|Error:" "$LOG_DIR/build.log" | head -n 10 || true)

        if [ -n "$OTHER_ERRORS" ]; then
            echo "Error yang terdeteksi:"
            echo "$OTHER_ERRORS"
        fi

        echo
        echo "Cek log lengkap di:"
        echo "  $LOG_DIR/build.log"
        echo "  out/error.log"

        exit $BUILD_STATUS
    fi
fi

# ============================================================
# BUILD SUCCESS
# ============================================================

section "BUILD SUCCESS"

echo -e "${GREEN}${BOLD}Build completed successfully.${RESET}"
echo "Build time: $BUILD_TIME seconds"

# ============================================================
# ARTIFACT CHECK
# ============================================================

section "BUILD ARTIFACTS"

if [ ! -d "$OUT_DIR" ]; then
    echo -e "${RED}ERROR:${RESET} Output directory tidak ditemukan: $OUT_DIR"
    exit 1
fi

echo "Output directory: $OUT_DIR"
echo
echo "Files:"
find "$OUT_DIR" -maxdepth 1 -type f \( -name "*.zip" -o -name "*.img" -o -name "*.sha256sum" -o -name "*.json" \) -printf '%f\n' | sort

# ============================================================
# ROM ZIP
# ============================================================

section "ROM ZIP CHECK"

ZIP=$(find "$OUT_DIR" -maxdepth 1 -type f -name "*.zip" ! -name "*ota*.zip" | head -n 1)

if [ -n "$ZIP" ]; then
    echo -e "${GREEN}ROM ZIP found:${RESET}"
    echo "$ZIP"
else
    echo -e "${RED}No ROM ZIP found in artifacts!${RESET}"
    exit 1
fi

# ============================================================
# IMAGE CHECK
# ============================================================

section "IMAGE CHECK"

for IMAGE in boot.img vendor.img system.img init_boot.img recovery.img dtb.img; do
    if [ -f "$OUT_DIR/$IMAGE" ]; then
        echo -e "${GREEN}[OK]${RESET} $IMAGE"
    else
        echo -e "${YELLOW}[--]${RESET} $IMAGE"
    fi
done

# ============================================================
# SHA256
# ============================================================

section "SHA256"

command -v sha256sum >/dev/null 2>&1 && sha256sum "$ZIP"

# ============================================================
# FINAL
# ============================================================

section "BUILD COMPLETE"

echo -e "${GREEN}${BOLD}ROM:${RESET} $ROM_NAME"
echo -e "${GREEN}${BOLD}DEVICE:${RESET} $DEVICE"
echo
echo "Kernel: $PREBUILT_KERNEL"
echo "ZIP: $ZIP"
echo "Output: $OUT_DIR"
echo "Build time: $BUILD_TIME seconds"
echo
echo "Auto-fix log: $AUTOFIX_LOG"
echo
echo "============================================================"
echo "                       DONE"
echo "============================================================"
