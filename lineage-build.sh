#!/bin/bash
set -e

# ============================================================
# CLEANUP
# ============================================================
rm -rf .repo/local_manifests/

# ============================================================
# REPO INIT
# ============================================================
repo init -u https://github.com/LineageOS/android.git \
    -b lineage-23.2 \
    --git-lfs \
    --depth=1

echo "=================="
echo "Repo init success"
echo "=================="

# ============================================================
# LOCAL MANIFESTS
# ============================================================
git clone -b generic \
    https://github.com/JBHPocong/lineage-tissot-manifest.git \
    .repo/local_manifests

echo "============================"
echo "Local manifest clone success"
echo "============================"

# ============================================================
# SYNC
# ============================================================
/opt/crave/resync.sh

echo "============="
echo "Sync success"
echo "============="

# ============================================================
# EXPORT ENV
# ============================================================
export BUILD_USERNAME=Arden-Vey
export BUILD_HOSTNAME=crave
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true

export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C

echo "======= Export Done ======"

# ============================================================
# BUILD ENV
# ============================================================
source build/envsetup.sh

echo "=========================="
echo "Build environment ready"
echo "=========================="

# ============================================================
# SHOW AVAILABLE GENERIC TARGETS
# ============================================================
echo "======================================"
echo "Available Generic Mainline targets:"
echo "======================================"

lunch --help >/dev/null 2>&1 || true

grep -R \
    "COMMON_LUNCH_CHOICES" \
    device/mainline/generic \
    device/mainline/common \
    2>/dev/null || true

echo "======================================"

# ============================================================
# LUNCH
# ============================================================
# Generic ARM64 / GSI
#
# Ubah target ini kalau hasil pengecekan di atas menunjukkan
# nama lunch yang berbeda.
#
lunch lineage_gsi_arm64-userdebug

echo "=================="
echo "Lunch success"
echo "=================="

# ============================================================
# FIX libjxl / libhwy MISSING VARIANT
# ============================================================

if [ -f external/libjxl/Android.bp ]; then
    echo ">>> Patching external/libjxl/Android.bp ..."

    sed -i 's/sdk_version: "current",//g' \
        external/libjxl/Android.bp

    grep -q 'sdk_version' external/libjxl/Android.bp || \
        sed -i \
        's/name: "libjxl",/name: "libjxl",\n    sdk_version: "none",/' \
        external/libjxl/Android.bp
fi

if [ -f external/highway/Android.bp ]; then
    echo ">>> Patching external/highway/Android.bp ..."

    grep -q 'sdk_version' external/highway/Android.bp || \
        sed -i \
        's/name: "libhwy",/name: "libhwy",\n    sdk_version: "none",/' \
        external/highway/Android.bp
fi

# ============================================================
# BUILD
# ============================================================
mka bacon

# ============================================================
# OUTPUT
# ============================================================
mkdir -p imgs_output

# Generic GSI biasanya output di target product sesuai lunch.
OUT_DIR="out/target/product/$(get_build_var TARGET_PRODUCT)"

echo "======================================"
echo "TARGET PRODUCT: $(get_build_var TARGET_PRODUCT)"
echo "OUT DIR: $OUT_DIR"
echo "======================================"

echo ">>> Isi direktori output:"
find "$OUT_DIR" -maxdepth 1 -type f \
    \( -name "*.img" -o -name "*.zip" \) \
    2>/dev/null || true

# ============================================================
# COPY IMAGES
# ============================================================
for img in \
    system.img \
    system_ext.img \
    product.img \
    vendor.img \
    odm.img \
    boot.img \
    vendor_boot.img \
    init_boot.img \
    dtbo.img \
    vbmeta.img
do
    if [ -f "$OUT_DIR/$img" ]; then
        cp "$OUT_DIR/$img" imgs_output/
        echo "Copied: $img"
    else
        echo "Not found: $img — skipped"
    fi
done

# ============================================================
# COPY ROM ZIP
# ============================================================
if ls "$OUT_DIR"/lineage-*.zip 1>/dev/null 2>&1; then
    cp "$OUT_DIR"/lineage-*.zip imgs_output/
    echo "Copied: ROM zip"
fi

# ============================================================
# COPY SUPER IMAGE
# ============================================================
if [ -f "$OUT_DIR/super.img" ]; then
    cp "$OUT_DIR/super.img" imgs_output/
    echo "Copied: super.img"
fi

# ============================================================
# DONE
# ============================================================
echo ""
echo "=========================================="
echo "        GENERIC MAINLINE BUILD DONE"
echo "=========================================="
echo "Output:"
ls -lh imgs_output/ 2>/dev/null || true
echo "=========================================="
