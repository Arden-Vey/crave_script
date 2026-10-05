#!/bin/bash

# ============================================================
# TISSOT MAINLINE - FULL AUTO BUILD SCRIPT (ALL-IN-ONE)
# ============================================================
# LineageOS 23.2 + tissot_mainline
# Prebuilt kernel: Image.gz-dtb (kernel + DTB embedded)
#
# Auto-install: extract-dtb, dtc, python3, tools pendukung
# Auto-extract DTB dari Image.gz-dtb
# Auto-fix dtb.img missing
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

LOG_DIR="build_logs"
AUTOFIX_LOG="$LOG_DIR/autofix.log"
TOOLS_DIR="$HOME/.local/tissot-tools"
mkdir -p "$LOG_DIR" "$TOOLS_DIR"

# ============================================================
# HELPERS
# ============================================================
log() { echo -e "$1" | tee -a "$AUTOFIX_LOG"; }

section() {
    echo
    echo "============================================================" | tee -a "$AUTOFIX_LOG"
    echo "  $1" | tee -a "$AUTOFIX_LOG"
    echo "============================================================" | tee -a "$AUTOFIX_LOG"
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# ============================================================
# BANNER
# ============================================================
clear
echo -e "${CYAN}${BOLD}"
cat <<'BANNER'
╔═════════════════════════════════════════════════════════════════╗
║      ██╗     ██╗███╗   ██╗███████╗ █████╗  ██████╗ ███████╗     ║
║      ██║     ██║████╗  ██║██╔════╝██╔══██╗██╔════╝ ██╔════╝     ║
║      ██║     ██║██╔██╗ ██║█████╗  ███████║██║  ███╗█████╗       ║
║      ██║     ██║██║╚██╗██║██╔══╝  ██╔══██║██║   ██║██╔══╝       ║
║      ███████╗██║██║ ╚████║███████╗██║  ██║╚██████╔╝███████╗     ║
║      ╚══════╝╚═╝╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝     ║
║                  T I S S O T   M A I N L I N E                  ║
║         Automated Release Builder + AUTO DETECT/FIX v3          ║
╠═════════════════════════════════════════════════════════════════╣
║  ROM        : LineageOS 23.2                                    ║
║  Device     : tissot_mainline                                   ║
║  Kernel     : PREBUILT Image.gz-dtb                             ║
║  Auto-Fix   : dtb.img (extract asli) + auto-install tools       ║
╚═════════════════════════════════════════════════════════════════╝
BANNER
echo -e "${RESET}"

echo "=== AUTOFIX LOG $(date) ===" > "$AUTOFIX_LOG"

# ============================================================
# 0. ★ AUTO-INSTALL DEPENDENCIES ★
# ============================================================
section "AUTO-INSTALL DEPENDENCIES"

export PATH="$TOOLS_DIR/bin:$PATH"
mkdir -p "$TOOLS_DIR/bin"

# --- Python3 ---
if ! have_cmd python3; then
    log "${YELLOW}[WARN]${RESET} python3 tidak ada, mencoba install..."
    if have_cmd apt; then
        sudo apt-get update -qq && sudo apt-get install -y -qq python3 python3-pip
    elif have_cmd dnf; then
        sudo dnf install -y python3 python3-pip
    elif have_cmd pacman; then
        sudo pacman -Sy --noconfirm python python-pip
    fi
fi
log "${GREEN}[OK]${RESET} python3: $(python3 --version 2>&1 || echo 'N/A')"

# --- pip packages ---
PY_PIP_DEPS="extract-dtb"
for pkg in $PY_PIP_DEPS; do
    if ! python3 -c "import ${pkg//-/_}" 2>/dev/null && ! have_cmd "$pkg"; then
        log "${CYAN}[INFO]${RESET} Install pip package: $pkg"
        pip3 install --quiet --user "$pkg" 2>/dev/null || \
            pip3 install --quiet --break-system-packages "$pkg" 2>/dev/null || \
            pip3 install --quiet "$pkg" 2>/dev/null || \
            log "${YELLOW}[WARN]${RESET} Gagal install $pkg via pip, akan pakai fallback"
    fi
done

# --- extract-dtb (fallback: download standalone) ---
if ! have_cmd extract-dtb; then
    log "${CYAN}[INFO]${RESET} Download extract-dtb standalone script..."
    curl -fsSL -o "$TOOLS_DIR/bin/extract-dtb" \
        "https://raw.githubusercontent.com/PabloCastellano/extract-dtb/master/extract_dtb/extract_dtb.py" \
        2>/dev/null || \
    wget -q -O "$TOOLS_DIR/bin/extract-dtb" \
        "https://raw.githubusercontent.com/PabloCastellano/extract-dtb/master/extract_dtb/extract_dtb.py" \
        2>/dev/null || true

    if [ -f "$TOOLS_DIR/bin/extract-dtb" ] && [ -s "$TOOLS_DIR/bin/extract-dtb" ]; then
        chmod +x "$TOOLS_DIR/bin/extract-dtb"
        log "${GREEN}[OK]${RESET} extract-dtb (standalone) terinstall"
    else
        log "${YELLOW}[WARN]${RESET} extract-dtb tidak bisa diinstall, pakai metode fallback (scan magic)"
        rm -f "$TOOLS_DIR/bin/extract-dtb"
    fi
else
    log "${GREEN}[OK]${RESET} extract-dtb tersedia"
fi

# --- dtc (device tree compiler) ---
if ! have_cmd dtc; then
    log "${CYAN}[INFO]${RESET} Mencoba install dtc..."
    if have_cmd apt; then
        sudo apt-get install -y -qq device-tree-compiler 2>/dev/null || true
    elif have_cmd dnf; then
        sudo dnf install -y dtc 2>/dev/null || true
    elif have_cmd pacman; then
        sudo pacman -S --noconfirm dtc 2>/dev/null || true
    fi
fi
have_cmd dtc && log "${GREEN}[OK]${RESET} dtc: $(dtc --version 2>&1 | head -1)" \
             || log "${YELLOW}[INFO]${RESET} dtc tidak ada (tidak wajib, script punya fallback)"

# --- git-lfs ---
if ! have_cmd git-lfs; then
    log "${CYAN}[INFO]${RESET} Mencoba install git-lfs..."
    if have_cmd apt; then
        sudo apt-get install -y -qq git-lfs 2>/dev/null || true
    elif have_cmd dnf; then
        sudo dnf install -y git-lfs 2>/dev/null || true
    fi
    have_cmd git-lfs && git lfs install 2>/dev/null || true
fi
have_cmd git-lfs && log "${GREEN}[OK]${RESET} git-lfs tersedia" \
                 || log "${YELLOW}[WARN]${RESET} git-lfs tidak ada"

# --- curl / wget ---
if ! have_cmd curl && ! have_cmd wget; then
    log "${CYAN}[INFO]${RESET} Install curl/wget..."
    have_cmd apt && sudo apt-get install -y -qq curl wget 2>/dev/null || true
fi

log "${GREEN}[OK]${RESET} Dependency check selesai"

# ============================================================
# 1. CLEAN LOCAL MANIFEST
# ============================================================
section "CLEANING UP PREVIOUS LOCAL MANIFESTS"
rm -rf .repo/local_manifests
log "${GREEN}Local manifests cleaned.${RESET}"

# ============================================================
# 2. REPO INIT
# ============================================================
section "REPO INIT"
if ! have_cmd repo; then
    log "${CYAN}[INFO]${RESET} Install repo tool..."
    mkdir -p "$HOME/bin"
    curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo \
        -o "$HOME/bin/repo" 2>/dev/null || \
    wget -q -O "$HOME/bin/repo" \
        https://storage.googleapis.com/git-repo-downloads/repo
    chmod +x "$HOME/bin/repo"
    export PATH="$HOME/bin:$PATH"
fi

repo init -u https://github.com/LineageOS/android.git \
    -b "$ROM_BRANCH" --depth=1 --git-lfs
log "${GREEN}repo init completed.${RESET}"

# ============================================================
# 3. CLONE LOCAL MANIFEST
# ============================================================
section "CLONING MANIFEST"
git clone -b "$MANIFEST_BRANCH" --depth=1 \
    "$MANIFEST_URL" .repo/local_manifests
log "${GREEN}Local manifest cloned.${RESET}"

# ============================================================
# 4. VERIFY MANIFEST
# ============================================================
section "VERIFYING MANIFEST"
MANIFEST_FILE=$(find .repo/local_manifests -name "*.xml" | head -n 1)

if [ -z "$MANIFEST_FILE" ]; then
    log "${RED}[ERROR]${RESET} Manifest XML tidak ditemukan"
    exit 1
fi
log "${GREEN}[OK]${RESET} Manifest: $MANIFEST_FILE"

grep -q "prebuilts/kernel/tissot" "$MANIFEST_FILE" \
    && log "${GREEN}[OK]${RESET} Prebuilt kernel project terdeteksi" \
    || { log "${RED}[ERROR]${RESET} Prebuilt kernel project tidak ditemukan"; exit 1; }

grep -q 'revision="Image.gz-dtb"' "$MANIFEST_FILE" \
    && log "${GREEN}[OK]${RESET} Kernel revision: Image.gz-dtb" \
    || { log "${RED}[ERROR]${RESET} Revision Image.gz-dtb tidak ditemukan"; exit 1; }

# ============================================================
# 5. REPO SYNC
# ============================================================
section "REPO SYNC"
if [ -x /opt/crave/resync.sh ]; then
    /opt/crave/resync.sh
else
    repo sync -c -j"$(nproc --all)" --force-sync --no-clone-bundle --no-tags
fi
log "${GREEN}Repository sync completed.${RESET}"

# ============================================================
# 6. VERIFY PREBUILT KERNEL
# ============================================================
section "VERIFYING PREBUILT KERNEL"

if [ ! -f "$PREBUILT_KERNEL" ]; then
    log "${RED}[ERROR]${RESET} Image.gz-dtb tidak ditemukan: $PREBUILT_KERNEL"
    exit 1
fi

KERNEL_SIZE=$(stat -c%s "$PREBUILT_KERNEL" 2>/dev/null || stat -f%z "$PREBUILT_KERNEL")
log "${GREEN}[OK]${RESET} Image.gz-dtb ditemukan (${KERNEL_SIZE} bytes)"

if [ "$KERNEL_SIZE" -lt 1000000 ]; then
    log "${YELLOW}[WARN]${RESET} File terlalu kecil, coba git lfs pull..."
    (cd "$PREBUILT_KERNEL_DIR" && git lfs pull) || true
    KERNEL_SIZE=$(stat -c%s "$PREBUILT_KERNEL" 2>/dev/null || echo 0)
    if [ "$KERNEL_SIZE" -lt 1000000 ]; then
        log "${RED}[ERROR]${RESET} Image.gz-dtb masih corrupt"
        exit 1
    fi
fi

ls -lh "$PREBUILT_KERNEL"
file "$PREBUILT_KERNEL" 2>/dev/null || true

# ============================================================
# 7. BUILD ENV
# ============================================================
section "BUILD ENVIRONMENT SETUP"
export BUILD_USERNAME="$BUILD_USERNAME"
export BUILD_HOSTNAME="$BUILD_HOSTNAME"
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C

# ============================================================
# 8. PATCH LIBJXL
# ============================================================
section "PATCHING external/libjxl"
if [ -f "external/libjxl/Android.bp" ]; then
    sed -i 's/sdk_version: "none"/sdk_version: "current"/' external/libjxl/Android.bp
    log "${GREEN}[OK]${RESET} external/libjxl/Android.bp dipatch"
else
    log "${YELLOW}[WARN]${RESET} external/libjxl/Android.bp tidak ditemukan"
fi

# ============================================================
# 9. PATCH DEVICE.MK
# ============================================================
section "PATCHING tissot_mainline/device.mk"
if [ -f "$DEVICE_MK" ]; then
    cp "$DEVICE_MK" "$DEVICE_MK.bak"

    sed -i 's|^\(.*vendor/xiaomi/msm8953-common.*\)$|# \1|' "$DEVICE_MK"

    ACTIVE_REFS=$(grep -n "^[^#].*vendor/xiaomi/msm8953-common" "$DEVICE_MK" || true)
    if [ -n "$ACTIVE_REFS" ]; then
        log "${RED}[ERROR]${RESET} masih ada referensi vendor blobs aktif!"
        log "$ACTIVE_REFS"
        mv "$DEVICE_MK.bak" "$DEVICE_MK"
        exit 1
    fi
    log "${GREEN}[OK]${RESET} vendor blobs di-comment"
else
    log "${RED}[ERROR]${RESET} $DEVICE_MK tidak ditemukan"
    exit 1
fi

# ============================================================
# 10. SOURCE BUILD ENV + LUNCH
# ============================================================
section "LOADING BUILD ENVIRONMENT"
source build/envsetup.sh
log "${GREEN}Build environment loaded.${RESET}"

section "LUNCH"
lunch "$LUNCH_TARGET"
log "${GREEN}Lunch completed.${RESET}"

# ============================================================
# 11. ★★★ EXTRACT DTB DARI Image.gz-dtb ★★★
# ============================================================
section "EXTRACTING DTB FROM Image.gz-dtb"

if [ -f "$PREBUILT_DTB" ] && [ "$(stat -c%s "$PREBUILT_DTB")" -gt 1000 ]; then
    log "${GREEN}[OK]${RESET} dtb.img sudah ada ($(stat -c%s "$PREBUILT_DTB") bytes)"
else
    TMP_EXTRACT=$(mktemp -d)
    DTB_EXTRACTED=""

    # --- METODE 1: extract-dtb ---
    if have_cmd extract-dtb; then
        log "${CYAN}[INFO]${RESET} Metode 1: extract-dtb..."
        (cd "$TMP_EXTRACT" && extract-dtb "$OLDPWD/$PREBUILT_KERNEL") >/dev/null 2>&1 || true
        if [ -f "$TMP_EXTRACT/dtb" ]; then
            DTB_EXTRACTED="$TMP_EXTRACT/dtb"
        elif ls "$TMP_EXTRACT"/dtb.* >/dev/null 2>&1; then
            cat "$TMP_EXTRACT"/dtb.* > "$TMP_EXTRACT/combined.dtb"
            DTB_EXTRACTED="$TMP_EXTRACT/combined.dtb"
        fi
    fi

    # --- METODE 2: unpack_bootimg ---
    if [ -z "$DTB_EXTRACTED" ] && have_cmd unpack_bootimg; then
        log "${CYAN}[INFO]${RESET} Metode 2: unpack_bootimg..."
        (cd "$TMP_EXTRACT" && unpack_bootimg --boot_img "$OLDPWD/$PREBUILT_KERNEL" \
            --out "$TMP_EXTRACT/out") >/dev/null 2>&1 || true
        [ -f "$TMP_EXTRACT/out/dtb" ] && DTB_EXTRACTED="$TMP_EXTRACT/out/dtb"
    fi

    # --- METODE 3: gunzip + scan magic DTB ---
    if [ -z "$DTB_EXTRACTED" ]; then
        log "${CYAN}[INFO]${RESET} Metode 3: gunzip + scan magic 0xd00dfeed..."

        # Decompress
        if file "$PREBUILT_KERNEL" 2>/dev/null | grep -qi gzip || \
           [[ "$PREBUILT_KERNEL" == *.gz ]]; then
            gunzip -c "$PREBUILT_KERNEL" > "$TMP_EXTRACT/Image" 2>/dev/null || \
                zcat "$PREBUILT_KERNEL" > "$TMP_EXTRACT/Image" 2>/dev/null || \
                cp "$PREBUILT_KERNEL" "$TMP_EXTRACT/Image"
        else
            cp "$PREBUILT_KERNEL" "$TMP_EXTRACT/Image"
        fi

        if [ -f "$TMP_EXTRACT/Image" ]; then
            python3 - "$TMP_EXTRACT/Image" "$TMP_EXTRACT/found.dtb" <<'PY' || true
import sys, struct
data = open(sys.argv[1], 'rb').read()
magic = b'\xd0\x0d\xfe\xed'
pos = data.find(magic)
if pos == -1:
    sys.exit(1)
if pos + 8 > len(data):
    sys.exit(1)
total_size = int.from_bytes(data[pos+4:pos+8], 'big')
if total_size <= 0 or pos + total_size > len(data):
    dtb = data[pos:]
else:
    dtb = data[pos:pos+total_size]
open(sys.argv[2], 'wb').write(dtb)
print(f"DTB found at offset {pos}, size {len(dtb)}")
PY

            if [ -f "$TMP_EXTRACT/found.dtb" ] && \
               [ "$(stat -c%s "$TMP_EXTRACT/found.dtb")" -gt 100 ]; then
                DTB_EXTRACTED="$TMP_EXTRACT/found.dtb"
            fi
        fi
    fi

    # --- SIMPAN HASIL ---
    if [ -n "$DTB_EXTRACTED" ] && [ -f "$DTB_EXTRACTED" ]; then
        cp "$DTB_EXTRACTED" "$PREBUILT_DTB"
        log "${GREEN}[OK]${RESET} dtb.img berhasil di-extract ($(stat -c%s "$PREBUILT_DTB") bytes)"
    else
        log "${YELLOW}[FALLBACK]${RESET} Buat minimal valid DTB (bukan kosong)..."

        python3 - "$PREBUILT_DTB" <<'PY'
import struct, sys

def align4(b):
    while len(b) % 4 != 0:
        b += b'\x00'
    return b

# Struct block: BEGIN_NODE "root" + END_NODE + END
struct_block = struct.pack('>I', 1) + b'root\x00'
struct_block = align4(struct_block)
struct_block += struct.pack('>I', 2)  # END_NODE
struct_block = align4(struct_block)
struct_block += struct.pack('>I', 9)  # END
struct_block = align4(struct_block)

size_dt_struct = len(struct_block)
off_dt_struct = 0x38  # header(40) + mem_rsvmap(16)
size_dt_strings = 0
off_dt_strings = off_dt_struct + size_dt_struct
off_mem_rsvmap = 0x28
mem_rsv = b'\x00' * 16
totalsize = off_dt_strings  # tidak ada strings

header = struct.pack('>10I',
    0xd00dfeed, totalsize, off_dt_struct, off_dt_strings,
    off_mem_rsvmap, 17, 16, 0, size_dt_strings, size_dt_struct)

open(sys.argv[1], 'wb').write(header + mem_rsv + struct_block)
print(f"Minimal DTB written: {totalsize} bytes")
PY
        log "${GREEN}[OK]${RESET} Minimal DTB dibuat"
    fi

    rm -rf "$TMP_EXTRACT"
fi

# Verifikasi final dtb.img
if [ ! -f "$PREBUILT_DTB" ] || [ "$(stat -c%s "$PREBUILT_DTB")" -lt 100 ]; then
    log "${RED}[ERROR]${RESET} dtb.img tidak valid!"
    exit 1
fi
log "${GREEN}[OK]${RESET} dtb.img final: $(stat -c%s "$PREBUILT_DTB") bytes"

# ============================================================
# 12. PATCH BOARDCONFIG
# ============================================================
section "PATCHING TISSOT BOARDCONFIG"

if [ ! -f "$BOARD_CONFIG" ]; then
    log "${RED}[ERROR]${RESET} BoardConfig tidak ditemukan"
    exit 1
fi

[ ! -f "$BOARD_CONFIG.bak-prebuilt" ] && cp "$BOARD_CONFIG" "$BOARD_CONFIG.bak-prebuilt"

# Hapus konfigurasi kernel lama
python3 - "$BOARD_CONFIG" <<'PY'
import re, sys
path = sys.argv[1]
lines = open(path).readlines()

variables = {
    "TARGET_KERNEL_SOURCE", "TARGET_KERNEL_CONFIG", "TARGET_KERNEL_CONFIG_EXT",
    "TARGET_PREBUILT_KERNEL", "TARGET_FORCE_PREBUILT_KERNEL",
    "BOARD_KERNEL_IMAGE_NAME", "BOARD_PREBUILT_DTBIMAGE_DIR",
    "TARGET_PREBUILT_DTB", "BOARD_PREBUILT_DTB", "BOARD_KERNEL_DTB",
    "TARGET_KERNEL_DTB", "TARGET_KERNEL_DTBIMAGE", "BOARD_KERNEL_SEPARATED_DT",
    "BOARD_KERNEL_DTBIMAGE", "BOARD_DTB_IMAGE", "BOARD_INCLUDE_DTB_IN_BOOTIMG",
}

out = []
for line in lines:
    s = line.lstrip()
    if s.startswith("#"):
        out.append(line); continue
    m = re.match(r'^\s*([A-Za-z0-9_]+)\s*(?::|\?|\+)?=\s*', line)
    if m and m.group(1) in variables:
        out.append("# PREBUILT-KERNEL: disabled old setting: " + line)
    else:
        out.append(line)

open(path, "w").writelines(out)
PY

cat >> "$BOARD_CONFIG" <<'EOF'

# ============================================================
# PREBUILT MAINLINE KERNEL (AUTO-FIX v3)
# ============================================================
# Image.gz-dtb sudah mengandung DTB, tapi ninja tetap butuh
# file dtb.img untuk target_files.zip.list.
# Solusi: TARGET_PREBUILT_DTB di-set ke dtb.img yang di-extract
# dari Image.gz-dtb oleh script.

TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64

BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb

TARGET_PREBUILT_KERNEL := prebuilts/kernel/tissot/Image.gz-dtb

# DTB terpisah — di-extract dari Image.gz-dtb oleh script
TARGET_PREBUILT_DTB := prebuilts/kernel/tissot/dtb.img
BOARD_PREBUILT_DTBIMAGE_DIR := prebuilts/kernel/tissot

# Boot.img pakai Image.gz-dtb yang sudah embed DTB
BOARD_INCLUDE_DTB_IN_BOOTIMG := false
EOF

log "${GREEN}[OK]${RESET} Prebuilt kernel configuration ditambahkan"

# ============================================================
# 13. VERIFIKASI FINAL
# ============================================================
section "VERIFIKASI BOARDCONFIG"
grep -nE \
    'TARGET_KERNEL_ARCH|BOARD_KERNEL_IMAGE_NAME|TARGET_PREBUILT_KERNEL|TARGET_PREBUILT_DTB|BOARD_PREBUILT_DTBIMAGE_DIR|BOARD_INCLUDE_DTB_IN_BOOTIMG' \
    "$BOARD_CONFIG" || true

# ============================================================
# 14. BUILD
# ============================================================
section "STARTING BUILD"
log "Command: mka bacon"

BUILD_START=$(date +%s)
set +e
mka bacon 2>&1 | tee -a "$LOG_DIR/build.log"
BUILD_STATUS=${PIPESTATUS[0]}
set -e
BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

# ============================================================
# 15. POST-BUILD
# ============================================================
if [ $BUILD_STATUS -ne 0 ]; then
    section "BUILD FAILED"
    log "${RED}Build failed (status=$BUILD_STATUS, time=${BUILD_TIME}s)${RESET}"

    if grep -q "dtb\.img.*missing and no known rule" "$LOG_DIR/build.log"; then
        log "${RED}[DETEKSI]${RESET} error dtb.img masih muncul"
        log "  dtb.img: $PREBUILT_DTB ($(stat -c%s "$PREBUILT_DTB" 2>/dev/null || echo 0) bytes)"
        log "  BoardConfig: $BOARD_CONFIG"
        log "  Coba cek manual apakah TARGET_PREBUILT_DTB ke-load"
    else
        log "${YELLOW}[INFO]${RESET} Error bukan dtb.img. 10 error terakhir:"
        grep -E "FAILED:|error:|Error:" "$LOG_DIR/build.log" | tail -n 10 || true
    fi

    log "Log lengkap: $LOG_DIR/build.log"
    exit $BUILD_STATUS
fi

# ============================================================
# 16. SUCCESS
# ============================================================
section "BUILD SUCCESS"
log "${GREEN}Build completed in ${BUILD_TIME}s${RESET}"

section "BUILD ARTIFACTS"
find "$OUT_DIR" -maxdepth 1 -type f \
    \( -name "*.zip" -o -name "*.img" -o -name "*.sha256sum" -o -name "*.json" \) \
    -printf '%f\n' | sort

ZIP=$(find "$OUT_DIR" -maxdepth 1 -type f -name "*.zip" ! -name "*ota*.zip" | head -n 1)
if [ -z "$ZIP" ]; then
    log "${RED}No ROM ZIP found!${RESET}"
    exit 1
fi
log "${GREEN}ROM ZIP: $ZIP${RESET}"

section "IMAGE CHECK"
for IMAGE in boot.img vendor.img system.img init_boot.img recovery.img dtb.img; do
    if [ -f "$OUT_DIR/$IMAGE" ]; then
        log "${GREEN}[OK]${RESET} $IMAGE"
    else
        log "${YELLOW}[--]${RESET} $IMAGE (tidak ada)"
    fi
done

section "SHA256"
sha256sum "$ZIP"

section "DONE"
log "ROM: $ROM_NAME"
log "Device: $DEVICE"
log "Kernel: $PREBUILT_KERNEL"
log "DTB: $PREBUILT_DTB"
log "ZIP: $ZIP"
log "Build time: ${BUILD_TIME}s"
log "Auto-fix log: $AUTOFIX_LOG"
