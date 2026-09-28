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

# ------------------------------------------------------------
# PATCH external/libjxl
# ------------------------------------------------------------

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

# ------------------------------------------------------------
# PATCH external/boringssl (fix libcrypto_static visibility)
# ------------------------------------------------------------

echo
echo "============================================="
echo "   patching external/boringssl visibility"
echo "============================================="

DEVICE_INIT_BP="device/mainline/generic/services/generic_init/Android.bp"
BORINGSSL_BP="external/boringssl/Android.bp"
GENERIC_INIT_VISIBILITY='"//device/mainline/generic/services/generic_init",'

# --- OPSI 1: Ganti libcrypto_static -> libcrypto di generic_init ---
if [ -f "$DEVICE_INIT_BP" ]; then
    if grep -q "libcrypto_static" "$DEVICE_INIT_BP"; then
        cp "$DEVICE_INIT_BP" "$DEVICE_INIT_BP.bak.$(date +%s)"
        sed -i 's/\blibcrypto_static\b/libcrypto/g' "$DEVICE_INIT_BP"
        echo -e "${GREEN}[OK]${RESET} libcrypto_static -> libcrypto di $DEVICE_INIT_BP"
    else
        echo -e "${GREEN}[OK]${RESET} Tidak ada libcrypto_static di $DEVICE_INIT_BP"
    fi
else
    echo -e "${YELLOW}[WARNING]${RESET} $DEVICE_INIT_BP tidak ditemukan, skip Opsi 1"
fi

# --- OPSI 2: Tambahkan visibility whitelist di boringssl ---
if [ -f "$BORINGSSL_BP" ]; then
    if grep -q "device/mainline/generic/services/generic_init" "$BORINGSSL_BP"; then
        echo -e "${GREEN}[OK]${RESET} Visibility sudah ada di $BORINGSSL_BP"
    else
        cp "$BORINGSSL_BP" "$BORINGSSL_BP.bak.$(date +%s)"

        python3 - <<'PYEOF' || warn "Gagal patch visibility boringssl via python3"
import re

bp_file = "external/boringssl/Android.bp"
target_visibility = '"//device/mainline/generic/services/generic_init",'

with open(bp_file, "r") as f:
    content = f.read()

pattern = r'(name:\s*"libcrypto_static",)(.*?)(\n\})'
match = re.search(pattern, content, re.DOTALL)

if not match:
    print("[WARN] Module libcrypto_static tidak ditemukan di Android.bp")
    raise SystemExit(0)

module_body = match.group(2)

if "visibility:" in module_body:
    new_body = re.sub(
        r'(visibility:\s*\[)(.*?)(\])',
        lambda m: m.group(1) + m.group(2) + "\n        " + target_visibility + "\n    " + m.group(3),
        module_body,
        flags=re.DOTALL
    )
    print("[INFO] Menambahkan ke visibility yang sudah ada")
else:
    new_body = module_body + "\n    visibility: [\n        " + target_visibility + "\n    ],"
    print("[INFO] Membuat visibility baru")

new_content = content[:match.start(2)] + new_body + content[match.end(2):]

with open(bp_file, "w") as f:
    f.write(new_content)

print("[OK] Visibility berhasil ditambahkan ke libcrypto_static")
PYEOF
    fi
else
    echo -e "${YELLOW}[WARNING]${RESET} $BORINGSSL_BP tidak ditemukan, skip Opsi 2"
fi

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
