#!/bin/bash
set -e  # opsional: stop kalau ada error fatal, tapi hati-hati dengan mka

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
git clone -b main \
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

# Tambahan penting: paksa pakai semua core & hindari OOM
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
# LUNCH
# ============================================================
lunch lineage_tissot_mainline-trunk_staging-userdebug

echo "=================="
echo "Lunch success"
echo "=================="

# ============================================================
# FIX libjxl / libhwy missing variant
# ============================================================
# Cek apakah file ada, lalu patch Android.bp libjxl
if [ -f external/libjxl/Android.bp ]; then
    echo ">>> Patching external/libjxl/Android.bp ..."
    # Hapus dependensi sdk variant yang bermasalah
    sed -i 's/sdk_version: "current",//g' external/libjxl/Android.bp
    # Alternatif: paksa sdk_version none
    grep -q 'sdk_version' external/libjxl/Android.bp || \
        sed -i 's/name: "libjxl",/name: "libjxl",\n    sdk_version: "none",/' external/libjxl/Android.bp
fi

if [ -f external/highway/Android.bp ]; then
    echo ">>> Patching external/highway/Android.bp ..."
    # Pastikan libhwy punya sdk_version yang cocok
    grep -q 'sdk_version' external/highway/Android.bp || \
        sed -i 's/name: "libhwy",/name: "libhwy",\n    sdk_version: "none",/' external/highway/Android.bp
fi

# ============================================================
# BUILD
# ============================================================
mka bacon

# ============================================================
# COPY IMAGES (lebih fleksibel)
# ============================================================
mkdir -p imgs_output
OUT_DIR="out/target/product/tissot_mainline"

echo ">>> Isi direktori output:"
find "$OUT_DIR" -maxdepth 1 -type f \( -name "*.img" -o -name "*.zip" \) 2>/dev/null || true

# Copy semua image yang ada
for img in boot.img vendor_boot.img system.img system_ext.img product.img vendor.img dtbo.img vbmeta.img; do
    if [ -f "$OUT_DIR/$img" ]; then
        cp "$OUT_DIR/$img" imgs_output/
        echo "Copied: $img"
    else
        echo "Not found: $img — skipped"
    fi
done

# Copy zip ROM kalau ada
if ls "$OUT_DIR"/lineage-*.zip 1> /dev/null 2>&1; then
    cp "$OUT_DIR"/lineage-*.zip imgs_output/
    echo "Copied: ROM zip"
fi

echo "=========================="
echo "Build finished"
echo "Images copied to imgs_output"
echo "=========================="
