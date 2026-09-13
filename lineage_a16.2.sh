#!/bin/bash

rm -rf .repo/local_manifests/

# Repo init ROM
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --depth=1
echo "=================="
echo "Repo init success"
echo "=================="

# Local manifests
git clone -b main https://github.com/JBHPocong/lineage-tissot-manifest.git .repo/local_manifests
echo "============================"
echo "Local manifest clone success"
echo "============================"

# Build Sync
/opt/crave/resync.sh
echo "============="
echo "Sync success"
echo "============="

# Fetch Build Soong
cd build/soong
git fetch origin
git reset --hard FETCH_HEAD
cd ../..

# Export
export BUILD_USERNAME=Arden-Vey
export BUILD_HOSTNAME=crave
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
echo "======= Export Done ======"

# Set up build environment
source build/envsetup.sh
echo "=========================="
echo "Build environment ready"
echo "=========================="

# Lunch
lunch lineage_tissot_mainline-trunk_staging-userdebug

# Build
mka bacon

# Copy imgs to a separate folder for easy download
mkdir -p imgs_output

for img in boot.img system.img vendor.img; do
    if [ -f "out/target/product/tissot_mainline/$img" ]; then
        cp "out/target/product/tissot_mainline/$img" imgs_output/
        echo "Copied: $img"
    else
        echo "Not found: $img — skipped"
    fi
done

echo "=========================="
echo "Build finished"
echo "Images copied to imgs_output"
echo "=========================="
