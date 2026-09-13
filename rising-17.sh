#!/bin/bash

rm -rf .repo/local_manifests/

# repo init rom
repo init -u https://github.com/RisingOS-Revived/android -b seventeen --git-lfs --depth=1
echo "=================="
echo "Repo init success"
echo "=================="

# Local manifests
git clone https://github.com/DarkKiller28/local_manifest_peridot.git .repo/local_manifests -b rising-17 
echo "============================"
echo "Local manifest clone success"
echo "============================"

# Build Sync
/opt/crave/resync.sh
echo "============="
echo "Sync success"
echo "============="

# Fetch Build Soong
cd build/soong && git remote add custom https://github.com/DarkKiller28/android_build_soong.git && git fetch custom && git reset --hard custom/seventeen && cd ../..

# Export
export BUILD_USERNAME=DarkKiller
export BUILD_HOSTNAME=crave
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
echo "======= Export Done ======"

# Set up build environment
source build/envsetup.sh
echo "============="

# Start Rising
riseup peridot userdebug

# Build
rise b

# Copy imgs to a separate folder for easy download
mkdir -p imgs_output
cp out/target/product/peridot/boot.img imgs_output/
cp out/target/product/peridot/init_boot.img imgs_output/
cp out/target/product/peridot/dtbo.img imgs_output/
cp out/target/product/peridot/recovery.img imgs_output/
cp out/target/product/peridot/vendor_boot.img imgs_output/
