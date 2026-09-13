#!/bin/bash

rm -rf .repo/local_manifests/

# repo init rom
repo init -u https://github.com/crdroidandroid/android.git -b 16.0 --git-lfs --no-clone-bundle --depth=1
echo "=================="
echo "Repo init success"
echo "=================="

# Local manifests
git clone https://github.com/DarkKiller28/local_manifest_peridot.git .repo/local_manifests -b lineage-23.2 
echo "============================"
echo "Local manifest clone success"
echo "============================"

# Clone crDroid Settings
rm -rf packages/apps/crDroidSettings
rm -rf android/vendor/crDroidOTA
git clone https://github.com/DarkKiller28/android_packages_apps_crDroidSettings.git -b 16.0 packages/apps/crDroidSettings
git clone https://github.com/DarkKiller28/android_vendor_crDroidOTA.git -b 16.0 android/vendor/crdroidOTA
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
source build/envsetup.sh
echo "============="

# Build
brunch peridot

# Copy imgs to a separate folder for easy download
mkdir -p imgs_output
cp out/target/product/peridot/boot.img imgs_output/
cp out/target/product/peridot/init_boot.img imgs_output/
cp out/target/product/peridot/dtbo.img imgs_output/
cp out/target/product/peridot/recovery.img imgs_output/
cp out/target/product/peridot/vendor_boot.img imgs_output/
