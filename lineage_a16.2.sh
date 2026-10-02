```bash
#!/bin/bash

# ============================================================
# LINEAGEOS 23.2 TISSOT MAINLINE
# AUTOMATED BUILD + KERNEL UNKNOWN SYMBOL AUTO-FIX
# ============================================================

# ============================================================
# SAFETY
# ============================================================

set -u

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

KERNEL_DIR="kernel/mainline/msm8953-mainline"
KERNEL_OUT="$OUT_DIR/obj/KERNEL_OBJ"

KERNEL_CONFIG="$KERNEL_OUT/.config"
MODULE_SYMVERS="$KERNEL_OUT/Module.symvers"

AUTO_KERNEL_FIX="${AUTO_KERNEL_FIX:-1}"
AUTO_REBUILD="${AUTO_REBUILD:-1}"
MAX_RETRIES="${MAX_RETRIES:-2}"

KERNEL_FIX_DIR="out/kernel-auto-fix"
UNKNOWN_SYMBOLS="$KERNEL_FIX_DIR/unknown-symbols.txt"
PROVIDER_REPORT="$KERNEL_FIX_DIR/provider-report.txt"
CONFIG_REPORT="$KERNEL_FIX_DIR/config-changes.txt"
FIX_LOG="$KERNEL_FIX_DIR/fix.log"

# ============================================================
# FUNCTIONS
# ============================================================

log() {
    echo -e "${CYAN}[INFO]${RESET} $*"
}

ok() {
    echo -e "${GREEN}[OK]${RESET} $*"
}

warn() {
    echo -e "${YELLOW}[WARNING]${RESET} $*"
}

error() {
    echo -e "${RED}[ERROR]${RESET} $*"
}

die() {
    error "$*"
    exit 1
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
    echo "║                Automated Release Builder                        ║"
    echo "║                                                                 ║"
    echo "╠═════════════════════════════════════════════════════════════════╣"
    echo "║  ROM        : LineageOS 23.2                                    ║"
    echo "║  Device     : tissot_mainline                                   ║"
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
echo "Lunch target    : $LUNCH_TARGET"
echo "Manifest        : $MANIFEST_URL"
echo "Manifest branch : $MANIFEST_BRANCH"
echo "Output          : $OUT_DIR"
echo "Kernel          : $KERNEL_DIR"
echo "Kernel output   : $KERNEL_OUT"
echo

# ============================================================
# PREPARE AUTO-FIX DIRECTORY
# ============================================================

mkdir -p "$KERNEL_FIX_DIR"

touch "$FIX_LOG"

# ============================================================
# CLEAN LOCAL MANIFEST
# ============================================================

echo
echo "============================================="
echo "    cleaning up previous local manifests"
echo "============================================="

rm -rf .repo/local_manifests

ok "Local manifests cleaned."

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

ok "repo init completed."

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

ok "Local manifest cloned."

# ============================================================
# CRAVE SYNC
# ============================================================

echo
echo "==================="
echo "     repo sync"
echo "==================="

/opt/crave/resync.sh

ok "Repository sync completed."

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
# PATCH LIBJXL
# ============================================================

echo
echo "============================================="
echo "       patching external/libjxl"
echo "============================================="

if [ -f "external/libjxl/Android.bp" ]; then

    sed -i 's/sdk_version: "none"/sdk_version: "current"/' \
        external/libjxl/Android.bp

    ok "external/libjxl/Android.bp dipatch"

else

    warn "external/libjxl/Android.bp tidak ditemukan"

fi

# ============================================================
# PATCH DEVICE.MK
# ============================================================

echo
echo "============================================="
echo "   patching tissot_mainline/device.mk"
echo "============================================="

if [ -f "$DEVICE_MK" ]; then

    cp "$DEVICE_MK" "$DEVICE_MK.bak"

    echo "Backup: $DEVICE_MK.bak"

    sed -i \
        's|^\(.*vendor/xiaomi/msm8953-common.*\)$|# \1|' \
        "$DEVICE_MK"

    sed -i \
        '/^PRODUCT_COPY_FILES += \\$/{N;/^# .*vendor\/xiaomi\/msm8953-common/s/^/# /}' \
        "$DEVICE_MK"

    ACTIVE_REFS=$(
        grep -n \
        "^[^#].*vendor/xiaomi/msm8953-common" \
        "$DEVICE_MK" || true
    )

    if [ -n "$ACTIVE_REFS" ]; then

        error "masih ada referensi vendor blobs yang aktif!"

        echo
        echo "Baris aktif:"
        echo "$ACTIVE_REFS"

        echo
        echo "Restore dari backup..."

        mv "$DEVICE_MK.bak" "$DEVICE_MK"

        exit 1

    else

        ok "vendor blobs di-comment"
        ok "verifikasi: tidak ada vendor blobs aktif"

    fi

    EMPTY_COPY=$(
        grep -n \
        "^PRODUCT_COPY_FILES += \\\\$" \
        "$DEVICE_MK" || true
    )

    if [ -n "$EMPTY_COPY" ]; then

        warn "ada PRODUCT_COPY_FILES += \\ yang kosong"

        echo "$EMPTY_COPY"

        echo "Cek manual:"
        echo "$DEVICE_MK"

    fi

else

    error "$DEVICE_MK tidak ditemukan"
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

    warn "$PROP_FILE tidak ditemukan."
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

ok "Build environment loaded."

# ============================================================
# LUNCH
# ============================================================

echo
echo "===================="
echo "       lunch"
echo "===================="

lunch "$LUNCH_TARGET"

ok "Lunch completed."

# ============================================================
# DEVICE CHECK
# ============================================================

echo
echo "============================================="
echo "          checking device tree"
echo "============================================="

if [ -d "device/xiaomi/mi89xx-mainline" ]; then

    ok "device/xiaomi/mi89xx-mainline"

else

    error "device/xiaomi/mi89xx-mainline"
    exit 1

fi

# ============================================================
# KERNEL CHECK
# ============================================================

echo
echo "============================================="
echo "          checking mainline kernel"
echo "============================================="

if [ -d "$KERNEL_DIR" ]; then

    ok "$KERNEL_DIR"

else

    error "$KERNEL_DIR"
    exit 1

fi

# ============================================================
# LIBJXL DEBUG
# ============================================================

echo
echo "============================================="
echo "       checking external/libjxl"
echo "============================================="

if [ -f "external/libjxl/Android.bp" ]; then

    ok "external/libjxl/Android.bp"

    echo
    echo "Relevant properties:"

    grep -nE \
        'sdk_version|min_sdk_version|compile_multilib|apex_available|name:|libs:|shared_libs:|static_libs:' \
        external/libjxl/Android.bp \
        || true

else

    warn "external/libjxl/Android.bp missing"

fi

# ============================================================
# HIGHWAY DEBUG
# ============================================================

echo
echo "============================================="
echo "       checking external/highway"
echo "============================================="

if [ -f "external/highway/Android.bp" ]; then

    ok "external/highway/Android.bp"

    echo
    echo "Relevant properties:"

    grep -nE \
        'sdk_version|min_sdk_version|compile_multilib|apex_available|name:|libs:|shared_libs:|static_libs:' \
        external/highway/Android.bp \
        || true

else

    warn "external/highway/Android.bp missing"

fi

# ============================================================
# VENDOR COMMON VERIFICATION
# ============================================================

echo
echo "===================================="
echo "    Checking vendor/vendor-common   "
echo "===================================="

if grep -q \
    "^[^#].*vendor/xiaomi/msm8953-common" \
    "$DEVICE_MK"; then

    error "masih ada referensi vendor blobs yang aktif!"

    echo
    grep -n \
        "^[^#].*vendor/xiaomi/msm8953-common" \
        "$DEVICE_MK"

    exit 1

fi

if grep -q \
    "^PRODUCT_COPY_FILES += \\\\$" \
    "$DEVICE_MK"; then

    warn "ada PRODUCT_COPY_FILES += \\ yang kosong"

fi

ok "patch berhasil"

# ============================================================
# ============================================================
# KERNEL AUTO SYMBOL FIX
# ============================================================
# ============================================================

extract_unknown_symbols() {

    mkdir -p "$KERNEL_FIX_DIR"

    : > "$UNKNOWN_SYMBOLS"

    log "Scanning build logs for unknown kernel symbols..."

    SEARCH_FILES=""

    [ -f "out/error.log" ] && SEARCH_FILES="$SEARCH_FILES out/error.log"
    [ -f "out/verbose.log" ] && SEARCH_FILES="$SEARCH_FILES out/verbose.log"
    [ -f "out/verbose.log.gz" ] && SEARCH_FILES="$SEARCH_FILES out/verbose.log.gz"
    [ -f "$KERNEL_FIX_DIR/depmod.stderr" ] && \
        SEARCH_FILES="$SEARCH_FILES $KERNEL_FIX_DIR/depmod.stderr"

    if [ -z "$SEARCH_FILES" ]; then

        warn "Tidak ada log yang bisa discan."
        return 1

    fi

    for FILE in $SEARCH_FILES; do

        case "$FILE" in

            *.gz)
                zcat "$FILE" 2>/dev/null || true
                ;;

            *)
                cat "$FILE" 2>/dev/null || true
                ;;

        esac

    done |
    grep -oE \
        'needs unknown symbol [A-Za-z0-9_]+|unknown symbol [A-Za-z0-9_]+' |
    sed -E \
        's/.*unknown symbol[[:space:]]+//' |
    sort -u > "$UNKNOWN_SYMBOLS"

    if [ ! -s "$UNKNOWN_SYMBOLS" ]; then

        warn "Tidak ditemukan unknown symbol."

        return 1

    fi

    echo
    echo "Unknown symbols:"
    cat "$UNKNOWN_SYMBOLS"
    echo

    return 0
}

# ============================================================
# FIND SYMBOL PROVIDER
# ============================================================

find_symbol_provider() {

    SYMBOL="$1"

    grep -RIl \
        --exclude-dir=.git \
        --exclude-dir=Documentation \
        --exclude-dir=tools \
        -E \
        "EXPORT_SYMBOL(_GPL)?[[:space:]]*\([[:space:]]*$SYMBOL[[:space:]]*\)" \
        "$KERNEL_DIR" \
        2>/dev/null |
        head -n 1

}

# ============================================================
# FIND KCONFIG FOR FILE
# ============================================================

find_kconfig_for_file() {

    FILE="$1"

    REL="${FILE#$KERNEL_DIR/}"

    DIR=$(dirname "$REL")

    CURRENT="$DIR"

    while [ "$CURRENT" != "." ] && [ "$CURRENT" != "/" ]; do

        for KFILE in \
            "$KERNEL_DIR/$CURRENT/Kconfig" \
            "$KERNEL_DIR/$CURRENT/Kconfig.*"; do

            if [ -f "$KFILE" ]; then
                echo "$KFILE"
                return 0
            fi

        done

        CURRENT=$(dirname "$CURRENT")

    done

    find "$KERNEL_DIR" \
        -type f \
        \( -name "Kconfig" -o -name "Kconfig.*" \) \
        -print 2>/dev/null |
        head -n 1

}

# ============================================================
# SYMBOL PROVIDER REPORT
# ============================================================

generate_provider_report() {

    echo
    echo "============================================="
    echo "       KERNEL SYMBOL PROVIDER ANALYSIS"
    echo "============================================="

    : > "$PROVIDER_REPORT"

    if [ ! -s "$UNKNOWN_SYMBOLS" ]; then
        warn "Tidak ada unknown symbols."
        return
    fi

    while IFS= read -r SYMBOL; do

        [ -z "$SYMBOL" ] && continue

        echo
        echo "Symbol: $SYMBOL"

        PROVIDER=$(find_symbol_provider "$SYMBOL" || true)

        if [ -n "$PROVIDER" ]; then

            echo "Provider: $PROVIDER"

            {
                echo "SYMBOL=$SYMBOL"
                echo "PROVIDER=$PROVIDER"
            } >> "$PROVIDER_REPORT"

            KCONFIG=$(find_kconfig_for_file "$PROVIDER" || true)

            if [ -n "$KCONFIG" ]; then
                echo "Kconfig: $KCONFIG"
                echo "KCONFIG=$KCONFIG" >> "$PROVIDER_REPORT"
            else
                echo "Kconfig: NOT FOUND"
            fi

        else

            echo "Provider: NOT FOUND"

            {
                echo "SYMBOL=$SYMBOL"
                echo "PROVIDER=NOT_FOUND"
            } >> "$PROVIDER_REPORT"

        fi

        echo "---------------------------------------------"

    done < "$UNKNOWN_SYMBOLS"

}

# ============================================================
# SAFE KNOWN CONFIG DETECTION
# ============================================================

detect_safe_configs() {

    echo
    echo "============================================="
    echo "       SAFE KERNEL CONFIG DETECTION"
    echo "============================================="

    : > "$CONFIG_REPORT"

    [ ! -f "$KERNEL_CONFIG" ] && {
        warn "Kernel .config belum ada."
        return
    }

    [ ! -x "$KERNEL_DIR/scripts/config" ] && {

        echo "Building scripts/config..."

        make -C "$KERNEL_DIR" \
            O="$KERNEL_OUT" \
            ARCH=arm64 \
            LLVM=1 \
            LLVM_IAS=1 \
            scripts

    }

    CONFIG_TOOL="$KERNEL_DIR/scripts/config"

    if [ ! -x "$CONFIG_TOOL" ]; then

        warn "scripts/config tidak tersedia."
        return

    fi

    # --------------------------------------------------------
    # IMPORTANT:
    # Hanya config yang benar-benar dapat diverifikasi.
    # --------------------------------------------------------

    declare -A SAFE_CONFIGS

    SAFE_CONFIGS["drm_fb_helper_damage_area"]="CONFIG_DRM_FBDEV_EMULATION"
    SAFE_CONFIGS["drm_fb_helper_fini"]="CONFIG_DRM_FBDEV_EMULATION"
    SAFE_CONFIGS["drm_fb_helper_check_var"]="CONFIG_DRM_FBDEV_EMULATION"
    SAFE_CONFIGS["drm_fb_helper_set_par"]="CONFIG_DRM_FBDEV_EMULATION"
    SAFE_CONFIGS["drm_fb_helper_setcmap"]="CONFIG_DRM_FBDEV_EMULATION"
    SAFE_CONFIGS["drm_fb_helper_blank"]="CONFIG_DRM_FBDEV_EMULATION"
    SAFE_CONFIGS["drm_fb_helper_pan_display"]="CONFIG_DRM_FBDEV_EMULATION"
    SAFE_CONFIGS["drm_fb_helper_ioctl"]="CONFIG_DRM_FBDEV_EMULATION"

    SAFE_CONFIGS["drm_sched_wqueue_stop"]="CONFIG_DRM_SCHED"
    SAFE_CONFIGS["drm_sched_wqueue_start"]="CONFIG_DRM_SCHED"

    SAFE_CONFIGS["qcom_mdt_get_size"]="CONFIG_QCOM_MDT_LOADER"
    SAFE_CONFIGS["qcom_mdt_load"]="CONFIG_QCOM_MDT_LOADER"

    SAFE_CONFIGS["devm_reboot_mode_register"]="CONFIG_REBOOT_MODE"

    declare -A ENABLED

    while IFS= read -r SYMBOL; do

        [ -z "$SYMBOL" ] && continue

        CONFIG="${SAFE_CONFIGS[$SYMBOL]:-}"

        [ -z "$CONFIG" ] && continue

        if [ -n "${ENABLED[$CONFIG]:-}" ]; then
            continue
        fi

        echo
        echo "Symbol : $SYMBOL"
        echo "Config : $CONFIG"

        # Pastikan config memang tersedia di kernel tree.
        if grep -Rqs \
            --exclude-dir=.git \
            "config ${CONFIG#CONFIG_}" \
            "$KERNEL_DIR"; then

            echo "Action : enable $CONFIG"

            "$CONFIG_TOOL" \
                --enable "$CONFIG" \
                "$KERNEL_CONFIG"

            echo "$CONFIG enabled" >> "$CONFIG_REPORT"

            ENABLED["$CONFIG"]=1

        else

            warn "$CONFIG tidak ditemukan di Kconfig tree"

        fi

    done < "$UNKNOWN_SYMBOLS"

    # ========================================================
    # REGENERATE CONFIG
    # ========================================================

    if [ -s "$CONFIG_REPORT" ]; then

        echo
        echo "Regenerating kernel config..."

        make -C "$KERNEL_DIR" \
            O="$KERNEL_OUT" \
            ARCH=arm64 \
            LLVM=1 \
            LLVM_IAS=1 \
            olddefconfig

        ok "Kernel config regenerated."

    else

        echo
        warn "Tidak ada config yang aman untuk di-enable."

    fi

}

# ============================================================
# BACKUP KERNEL CONFIG
# ============================================================

backup_kernel_config() {

    if [ ! -f "$KERNEL_CONFIG" ]; then
        return
    fi

    BACKUP_DIR="$KERNEL_FIX_DIR/config-backups"

    mkdir -p "$BACKUP_DIR"

    TIMESTAMP=$(date '+%Y%m%d-%H%M%S')

    cp \
        "$KERNEL_CONFIG" \
        "$BACKUP_DIR/config.before-fix.$TIMESTAMP"

    echo "Kernel config backup:"
    echo "$BACKUP_DIR/config.before-fix.$TIMESTAMP"

}

# ============================================================
# KERNEL AUTO FIX ENTRY
# ============================================================

kernel_auto_fix() {

    [ "$AUTO_KERNEL_FIX" != "1" ] && return 0

    echo
    echo "============================================================"
    echo "             KERNEL UNKNOWN SYMBOL AUTO-FIX"
    echo "============================================================"

    if [ ! -d "$KERNEL_DIR" ]; then

        warn "Kernel directory tidak ditemukan."
        return 0

    fi

    if [ ! -f "$KERNEL_CONFIG" ]; then

        warn "Kernel .config belum tersedia."
        echo "Auto-fix akan dilakukan setelah kernel build pertama."

        return 0

    fi

    backup_kernel_config

    if extract_unknown_symbols; then

        generate_provider_report
        detect_safe_configs

    else

        ok "Tidak ada unknown symbol untuk diperbaiki."

    fi

}

# ============================================================
# PRE-BUILD KERNEL AUTO-FIX
# ============================================================

kernel_auto_fix

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
echo "Kernel          : $KERNEL_DIR"
echo "Auto kernel fix : $AUTO_KERNEL_FIX"
echo "Auto rebuild    : $AUTO_REBUILD"
echo "Max retries     : $MAX_RETRIES"

echo
echo "============================================================"
echo "                    STARTING BUILD"
echo "============================================================"

echo
echo "Command:"
echo
echo "    mka bacon"
echo

# ============================================================
# BUILD FUNCTION
# ============================================================

run_build() {

    BUILD_START=$(date +%s)

    set +e

    mka bacon

    BUILD_STATUS=$?

    set -e

    BUILD_END=$(date +%s)
    BUILD_TIME=$((BUILD_END - BUILD_START))

    echo
    echo "Build time: $BUILD_TIME seconds"

    return "$BUILD_STATUS"

}

# ============================================================
# BUILD LOOP
# ============================================================

ATTEMPT=0
BUILD_STATUS=1

while true; do

    ATTEMPT=$((ATTEMPT + 1))

    echo
    echo "============================================================"
    echo "                    BUILD ATTEMPT $ATTEMPT"
    echo "============================================================"

    run_build
    BUILD_STATUS=$?

    if [ "$BUILD_STATUS" -eq 0 ]; then
        break
    fi

    echo
    echo "============================================================"
    echo "                    BUILD FAILED"
    echo "============================================================"

    error "Build failed with exit status: $BUILD_STATUS"

    # --------------------------------------------------------
    # Stop if auto rebuild disabled
    # --------------------------------------------------------

    if [ "$AUTO_REBUILD" != "1" ]; then

        warn "AUTO_REBUILD disabled."

        break

    fi

    # --------------------------------------------------------
    # Stop when max retries reached
    # --------------------------------------------------------

    if [ "$ATTEMPT" -ge "$MAX_RETRIES" ]; then

        warn "Maximum retry reached: $MAX_RETRIES"

        break

    fi

    # --------------------------------------------------------
    # Analyze kernel symbols from failed build
    # --------------------------------------------------------

    echo
    echo "============================================================"
    echo "             ANALYZING FAILED KERNEL BUILD"
    echo "============================================================"

    if extract_unknown_symbols; then

        backup_kernel_config

        generate_provider_report

        detect_safe_configs

        if [ -s "$CONFIG_REPORT" ]; then

            echo
            ok "Kernel config berubah."
            echo "Retrying build..."

            continue

        else

            warn "Tidak ada perubahan config."
            warn "Kemungkinan error adalah kernel API mismatch."

            break

        fi

    else

        warn "Failure bukan unknown-symbol kernel."

        break

    fi

done

# ============================================================
# FINAL BUILD FAILURE
# ============================================================

if [ "$BUILD_STATUS" -ne 0 ]; then

    echo
    echo "============================================================"
    echo "                    BUILD FAILED"
    echo "============================================================"

    error "Build failed."

    echo
    echo "Log:"
    echo "  out/error.log"
    echo "  out/verbose.log.gz"

    echo
    echo "Kernel auto-fix report:"
    echo "  $KERNEL_FIX_DIR"

    if [ -f "$UNKNOWN_SYMBOLS" ]; then

        echo
        echo "Unknown symbols:"
        cat "$UNKNOWN_SYMBOLS"

    fi

    if [ -f "$PROVIDER_REPORT" ]; then

        echo
        echo "Provider report:"
        cat "$PROVIDER_REPORT"

    fi

    echo
    echo "============================================================"
    echo " IMPORTANT"
    echo "============================================================"
    echo
    echo "Jika symbol tidak mempunyai EXPORT_SYMBOL di kernel tree,"
    echo "script TIDAK akan membuat patch API secara otomatis."
    echo
    echo "Contoh yang biasanya membutuhkan compatibility patch:"
    echo
    echo "  drm_flip_work_*"
    echo "  __drm_atomic_helper_*"
    echo "  drm_connector_helper_*"
    echo
    echo "Ini merupakan indikasi driver lama vs DRM API kernel."
    echo
    echo "Jangan bypass depmod atau menghapus pengecekan"
    echo "unknown kernel symbols."
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
echo -e "${GREEN}${BOLD}Build completed successfully.${RESET}"

# ============================================================
# ARTIFACT CHECK
# ============================================================

echo
echo "============================================================"
echo "                  BUILD ARTIFACTS"
echo "============================================================"

if [ ! -d "$OUT_DIR" ]; then

    error "Output directory tidak ditemukan:"
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

    error "No ROM ZIP found in artifacts!"
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
echo "ZIP:"
echo "$ZIP"

echo
echo "Output:"
echo "$OUT_DIR"

echo
echo "Kernel auto-fix reports:"
echo "$KERNEL_FIX_DIR"

echo
echo "============================================================"
echo "                       DONE"
echo "============================================================"
```
