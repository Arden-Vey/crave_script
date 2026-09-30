#!/bin/bash
set -e

# ============================================================
# LINEAGEOS 23.2 - GENERIC ARM64 BUILDER
# WITH AUTO-DETECT & FIX DUPLICATE MODULES / FOLDERS
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

GENERIC_INIT_VISIBILITY="//device/mainline/generic/services/generic_init"

# Daftar direktori yang TIDAK boleh memiliki Android.mk duplikat
DEDUP_SCAN_DIRS=(
    "external/mesa"
    "external/mesa/android"
    "hardware/mainline"
    "device/mainline"
)

# ============================================================
# FUNCTIONS
# ============================================================

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

info() {
    echo -e "${CYAN}[INFO]${RESET} $1"
}

# ============================================================
# HEADER
# ============================================================

echo
echo "============================================================"
echo "        LINEAGEOS 23.2 GENERIC ARM64 BUILDER"
echo "        (with Auto-Fix Duplicate Modules)"
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

command -v python3 >/dev/null 2>&1 || {
    err "python3 tidak ditemukan."
    exit 1
}

if [ ! -x "/opt/crave/resync.sh" ]; then
    err "/opt/crave/resync.sh tidak ditemukan."
    exit 1
fi

ok "repo tersedia."
ok "git tersedia."
ok "python3 tersedia."
ok "Crave resync tersedia."

# ============================================================
# CLEAN LOCAL MANIFEST
# ============================================================

section "PREPARING LOCAL MANIFEST"

if [ -d ".repo/local_manifests" ]; then
    info "Menghapus local_manifests lama..."
    rm -rf .repo/local_manifests
fi

ok "Local manifest directory siap."

# ============================================================
# REPO INIT
# ============================================================

section "INITIALIZING LINEAGEOS"

repo init \
    -u https://github.com/LineageOS/android.git \
    -b "$ROM_BRANCH" \
    --depth=1 \
    --git-lfs

ok "Repo initialized."

# ============================================================
# MANIFEST
# ============================================================

section "CLONING CUSTOM MANIFEST"

git clone \
    -b "$MANIFEST_BRANCH" \
    --depth=1 \
    "$MANIFEST_URL" \
    .repo/local_manifests

ok "Custom manifest berhasil dipasang."

# ============================================================
# CRAVE SYNC
# ============================================================

section "SYNCING SOURCE WITH CRAVE"

info "Menjalankan Crave resync..."
/opt/crave/resync.sh

ok "Source sync selesai."

# ============================================================
# BUILD ENVIRONMENT
# ============================================================

section "SETTING BUILD ENVIRONMENT"

export BUILD_USERNAME="$BUILD_USERNAME"
export BUILD_HOSTNAME="$BUILD_HOSTNAME"

export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
export ALLOW_MISSING_DEPENDENCIES=true

export LC_ALL=C

ok "Build environment configured."

# ============================================================
# [NEW] AUTO-DETECT & FIX DUPLICATE MODULES
# ============================================================

section "SCANNING FOR DUPLICATE MODULES / FOLDERS"

# Fungsi untuk mendeteksi duplikasi module di Android.mk/Android.bp
detect_duplicate_modules() {
    local dir="$1"
    local found_dup=0

    if [ ! -d "$dir" ]; then
        return 0
    fi

    # Cari semua file Android.mk/Android.bp
    while IFS= read -r mkfile; do
        [ -z "$mkfile" ] && continue

        # Ambil semua LOCAL_MODULE / name:
        local modules
        modules=$(grep -hoE 'LOCAL_MODULE[[:space:]]*:?=[[:space:]]*[^ ]+' "$mkfile" 2>/dev/null | awk '{print $NF}' | tr -d '"' | sort -u)

        while IFS= read -r mod; do
            [ -z "$mod" ] && continue

            # Cari apakah module yang sama didefinisikan di file lain
            local other_files
            other_files=$(grep -rlE "LOCAL_MODULE[[:space:]]*:?=[[:space:]]*[\"']?$mod[\"']?([[:space:]]|$)" \
                --include="Android.mk" \
                --include="Android.bp" \
                "$dir" 2>/dev/null | grep -v "^$mkfile$" || true)

            if [ -n "$other_files" ]; then
                warn "DUPLIKAT module '$mod' ditemukan:"
                echo "    - $mkfile"
                echo "$other_files" | while read -r f; do
                    echo "    - $f"
                done
                found_dup=1
            fi
        done <<< "$modules"
    done < <(find "$dir" -type f \( -name "Android.mk" -o -name "Android.bp" \) 2>/dev/null)

    return $found_dup
}

# Fungsi untuk membersihkan duplikasi file Android.mk/Android.bp
fix_duplicate_mk_files() {
    local dir="$1"

    if [ ! -d "$dir" ]; then
        return 0
    fi

    # Cari file Android.mk yang berada di subfolder yang sama dengan Android.bp
    # (biasanya menyebabkan duplikasi)
    while IFS= read -r mkfile; do
        local parent
        parent="$(dirname "$mkfile")"

        # Skip root Android.mk
        [ "$parent" = "$dir" ] && continue

        local bpfile="$parent/Android.bp"

        if [ -f "$bpfile" ]; then
            warn "Konflik: $mkfile dan $bpfile di folder yang sama."
            info "Membackup dan menonaktifkan Android.mk duplikat..."

            # Backup
            if [ ! -f "${mkfile}.disabled" ]; then
                mv "$mkfile" "${mkfile}.disabled"
                ok "Dinonaktifkan: $mkfile -> ${mkfile}.disabled"
            fi
        fi
    done < <(find "$dir" -type f -name "Android.mk" 2>/dev/null)
}

# Fungsi untuk membersihkan duplikasi folder (symlink atau copy)
fix_duplicate_folders() {
    local base_dir="$1"

    if [ ! -d "$base_dir" ]; then
        return 0
    fi

    # Deteksi folder dengan nama yang sama (case-insensitive)
    find "$base_dir" -maxdepth 3 -type d 2>/dev/null | \
        awk -F/ '{print tolower($NF)"|"$0}' | \
        sort | \
        awk -F'|' '
        {
            if ($1 == prev_key) {
                print "DUPLIKAT FOLDER: " prev_path " <-> " $2
            }
            prev_key = $1
            prev_path = $2
        }' | while read -r line; do
            if echo "$line" | grep -q "DUPLIKAT FOLDER"; then
                warn "$line"
            fi
        done
}

# Jalankan deteksi & fix untuk setiap direktori target
for d in "${DEDUP_SCAN_DIRS[@]}"; do
    if [ -d "$d" ]; then
        info "Scanning: $d"

        detect_duplicate_modules "$d" || true
        fix_duplicate_mk_files "$d" || true
        fix_duplicate_folders "$d" || true

        echo
    fi
done

# --------------------------------------------
# FIX KHUSUS: external/mesa/android/vulkan
# --------------------------------------------

section "FIXING MESA VULKAN DUPLICATE"

MESA_ANDROID_DIR="external/mesa/android"

if [ -d "$MESA_ANDROID_DIR" ]; then

    # Cari definisi vulkan di Android.mk
    MESA_MK="$MESA_ANDROID_DIR/Android.mk"

    if [ -f "$MESA_MK" ]; then

        VULKAN_COUNT=$(grep -cE 'LOCAL_MODULE[[:space:]]*:?=[[:space:]]*vulkan' "$MESA_MK" 2>/dev/null || echo 0)

        if [ "$VULKAN_COUNT" -gt 1 ]; then

            warn "Module 'vulkan' didefinisikan $VULKAN_COUNT kali di $MESA_MK"

            # Cek apakah ada include ganda
            INCLUDE_COUNT=$(grep -cE 'include[[:space:]]+\$\(call[[:space:]]+all-makefiles-under' "$MESA_MK" 2>/dev/null || echo 0)

            if [ "$INCLUDE_COUNT" -gt 1 ]; then
                warn "Include ganda terdeteksi di $MESA_MK"
            fi

            info "Membackup $MESA_MK..."

            if [ ! -f "${MESA_MK}.bak" ]; then
                cp "$MESA_MK" "${MESA_MK}.bak"
                ok "Backup: ${MESA_MK}.bak"
            fi

        else
            ok "Tidak ada duplikasi 'vulkan' di $MESA_MK"
        fi

    else
        info "$MESA_MK tidak ditemukan (mungkin pakai Android.bp saja)."
    fi

    # Cek apakah ada file .disabled yang tertinggal
    find "$MESA_ANDROID_DIR" -name "*.disabled" 2>/dev/null | while read -r f; do
        warn "File dinonaktifkan sebelumnya: $f"
    done

else
    warn "$MESA_ANDROID_DIR tidak ditemukan."
fi

# ============================================================
# PATCH LIBJXL
# ============================================================

section "PATCHING LIBJXL"

LIBJXL_BP="external/libjxl/Android.bp"

if [ -f "$LIBJXL_BP" ]; then

    if grep -q 'sdk_version: "none"' "$LIBJXL_BP"; then

        cp "$LIBJXL_BP" "${LIBJXL_BP}.bak"

        sed -i \
            's/sdk_version: "none"/sdk_version: "current"/g' \
            "$LIBJXL_BP"

        ok "libjxl sdk_version diubah dari none -> current."

    elif grep -q 'sdk_version: "current"' "$LIBJXL_BP"; then

        ok "libjxl sdk_version sudah current."

    else

        warn "libjxl tidak memiliki sdk_version yang dikenali."

    fi

else

    warn "$LIBJXL_BP tidak ditemukan."

fi

# ============================================================
# VERIFY LIBJXL
# ============================================================

section "VERIFYING LIBJXL PATCH"

if [ -f "$LIBJXL_BP" ]; then

    if grep -q 'sdk_version: "current"' "$LIBJXL_BP"; then
        ok "libjxl sdk_version: OK"
    else
        warn "libjxl sdk_version mungkin masih none atau tidak ditemukan."
    fi

fi

# ============================================================
# FIND BORINGSSL libcrypto_static
# ============================================================

section "LOCATING BORINGSSL libcrypto_static"

BORINGSSL_BP=""

while IFS= read -r file; do

    if grep -qE 'name:[[:space:]]*"libcrypto_static"' "$file"; then
        BORINGSSL_BP="$file"
        break
    fi

done < <(
    find external/boringssl \
        -type f \
        -name "Android.bp" \
        2>/dev/null
)

if [ -z "$BORINGSSL_BP" ]; then

    err "Module libcrypto_static tidak ditemukan di external/boringssl."

    echo
    echo "Pencarian:"
    grep -RIn \
        --include="Android.bp" \
        'name: "libcrypto_static"' \
        external/boringssl 2>/dev/null || true

    exit 1

fi

ok "libcrypto_static ditemukan:"
echo "    $BORINGSSL_BP"

# ============================================================
# SHOW CURRENT BORINGSSL STATE
# ============================================================

section "CHECKING BORINGSSL VISIBILITY"

grep -n \
    -A25 \
    -B5 \
    'name: "libcrypto_static"' \
    "$BORINGSSL_BP" || true

if grep -q 'default_visibility:' "$BORINGSSL_BP"; then
    warn "default_visibility ditemukan di $BORINGSSL_BP"
fi

# ============================================================
# BACKUP BORINGSSL
# ============================================================

section "BACKING UP BORINGSSL"

if [ ! -f "${BORINGSSL_BP}.bak" ]; then
    cp "$BORINGSSL_BP" "${BORINGSSL_BP}.bak"
    ok "Backup dibuat:"
    echo "    ${BORINGSSL_BP}.bak"
else
    info "Backup sudah ada, tidak dibuat ulang."
fi

# ============================================================
# PATCH BORINGSSL VISIBILITY
# ============================================================

section "PATCHING BORINGSSL VISIBILITY"

export BORINGSSL_BP
export GENERIC_INIT_VISIBILITY

python3 <<'PY'
import os
import re
import sys

path = os.environ["BORINGSSL_BP"]
required_visibility = os.environ["GENERIC_INIT_VISIBILITY"]

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Find libcrypto_static module
name_match = re.search(
    r'name\s*:\s*"libcrypto_static"\s*,?',
    content
)

if not name_match:
    print("[ERROR] libcrypto_static tidak ditemukan.")
    sys.exit(1)

module_pattern = re.compile(
    r'(?:cc_library_static|cc_library)\s*\{',
    re.MULTILINE
)

module_start = None

for match in module_pattern.finditer(content, 0, name_match.start() + 1):
    module_start = match.start()

if module_start is None:
    print("[ERROR] Awal module cc_library_static tidak ditemukan.")
    sys.exit(1)

brace_start = content.find("{", module_start)

if brace_start == -1:
    print("[ERROR] Opening brace module tidak ditemukan.")
    sys.exit(1)

depth = 0
module_end = None

in_line_comment = False
in_block_comment = False
in_string = False
escape = False

i = brace_start

while i < len(content):

    c = content[i]
    n = content[i + 1] if i + 1 < len(content) else ""

    if in_line_comment:
        if c == "\n":
            in_line_comment = False

    elif in_block_comment:
        if c == "*" and n == "/":
            in_block_comment = False
            i += 1

    elif in_string:
        if escape:
            escape = False
        elif c == "\\":
            escape = True
        elif c == '"':
            in_string = False

    else:

        if c == "/" and n == "/":
            in_line_comment = True
            i += 1

        elif c == "/" and n == "*":
            in_block_comment = True
            i += 1

        elif c == '"':
            in_string = True

        elif c == "{":
            depth += 1

        elif c == "}":
            depth -= 1

            if depth == 0:
                module_end = i
                break

    i += 1

if module_end is None:
    print("[ERROR] Penutup module libcrypto_static tidak ditemukan.")
    sys.exit(1)

module = content[module_start:module_end + 1]

visibility_match = re.search(
    r'visibility\s*:\s*\[(.*?)\]',
    module,
    re.DOTALL
)

if visibility_match:

    visibility_block = visibility_match.group(1)

    if required_visibility in visibility_block:

        print("[OK] Visibility sudah berisi:")
        print(f"      {required_visibility}")

    else:

        new_visibility_block = (
            visibility_block.rstrip()
        )

        if new_visibility_block:
            new_visibility_block += "\n        "
        else:
            new_visibility_block = "\n        "

        new_visibility_block += f'"{required_visibility}",\n    '

        new_visibility = (
            "visibility: ["
            + new_visibility_block
            + "]"
        )

        old_visibility = visibility_match.group(0)

        module = module.replace(
            old_visibility,
            new_visibility,
            1
        )

        content = (
            content[:module_start]
            + module
            + content[module_end + 1:]
        )

        with open(path, "w", encoding="utf-8") as f:
            f.write(content)

        print("[OK] Visibility berhasil ditambahkan.")
        print(f"      {required_visibility}")

else:

    module_body_start = brace_start - module_start + 1

    insert_at = module_start + module_body_start

    indentation = "    "

    visibility_text = (
        "\n"
        + indentation
        + "visibility: [\n"
        + indentation
        + f'    "{required_visibility}",\n'
        + indentation
        + "],\n"
    )

    content = (
        content[:insert_at]
        + visibility_text
        + content[insert_at:]
    )

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

    print("[OK] visibility property dibuat.")
    print(f"      {required_visibility}")

PY

ok "BoringSSL visibility patch selesai."

# ============================================================
# VERIFY BORINGSSL PATCH
# ============================================================

section "VERIFYING BORINGSSL PATCH"

if grep -qF "$GENERIC_INIT_VISIBILITY" "$BORINGSSL_BP"; then

    ok "Visibility ditemukan di BoringSSL."

else

    err "Visibility patch gagal."

    echo
    echo "Expected:"
    echo "    $GENERIC_INIT_VISIBILITY"

    exit 1

fi

# ============================================================
# SHOW PATCHED MODULE
# ============================================================

section "SHOWING PATCHED libcrypto_static"

grep -n \
    -A30 \
    -B3 \
    'name: "libcrypto_static"' \
    "$BORINGSSL_BP" || true

# ============================================================
# VERIFY ALL PATCHES
# ============================================================

section "VERIFYING ALL PATCHES"

echo

if [ -f "$LIBJXL_BP" ]; then
    if grep -q 'sdk_version: "current"' "$LIBJXL_BP"; then
        ok "libjxl patch: PASS"
    else
        warn "libjxl patch: CHECK"
    fi
fi

if grep -qF "$GENERIC_INIT_VISIBILITY" "$BORINGSSL_BP"; then
    ok "BoringSSL visibility patch: PASS"
else
    err "BoringSSL visibility patch: FAIL"
    exit 1
fi

# ============================================================
# DIAGNOSTIC DEVICE INIT
# ============================================================

section "DIAGNOSTIC GENERIC INIT"

DEVICE_INIT_BP="device/mainline/generic/services/generic_init/Android.bp"

if [ -f "$DEVICE_INIT_BP" ]; then

    info "Menampilkan area sekitar line 115-135:"

    sed -n '115,135p' "$DEVICE_INIT_BP"

else

    warn "$DEVICE_INIT_BP tidak ditemukan."

fi

# ============================================================
# CLEAN SOONG STATE
# ============================================================

section "CLEANING SOONG STATE"

if [ -f "out/soong/build.lineage_${DEVICE}.ninja" ]; then

    rm -f "out/soong/build.lineage_${DEVICE}.ninja"

    ok "Removed stale Soong ninja file."

fi

if [ -d "out/soong/.bootstrap" ]; then

    rm -rf "out/soong/.bootstrap"

    ok "Removed Soong bootstrap state."

fi

# --------------------------------------------
# [NEW] CLEAN STALE KATI CACHE
# --------------------------------------------
if [ -d "out/build.trace" ]; then
    rm -rf "out/build.trace"
    ok "Removed stale build.trace."
fi

if [ -f "out/.kati_stamp-*" ]; then
    rm -f out/.kati_stamp-* 2>/dev/null || true
    ok "Removed stale kati stamp."
fi

ok "Soong state cleaned."

# ============================================================
# ENVSETUP
# ============================================================

section "LOADING BUILD ENVIRONMENT"

source build/envsetup.sh

ok "build/envsetup.sh loaded."

# ============================================================
# CHECK GENERIC TREE
# ============================================================

section "CHECKING GENERIC TREE"

REQUIRED_DIRS=(
    "device/mainline/generic"
    "device/mainline/common"
    "hardware/mainline/common"
)

for dir in "${REQUIRED_DIRS[@]}"; do

    if [ -d "$dir" ]; then
        ok "$dir"
    else
        err "Missing: $dir"
        exit 1
    fi

done

# ============================================================
# CHECK OPTIONAL MAINLINE DEPENDENCIES
# ============================================================

section "CHECKING OPTIONAL MAINLINE DEPENDENCIES"

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

for dir in "${OPTIONAL_DIRS[@]}"; do

    if [ -d "$dir" ]; then
        ok "$dir"
    else
        warn "Optional dependency missing: $dir"
    fi

done

# ============================================================
# [NEW] PRE-BUILD DUPLICATE CHECK (FINAL)
# ============================================================

section "FINAL DUPLICATE MODULE CHECK"

DUPLICATE_FOUND=0

# Cek mesa Android.mk vs Android.bp
if [ -f "external/mesa/android/Android.mk" ] && [ -f "external/mesa/android/Android.bp" ]; then
    warn "external/mesa/android memiliki Android.mk DAN Android.bp"
    warn "  -> berpotensi duplikasi module 'vulkan'"

    if [ ! -f "external/mesa/android/Android.mk.disabled" ]; then
        mv "external/mesa/android/Android.mk" "external/mesa/android/Android.mk.disabled"
        ok "Android.mk dinonaktifkan (backup: Android.mk.disabled)"
    fi

    DUPLICATE_FOUND=1
fi

# Cek duplikasi module 'vulkan' di seluruh tree mesa
VULKAN_DEFS=$(grep -rlE 'LOCAL_MODULE[[:space:]]*:?=[[:space:]]*vulkan([[:space:]]|$)' \
    --include="Android.mk" \
    external/mesa 2>/dev/null || true)

VULKAN_COUNT=$(echo "$VULKAN_DEFS" | grep -c . || echo 0)

if [ "$VULKAN_COUNT" -gt 1 ]; then
    warn "Module 'vulkan' didefinisikan di $VULKAN_COUNT file:"
    echo "$VULKAN_DEFS" | while read -r f; do
        echo "    - $f"
    done

    # Nonaktifkan file duplikat (selain yang pertama)
    echo "$VULKAN_DEFS" | tail -n +2 | while read -r f; do
        if [ -f "$f" ] && [ ! -f "${f}.disabled" ]; then
            mv "$f" "${f}.disabled"
            ok "Dinonaktifkan: $f -> ${f}.disabled"
        fi
    done

    DUPLICATE_FOUND=1
fi

if [ "$DUPLICATE_FOUND" -eq 0 ]; then
    ok "Tidak ada duplikasi module terdeteksi."
fi

# ============================================================
# SELECT TARGET
# ============================================================

section "SELECTING BUILD TARGET"

breakfast "$DEVICE"

ok "Target selection selesai."

# ============================================================
# VERIFY TARGET
# ============================================================

section "VERIFYING BUILD TARGET"

TARGET_PRODUCT="$(get_build_var TARGET_PRODUCT)"
TARGET_DEVICE="$(get_build_var TARGET_DEVICE)"
TARGET_ARCH="$(get_build_var TARGET_ARCH)"
TARGET_ARCH_VARIANT="$(get_build_var TARGET_ARCH_VARIANT)"

echo
echo "TARGET_PRODUCT       : $TARGET_PRODUCT"
echo "TARGET_DEVICE        : $TARGET_DEVICE"
echo "TARGET_ARCH          : $TARGET_ARCH"
echo "TARGET_ARCH_VARIANT  : $TARGET_ARCH_VARIANT"
echo

if [ -z "$TARGET_PRODUCT" ]; then
    err "TARGET_PRODUCT kosong."
    exit 1
fi

if [ -z "$TARGET_ARCH" ]; then
    err "TARGET_ARCH kosong."
    exit 1
fi

if [ "$TARGET_ARCH" != "arm64" ]; then
    warn "TARGET_ARCH bukan arm64."
fi

ok "Build target valid."

# ============================================================
# FINAL PRE-BUILD CHECK
# ============================================================

section "FINAL PRE-BUILD CHECK"

echo "ROM             : $ROM_NAME"
echo "Device          : $DEVICE"
echo "Target          : $BUILD_TARGET"
echo "Product         : $TARGET_PRODUCT"
echo "Architecture    : $TARGET_ARCH"
echo "Threads         : $(nproc --all)"
echo

if [ -f "$BORINGSSL_BP" ]; then
    ok "BoringSSL Android.bp tersedia."
else
    err "BoringSSL Android.bp hilang."
    exit 1
fi

if grep -qF "$GENERIC_INIT_VISIBILITY" "$BORINGSSL_BP"; then
    ok "libcrypto_static visibility sudah diperbaiki."
else
    err "libcrypto_static visibility belum diperbaiki."
    exit 1
fi

ok "Semua pre-build check PASS."

# ============================================================
# BUILD
# ============================================================

section "STARTING BUILD"

echo
echo "Building:"
echo "    $BUILD_TARGET"
echo
echo "Please wait..."
echo

# --------------------------------------------
# [NEW] Jalankan build dengan fallback
# --------------------------------------------
set +e
m "$BUILD_TARGET"
BUILD_RESULT=$?
set -e

if [ "$BUILD_RESULT" -ne 0 ]; then

    err "Build gagal dengan exit code $BUILD_RESULT"

    echo
    info "Mencoba membersihkan state dan build ulang..."

    # Bersihkan kati cache
    rm -f out/.kati_stamp-* 2>/dev/null || true
    rm -rf out/soong/.bootstrap 2>/dev/null || true
    rm -f out/soong/build.lineage_${DEVICE}.ninja 2>/dev/null || true

    # Cek log error terakhir
    if [ -f "out/error.log" ]; then
        warn "Error log terakhir:"
        tail -n 30 "out/error.log"
    fi

    info "Silakan cek error di atas, lalu jalankan ulang script."
    exit 1
fi

# ============================================================
# OUTPUT
# ============================================================

section "CHECKING BUILD OUTPUT"

if [ ! -d "$OUT_DIR" ]; then

    err "Output directory tidak ditemukan:"
    echo "    $OUT_DIR"

    exit 1

fi

ok "Output directory ditemukan:"
echo "    $OUT_DIR"

# ============================================================
# IMAGE CHECK
# ============================================================

section "CHECKING GENERATED IMAGES"

IMAGE_FOUND=0

for image in \
    system.img \
    vendor.img \
    boot.img \
    init_boot.img \
    recovery.img \
    super.img \
    product.img \
    system_ext.img
do

    if [ -f "$OUT_DIR/$image" ]; then

        SIZE="$(du -h "$OUT_DIR/$image" | awk '{print $1}')"

        ok "$image ($SIZE)"

        IMAGE_FOUND=1

    fi

done

if [ "$IMAGE_FOUND" -eq 0 ]; then

    warn "Tidak ada image yang ditemukan di output."

else

    echo
    ok "Image hasil build ditemukan."

fi

# ============================================================
# FINAL
# ============================================================

section "BUILD FINISHED"

echo
echo -e "${GREEN}${BOLD}"
echo "============================================================"
echo "              BUILD SUCCESSFUL"
echo "============================================================"
echo -e "${RESET}"

echo "ROM      : $ROM_NAME"
echo "Device   : $DEVICE"
echo "Target   : $BUILD_TARGET"
echo "Output   : $OUT_DIR"
echo

echo "Generated files:"
find "$OUT_DIR" \
    -maxdepth 1 \
    -type f \
    \( -name "*.img" -o -name "*.zip" -o -name "*.zip.md5sum" \) \
    -printf "  %f\n" \
    2>/dev/null || true

echo
echo "============================================================"
echo "                    DONE"
echo "============================================================"
echo
