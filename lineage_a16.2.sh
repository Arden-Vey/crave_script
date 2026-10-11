#!/bin/bash

# ============================================================
# AUTO-FIX BUILD SCRIPT
# LineageOS 23.2 - tissot_mainline
# Urutan: init -> clone -> sync -> fix -> lunch -> build
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

OUT_DIR="out/target/product/$DEVICE"

DEVICE_MK="device/xiaomi/mi89xx-mainline/tissot_mainline/device.mk"
BOARD_CONFIG="device/xiaomi/mi89xx-mainline/tissot_mainline/BoardConfig.mk"
LINEAGE_COMPAT_BP="hardware/lineage/compat/Android.bp"
LIBJXL_BP="external/libjxl/Android.bp"

MAX_RETRY=8
LOG_FILE="/tmp/tissot_build.log"

# ============================================================
# HELPER
# ============================================================

info()    { echo -e "${BLUE}[INFO]${RESET} $*"; }
ok()      { echo -e "${GREEN}[OK]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
fail()    { echo -e "${RED}[FAIL]${RESET} $*"; }
section() {
    echo
    echo "============================================================"
    echo "  $*"
    echo "============================================================"
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
    echo "║              Automated Release Builder + Auto-Fix               ║"
    echo "║                                                                 ║"
    echo "╠═════════════════════════════════════════════════════════════════╣"
    echo "║  ROM        : LineageOS 23.2                                    ║"
    echo "║  Device     : tissot_mainline                                   ║"
    echo "║  Branch     : lineage-23.2                                      ║"
    echo "║  Build      : userdebug                                         ║"
    echo "╚═════════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# ============================================================
# AUTO-FIX FUNCTIONS
# ============================================================

fix_duplicate_protobuf() {
    section "AUTO-FIX: Duplicate protobuf modules"

    local target="$LINEAGE_COMPAT_BP"
    [ -f "$target" ] || { warn "$target tidak ada, skip"; return 1; }

    if grep -q "DISABLED_BY_AUTOFIX" "$target"; then
        ok "Sudah pernah dipatch, skip"
        return 0
    fi

    cp "$target" "$target.bak"

    python3 - "$target" <<'PYEOF'
import re, sys
path = sys.argv[1]
content = open(path).read()

targets = [
    'prebuilt_libprotobuf-cpp-full-3.9.1-vendorcompat',
    'prebuilt_libprotobuf-cpp-lite-3.9.1-vendorcompat',
    'prebuilt_libprotobuf-cpp-full-21.12-vendorcompat',
    'prebuilt_libprotobuf-cpp-lite-21.12-vendorcompat',
]

pattern = re.compile(
    r'cc_prebuilt_library_shared\s*\{[^}]*?name:\s*"([^"]+)"[^}]*?\}',
    re.DOTALL
)

def repl(m):
    if m.group(1) in targets:
        return '\n'.join(
            ('// DISABLED_BY_AUTOFIX: ' + ln) if ln.strip() else ln
            for ln in m.group(0).split('\n')
        )
    return m.group(0)

new = pattern.sub(repl, content)
open(path, 'w').write(new)
print("OK")
PYEOF

    if grep -qE '^\s*name:\s*"prebuilt_libprotobuf-cpp-(full|lite)-(3\.9\.1|21\.12)-vendorcompat"' "$target"; then
        fail "Masih ada yang aktif, restore"
        mv "$target.bak" "$target"
        return 1
    fi

    ok "Modul protobuf duplikat di-disable"
    return 0
}

fix_dtb_config() {
    section "AUTO-FIX: BOARD_INCLUDE_DTB_IN_BOOTIMG"

    [ -f "$BOARD_CONFIG" ] || { warn "$BOARD_CONFIG tidak ada"; return 1; }

    if ! grep -q "BOARD_PREBUILT_DTBIMAGE_DIR" "$BOARD_CONFIG"; then
        ok "Tidak pakai BOARD_PREBUILT_DTBIMAGE_DIR"
        return 0
    fi

    if grep -qE "BOARD_INCLUDE_DTB_IN_BOOTIMG\s*:=\s*true" "$BOARD_CONFIG"; then
        ok "Sudah true"
        return 0
    fi

    cp "$BOARD_CONFIG" "$BOARD_CONFIG.bak"
    {
        echo ""
        echo "# Added by AutoFix"
        echo "BOARD_INCLUDE_DTB_IN_BOOTIMG := true"
    } >> "$BOARD_CONFIG"

    ok "Ditambahkan BOARD_INCLUDE_DTB_IN_BOOTIMG := true"
    return 0
}

fix_libjxl() {
    section "AUTO-FIX: libjxl sdk_version"

    [ -f "$LIBJXL_BP" ] || { warn "$LIBJXL_BP tidak ada"; return 1; }

    if grep -q 'sdk_version: "none"' "$LIBJXL_BP"; then
        sed -i 's/sdk_version: "none"/sdk_version: "current"/' "$LIBJXL_BP"
        ok "sdk_version diubah ke current"
        return 0
    fi
    ok "Tidak perlu diubah"
    return 1
}

fix_vendor_blobs() {
    section "AUTO-FIX: vendor/xiaomi/msm8953-common"

    [ -f "$DEVICE_MK" ] || { warn "$DEVICE_MK tidak ada"; return 1; }

    local active
    active=$(grep -c "^[^#].*vendor/xiaomi/msm8953-common" "$DEVICE_MK" || true)

    if [ "$active" -eq 0 ]; then
        ok "Tidak ada referensi aktif"
        return 0
    fi

    cp "$DEVICE_MK" "$DEVICE_MK.bak"
    sed -i 's|^\(.*vendor/xiaomi/msm8953-common.*\)$|# \1|' "$DEVICE_MK"

    active=$(grep -c "^[^#].*vendor/xiaomi/msm8953-common" "$DEVICE_MK" || true)
    if [ "$active" -eq 0 ]; then
        ok "Semua referensi di-comment"
    else
        warn "Masih ada $active referensi aktif"
    fi
    return 0
}

fix_empty_copy_files() {
    section "AUTO-FIX: PRODUCT_COPY_FILES += \\ kosong"

    [ -f "$DEVICE_MK" ] || { warn "$DEVICE_MK tidak ada"; return 1; }

    if ! grep -qE '^PRODUCT_COPY_FILES \+= \\$' "$DEVICE_MK"; then
        ok "Tidak ada PRODUCT_COPY_FILES kosong"
        return 1
    fi

    cp "$DEVICE_MK" "$DEVICE_MK.bak"

    python3 - "$DEVICE_MK" <<'PYEOF'
import re, sys
path = sys.argv[1]
lines = open(path).read().split('\n')
out = []
i = 0
while i < len(lines):
    line = lines[i]
    if re.match(r'^PRODUCT_COPY_FILES \+= \\\s*$', line):
        nxt = lines[i+1] if i+1 < len(lines) else ''
        if not nxt.strip() or nxt.strip().startswith('#'):
            i += 1
            continue
    out.append(line)
    i += 1
open(path, 'w').write('\n'.join(out))
print("OK")
PYEOF

    ok "Baris kosong dibersihkan"
    return 0
}

fix_clean_soong() {
    section "AUTO-FIX: Bersihkan out/soong"

    if grep -q "dumpvars failed\|panic:" "$LOG_FILE" 2>/dev/null; then
        warn "Soong panic terdeteksi, bersihkan out/soong..."
        rm -rf out/soong out/.module_paths out/.lock 2>/dev/null
        ok "out/soong dibersihkan"
        return 0
    fi
    ok "Tidak perlu dibersihkan"
    return 1
}

fix_soong_duplicate_generic() {
    section "AUTO-FIX: Duplicate module (generic)"

    local dup_modules
    dup_modules=$(grep -oE 'module "[^"]+" already defined' "$LOG_FILE" 2>/dev/null \
        | sed 's/module "//;s/" already defined//' | sort -u || true)

    [ -z "$dup_modules" ] && { ok "Tidak ada module duplikat"; return 1; }

    local fixed=0
    while IFS= read -r mod; do
        [ -z "$mod" ] && continue
        warn "Module duplikat: $mod"

        local files
        files=$(grep -rl "name: \"$mod\"" --include="Android.bp" . 2>/dev/null \
            | grep -v "^./out/" || true)

        local count
        count=$(echo "$files" | grep -c . || true)

        if [ "$count" -gt 1 ]; then
            local idx=0
            while IFS= read -r f; do
                [ -z "$f" ] && continue
                idx=$((idx+1))
                [ $idx -eq 1 ] && continue

                python3 - "$f" "$mod" <<'PYEOF'
import re, sys
path, mod = sys.argv[1], sys.argv[2]
content = open(path).read()

pattern = re.compile(
    r'((?:cc_prebuilt_library_shared|cc_library_shared|cc_library|cc_prebuilt_library_static|'
    r'cc_library_static|cc_binary|cc_prebuilt_binary|java_library|android_app|'
    r'android_app_import|sh_binary|phony|cc_defaults|cc_library_headers)\s*\{[^}]*?name:\s*"'
    + re.escape(mod) + r'"[^}]*?\})',
    re.DOTALL
)

def repl(m):
    return '\n'.join(
        ('// DISABLED_BY_AUTOFIX: ' + ln) if ln.strip() else ln
        for ln in m.group(1).split('\n')
    )

new = pattern.sub(repl, content)
open(path, 'w').write(new)
PYEOF
                ok "Disabled '$mod' di $f"
                fixed=1
            done <<< "$files"
        fi
    done <<< "$dup_modules"

    [ "$fixed" -eq 1 ] && return 0
    return 1
}

# ============================================================
# RUN ALL FIXES
# ============================================================

run_all_fixes() {
    local fixed_any=0

    fix_duplicate_protobuf      && fixed_any=1
    fix_dtb_config              && fixed_any=1
    fix_libjxl                  && fixed_any=1
    fix_vendor_blobs            && fixed_any=1
    fix_empty_copy_files        && fixed_any=1
    fix_clean_soong             && fixed_any=1
    fix_soong_duplicate_generic && fixed_any=1

    [ "$fixed_any" -eq 1 ] && return 0
    return 1
}

# ============================================================
# PHASE 1: INIT
# ============================================================

banner

echo
echo -e "${BLUE}${BOLD}Build configuration${RESET}"
echo "--------------------------------------------"
echo "ROM             : $ROM_NAME"
echo "ROM branch      : $ROM_BRANCH"
echo "Device          : $DEVICE"
echo "Lunch target    : $LUNCH_TARGET"
echo "Target release  : $TARGET_RELEASE_VALUE"
echo "Manifest        : $MANIFEST_URL"
echo "Manifest branch : $MANIFEST_BRANCH"
echo "Output          : $OUT_DIR"
echo

# --- Clean local manifest ---
section "1. Clean local manifests"
rm -rf .repo/local_manifests
ok "Local manifests cleaned"

# --- Repo init ---
section "2. Repo init"
repo init \
    -u https://github.com/LineageOS/android.git \
    -b "$ROM_BRANCH" \
    --depth=1 \
    --git-lfs
ok "repo init done"

# --- Clone manifest ---
section "3. Clone local manifest"
git clone \
    -b "$MANIFEST_BRANCH" \
    --depth=1 \
    "$MANIFEST_URL" \
    .repo/local_manifests
ok "Local manifest cloned"

# --- Sync ---
section "4. Repo sync"
if [ -x /opt/crave/resync.sh ]; then
    /opt/crave/resync.sh
else
    repo sync -c -j"$(nproc --all)" --force-sync --no-clone-bundle --no-tags
fi
ok "Sync done"

# ============================================================
# PHASE 2: ENV
# ============================================================

section "5. Build environment"
export BUILD_USERNAME="$BUILD_USERNAME"
export BUILD_HOSTNAME="$BUILD_HOSTNAME"
export TARGET_RELEASE="$TARGET_RELEASE_VALUE"
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C
ok "Environment set"

# ============================================================
# PHASE 3: FIX (SETELAH SYNC, SEBELUM LUNCH)
# ============================================================

section "6. AUTO-FIX PRE-BUILD"
info "Menjalankan semua fix yang diperlukan sebelum build..."

fix_duplicate_protobuf
fix_dtb_config
fix_libjxl
fix_vendor_blobs
fix_empty_copy_files

ok "Pre-build fix selesai"

# ============================================================
# PHASE 4: SOURCE ENVSETUP
# ============================================================

section "7. Source build/envsetup.sh"
source build/envsetup.sh
ok "envsetup loaded"

# ============================================================
# PHASE 5: BUILD LOOP
# ============================================================

attempt=0
build_success=0

while [ $attempt -lt $MAX_RETRY ]; do
    attempt=$((attempt+1))
    section "BUILD ATTEMPT #$attempt / $MAX_RETRY"

    # Lunch
    info "Running lunch..."
    lunch "$LUNCH_TARGET" > /tmp/lunch.log 2>&1
    LUNCH_STATUS=$?

    if [ $LUNCH_STATUS -ne 0 ] || ! grep -q "lineage_tissot_mainline" /tmp/lunch.log; then
        warn "Lunch gagal, coba auto-fix..."

        cat /tmp/lunch.log >> "$LOG_FILE"

        if ! run_all_fixes; then
            fail "Tidak ada fix yang bisa diterapkan untuk lunch error"
            echo
            echo "Log lunch (30 baris terakhir):"
            tail -n 30 /tmp/lunch.log
            exit 1
        fi

        info "Re-source envsetup setelah fix..."
        source build/envsetup.sh
        continue
    fi
    ok "Lunch berhasil"

    # Build
    BUILD_START=$(date +%s)
    set +e
    mka bacon 2>&1 | tee "$LOG_FILE"
    BUILD_STATUS=${PIPESTATUS[0]}
    set -e
    BUILD_END=$(date +%s)
    BUILD_TIME=$((BUILD_END - BUILD_START))

    if [ $BUILD_STATUS -eq 0 ]; then
        build_success=1
        break
    fi

    fail "Build gagal (exit $BUILD_STATUS) setelah $BUILD_TIME detik"
    echo
    info "Error terakhir:"
    grep -iE "error:|FAILED:" "$LOG_FILE" | tail -n 15 || true
    echo
    info "Coba auto-fix dan rebuild..."

    if ! run_all_fixes; then
        fail "Tidak ada fix yang bisa diterapkan"
        echo
        info "Log: $LOG_FILE"
        exit $BUILD_STATUS
    fi

    info "Re-source envsetup..."
    source build/envsetup.sh
done

# ============================================================
# HASIL
# ============================================================

if [ $build_success -ne 1 ]; then
    section "BUILD GAGAL setelah $MAX_RETRY percobaan"
    info "Log: $LOG_FILE"
    exit 1
fi

section "BUILD SUCCESS"
echo
echo -e "${GREEN}${BOLD}Build berhasil!${RESET}"
echo "Build time: $BUILD_TIME seconds"
echo "Attempts  : $attempt"

section "BUILD ARTIFACTS"
[ -d "$OUT_DIR" ] && find "$OUT_DIR" -maxdepth 1 -type f \
    \( -name "*.zip" -o -name "*.img" -o -name "*.sha256sum" -o -name "*.json" \) \
    -printf '%f\n' | sort

ZIP=$(find "$OUT_DIR" -maxdepth 1 -type f -name "*.zip" ! -name "*ota*.zip" | head -n 1)
if [ -n "$ZIP" ]; then
    echo
    ok "ROM ZIP: $ZIP"
    echo
    sha256sum "$ZIP"
fi

echo
section "DONE"
