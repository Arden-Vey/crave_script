```bash
#!/bin/bash
set -euo pipefail

# ============================================================
# LINEAGEOS 23.2 - GENERIC ARM64 BUILD
# ============================================================

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
PRODUCT="lineage_Generic_arm64"
RELEASE="trunk_staging"
VARIANT="userdebug"

MANIFEST_URL="https://github.com/JBHPocong/lineage-tissot-manifest.git"
MANIFEST_BRANCH="generic"

BUILD_USERNAME="Arden-Vey"
BUILD_HOSTNAME="crave"

OUT_DIR="out/target/product/${DEVICE}"

# ============================================================
# FUNCTIONS
# ============================================================

info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

success() {
    echo -e "${GREEN}[OK]${RESET} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

section() {
    echo
    echo -e "${CYAN}${BOLD}============================================================${RESET}"
    echo -e "${CYAN}${BOLD} $1${RESET}"
    echo -e "${CYAN}${BOLD}============================================================${RESET}"
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
    echo "║                    G E N E R I C   M A I N L I N E              ║"
    echo "║                    Automated Release Builder                    ║"
    echo "║                                                                 ║"
    echo "╠═════════════════════════════════════════════════════════════════╣"
    echo "║  ROM        : LineageOS 23.2                                    ║"
    echo "║  Device     : Generic ARM64                                     ║"
    echo "║  Branch     : lineage-23.2                                      ║"
    echo "║  Release    : trunk_staging                                     ║"
    echo "║  Build      : userdebug                                         ║"
    echo "╚═════════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# ============================================================
# START
# ============================================================

banner

section "BUILD CONFIGURATION"

echo "ROM             : $ROM_NAME"
echo "Branch          : $ROM_BRANCH"
echo "Device          : $DEVICE"
echo "Product         : $PRODUCT"
echo "Release         : $RELEASE"
echo "Variant         : $VARIANT"
echo "Lunch           : $PRODUCT $RELEASE $VARIANT"
echo "Manifest        : $MANIFEST_URL"
echo "Manifest branch : $MANIFEST_BRANCH"
echo "Output          : $OUT_DIR"
echo "CPU threads     : $(nproc --all)"

# ============================================================
# REQUIREMENTS
# ============================================================

section "CHECKING REQUIREMENTS"

for CMD in repo git curl; do
    if command -v "$CMD" >/dev/null 2>&1; then
        success "$CMD"
    else
        error "$CMD tidak ditemukan."
        exit 1
    fi
done

if [ ! -x "/opt/crave/resync.sh" ]; then
    error "/opt/crave/resync.sh tidak ditemukan."
    exit 1
fi

success "Build environment ready."

# ============================================================
# CLEAN LOCAL MANIFEST
# ============================================================

section "CLEANING LOCAL MANIFEST"

if [ -d ".repo/local_manifests" ]; then
    rm -rf .repo/local_manifests
    success "Old local manifests removed."
else
    info "No previous local manifests."
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

success "Repo initialized."

# ============================================================
# LOCAL MANIFEST
# ============================================================

section "CLONING LOCAL MANIFEST"

git clone \
    -b "$MANIFEST_BRANCH" \
    --depth=1 \
    "$MANIFEST_URL" \
    .repo/local_manifests

success "Local manifest cloned."

# ============================================================
# CRAVE SYNC
# ============================================================

section "SYNCING SOURCE"

info "Running /opt/crave/resync.sh ..."
/opt/crave/resync.sh

success "Source sync completed."

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
echo "LC_ALL=$LC_ALL"

# ============================================================
# LOAD BUILD ENVIRONMENT
# ============================================================

section "LOADING BUILD ENVIRONMENT"

if [ ! -f "build/envsetup.sh" ]; then
    error "build/envsetup.sh tidak ditemukan."
    exit 1
fi

source build/envsetup.sh

success "Build environment loaded."

# ============================================================
# CHECK GENERIC TREE
# ============================================================

section "CHECKING GENERIC DEVICE TREE"

REQUIRED_DIRS=(
    "device/mainline/generic"
    "device/mainline/common"
    "hardware/mainline/common"
)

for DIR in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
        success "$DIR"
    else
        error "$DIR tidak ditemukan."
        exit 1
    fi
done

# ============================================================
# OPTIONAL MAINLINE DEPENDENCIES
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
        success "$DIR"
    else
        warning "$DIR missing"
    fi
done

# ============================================================
# LUNCH
# ============================================================

section "LUNCH TARGET"

echo "Product : $PRODUCT"
echo "Release : $RELEASE"
echo "Variant : $VARIANT"
echo

info "Running:"
echo
echo "    lunch $PRODUCT $RELEASE $VARIANT"
echo

# IMPORTANT:
# Do NOT use:
# lunch lineage_Generic_arm64-userdebug
#
# LOS 23.2 uses:
# lunch PRODUCT RELEASE VARIANT

lunch "$PRODUCT" "$RELEASE" "$VARIANT"

success "Lunch completed."

# ============================================================
# VERIFY TARGET
# ============================================================

section "VERIFYING BUILD TARGET"

TARGET_PRODUCT="$(get_build_var TARGET_PRODUCT)"
TARGET_DEVICE="$(get_build_var TARGET_DEVICE)"
TARGET_RELEASE="$(get_build_var TARGET_RELEASE)"
TARGET_VARIANT="$(get_build_var TARGET_BUILD_VARIANT)"
TARGET_ARCH="$(get_build_var TARGET_ARCH)"
TARGET_ARCH_VARIANT="$(get_build_var TARGET_ARCH_VARIANT)"

echo "TARGET_PRODUCT       : $TARGET_PRODUCT"
echo "TARGET_DEVICE        : $TARGET_DEVICE"
echo "TARGET_RELEASE       : $TARGET_RELEASE"
echo "TARGET_BUILD_VARIANT : $TARGET_VARIANT"
echo "TARGET_ARCH          : $TARGET_ARCH"
echo "TARGET_ARCH_VARIANT  : $TARGET_ARCH_VARIANT"

if [ "$TARGET_PRODUCT" != "$PRODUCT" ]; then
    error "TARGET_PRODUCT tidak sesuai."
    exit 1
fi

if [ "$TARGET_VARIANT" != "$VARIANT" ]; then
    error "TARGET_BUILD_VARIANT tidak sesuai."
    exit 1
fi

success "Build target verified."

# ============================================================
# LIBJXL CHECK
# ============================================================

section "CHECKING LIBJXL"

if [ -f "external/libjxl/Android.bp" ]; then
    success "external/libjxl/Android.bp"

    grep -nE \
        'sdk_version|min_sdk_version|compile_multilib|apex_available|name:|libs:|shared_libs:|static_libs:' \
        external/libjxl/Android.bp \
        || true
else
    warning "external/libjxl/Android.bp missing"
fi

# ============================================================
# HIGHWAY CHECK
# ============================================================

section "CHECKING HIGHWAY"

if [ -f "external/highway/Android.bp" ]; then
    success "external/highway/Android.bp"

    grep -nE \
        'sdk_version|min_sdk_version|compile_multilib|apex_available|name:|libs:|shared_libs:|static_libs:' \
        external/highway/Android.bp \
        || true
else
    warning "external/highway/Android.bp missing"
fi

# ============================================================
# PRE-BUILD SUMMARY
# ============================================================

section "PRE-BUILD SUMMARY"

echo "ROM             : $ROM_NAME"
echo "Branch          : $ROM_BRANCH"
echo "Device          : $DEVICE"
echo "Product         : $PRODUCT"
echo "Release         : $RELEASE"
echo "Variant         : $VARIANT"
echo "Build username  : $BUILD_USERNAME"
echo "Build hostname  : $BUILD_HOSTNAME"
echo "CPU threads     : $(nproc --all)"
echo "Output          : $OUT_DIR"

echo
echo "Build command:"
echo
echo "    mka bacon"

# ============================================================
# BUILD
# ============================================================

section "STARTING BUILD"

BUILD_START=$(date +%s)

mka bacon

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

# ============================================================
# ARTIFACT CHECK
# ============================================================

section "CHECKING BUILD ARTIFACTS"

if [ ! -d "$OUT_DIR" ]; then
    error "Output directory tidak ditemukan:"
    echo "$OUT_DIR"
    exit 1
fi

success "Output directory exists:"
echo "$OUT_DIR"

echo
echo "Artifacts:"
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
# ROM ZIP
# ============================================================

section "ROM ZIP"

ZIP=""

while IFS= read -r FILE; do
    ZIP="$FILE"
    break
done < <(
    find "$OUT_DIR" \
        -maxdepth 1 \
        -type f \
        -name "*.zip" \
        ! -name "*ota*.zip" \
        | sort
)

if [ -n "$ZIP" ]; then
    success "ROM ZIP found:"
    echo "$ZIP"
else
    warning "No ROM ZIP found."
fi

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
    super.img
do
    if [ -f "$OUT_DIR/$IMAGE" ]; then
        success "$IMAGE"
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
else
    warning "ZIP tidak tersedia, SHA256 dilewati."
fi

# ============================================================
# BUILD TIME
# ============================================================

section "BUILD COMPLETE"

echo "ROM        : $ROM_NAME"
echo "Device     : $DEVICE"
echo "Product    : $PRODUCT"
echo "Release    : $RELEASE"
echo "Variant    : $VARIANT"
echo "Output     : $OUT_DIR"
echo "Build time : $BUILD_TIME seconds"

echo

if [ -n "$ZIP" ]; then
    echo -e "${GREEN}${BOLD}BUILD SUCCESS${RESET}"
    echo
    echo "ROM ZIP:"
    echo "$ZIP"
else
    echo -e "${YELLOW}${BOLD}BUILD FINISHED, BUT NO ROM ZIP WAS FOUND${RESET}"
fi

echo
echo "============================================================"
echo "                         DONE"
echo "============================================================"
```
