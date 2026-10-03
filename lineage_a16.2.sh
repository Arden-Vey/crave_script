#!/usr/bin/env bash

###############################################################################
# LineageOS 23.2 - Xiaomi Mi A1 (tissot)
#
# PREBUILT KERNEL BUILD
#
# Kernel:
#   Image.gz-dtb
#
# Kernel source:
#   DISABLED
#
# Prebuilt kernel:
#   prebuilts/kernel/tissot/Image.gz-dtb
#
# Device:
#   tissot_mainline
#
# Lunch:
#   lineage_tissot_mainline-trunk_staging-userdebug
#
# Manifest:
#   https://github.com/JBHPocong/lineage-tissot-manifest.git
#   branch: main
#
# Crave:
#   Used for repo sync and build
#
###############################################################################

set -Eeuo pipefail

###############################################################################
# CONFIG
###############################################################################

ROM_BRANCH="lineage-23.2"

MANIFEST_URL="https://github.com/JBHPocong/lineage-tissot-manifest.git"
MANIFEST_BRANCH="main"

DEVICE_DIR="device/xiaomi/mi89xx-mainline"
DEVICE_NAME="tissot_mainline"

BOARD_CONFIG="${DEVICE_DIR}/tissot_mainline/BoardConfig.mk"

PREBUILT_KERNEL_DIR="prebuilts/kernel/tissot"
PREBUILT_KERNEL="${PREBUILT_KERNEL_DIR}/Image.gz-dtb"

KERNEL_SOURCE_PATH="kernel/mainline/msm8953-mainline"

KERNEL_SOURCE_PROJECT="msm8953-mainline/linux"

KERNEL_CONFIG_PROJECT="android_kernel_mainline_configs"
KERNEL_CONFIG_PATH="kernel/mainline/configs"

FIRMWARE_PATH="vendor/firmware/bq-bardockpro"

LUNCH_TARGET="lineage_tissot_mainline-trunk_staging-userdebug"

OUT_DIR="out"
PRODUCT_OUT="${OUT_DIR}/target/product/${DEVICE_NAME}"

LOG_DIR="${OUT_DIR}/prebuilt-kernel-build-logs"

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"

LOG_FILE="${LOG_DIR}/build-${TIMESTAMP}.log"

###############################################################################
# COLORS
###############################################################################

if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    RESET='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    RESET=''
fi

###############################################################################
# LOGGING
###############################################################################

mkdir -p "${LOG_DIR}"

exec > >(tee -a "${LOG_FILE}") 2>&1

###############################################################################
# HELPERS
###############################################################################

info() {
    echo -e "${CYAN}[INFO]${RESET} $*"
}

ok() {
    echo -e "${GREEN}[ OK ]${RESET} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${RESET} $*"
}

error() {
    echo -e "${RED}[ERROR]${RESET} $*"
}

die() {
    error "$*"
    echo
    error "Log:"
    echo "  ${LOG_FILE}"
    exit 1
}

section() {
    echo
    echo "============================================================"
    echo "$*"
    echo "============================================================"
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Command tidak ditemukan: $1"
}

###############################################################################
# ERROR HANDLER
###############################################################################

trap 'error "Script gagal pada line ${LINENO}: ${BASH_COMMAND}"' ERR

###############################################################################
# BASIC CHECK
###############################################################################

section "CHECK ENVIRONMENT"

if [[ ! -d ".repo" ]]; then
    die "Script harus dijalankan dari root source LineageOS."
fi

require_cmd git
require_cmd awk
require_cmd sed
require_cmd grep
require_cmd find
require_cmd sha256sum

if command -v crave >/dev/null 2>&1; then
    ok "Crave ditemukan: $(command -v crave)"
else
    die "crave tidak ditemukan."
fi

ok "Root source: $(pwd)"
ok "Branch ROM: ${ROM_BRANCH}"
ok "Device: ${DEVICE_NAME}"
ok "BoardConfig: ${BOARD_CONFIG}"

###############################################################################
# CHECK DEVICE TREE
###############################################################################

section "CHECK DEVICE TREE"

[[ -d "${DEVICE_DIR}" ]] \
    || die "Device tree tidak ditemukan: ${DEVICE_DIR}"

[[ -f "${BOARD_CONFIG}" ]] \
    || die "BoardConfig tidak ditemukan: ${BOARD_CONFIG}"

ok "Device tree ditemukan"
ok "BoardConfig ditemukan"

###############################################################################
# LOCAL MANIFEST DIRECTORY
###############################################################################

section "PREPARE LOCAL MANIFEST"

LOCAL_MANIFEST_DIR=".repo/local_manifests"

mkdir -p "${LOCAL_MANIFEST_DIR}"

###############################################################################
# FIND MANIFEST FILE
###############################################################################

MANIFEST_FILE=""

if [[ -f "${LOCAL_MANIFEST_DIR}/tissot.xml" ]]; then
    MANIFEST_FILE="${LOCAL_MANIFEST_DIR}/tissot.xml"
elif [[ -f "${LOCAL_MANIFEST_DIR}/lineage-tissot.xml" ]]; then
    MANIFEST_FILE="${LOCAL_MANIFEST_DIR}/lineage-tissot.xml"
else
    info "Manifest tissot belum ditemukan."

    TEMP_MANIFEST="/tmp/lineage-tissot-manifest-${TIMESTAMP}"

    rm -rf "${TEMP_MANIFEST}"

    git clone \
        --depth=1 \
        --branch "${MANIFEST_BRANCH}" \
        "${MANIFEST_URL}" \
        "${TEMP_MANIFEST}"

    FOUND_MANIFEST="$(find "${TEMP_MANIFEST}" -maxdepth 2 -type f -name '*.xml' | head -n 1 || true)"

    [[ -n "${FOUND_MANIFEST}" ]] \
        || die "Tidak menemukan XML manifest di repository."

    MANIFEST_FILE="${LOCAL_MANIFEST_DIR}/$(basename "${FOUND_MANIFEST}")"

    cp -f "${FOUND_MANIFEST}" "${MANIFEST_FILE}"

    ok "Manifest diambil dari repository."
fi

ok "Manifest: ${MANIFEST_FILE}"

###############################################################################
# BACKUP MANIFEST
###############################################################################

MANIFEST_BACKUP="${MANIFEST_FILE}.backup-${TIMESTAMP}"

cp -f "${MANIFEST_FILE}" "${MANIFEST_BACKUP}"

ok "Backup manifest:"
echo "  ${MANIFEST_BACKUP}"

###############################################################################
# PATCH MANIFEST
###############################################################################

section "PATCH MANIFEST"

python3 - "${MANIFEST_FILE}" <<'PY'
import sys
import re
from pathlib import Path

manifest = Path(sys.argv[1])

text = manifest.read_text()

KERNEL_PROJECT = "msm8953-mainline/linux"
KERNEL_PATH = "kernel/mainline/msm8953-mainline"

PREBUILT_PROJECT = "JBHPocong/lineage-tissot-manifest"
PREBUILT_PATH = "prebuilts/kernel/tissot"
PREBUILT_REV = "Image.gz-dtb"

###############################################################################
# Remove old kernel source project
###############################################################################

patterns = [
    rf'\s*<project\b[^>]*\bname="{re.escape(KERNEL_PROJECT)}"[^>]*/>\s*',
    rf'\s*<project\b[^>]*\bpath="{re.escape(KERNEL_PATH)}"[^>]*/>\s*',
]

for pattern in patterns:
    text = re.sub(pattern, "\n", text, flags=re.MULTILINE)

###############################################################################
# Remove an existing prebuilt project with same path/name
###############################################################################

project_blocks = re.findall(
    r'<project\b.*?(?:/>|</project>)',
    text,
    flags=re.DOTALL
)

for block in project_blocks:
    if (
        f'name="{PREBUILT_PROJECT}"' in block
        or f'path="{PREBUILT_PATH}"' in block
    ):
        text = text.replace(block, "")

###############################################################################
# Determine remote
###############################################################################

remote = "tissot-github"

if f'name="{remote}"' not in text:
    # Try to reuse an existing GitHub remote.
    remotes = re.findall(
        r'<remote\b[^>]*\bname="([^"]+)"[^>]*\bfetch="[^"]*"[^>]*/>',
        text
    )

    if remotes:
        remote = remotes[0]
    else:
        remote = "github"

###############################################################################
# Add prebuilt project
###############################################################################

project = f'''    <project
        name="{PREBUILT_PROJECT}"
        path="{PREBUILT_PATH}"
        remote="{remote}"
        revision="{PREBUILT_REV}" />'''

root_match = re.search(r'<manifest\b[^>]*>', text)

if not root_match:
    raise SystemExit("Manifest XML tidak memiliki <manifest> root.")

insert_at = root_match.end()

text = text[:insert_at] + "\n\n" + project + text[insert_at:]

manifest.write_text(text)
PY

###############################################################################
# MANIFEST VALIDATION
###############################################################################

info "Validating manifest..."

if grep -q 'msm8953-mainline/linux' "${MANIFEST_FILE}"; then
    die "Kernel source msm8953-mainline/linux masih ada di manifest."
fi

if grep -q 'path="kernel/mainline/msm8953-mainline"' "${MANIFEST_FILE}"; then
    die "Kernel source path lama masih ada di manifest."
fi

if ! grep -q 'path="prebuilts/kernel/tissot"' "${MANIFEST_FILE}"; then
    die "Prebuilt kernel project belum masuk manifest."
fi

if ! grep -q 'revision="Image.gz-dtb"' "${MANIFEST_FILE}"; then
    die "Revision Image.gz-dtb tidak ditemukan di manifest."
fi

if ! grep -q 'path="kernel/mainline/configs"' "${MANIFEST_FILE}"; then
    warn "android_kernel_mainline_configs tidak ditemukan."
    warn "Script TIDAK akan menghapus dependency tersebut jika memang diperlukan device tree."
else
    ok "android_kernel_mainline_configs tetap ada."
fi

ok "Manifest kernel source lama sudah dihapus."
ok "Manifest prebuilt kernel sudah dikonfigurasi."

###############################################################################
# SHOW MANIFEST KERNEL CONFIG
###############################################################################

echo
echo "Relevant manifest entries:"
grep -n -E \
    'msm8953-mainline|prebuilts/kernel/tissot|kernel/mainline/configs|firmware-bq-bardockpro' \
    "${MANIFEST_FILE}" \
    || true

###############################################################################
# CRAVE RESYNC
###############################################################################

section "CRAVE RESYNC"

info "Meminta Crave melakukan sync setelah manifest berubah."

crave run \
    --repo-sync

ok "Crave repo sync selesai."

###############################################################################
# VERIFY PREBUILT KERNEL
###############################################################################

section "VERIFY PREBUILT KERNEL"

if [[ ! -f "${PREBUILT_KERNEL}" ]]; then

    warn "Kernel belum berada di lokasi:"
    echo "  ${PREBUILT_KERNEL}"

    info "Mencari Image.gz-dtb..."

    mapfile -t KERNEL_CANDIDATES < <(
        find . \
            -type f \
            -name "Image.gz-dtb" \
            -not -path "./.repo/*" \
            2>/dev/null
    )

    if [[ "${#KERNEL_CANDIDATES[@]}" -eq 0 ]]; then
        die "Image.gz-dtb tidak ditemukan setelah sync."
    fi

    if [[ "${#KERNEL_CANDIDATES[@]}" -gt 1 ]]; then
        warn "Ditemukan beberapa Image.gz-dtb:"
        printf '  %s\n' "${KERNEL_CANDIDATES[@]}"

        # Prefer the expected manifest location.
        FOUND=""

        for candidate in "${KERNEL_CANDIDATES[@]}"; do
            if [[ "${candidate}" == "./${PREBUILT_KERNEL}" ]]; then
                FOUND="${candidate}"
                break
            fi
        done

        if [[ -z "${FOUND}" ]]; then
            die "Lebih dari satu Image.gz-dtb ditemukan dan tidak ada yang berada di lokasi manifest."
        fi

        KERNEL_SOURCE_FILE="${FOUND}"
    else
        KERNEL_SOURCE_FILE="${KERNEL_CANDIDATES[0]}"
    fi

    mkdir -p "${PREBUILT_KERNEL_DIR}"

    if [[ "${KERNEL_SOURCE_FILE}" != "./${PREBUILT_KERNEL}" ]]; then
        cp -f "${KERNEL_SOURCE_FILE}" "${PREBUILT_KERNEL}"
        ok "Image.gz-dtb disalin ke ${PREBUILT_KERNEL}"
    fi
fi

[[ -f "${PREBUILT_KERNEL}" ]] \
    || die "Prebuilt kernel final tidak ditemukan."

KERNEL_SIZE="$(stat -c '%s' "${PREBUILT_KERNEL}")"
KERNEL_SHA256="$(sha256sum "${PREBUILT_KERNEL}" | awk '{print $1}')"

if (( KERNEL_SIZE < 1024 * 1024 )); then
    die "Image.gz-dtb terlalu kecil: ${KERNEL_SIZE} bytes"
fi

ok "Prebuilt kernel ditemukan."
echo "  Path : ${PREBUILT_KERNEL}"
echo "  Size : ${KERNEL_SIZE} bytes"
echo "  SHA  : ${KERNEL_SHA256}"

###############################################################################
# FILE TYPE
###############################################################################

if command -v file >/dev/null 2>&1; then
    file "${PREBUILT_KERNEL}" || true
fi

###############################################################################
# BACKUP BOARD CONFIG
###############################################################################

section "BACKUP BOARD CONFIG"

BOARD_BACKUP="${BOARD_CONFIG}.backup-${TIMESTAMP}"

cp -f "${BOARD_CONFIG}" "${BOARD_BACKUP}"

ok "Backup:"
echo "  ${BOARD_BACKUP}"

###############################################################################
# PATCH BOARD CONFIG
###############################################################################

section "PATCH TISSOT BOARD CONFIG"

python3 - "${BOARD_CONFIG}" "${PREBUILT_KERNEL}" <<'PY'
import sys
import re
from pathlib import Path

board = Path(sys.argv[1])
kernel = sys.argv[2]

text = board.read_text()

###############################################################################
# Remove old kernel configuration blocks
###############################################################################

remove_exact = [
    r'^\s*TARGET_KERNEL_SOURCE\s*:=.*$',
    r'^\s*TARGET_KERNEL_CONFIG\s*:=.*$',
    r'^\s*TARGET_KERNEL_CONFIG_EXT\s*:=.*$',
    r'^\s*TARGET_KERNEL_ADDITIONAL_FLAGS\s*:=.*$',
    r'^\s*KERNEL_DEFCONFIG\s*:=.*$',
    r'^\s*TARGET_KERNEL_VERSION\s*:=.*$',
    r'^\s*TARGET_KERNEL_PLATFORM_TARGET\s*:=.*$',
    r'^\s*TARGET_KERNEL_CLANG_COMPILE\s*:=.*$',
    r'^\s*TARGET_KERNEL_CLANG_VERSION\s*:=.*$',
    r'^\s*TARGET_KERNEL_CROSS_COMPILE_PREFIX\s*:=.*$',
    r'^\s*TARGET_KERNEL_CROSS_COMPILE_ARM32_PREFIX\s*:=.*$',
    r'^\s*TARGET_KERNEL_TOOLCHAIN_PREFIX\s*:=.*$',
    r'^\s*TARGET_KERNEL_LLVM_BINUTILS\s*:=.*$',
    r'^\s*TARGET_KERNEL_NO_GCC\s*:=.*$',
    r'^\s*TARGET_KERNEL_MIXED_MODE\s*:=.*$',
    r'^\s*TARGET_KERNEL_PREBUILT\s*:=.*$',
    r'^\s*TARGET_PREBUILT_KERNEL\s*:=.*$',
    r'^\s*TARGET_FORCE_PREBUILT_KERNEL\s*:=.*$',
    r'^\s*TARGET_PREBUILT_KERNEL_HEADERS\s*:=.*$',
    r'^\s*TARGET_NO_KERNEL_OVERRIDE\s*:=.*$',
]

for pattern in remove_exact:
    text = re.sub(pattern, "", text, flags=re.MULTILINE)

###############################################################################
# Remove old kernel module variables
#
# IMPORTANT:
# These are the variables that can make the build system attempt to find
# system_dlkm.modules.load or .ko files inside the prebuilt kernel directory.
###############################################################################

module_patterns = [
    r'^\s*BOARD_SYSTEM_KERNEL_MODULES\s*:=.*$',
    r'^\s*BOARD_SYSTEM_KERNEL_MODULES_LOAD\s*:=.*$',
    r'^\s*BOARD_SYSTEM_KERNEL_MODULES_BLOCKLIST_FILE\s*:=.*$',
    r'^\s*BOARD_VENDOR_KERNEL_MODULES\s*:=.*$',
    r'^\s*BOARD_VENDOR_KERNEL_MODULES_LOAD\s*:=.*$',
    r'^\s*BOARD_VENDOR_KERNEL_MODULES_BLOCKLIST_FILE\s*:=.*$',
    r'^\s*BOARD_VENDOR_RAMDISK_KERNEL_MODULES\s*:=.*$',
    r'^\s*BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD\s*:=.*$',
    r'^\s*BOARD_VENDOR_RAMDISK_KERNEL_MODULES_BLOCKLIST_FILE\s*:=.*$',
    r'^\s*BOARD_RECOVERY_KERNEL_MODULES\s*:=.*$',
    r'^\s*BOARD_RECOVERY_KERNEL_MODULES_LOAD\s*:=.*$',
    r'^\s*BOARD_RECOVERY_KERNEL_MODULES_BLOCKLIST_FILE\s*:=.*$',
    r'^\s*BOARD_KERNEL_MODULES\s*:=.*$',
    r'^\s*TARGET_KERNEL_MODULES\s*:=.*$',
    r'^\s*TARGET_KERNEL_EXT_MODULES\s*:=.*$',
    r'^\s*TARGET_MODULE_ALIASES\s*:=.*$',
    r'^\s*BOARD_VENDOR_KERNEL_MODULES_LOAD\s*\+=.*$',
    r'^\s*BOARD_SYSTEM_KERNEL_MODULES_LOAD\s*\+=.*$',
    r'^\s*BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD\s*\+=.*$',
]

for pattern in module_patterns:
    text = re.sub(pattern, "", text, flags=re.MULTILINE)

###############################################################################
# Remove stale system_dlkm/prebuilt-kernel path variables
###############################################################################

path_patterns = [
    r'^\s*SYSTEM_DLKM_MODULES_PATH\s*:=.*$',
    r'^\s*DLKM_MODULES_PATH\s*:=.*$',
    r'^\s*RAMDISK_MODULES_PATH\s*:=.*$',
    r'^\s*KERNEL_MODULES_PATH\s*:=.*$',
    r'^\s*PREBUILT_KERNEL_PATH\s*:=.*$',
]

for pattern in path_patterns:
    text = re.sub(pattern, "", text, flags=re.MULTILINE)

###############################################################################
# Remove separate DTB configuration
#
# Image.gz-dtb already contains kernel + DTB.
###############################################################################

dtb_patterns = [
    r'^\s*BOARD_PREBUILT_DTBIMAGE_DIR\s*:=.*$',
    r'^\s*BOARD_PREBUILT_DTBIMAGE_DIR\s*\?=.*$',
    r'^\s*TARGET_PREBUILT_DTB\s*:=.*$',
    r'^\s*BOARD_PREBUILT_DTB\s*:=.*$',
    r'^\s*BOARD_DTBIMAGE_PARTITION_SIZE\s*:=.*$',
    r'^\s*BOARD_DTB_OFFSET\s*:=.*$',
    r'^\s*BOARD_KERNEL_DTB\s*:=.*$',
    r'^\s*TARGET_KERNEL_DTB\s*:=.*$',
    r'^\s*TARGET_KERNEL_DTBIMAGE\s*:=.*$',
]

for pattern in dtb_patterns:
    text = re.sub(pattern, "", text, flags=re.MULTILINE)

###############################################################################
# Remove BOARD_MKBOOTIMG_ARGS entries that explicitly reference DTB
###############################################################################

text = re.sub(
    r'^[ \t]*BOARD_MKBOOTIMG_ARGS\s*\+=\s*--dtb(?:_offset)?\s+\S+.*$',
    "",
    text,
    flags=re.MULTILINE
)

###############################################################################
# Remove stale PRODUCT_COPY_FILES kernel entries
###############################################################################

text = re.sub(
    r'^[ \t]*PRODUCT_COPY_FILES\s*(?:\+=|:=)\s*.*TARGET_PREBUILT_KERNEL.*$',
    "",
    text,
    flags=re.MULTILINE
)

text = re.sub(
    r'^[ \t]*PRODUCT_COPY_FILES\s*.*:kernel\s*$',
    "",
    text,
    flags=re.MULTILINE
)

###############################################################################
# Remove old kernel section comments if present
###############################################################################

text = re.sub(
    r'\n[ \t]*#\s*Kernel\s*-\s*prebuilt[^\n]*\n',
    "\n",
    text,
    flags=re.IGNORECASE
)

###############################################################################
# Normalize duplicate empty lines
###############################################################################

text = re.sub(r'\n{3,}', '\n\n', text)

###############################################################################
# Kernel configuration
###############################################################################

kernel_block = f'''
###############################################################################
# PREBUILT MAINLINE KERNEL
###############################################################################

# Image.gz-dtb contains the kernel image and embedded DTB.
# No separate dtb.img is required.

TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64

BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb

TARGET_FORCE_PREBUILT_KERNEL := true
TARGET_PREBUILT_KERNEL := {kernel}

# The kernel source is intentionally unset.
# This forces LineageOS kernel.mk to use TARGET_PREBUILT_KERNEL.
TARGET_KERNEL_SOURCE :=
TARGET_KERNEL_CONFIG :=
TARGET_KERNEL_CONFIG_EXT :=

# Do not use source/platform kernel build mode.
TARGET_KERNEL_PLATFORM_TARGET :=
TARGET_KERNEL_MIXED_MODE := false

# Do not search the prebuilt kernel directory for kernel modules.
BOARD_SYSTEM_KERNEL_MODULES :=
BOARD_SYSTEM_KERNEL_MODULES_LOAD :=
BOARD_VENDOR_KERNEL_MODULES :=
BOARD_VENDOR_KERNEL_MODULES_LOAD :=
BOARD_VENDOR_RAMDISK_KERNEL_MODULES :=
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD :=
'''

text = text.rstrip() + "\n" + kernel_block + "\n"

board.write_text(text)
PY

ok "BoardConfig tissot_mainline berhasil dipatch."

###############################################################################
# REMOVE ACCIDENTAL PREBUILT CONFIG FROM OTHER BOARD FILES
#
# We do NOT modify them.
# We only check and report if the previous script contaminated them.
###############################################################################

section "CHECK OTHER BOARD CONFIGS"

OTHER_KERNEL_CONFIGS="$(
    find "${DEVICE_DIR}" \
        -type f \
        \( -name 'BoardConfig.mk' -o -name 'BoardConfigCommon.mk' \) \
        -not -path "${DEVICE_DIR}/tissot_mainline/*" \
        -print
)"

if [[ -n "${OTHER_KERNEL_CONFIGS}" ]]; then
    FOUND_BAD=0

    while IFS= read -r cfg; do
        [[ -z "${cfg}" ]] && continue

        if grep -q \
            -E \
            'TARGET_PREBUILT_KERNEL.*prebuilts/kernel/tissot|TARGET_FORCE_PREBUILT_KERNEL.*true' \
            "${cfg}"; then

            warn "BoardConfig lain pernah terkontaminasi:"
            echo "  ${cfg}"

            FOUND_BAD=1
        fi
    done <<< "${OTHER_KERNEL_CONFIGS}"

    if (( FOUND_BAD )); then
        warn "Script ini TIDAK mengedit BoardConfig device lain."
        warn "Jika backup dari run sebelumnya tersedia, restore BoardConfig tersebut secara manual."
    else
        ok "Tidak ada BoardConfig device lain yang menunjukkan konfigurasi prebuilt tissot."
    fi
fi

###############################################################################
# REMOVE STALE KERNEL SOURCE DIRECTORY IF IT EXISTS
###############################################################################

section "CHECK OLD KERNEL SOURCE"

if [[ -d "${KERNEL_SOURCE_PATH}" ]]; then
    warn "Kernel source lama masih ada:"
    echo "  ${KERNEL_SOURCE_PATH}"

    warn "Manifest sudah tidak mereferensikan source tersebut."

    # IMPORTANT:
    # Do not rm -rf it.
    # Leave it alone because Crave workspace/source management owns it.
else
    ok "Kernel source lama tidak ada."
fi

###############################################################################
# VERIFY BOARD CONFIG
###############################################################################

section "VERIFY BOARD CONFIG"

echo
echo "=== Kernel configuration ==="

grep -n -E \
    'TARGET_KERNEL_ARCH|TARGET_KERNEL_HEADER_ARCH|BOARD_KERNEL_IMAGE_NAME|TARGET_FORCE_PREBUILT_KERNEL|TARGET_PREBUILT_KERNEL|TARGET_KERNEL_SOURCE|TARGET_KERNEL_CONFIG|TARGET_KERNEL_PLATFORM_TARGET|TARGET_KERNEL_MIXED_MODE' \
    "${BOARD_CONFIG}" \
    || true

echo
echo "=== DTB configuration ==="

grep -n -E \
    'BOARD_PREBUILT_DTBIMAGE_DIR|TARGET_PREBUILT_DTB|BOARD_PREBUILT_DTB|BOARD_DTB_OFFSET|TARGET_KERNEL_DTB|TARGET_KERNEL_DTBIMAGE' \
    "${BOARD_CONFIG}" \
    || true

echo
echo "=== Kernel module configuration ==="

grep -n -E \
    'BOARD_SYSTEM_KERNEL_MODULES|BOARD_VENDOR_KERNEL_MODULES|BOARD_VENDOR_RAMDISK_KERNEL_MODULES|SYSTEM_DLKM_MODULES_PATH|DLKM_MODULES_PATH|RAMDISK_MODULES_PATH' \
    "${BOARD_CONFIG}" \
    || true

###############################################################################
# HARD VALIDATION
###############################################################################

section "HARD VALIDATION"

FAIL=0

if ! grep -q '^TARGET_FORCE_PREBUILT_KERNEL := true$' "${BOARD_CONFIG}"; then
    error "TARGET_FORCE_PREBUILT_KERNEL tidak aktif."
    FAIL=1
fi

if ! grep -q "^TARGET_PREBUILT_KERNEL := ${PREBUILT_KERNEL}$" "${BOARD_CONFIG}"; then
    error "TARGET_PREBUILT_KERNEL tidak menunjuk ke ${PREBUILT_KERNEL}"
    FAIL=1
fi

if ! grep -q '^BOARD_KERNEL_IMAGE_NAME := Image.gz-dtb$' "${BOARD_CONFIG}"; then
    error "BOARD_KERNEL_IMAGE_NAME bukan Image.gz-dtb."
    FAIL=1
fi

if grep -qE '^TARGET_KERNEL_SOURCE\s*:=[[:space:]]*[^[:space:]]' "${BOARD_CONFIG}"; then
    error "TARGET_KERNEL_SOURCE masih menunjuk ke source."
    FAIL=1
fi

if grep -qE '^TARGET_KERNEL_CONFIG\s*:=[[:space:]]*[^[:space:]]' "${BOARD_CONFIG}"; then
    error "TARGET_KERNEL_CONFIG masih aktif."
    FAIL=1
fi

if grep -qE \
    '^[[:space:]]*(BOARD_PREBUILT_DTBIMAGE_DIR|TARGET_PREBUILT_DTB|BOARD_PREBUILT_DTB|BOARD_DTB_OFFSET|TARGET_KERNEL_DTB|TARGET_KERNEL_DTBIMAGE)[[:space:]]*:?=' \
    "${BOARD_CONFIG}"; then

    error "Konfigurasi separate DTB masih ditemukan."
    FAIL=1
fi

if grep -qE \
    '^[[:space:]]*(BOARD_SYSTEM_KERNEL_MODULES|BOARD_SYSTEM_KERNEL_MODULES_LOAD|BOARD_VENDOR_KERNEL_MODULES|BOARD_VENDOR_KERNEL_MODULES_LOAD|BOARD_VENDOR_RAMDISK_KERNEL_MODULES|BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD)[[:space:]]*:?=' \
    "${BOARD_CONFIG}"; then

    # Empty assignment is allowed.
    NONEMPTY_MODULE_LINES="$(
        grep -E \
            '^[[:space:]]*(BOARD_SYSTEM_KERNEL_MODULES|BOARD_SYSTEM_KERNEL_MODULES_LOAD|BOARD_VENDOR_KERNEL_MODULES|BOARD_VENDOR_KERNEL_MODULES_LOAD|BOARD_VENDOR_RAMDISK_KERNEL_MODULES|BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD)[[:space:]]*:=[[:space:]]*[^[:space:]]' \
            "${BOARD_CONFIG}" \
            || true
    )"

    if [[ -n "${NONEMPTY_MODULE_LINES}" ]]; then
        error "Kernel module path masih aktif:"
        echo "${NONEMPTY_MODULE_LINES}"
        FAIL=1
    fi
fi

if (( FAIL )); then
    die "Validasi BoardConfig gagal."
fi

ok "BoardConfig valid untuk prebuilt Image.gz-dtb."

###############################################################################
# SEARCH DANGEROUS STALE REFERENCES
###############################################################################

section "SEARCH STALE PREBUILT REFERENCES"

STALE_HITS="$(
    grep -RIn \
        --exclude-dir=.git \
        --exclude-dir=.repo \
        --exclude='*.backup-*' \
        -E \
        'prebuilts/kernel/tissot/.*/(system_dlkm|vendor_dlkm|modules)|prebuilts/kernel/tissot/(dtb|dtbo)|TARGET_PREBUILT_DTB|BOARD_PREBUILT_DTBIMAGE_DIR' \
        device/xiaomi/mi89xx-mainline \
        2>/dev/null \
        || true
)"

if [[ -n "${STALE_HITS}" ]]; then
    warn "Ditemukan referensi stale:"
    echo "${STALE_HITS}"
    warn "Referensi tersebut tidak otomatis diubah kecuali berasal dari BoardConfig tissot."
else
    ok "Tidak ada referensi stale yang terdeteksi."
fi

###############################################################################
# SEARCH SYSTEM DLKM REFERENCES
###############################################################################

section "CHECK SYSTEM DLKM"

DLKM_HITS="$(
    grep -RIn \
        --exclude-dir=.git \
        --exclude-dir=.repo \
        --exclude='*.backup-*' \
        -E \
        'system_dlkm\.modules\.load|BOARD_SYSTEM_KERNEL_MODULES|SYSTEM_KERNEL_MODULES' \
        "${DEVICE_DIR}" \
        2>/dev/null \
        || true
)"

if [[ -n "${DLKM_HITS}" ]]; then
    echo "${DLKM_HITS}"
else
    ok "Tidak ada system_dlkm kernel module reference di device tree."
fi

###############################################################################
# CHECK MANIFEST AGAIN
###############################################################################

section "FINAL MANIFEST CHECK"

if grep -q 'msm8953-mainline/linux' "${MANIFEST_FILE}"; then
    die "Manifest masih memiliki msm8953-mainline/linux."
fi

if grep -q 'kernel/mainline/msm8953-mainline' "${MANIFEST_FILE}"; then
    die "Manifest masih memiliki kernel/mainline/msm8953-mainline."
fi

if ! grep -q 'prebuilts/kernel/tissot' "${MANIFEST_FILE}"; then
    die "Manifest tidak memiliki prebuilts/kernel/tissot."
fi

if ! grep -q 'revision="Image.gz-dtb"' "${MANIFEST_FILE}"; then
    die "Manifest tidak menggunakan revision Image.gz-dtb."
fi

ok "Manifest final valid."

###############################################################################
# VERIFY KERNEL AGAIN
###############################################################################

section "FINAL KERNEL CHECK"

[[ -f "${PREBUILT_KERNEL}" ]] \
    || die "Final Image.gz-dtb tidak ditemukan."

KERNEL_SIZE="$(stat -c '%s' "${PREBUILT_KERNEL}")"
KERNEL_SHA256="$(sha256sum "${PREBUILT_KERNEL}" | awk '{print $1}')"

echo "Kernel:"
echo "  ${PREBUILT_KERNEL}"
echo
echo "Size:"
echo "  ${KERNEL_SIZE} bytes"
echo
echo "SHA256:"
echo "  ${KERNEL_SHA256}"

###############################################################################
# ENVIRONMENT
###############################################################################

section "SET BUILD ENVIRONMENT"

export ALLOW_MISSING_DEPENDENCIES=true
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true

# Make prebuilt kernel path visible to the shell/build environment.
export TARGET_PREBUILT_KERNEL="${PREBUILT_KERNEL}"

export BUILD_USERNAME="Arden-Vey"
export BUILD_HOSTNAME="crave"

export DEVICE="${DEVICE_NAME}"
export BUILD_TARGET="all_images"

ok "Build environment configured."

###############################################################################
# SOURCE ENVIRONMENT
###############################################################################

section "LOAD ANDROID BUILD ENVIRONMENT"

if [[ ! -f "build/envsetup.sh" ]]; then
    die "build/envsetup.sh tidak ditemukan."
fi

source build/envsetup.sh

ok "envsetup loaded."

###############################################################################
# LUNCH
###############################################################################

section "LUNCH"

lunch "${LUNCH_TARGET}"

ok "Lunch berhasil:"
echo "  ${LUNCH_TARGET}"

###############################################################################
# VERIFY TARGET VARIABLES
###############################################################################

section "VERIFY BUILD VARIABLES"

echo
echo "TARGET_DEVICE:"
echo "${TARGET_DEVICE:-<unset>}"

echo
echo "TARGET_PRODUCT:"
echo "${TARGET_PRODUCT:-<unset>}"

echo
echo "TARGET_BUILD_VARIANT:"
echo "${TARGET_BUILD_VARIANT:-<unset>}"

echo
echo "TARGET_PREBUILT_KERNEL:"
echo "${TARGET_PREBUILT_KERNEL:-<unset>}"

echo
echo "TARGET_KERNEL_SOURCE:"
echo "${TARGET_KERNEL_SOURCE:-<unset>}"

echo
echo "BOARD_KERNEL_IMAGE_NAME:"
echo "${BOARD_KERNEL_IMAGE_NAME:-<unset>}"

###############################################################################
# VARIABLE VALIDATION
###############################################################################

if [[ "${TARGET_DEVICE:-}" != "${DEVICE_NAME}" ]]; then
    warn "TARGET_DEVICE = ${TARGET_DEVICE:-unset}"
    warn "Expected      = ${DEVICE_NAME}"
fi

if [[ "${TARGET_PREBUILT_KERNEL:-}" != "${PREBUILT_KERNEL}" ]]; then
    die "Build environment TARGET_PREBUILT_KERNEL salah."
fi

if [[ -n "${TARGET_KERNEL_SOURCE:-}" ]]; then
    warn "TARGET_KERNEL_SOURCE masih memiliki nilai:"
    echo "  ${TARGET_KERNEL_SOURCE}"
    warn "Build system mungkin mendeteksi kernel source."
fi

if [[ "${BOARD_KERNEL_IMAGE_NAME:-}" != "Image.gz-dtb" ]]; then
    die "BOARD_KERNEL_IMAGE_NAME bukan Image.gz-dtb."
fi

###############################################################################
# PREBUILD EXISTENCE CHECK AFTER LUNCH
###############################################################################

[[ -f "${TARGET_PREBUILT_KERNEL}" ]] \
    || die "TARGET_PREBUILT_KERNEL tidak ada setelah lunch."

ok "Build system melihat prebuilt kernel."

###############################################################################
# CHECK OUT DIR
###############################################################################

section "CHECK OUTPUT DIRECTORY"

mkdir -p "${PRODUCT_OUT}"

ok "Product output:"
echo "  ${PRODUCT_OUT}"

###############################################################################
# BUILD
###############################################################################

section "BUILD LINEAGEOS 23.2"

info "Mulai build..."
info "Kernel TIDAK dikompilasi."
info "Kernel yang dipakai:"
echo "  ${PREBUILT_KERNEL}"
echo
info "Build command:"
echo "  mka bacon"

###############################################################################
# Build
###############################################################################

mka bacon

###############################################################################
# BUILD SUCCESS
###############################################################################

section "BUILD FINISHED"

ok "Build selesai."

###############################################################################
# ARTIFACT SEARCH
###############################################################################

section "SEARCH BUILD ARTIFACTS"

echo
echo "ZIP:"
find "${PRODUCT_OUT}" \
    -maxdepth 1 \
    -type f \
    \( -name '*.zip' -o -name '*.img' \) \
    -printf '%f\n' \
    2>/dev/null \
    | sort \
    || true

echo
echo "Boot images:"
find "${PRODUCT_OUT}" \
    -maxdepth 1 \
    -type f \
    \( \
        -name 'boot.img' \
        -o -name 'vendor_boot.img' \
        -o -name 'init_boot.img' \
        -o -name 'recovery.img' \
        -o -name 'dtbo.img' \
        -o -name 'vbmeta.img' \
    \) \
    -printf '%f\n' \
    2>/dev/null \
    | sort \
    || true

###############################################################################
# VERIFY IMPORTANT ARTIFACTS
###############################################################################

section "VERIFY ARTIFACTS"

BOOT_IMG="${PRODUCT_OUT}/boot.img"

if [[ -f "${BOOT_IMG}" ]]; then
    BOOT_SIZE="$(stat -c '%s' "${BOOT_IMG}")"
    BOOT_SHA="$(sha256sum "${BOOT_IMG}" | awk '{print $1}')"

    ok "boot.img ditemukan."
    echo "  Size: ${BOOT_SIZE}"
    echo "  SHA : ${BOOT_SHA}"
else
    warn "boot.img tidak ditemukan di output."
fi

###############################################################################
# FIND ROM ZIP
###############################################################################

ROM_ZIP="$(
    find "${PRODUCT_OUT}" \
        -maxdepth 1 \
        -type f \
        -name '*.zip' \
        -printf '%T@ %p\n' \
        2>/dev/null \
        | sort -nr \
        | awk 'NR==1 {$1=""; sub(/^ /,""); print}'
)"

if [[ -n "${ROM_ZIP}" && -f "${ROM_ZIP}" ]]; then
    ROM_SIZE="$(stat -c '%s' "${ROM_ZIP}")"
    ROM_SHA="$(sha256sum "${ROM_ZIP}" | awk '{print $1}')"

    ok "ROM ZIP ditemukan:"
    echo "  ${ROM_ZIP}"
    echo
    echo "Size:"
    echo "  ${ROM_SIZE} bytes"
    echo
    echo "SHA256:"
    echo "  ${ROM_SHA}"
else
    warn "ROM ZIP tidak ditemukan."
fi

###############################################################################
# FINAL SUMMARY
###############################################################################

section "FINAL SUMMARY"

echo
echo "ROM"
echo "----------------------------------------"
echo "Branch       : ${ROM_BRANCH}"
echo "Device       : ${DEVICE_NAME}"
echo "Lunch        : ${LUNCH_TARGET}"
echo

echo "Kernel"
echo "----------------------------------------"
echo "Type         : PREBUILT"
echo "Image        : Image.gz-dtb"
echo "Path         : ${PREBUILT_KERNEL}"
echo "Size         : ${KERNEL_SIZE}"
echo "SHA256       : ${KERNEL_SHA256}"
echo

echo "Manifest"
echo "----------------------------------------"
echo "Repository   : ${MANIFEST_URL}"
echo "Branch       : ${MANIFEST_BRANCH}"
echo "Kernel src   : DISABLED"
echo "Prebuilt     : ENABLED"
echo

echo "Output"
echo "----------------------------------------"
echo "${PRODUCT_OUT}"
echo

echo "Log"
echo "----------------------------------------"
echo "${LOG_FILE}"
echo

ok "SELESAI."
