#!/bin/bash

set -Eeuo pipefail

# ============================================================
# LineageOS 23.2 Tissot Mainline - Diagnostic Script
# ============================================================
#
# Fungsi:
#   1. Bersihkan local manifest lama
#   2. Repo init LineageOS 23.2
#   3. Clone local manifest Tissot
#   4. Resync menggunakan Crave
#   5. Cek source/device/kernel/vendor
#   6. Cek msm8953-common/Android.bp
#   7. Cek referensi Soong namespace
#   8. source build/envsetup.sh
#   9. lunch target
#  10. Kirim status/error ke Discord
#
# TIDAK melakukan:
#   - mka bacon
#   - make
#   - make clean
#   - rm -rf out
#
# Webhook Discord:
#   export DISCORD_WEBHOOK_URL="..."
#
# ============================================================

ROM_BRANCH="lineage-23.2"
MANIFEST_BRANCH="main"

MANIFEST_URL="https://github.com/JBHPocong/lineage-tissot-manifest.git"

LUNCH_TARGET="lineage_tissot_mainline-trunk_staging-userdebug"

DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"

LOG_FILE="tissot_diagnostic.log"

# ============================================================
# Discord
# ============================================================

discord_notify() {
    local message="$1"

    if [ -z "${DISCORD_WEBHOOK_URL}" ]; then
        echo "⚠️ DISCORD_WEBHOOK_URL belum tersedia."
        echo "Discord notification dilewati."
        return 0
    fi

    python3 - "$message" <<'PY' | curl -fsS \
        -H "Content-Type: application/json" \
        -X POST \
        -d @- \
        "$DISCORD_WEBHOOK_URL" >/dev/null
import json
import sys

message = sys.argv[1]

print(json.dumps({
    "content": message
}, ensure_ascii=False))
PY
}

# ============================================================
# Logging
# ============================================================

exec > >(tee -a "$LOG_FILE") 2>&1

# ============================================================
# Error Handler
# ============================================================

on_error() {
    local exit_code=$?
    local line_no=$1
    local command="${BASH_COMMAND}"

    echo
    echo "============================================================"
    echo "❌ SCRIPT ERROR"
    echo "============================================================"
    echo "Exit code : ${exit_code}"
    echo "Line      : ${line_no}"
    echo "Command   : ${command}"
    echo "============================================================"

    discord_notify "❌ **Tissot LOS 23.2 Diagnostic FAILED**

**Line:** ${line_no}
**Exit code:** ${exit_code}

**Command:**
\`${command}\`

Workspace: \`$(pwd)\`

Diagnostic dihentikan."

    exit "$exit_code"
}

trap 'on_error ${LINENO}' ERR

# ============================================================
# Header
# ============================================================

echo
echo "============================================================"
echo " LineageOS 23.2 Tissot Mainline Diagnostic"
echo "============================================================"
echo

echo "Workspace : $(pwd)"
echo "Date      : $(date)"
echo "User      : $(whoami)"
echo

discord_notify "🔎 **Tissot LOS 23.2 Diagnostic dimulai**

Workspace: \`$(pwd)\`
Target: \`${LUNCH_TARGET}\`"

# ============================================================
# Check required commands
# ============================================================

echo
echo "[1/10] Checking required commands..."

REQUIRED_COMMANDS=(
    git
    curl
    python3
    repo
)

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "✅ $cmd"
    else
        echo "❌ $cmd tidak ditemukan."
        exit 1
    fi
done

# ============================================================
# Local manifest
# ============================================================

echo
echo "[2/10] Preparing local manifest..."

if [ -d ".repo/local_manifests" ]; then
    echo "Removing old local manifests..."
    rm -rf .repo/local_manifests
fi

mkdir -p .repo/local_manifests

echo "Cloning:"
echo "$MANIFEST_URL"

git clone \
    -b "$MANIFEST_BRANCH" \
    "$MANIFEST_URL" \
    .repo/local_manifests

echo "✅ Local manifest cloned."

# ============================================================
# Repo init
# ============================================================

echo
echo "[3/10] Repo init LineageOS ${ROM_BRANCH}..."

repo init \
    -u https://github.com/LineageOS/android.git \
    -b "$ROM_BRANCH" \
    --git-lfs \
    --depth=1

echo "✅ Repo init completed."

# ============================================================
# Crave resync
# ============================================================

echo
echo "[4/10] Crave resync..."

if [ -x "/opt/crave/resync.sh" ]; then
    /opt/crave/resync.sh
else
    echo "❌ /opt/crave/resync.sh tidak ditemukan."
    exit 1
fi

echo "✅ Crave resync completed."

# ============================================================
# Check important directories
# ============================================================

echo
echo "[5/10] Checking important source directories..."

PATHS=(
    "device/xiaomi/mi89xx-mainline"
    "device/xiaomi/msm8953-common"
    "device/mainline/qcom-common"
    "device/mainline/common"
    "kernel/mainline/msm8953-mainline"
    "vendor/xiaomi/tissot"
    "hardware/xiaomi"
    "hardware/mainline/qcom"
    "hardware/mainline/common"
    "external/tinyhal"
    "external/mesa"
)

MISSING=0

for path in "${PATHS[@]}"; do
    if [ -e "$path" ]; then
        echo "✅ $path"
    else
        echo "❌ MISSING: $path"
        MISSING=1
    fi
done

if [ "$MISSING" -ne 0 ]; then
    echo
    echo "❌ Ada source/dependency yang hilang."
    exit 1
fi

# ============================================================
# Check msm8953-common Android.bp
# ============================================================

echo
echo "[6/10] Checking msm8953-common Android.bp..."

COMMON_BP="device/xiaomi/msm8953-common/Android.bp"

if [ ! -f "$COMMON_BP" ]; then
    echo "❌ File tidak ditemukan:"
    echo "$COMMON_BP"
    exit 1
fi

echo "✅ Found: $COMMON_BP"

echo
echo "----- Android.bp first 40 lines -----"

sed -n '1,40p' "$COMMON_BP"

echo
echo "----- Soong namespace references -----"

grep -nE \
    'soong_namespace|device/xiaomi/msm8953-common' \
    "$COMMON_BP" || true

# ============================================================
# Search Soong namespace references
# ============================================================

echo
echo "[7/10] Searching Soong namespace references..."

echo
echo "Searching for msm8953-common..."

grep -RIn \
    --exclude-dir=.git \
    --exclude-dir=out \
    "device/xiaomi/msm8953-common" \
    device/xiaomi \
    device/mainline \
    2>/dev/null | head -100 || true

echo
echo "Searching for soong_namespace..."

grep -RIn \
    --include='Android.bp' \
    --exclude-dir=.git \
    --exclude-dir=out \
    "soong_namespace" \
    device/xiaomi \
    device/mainline \
    2>/dev/null | head -100 || true

# ============================================================
# Manifest diagnostics
# ============================================================

echo
echo "[8/10] Checking manifest..."

echo
echo "----- Local manifests -----"

find .repo/local_manifests \
    -maxdepth 2 \
    -type f \
    -print

echo
echo "----- Tissot manifest content -----"

if [ -f ".repo/local_manifests/tissot.xml" ]; then
    sed -n '1,240p' .repo/local_manifests/tissot.xml
else
    echo "⚠️ tissot.xml tidak ditemukan dengan nama tersebut."
    echo
    echo "Manifest files:"
    find .repo/local_manifests -type f -maxdepth 2 -print
fi

# ============================================================
# Envsetup
# ============================================================

echo
echo "[9/10] Loading Android build environment..."

if [ ! -f "build/envsetup.sh" ]; then
    echo "❌ build/envsetup.sh tidak ditemukan."
    exit 1
fi

source build/envsetup.sh

echo "✅ build/envsetup.sh loaded."

# ============================================================
# Lunch
# ============================================================

echo
echo "Running lunch:"
echo "$LUNCH_TARGET"

lunch "$LUNCH_TARGET"

echo
echo "============================================================"
echo " Lunch result"
echo "============================================================"

echo "TARGET_PRODUCT=${TARGET_PRODUCT:-}"
echo "TARGET_BUILD_VARIANT=${TARGET_BUILD_VARIANT:-}"
echo "TARGET_BUILD_TYPE=${TARGET_BUILD_TYPE:-}"
echo "TARGET_DEVICE=${TARGET_DEVICE:-}"
echo "PLATFORM_VERSION=${PLATFORM_VERSION:-}"
echo "LINEAGE_VERSION=${LINEAGE_VERSION:-}"
echo "TARGET_ARCH=${TARGET_ARCH:-}"
echo "TARGET_CPU_VARIANT=${TARGET_CPU_VARIANT:-}"

# ============================================================
# Final validation
# ============================================================

echo
echo "[10/10] Final validation..."

FINAL_ERRORS=0

CHECK_FILES=(
    "build/envsetup.sh"
    "device/xiaomi/mi89xx-mainline"
    "device/xiaomi/msm8953-common/Android.bp"
    "kernel/mainline/msm8953-mainline"
    "vendor/xiaomi/tissot"
)

for item in "${CHECK_FILES[@]}"; do
    if [ -e "$item" ]; then
        echo "✅ $item"
    else
        echo "❌ $item"
        FINAL_ERRORS=1
    fi
done

echo

if [ "$FINAL_ERRORS" -ne 0 ]; then
    echo "❌ Final validation gagal."
    exit 1
fi

# ============================================================
# SUCCESS
# ============================================================

echo
echo "============================================================"
echo " ✅ DIAGNOSTIC SUCCESS"
echo "============================================================"
echo
echo "Semua pengecekan dasar berhasil."
echo
echo "Build TIDAK dijalankan."
echo "Tidak menggunakan mka bacon."
echo "Tidak menggunakan make."
echo

discord_notify "✅ **Tissot LOS 23.2 Diagnostic SUCCESS**

Semua pengecekan source, dependency, Android.bp, envsetup, dan lunch berhasil.

Target:
\`${LUNCH_TARGET}\`

Build belum dijalankan."

echo "Discord notification sent."
echo
echo "Diagnostic selesai."
