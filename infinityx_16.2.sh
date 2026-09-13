#!/bin/bash

rm -rf .repo/local_manifests/

# repo init rom
repo init --no-repo-verify --git-lfs -u https://github.com/ProjectInfinity-X/manifest -b 16 -g default,-mips,-darwin,-notdefault --depth=1
echo "=================="
echo "Repo init success"
echo "=================="

# Local manifests
git clone https://github.com/DarkKiller28/local_manifest_peridot.git .repo/local_manifests -b infinityx-16.2
echo "============================"
echo "Local manifest clone success"
echo "============================"

# Build Sync
/opt/crave/resync.sh 
echo "============="
echo "Sync success"
echo "============="

# Export
export BUILD_USERNAME=DarkKiller 
export BUILD_HOSTNAME=crave
export BUILD_BROKEN_MISSING_REQUIRED_MODULES=true
echo "======= Export Done ======"

# Set up build environment
. build/envsetup.sh
echo "============="

# Lunch
lunch infinity_peridot-userdebug

# Build
mka bacon

# Copy imgs to a separate folder for easy download
mkdir -p imgs_output
cp out/target/product/peridot/boot.img imgs_output/
cp out/target/product/peridot/init_boot.img imgs_output/
cp out/target/product/peridot/dtbo.img imgs_output/
cp out/target/product/peridot/recovery.img imgs_output/
cp out/target/product/peridot/vendor_boot.img imgs_output/
