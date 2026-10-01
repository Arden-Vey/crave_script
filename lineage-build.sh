#!/bin/bash
set -e

# ============================================================
# LINEAGEOS 23.2 - GENERIC ARM64 BUILDER
# WITH AUTO-DETECT & AUTO-FIX DUPLICATE MODULES
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

# Folder yang akan discan untuk duplikat (HANYA yang relevan)
DEDUP_SCAN_DIRS=(
    "external/mesa/android"
    "external/mesa/src"
    "hardware/mainline"
    "device/mainline/generic"
    "device/mainline/common"
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

# ------------------------------------------------------------
# Auto-fix: rename file duplikat dengan suffix .disabled
# ------------------------------------------------------------
disable_file() {
    local file="$1"
    local reason="$2"

    if [ ! -f "$file" ]; then
        return 1
    fi

    if [ -f "${file}.disabled" ]; then
        info "Sudah disabled sebelumnya: $file"
        return 0
    fi

    # Backup dengan timestamp
    local backup="${file}.bak.$(date +%s)"
    cp "$file" "$backup" 2>/dev/null || true

    # Rename ke .disabled
    mv "$file" "${file}.disabled"

    ok "Auto-disabled: $file"
    info "  Reason: $reason"
    info "  Backup: $backup"

    return 0
}

# ------------------------------------------------------------
# Deteksi & auto-fix konflik Android.mk vs Android.bp
# HANYA di folder yang sama, HANYA kalau module-nya sama
# ------------------------------------------------------------
fix_mk_bp_conflict() {
    local dir="$1"

    if [ ! -d "$dir" ]; then
        return 0
    fi

    local mk="$dir/Android.mk"
    local bp="$dir/Android.bp"

    # Skip kalau salah satu tidak ada
    if [ ! -f "$mk" ] || [ ! -f "$bp" ]; then
        return 0
    fi

    info "Cek konflik mk/bp di: $dir"

    # Ekstrak module dari Android.mk
    local mk_modules
    mk_modules=$(grep -hoE 'LOCAL_MODULE[[:space:]]*:?=[[:space:]]*[^ ]+' "$mk" 2>/dev/null \
        | awk '{print $NF}' | tr -d '"' | sort -u || true)

    # Ekstrak module dari Android.bp
    local bp_modules
    bp_modules=$(grep -hoE 'name[[:space:]]*:[[:space:]]*"[^"]+"' "$bp" 2>/dev/null \
        | sed -E 's/.*"([^"]+)".*/\1/' | sort -u || true)

    # Cari module yang sama
    local conflict_modules=""
    while IFS= read -r mod; do
        [ -z "$mod" ] && continue

        if echo "$bp_modules" | grep -qxF "$mod"; then
            conflict_modules="$conflict_modules $mod"
        fi
    done <<< "$mk_modules"

    conflict_modules=$(echo "$conflict_modules" | xargs)

    if [ -z "$conflict_modules" ]; then
        return 0
    fi

    warn "KONFLIK di $dir:"
    echo "    Module yang sama: $conflict_modules"
    echo "    Android.mk: $mk"
    echo "    Android.bp: $bp"

    # Auto-fix: disable Android.mk (karena Android.bp modern)
    disable_file "$mk" "konflik module: $conflict_modules"

    return 0
}

# ------------------------------------------------------------
# Deteksi & auto-fix module duplikat di file berbeda
# ------------------------------------------------------------
fix_duplicate_modules_in_dir() {
    local dir="$1"

    if [ ! -d "$dir" ]; then
        return 0
    fi

    # Kumpulkan semua module dari Android.mk
    declare -A module_map

    while IFS= read -r mkfile; do
        [ -z "$mkfile" ] && continue

        local modules
        modules=$(grep -hoE 'LOCAL_MODULE[[:space:]]*:?=[[:space:]]*[^ ]+' "$mkfile" 2>/dev/null \
            | awk '{print $NF}' | tr -d '"' | sort -u || true)

        while IFS= read -r mod; do
            [ -z "$mod" ] && continue

            if [ -n "${module_map[$mod]:-}" ]; then
                # Sudah ada di file lain -> konflik
                warn "DUPLIKAT module '$mod':"
                echo "    File 1: ${module_map[$mod]}"
                echo "    File 2: $mkfile"

                # Auto-fix: disable file kedua
                disable_file "$mkfile" "module '$mod' duplikat dengan ${module_map[$mod]}"
            else
                module_map[$mod]="$mkfile"
            fi
        done <<< "$modules"
    done < <(find "$dir" -type f -name "Android.mk" 2>/dev/null)

    return 0
}

# ------------------------------------------------------------
# Auto-fix khusus: mesa vulkan conflict
# ------------------------------------------------------------
fix_mesa_vulkan() {
    local dir="external/mesa/android"

    if [ ! -d "$dir" ]; then
        return 0
    fi

    local mk="$dir/Android.mk"
    local bp="$dir/Android.bp"

    local has_mk_vulkan=false
    local has_bp_vulkan=false

    if [ -f "$mk" ]; then
        if grep -qE 'LOCAL_MODULE[[:space:]]*:?=[[:space:]]*vulkan([[:space:]]|$)' "$mk" 2>/dev/null; then
            has_mk_vulkan=true
        fi
    fi

    if [ -f "$bp" ]; then
        if grep -qE 'name[[:space:]]*:[[:space:]]*"vulkan"' "$bp" 2>/dev/null; then
            has_bp_vulkan=true
        fi
    fi

    if [ "$has_mk_vulkan" = true ] && [ "$has_bp_vulkan" = true ]; then
        warn "KONFLIK mesa vulkan terdeteksi!"
        echo "    Android.mk: $mk (define vulkan)"
        echo "    Android.bp: $bp (define vulkan)"

        # Auto-fix: disable Android.mk
        disable_file "$mk" "vulkan duplikat dengan Android.bp"

        return 0
    fi

    return 0
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

command -v repo >/dev/null 2>&1 || { err "repo tidak ditemukan."; exit 1; }
command -v git >/dev/null 2>&1 || { err "git tidak ditemukan."; exit 1; }
command -v python3 >/dev/null 2>&1 || { err "python3 tidak ditemukan."; exit 1; }
[ -x "/opt/crave/resync.sh" ] || { err "/opt/crave/resync.sh tidak ditemukan."; exit 1; }

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
# AUTO-DETECT & AUTO-FIX DUPLICATE MODULES
# ============================================================

section "AUTO-DETECT & AUTO-FIX DUPLICATE MODULES"

FIXED_COUNT=0

# --------------------------------------------
# 1. Fix mesa vulkan (paling umum)
# --------------------------------------------
info "Step 1: Cek mesa vulkan conflict..."
BEFORE_DISABLED=$(find external/mesa/android -name "*.disabled" 2>/dev/null | wc -l | head -1)
BEFORE_DISABLED=${BEFORE_DISABLED:-0}

fix_mesa_vulkan || true

AFTER_DISABLED=$(find external/mesa/android -name "*.disabled" 2>/dev/null | wc -l | head -1)
AFTER_DISABLED=${AFTER_DISABLED:-0}

if [ "$AFTER_DISABLED" -gt "$BEFORE_DISABLED" ]; then
    FIXED_COUNT=$((FIXED_COUNT + 1))
fi

echo

# --------------------------------------------
# 2. Scan folder yang relevan untuk konflik mk/bp
# --------------------------------------------
info "Step 2: Scan konflik Android.mk vs Android.bp..."

for d in "${DEDUP_SCAN_DIRS[@]}"; do
    if [ -d "$d" ]; then
        info "  Scanning: $d"
        fix_mk_bp_conflict "$d" || true
    fi
done

echo

# --------------------------------------------
# 3. Scan module duplikat (beda file)
# --------------------------------------------
info "Step 3: Scan module duplikat antar file..."

for d in "${DEDUP_SCAN_DIRS[@]}"; do
    if [ -d "$d" ]; then
        fix_duplicate_modules_in_dir "$d" || true
    fi
done

echo

# --------------------------------------------
# 4. Summary
# --------------------------------------------
DISABLED_FILES=$(find "${DEDUP_SCAN_DIRS[@]}" -name "*.disabled" 2>/dev/null | wc -l | head -1)
DISABLED_FILES=${DISABLED_FILES:-0}

if [ "$DISABLED_FILES" -gt 0 ]; then
    warn "Total file yang di-disable: $DISABLED_FILES"
    echo
    echo "  Daftar file .disabled:"
    find "${DEDUP_SCAN_DIRS[@]}" -name "*.disabled" 2>/dev/null | sed 's/^/    /' || true
else
    ok "Tidak ada file yang perlu di-disable."
fi

# ============================================================
# PATCH LIBJXL
# ============================================================

section "PATCHING LIBJXL"

LIBJXL_BP="external/libjxl/Android.bp"

if [ -f "$LIBJXL_BP" ]; then
    if grep -q 'sdk_version: "none"' "$LIBJXL_BP"; then
        cp "$LIBJXL_BP" "${LIBJXL_BP}.bak"
        sed -i 's/sdk_version: "none"/sdk_version: "current"/g' "$LIBJXL_BP"
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
done < <(find external/boringssl -type f -name "Android.bp" 2>/dev/null)

if [ -z "$BORINGSSL_BP" ]; then
    err "Module libcrypto_static tidak ditemukan di external/boringssl."
    echo
    echo "Pencarian:"
    grep -RIn --include="Android.bp" 'name: "libcrypto_static"' external/boringssl 2>/dev/null || true
    exit 1
fi

ok "libcrypto_static ditemukan:"
echo "    $BORINGSSL_BP"

# ============================================================
# SHOW CURRENT BORINGSSL STATE
# ============================================================

section "CHECKING BORINGSSL VISIBILITY"

grep -n -A25 -B5 'name: "libcrypto_static"' "$BORINGSSL_BP" || true

if grep -q 'default_visibility:' "$BORINGSSL_BP"; then
    warn "default_visibility ditemukan di $BORINGSSL_BP"
fi

# ============================================================
# BACKUP BORINGSSL
# ============================================================

section "BACKING UP BORINGSSL"

if [ ! -f "${BORINGSSL_BP}.bak" ]; then
    cp "$BORINGSSL_BP" "${BORINGSSL_BP}.bak"
    ok "Backup dibuat: ${BORINGSSL_BP}.bak"
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

name_match = re.search(r'name\s*:\s*"libcrypto_static"\s*,?', content)
if not name_match:
    print("[ERROR] libcrypto_static tidak ditemukan.")
    sys.exit(1)

module_pattern = re.compile(r'(?:cc_library_static|cc_library)\s*\{', re.MULTILINE)

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
        if c == "\n": in_line_comment = False
    elif in_block_comment:
        if c == "*" and n == "/":
            in_block_comment = False
            i += 1
    elif in_string:
        if escape: escape = False
        elif c == "\\": escape = True
        elif c == '"': in_string = False
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
visibility_match = re.search(r'visibility\s*:\s*\[(.*?)\]', module, re.DOTALL)

if visibility_match:
    visibility_block = visibility_match.group(1)
    if required_visibility in visibility_block:
        print("[OK] Visibility sudah berisi:")
        print(f"      {required_visibility}")
    else:
        new_visibility_block = visibility_block.rstrip()
        if new_visibility_block:
            new_visibility_block += "\n        "
        else:
            new_visibility_block = "\n        "
        new_visibility_block += f'"{required_visibility}",\n    '
        new_visibility = "visibility: [" + new_visibility_block + "]"
        old_visibility = visibility_match.group(0)
        module = module.replace(old_visibility, new_visibility, 1)
        content = content[:module_start] + module + content[module_end + 1:]
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print("[OK] Visibility berhasil ditambahkan.")
        print(f"      {required_visibility}")
else:
    name_field = re.search(r'(name\s*:\s*"libcrypto_static"\s*,)', module)
    if not name_field:
        print("[ERROR] Field name tidak ditemukan.")
        sys.exit(1)
    insertion = (
        name_field.group(1) + '\n'
        + '    visibility: [\n'
        + '        "' + required_visibility + '",\n'
        + '    ],'
    )
    module = module[:name_field.start()] + insertion + module[name_field.end():]
    content = content[:module_start] + module + content[module_end + 1:]
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
    echo "Expected: $GENERIC_INIT_VISIBILITY"
    exit 1
fi

# ============================================================
# SHOW PATCHED MODULE
# ============================================================

section "SHOWING PATCHED libcrypto_static"

grep -n -A30 -B3 'name: "libcrypto_static"' "$BORINGSSL_BP" || true

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

if [ -d "out/build.trace" ]; then
    rm -rf "out/build.trace"
    ok "Removed stale build.trace."
fi

shopt -s nullglob
KATI_STAMPS=(out/.kati_stamp-*)
shopt -u nullglob

if [ ${#KATI_STAMPS[@]} -gt 0 ]; then
    rm -f "${KATI_STAMPS[@]}"
    ok "Removed stale kati stamps."
fi

ok "Soong state cleaned."

# ============================================================
# ENVSETUP
# ============================================================

section "LOADING BUILD ENVIRONMENT"

if [ ! -f "build/envsetup.sh" ]; then
    err "build/envsetup.sh tidak ditemukan."
    exit 1
fi

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
# FINAL DUPLICATE CHECK (BEFORE BUILD)
# ============================================================

section "FINAL DUPLICATE CHECK"

FINAL_CONFLICT=false

# Cek mesa vulkan conflict terakhir
MESA_MK="external/mesa/android/Android.mk"
MESA_BP="external/mesa/android/Android.bp"

if [ -f "$MESA_MK" ] && [ -f "$MESA_BP" ]; then
    if grep -qE 'LOCAL_MODULE[[:space:]]*:?=[[:space:]]*vulkan([[:space:]]|$)' "$MESA_MK" 2>/dev/null && \
       grep -qE 'name[[:space:]]*:[[:space:]]*"vulkan"' "$MESA_BP" 2>/dev/null; then
        err "Mesa vulkan conflict MASIH ADA!"
        FINAL_CONFLICT=true
    fi
fi

if [ "$FINAL_CONFLICT" = true ]; then
    err "Build dibatalkan. Ada konflik yang belum di-fix."
    exit 1
else
    ok "Tidak ada konflik duplikat."
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

if [ "$TARGET_DEVICE" != "$DEVICE" ]; then
    err "TARGET_DEVICE tidak sesuai."
    echo "Expected : $DEVICE"
    echo "Detected : $TARGET_DEVICE"
    exit 1
fi

ok "Build target valid."

# ============================================================
# FINAL PRE-BUILD CHECK
# ============================================================

section "FINAL PRE-BUILD CHECK"

echo "ROM          : $ROM_NAME"
echo "Device       : $DEVICE"
echo "Target       : $BUILD_TARGET"
echo "Product      : $TARGET_PRODUCT"
echo "Architecture : $TARGET_ARCH"
echo "Threads      : $(nproc --all)"
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

BUILD_START=$(date +%s)

m "$BUILD_TARGET"

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

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

echo "ROM        : $ROM_NAME"
echo "Device     : $DEVICE"
echo "Target     : $BUILD_TARGET"
echo "Output     : $OUT_DIR"
echo "Build time : $BUILD_TIME seconds"
echo

echo "Generated files:"
find "$OUT_DIR" \
    -maxdepth 1 \
    -type f \
    \( -name "*.img" -o -name "*.zip" -o -name "*.zip.md5sum" \) \
    -printf "  %f\n" \
    2>/dev/null | sort || true

echo
echo "============================================================"
echo "                    DONE"
echo "============================================================"
echo
