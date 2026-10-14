```bash
#!/bin/bash
# ============================================================
# LINEAGEOS 23.2 - GENERIC ARM64 BUILDER
# WITH AUTO-FIX DUPLICATE MODULES + FULL FEATURES
# ============================================================

set -o pipefail

# ============================================================
# KONFIGURASI
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

GENERIC_INIT_VISIBILITY="//device/mainline/generic/services/generic_init"

DEDUP_SCAN_DIRS=(
    "external/mesa/android"
    "external/mesa/src"
    "hardware/mainline"
    "device/mainline/generic"
    "device/mainline/common"
)

# Target dipilih otomatis oleh breakfast.
# Jangan memaksakan lunch combo yang belum tentu tersedia.
LUNCH_TARGET=""

# Build jobs
JOBS="${JOBS:-$(nproc --all)}"

# ccache
CCACHE_SIZE="50G"
CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"

# Log
LOG_DIR=".build_logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BUILD_LOG="$LOG_DIR/build_${TIMESTAMP}.log"

# Telegram (opsional)
TG_BOT_TOKEN="${TG_BOT_TOKEN:-}"
TG_CHAT_ID="${TG_CHAT_ID:-}"

# ============================================================
# WARNA
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ============================================================
# FUNCTIONS
# ============================================================

section() {
    echo
    echo "============================================================"
    echo " $1"
    echo "============================================================"
}

ok()   { echo -e "${GREEN}[OK]${RESET} $*" | tee -a "$BUILD_LOG"; }
warn() { echo -e "${YELLOW}[WARNING]${RESET} $*" | tee -a "$BUILD_LOG"; }
err()  { echo -e "${RED}[ERROR]${RESET} $*" | tee -a "$BUILD_LOG"; }
info() { echo -e "${CYAN}[INFO]${RESET} $*" | tee -a "$BUILD_LOG"; }

# Error trap
trap 'err "Script interrupted at line $LINENO"' ERR INT TERM

# Notifikasi (kalau TG token di-set)
notify() {
    local msg="$1"
    [ -z "$TG_BOT_TOKEN" ] && return 0
    [ -z "$TG_CHAT_ID" ] && return 0

    curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TG_CHAT_ID}" \
        -d "text=${msg}" >/dev/null 2>&1 || true
}

# ------------------------------------------------------------
# disable_file: backup + rename ke .disabled
# ------------------------------------------------------------
disable_file() {
    local file="$1"
    local reason="$2"

    [ ! -f "$file" ] && return 1

    if [ -f "${file}.disabled" ]; then
        info "Sudah disabled: $file"
        return 0
    fi

    local backup="${file}.bak.$(date +%s)"
    cp "$file" "$backup" 2>/dev/null || true
    mv "$file" "${file}.disabled"

    ok "Auto-disabled: $file"
    info "  Reason: $reason"
    info "  Backup: $backup"
    return 0
}

# ------------------------------------------------------------
# Mesa vulkan fix
# ------------------------------------------------------------
fix_mesa_vulkan() {
    local dir="external/mesa/android"
    [ ! -d "$dir" ] && return 0

    local mk="$dir/Android.mk"
    local bp="$dir/Android.bp"
    local has_mk=false
    local has_bp=false

    [ -f "$mk" ] &&
        grep -qE 'LOCAL_MODULE[[:space:]]*:?=[[:space:]]*vulkan([[:space:]]|$)' "$mk" 2>/dev/null &&
        has_mk=true

    [ -f "$bp" ] &&
        grep -qE 'name[[:space:]]*:[[:space:]]*"vulkan"' "$bp" 2>/dev/null &&
        has_bp=true

    if [ "$has_mk" = true ] && [ "$has_bp" = true ]; then
        warn "KONFLIK mesa vulkan!"
        disable_file "$mk" "vulkan duplikat dengan Android.bp"
    fi
}

# ------------------------------------------------------------
# mk vs bp conflict
# ------------------------------------------------------------
fix_mk_bp_conflict() {
    local dir="$1"
    [ ! -d "$dir" ] && return 0

    local mk="$dir/Android.mk"
    local bp="$dir/Android.bp"

    [ ! -f "$mk" ] || [ ! -f "$bp" ] && return 0

    info "Cek konflik mk/bp di: $dir"

    local mk_modules
    mk_modules=$(grep -hoE 'LOCAL_MODULE[[:space:]]*:?=[[:space:]]*[^ ]+' "$mk" 2>/dev/null \
        | awk '{print $NF}' | tr -d '"' | sort -u || true)

    local bp_modules
    bp_modules=$(grep -hoE 'name[[:space:]]*:[[:space:]]*"[^"]+"' "$bp" 2>/dev/null \
        | sed -E 's/.*"([^"]+)".*/\1/' | sort -u || true)

    local conflict=""
    while IFS= read -r mod; do
        [ -z "$mod" ] && continue
        echo "$bp_modules" | grep -qxF "$mod" && conflict="$conflict $mod"
    done <<< "$mk_modules"

    conflict=$(echo "$conflict" | xargs)
    [ -z "$conflict" ] && return 0

    warn "KONFLIK di $dir: $conflict"
    disable_file "$mk" "konflik module: $conflict"
}

# ------------------------------------------------------------
# Duplicate modules antar file
# ------------------------------------------------------------
fix_duplicate_modules_in_dir() {
    local dir="$1"
    [ ! -d "$dir" ] && return 0

    declare -A module_map

    while IFS= read -r mkfile; do
        [ -z "$mkfile" ] && continue

        local modules
        modules=$(grep -hoE 'LOCAL_MODULE[[:space:]]*:?=[[:space:]]*[^ ]+' "$mkfile" 2>/dev/null \
            | awk '{print $NF}' | tr -d '"' | sort -u || true)

        while IFS= read -r mod; do
            [ -z "$mod" ] && continue

            if [ -n "${module_map[$mod]:-}" ]; then
                warn "DUPLIKAT '$mod': ${module_map[$mod]} vs $mkfile"
                disable_file "$mkfile" "module '$mod' duplikat"
            else
                module_map[$mod]="$mkfile"
            fi
        done <<< "$modules"

    done < <(find "$dir" -type f -name "Android.mk" 2>/dev/null)
}

# ============================================================
# BANNER
# ============================================================

echo
echo -e "${MAGENTA}${BOLD}"
cat <<'EOF'
  _     _                            ___  ____
 | |   (_)_ __   __ _ _ __ ___  ___ / _ \|___ \
 | |   | | '_ \ / _` | '__/ _ \/ _ \ | | | __) |
 | |___| | | | | (_| | | |  __/  __/ |_| |/ __/
 |_____|_|_| |_|\__,_|_|  \___|\___|\___/|_____|
EOF
echo -e "${RESET}"
echo "        Generic ARM64 Builder v2.0"
echo "        LineageOS 23.2 + Auto-Fix"
echo

section "BUILD CONFIGURATION"

echo "ROM             : $ROM_NAME"
echo "Branch          : $ROM_BRANCH"
echo "Device          : $DEVICE"
echo "Build target    : $BUILD_TARGET"
echo "Target selection: breakfast $DEVICE"
echo "Manifest        : $MANIFEST_URL"
echo "Manifest branch : $MANIFEST_BRANCH"
echo "Output          : $OUT_DIR"
echo "CPU threads     : $(nproc --all)"
echo "Build jobs      : $JOBS"
echo "Log file        : $BUILD_LOG"

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

[ -x "/opt/crave/resync.sh" ] || {
    err "/opt/crave/resync.sh tidak ditemukan."
    exit 1
}

ok "repo tersedia."
ok "git tersedia."
ok "python3 tersedia."
ok "Crave resync tersedia."

# Disk space check
AVAIL_GB=$(df -BG . | awk 'NR==2 {gsub("G","",$4); print $4}')

if [ "${AVAIL_GB:-0}" -lt 100 ]; then
    err "Disk space kurang: ${AVAIL_GB}GB (butuh minimal 100GB)"
    exit 1
fi

ok "Disk space: ${AVAIL_GB}GB tersedia"

# ============================================================
# CCACHE SETUP
# ============================================================

section "SETTING UP CCACHE"

export USE_CCACHE=1
export CCACHE_EXEC="$(command -v ccache || echo /usr/bin/ccache)"
export CCACHE_DIR="$CCACHE_DIR"
export CCACHE_COMPRESS=1
export CCACHE_COMPRESSLEVEL=6
export CCACHE_MAXSIZE="$CCACHE_SIZE"

mkdir -p "$CCACHE_DIR"

if command -v ccache >/dev/null 2>&1; then
    ccache -M "$CCACHE_SIZE" 2>/dev/null || true
    ok "CCACHE: $CCACHE_DIR (max: $CCACHE_SIZE)"
else
    warn "ccache tidak terinstall — build akan lebih lambat"
fi

# ============================================================
# JAVA / MEMORY
# ============================================================

section "TUNING JAVA HEAP"

export _JAVA_OPTIONS="-Xmx8G"
export ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx8G"
export JACK_SERVER_VM_ARGUMENTS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx8G"

ok "_JAVA_OPTIONS = 8G"

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
# AUTO-FIX
# ============================================================

section "AUTO-DETECT & AUTO-FIX DUPLICATE MODULES"

FIXED_COUNT=0

# Step 1: Mesa vulkan
info "Step 1: Cek mesa vulkan conflict..."

BEFORE=$(find external/mesa/android -name "*.disabled" 2>/dev/null | wc -l | tr -d ' ')
fix_mesa_vulkan || true
AFTER=$(find external/mesa/android -name "*.disabled" 2>/dev/null | wc -l | tr -d ' ')

[ "${AFTER:-0}" -gt "${BEFORE:-0}" ] &&
    FIXED_COUNT=$((FIXED_COUNT+1))

echo

# Step 2: mk vs bp
info "Step 2: Scan konflik mk/bp..."

for d in "${DEDUP_SCAN_DIRS[@]}"; do
    [ -d "$d" ] && {
        info "  Scanning: $d"
        fix_mk_bp_conflict "$d" || true
    }
done

echo

# Step 3: Duplikat antar file
info "Step 3: Scan module duplikat..."

for d in "${DEDUP_SCAN_DIRS[@]}"; do
    [ -d "$d" ] && fix_duplicate_modules_in_dir "$d" || true
done

echo

# Step 4: Summary
DISABLED_FILES=$(find "${DEDUP_SCAN_DIRS[@]}" -name "*.disabled" 2>/dev/null | wc -l | tr -d ' ')
DISABLED_FILES=${DISABLED_FILES:-0}

if [ "$DISABLED_FILES" -gt 0 ]; then
    warn "Total file .disabled: $DISABLED_FILES"
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
        ok "libjxl sdk_version -> current"
    elif grep -q 'sdk_version: "current"' "$LIBJXL_BP"; then
        ok "libjxl sdk_version sudah current"
    else
        warn "libjxl tidak punya sdk_version dikenali"
    fi
else
    warn "$LIBJXL_BP tidak ditemukan"
fi

# ============================================================
# PATCH BORINGSSL
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
    err "libcrypto_static tidak ditemukan."
    exit 1
fi

ok "libcrypto_static: $BORINGSSL_BP"

section "BACKING UP BORINGSSL"

if [ ! -f "${BORINGSSL_BP}.bak" ]; then
    cp "$BORINGSSL_BP" "${BORINGSSL_BP}.bak"
    ok "Backup: ${BORINGSSL_BP}.bak"
else
    info "Backup sudah ada"
fi

section "PATCHING BORINGSSL VISIBILITY"

export BORINGSSL_BP
export GENERIC_INIT_VISIBILITY

python3 <<'PY'
import os, re, sys

path = os.environ["BORINGSSL_BP"]
required_visibility = os.environ["GENERIC_INIT_VISIBILITY"]

with open(path, "r", encoding="utf-8") as f:
    content = f.read()

name_match = re.search(r'name\s*:\s*"libcrypto_static"\s*,?', content)
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
    print("[ERROR] Awal module tidak ditemukan.")
    sys.exit(1)

brace_start = content.find("{", module_start)

if brace_start == -1:
    print("[ERROR] Opening brace tidak ditemukan.")
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
    print("[ERROR] Penutup module tidak ditemukan.")
    sys.exit(1)

module = content[module_start:module_end + 1]

visibility_match = re.search(
    r'visibility\s*:\s*\[(.*?)\]',
    module,
    re.DOTALL
)

if visibility_match:
    vis_block = visibility_match.group(1)

    if required_visibility in vis_block:
        print("[OK] Visibility sudah ada.")
    else:
        new_block = vis_block.rstrip()
        new_block = (new_block + "\n        ") if new_block else "\n        "
        new_block += f'"{required_visibility}",\n    '

        new_vis = "visibility: [" + new_block + "]"

        module = module.replace(
            visibility_match.group(0),
            new_vis,
            1
        )

        content = (
            content[:module_start]
            + module
            + content[module_end + 1:]
        )

        with open(path, "w", encoding="utf-8") as f:
            f.write(content)

        print("[OK] Visibility ditambahkan.")

else:
    name_field = re.search(
        r'(name\s*:\s*"libcrypto_static"\s*,)',
        module
    )

    if not name_field:
        print("[ERROR] Field name tidak ditemukan.")
        sys.exit(1)

    insertion = (
        name_field.group(1) + "\n"
        + "    visibility: [\n"
        + '        "' + required_visibility + '",\n'
        + "    ],"
    )

    module = (
        module[:name_field.start()]
        + insertion
        + module[name_field.end():]
    )

    content = (
        content[:module_start]
        + module
        + content[module_end + 1:]
    )

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

    print("[OK] visibility property dibuat.")
PY

ok "BoringSSL visibility patch selesai."

section "VERIFYING BORINGSSL PATCH"

if grep -qF "$GENERIC_INIT_VISIBILITY" "$BORINGSSL_BP"; then
    ok "Visibility OK."
else
    err "Visibility patch gagal."
    exit 1
fi

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
# FINAL DUPLICATE CHECK
# ============================================================

section "FINAL DUPLICATE CHECK"

MESA_MK="external/mesa/android/Android.mk"
MESA_BP="external/mesa/android/Android.bp"

if [ -f "$MESA_MK" ] && [ -f "$MESA_BP" ]; then
    if grep -qE 'LOCAL_MODULE[[:space:]]*:?=[[:space:]]*vulkan([[:space:]]|$)' "$MESA_MK" 2>/dev/null &&
       grep -qE 'name[[:space:]]*:[[:space:]]*"vulkan"' "$MESA_BP" 2>/dev/null; then
        err "Mesa vulkan conflict MASIH ADA!"
        exit 1
    fi
fi

ok "Tidak ada konflik duplikat."

# ============================================================
# SELECT BUILD TARGET
# FIX: GUNAKAN BREAKFAST, JANGAN LUNCH COMBO MANUAL
# ============================================================

section "SELECTING BUILD TARGET"

info "Breakfast device: $DEVICE"

if ! breakfast "$DEVICE" 2>&1 | tee -a "$BUILD_LOG"; then
    err "Breakfast gagal: $DEVICE"
    exit 1
fi

ok "Breakfast berhasil."

# Ambil target yang benar-benar dipilih oleh breakfast.
TARGET_PRODUCT="$(get_build_var TARGET_PRODUCT)"
TARGET_DEVICE="$(get_build_var TARGET_DEVICE)"
TARGET_ARCH="$(get_build_var TARGET_ARCH)"
TARGET_ARCH_VARIANT="$(get_build_var TARGET_ARCH_VARIANT)"
TARGET_BUILD_VARIANT="$(get_build_var TARGET_BUILD_VARIANT)"

if [ -z "$TARGET_PRODUCT" ]; then
    err "TARGET_PRODUCT kosong setelah breakfast."
    exit 1
fi

# Variabel ini hanya untuk informasi output, bukan untuk menjalankan lunch.
LUNCH_TARGET="$TARGET_PRODUCT ($TARGET_BUILD_VARIANT)"

ok "Target selection selesai."
info "Selected product: $TARGET_PRODUCT"

# ============================================================
# VERIFY TARGET
# ============================================================

section "VERIFYING BUILD TARGET"

echo
echo "TARGET_PRODUCT       : $TARGET_PRODUCT"
echo "TARGET_DEVICE        : $TARGET_DEVICE"
echo "TARGET_ARCH          : $TARGET_ARCH"
echo "TARGET_ARCH_VARIANT  : $TARGET_ARCH_VARIANT"
echo "TARGET_BUILD_VARIANT : $TARGET_BUILD_VARIANT"
echo

[ -z "$TARGET_PRODUCT" ] && {
    err "TARGET_PRODUCT kosong."
    exit 1
}

[ -z "$TARGET_ARCH" ] && {
    err "TARGET_ARCH kosong."
    exit 1
}

[ "$TARGET_DEVICE" != "$DEVICE" ] && {
    err "TARGET_DEVICE tidak sesuai: $TARGET_DEVICE (expected $DEVICE)"
    exit 1
}

[ "$TARGET_ARCH" != "arm64" ] &&
    warn "TARGET_ARCH bukan arm64."

ok "Build target valid."

# ============================================================
# PRE-BUILD CHECK
# ============================================================

section "FINAL PRE-BUILD CHECK"

echo "ROM          : $ROM_NAME"
echo "Device       : $DEVICE"
echo "Target       : $BUILD_TARGET"
echo "Product      : $TARGET_PRODUCT"
echo "Variant      : $TARGET_BUILD_VARIANT"
echo "Architecture : $TARGET_ARCH"
echo "Threads      : $JOBS"
echo

if grep -qF "$GENERIC_INIT_VISIBILITY" "$BORINGSSL_BP"; then
    ok "libcrypto_static visibility OK."
else
    err "libcrypto_static visibility belum fix."
    exit 1
fi

ok "Semua pre-build check PASS."

# ============================================================
# BUILD WITH RETRY + LOGGING
# ============================================================

section "STARTING BUILD"

echo
echo "Building    : $BUILD_TARGET"
echo "Product     : $TARGET_PRODUCT"
echo "Variant     : $TARGET_BUILD_VARIANT"
echo "Jobs        : $JOBS"
echo "Log         : $BUILD_LOG"
echo

BUILD_START=$(date +%s)

MAX_RETRY=2
BUILD_STATUS="FAILED"

for attempt in $(seq 1 "$MAX_RETRY"); do
    info "Build attempt $attempt/$MAX_RETRY..."

    if m -j"$JOBS" "$BUILD_TARGET" 2>&1 | tee -a "$BUILD_LOG"; then
        BUILD_STATUS="SUCCESS"
        break
    fi

    if [ "$attempt" -lt "$MAX_RETRY" ]; then
        warn "Build gagal. Retry dalam 5 detik..."
        sleep 5
    fi
done

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

# ============================================================
# HANDLE RESULT
# ============================================================

if [ "$BUILD_STATUS" = "FAILED" ]; then
    section "BUILD FAILED"
    err "Build gagal setelah $MAX_RETRY percobaan."

    if grep -q "already defined by" "$BUILD_LOG"; then
        err "MASIH ADA duplikat module!"
        grep -B2 -A2 "already defined by" "$BUILD_LOG" | head -30
    fi

    if grep -q "error:" "$BUILD_LOG"; then
        echo
        echo "Error terakhir:"
        grep "error:" "$BUILD_LOG" | tail -10
    fi

    notify "❌ Build FAILED: $ROM_NAME ($DEVICE)"
    exit 1
fi

# ============================================================
# CHECK OUTPUT
# ============================================================

section "CHECKING BUILD OUTPUT"

[ ! -d "$OUT_DIR" ] && {
    err "Output tidak ditemukan: $OUT_DIR"
    exit 1
}

ok "Output: $OUT_DIR"

# ============================================================
# IMAGE CHECK
# ============================================================

section "CHECKING GENERATED IMAGES"

IMAGE_FOUND=0

for image in \
    system.img vendor.img boot.img init_boot.img \
    recovery.img super.img product.img system_ext.img
do
    if [ -f "$OUT_DIR/$image" ]; then
        SIZE="$(du -h "$OUT_DIR/$image" | awk '{print $1}')"
        ok "$image ($SIZE)"
        IMAGE_FOUND=1
    fi
done

[ "$IMAGE_FOUND" -eq 0 ] &&
    warn "Tidak ada image di output."

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
echo "Product    : $TARGET_PRODUCT"
echo "Variant    : $TARGET_BUILD_VARIANT"
echo "Output     : $OUT_DIR"
echo "Build time : $BUILD_TIME seconds ($((BUILD_TIME/60)) min)"
echo "Log        : $BUILD_LOG"
echo

echo "Generated files:"
find "$OUT_DIR" -maxdepth 1 -type f \
    \( -name "*.img" -o -name "*.zip" -o -name "*.zip.md5sum" \) \
    -printf "  %f\n" 2>/dev/null | sort || true

notify "✅ Build SUCCESS: $ROM_NAME ($DEVICE) — ${BUILD_TIME}s"

echo
echo "============================================================"
echo "                    DONE"
echo "============================================================"
echo
```
