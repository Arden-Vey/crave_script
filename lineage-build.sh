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
