#!/bin/bash
# ==============================================================
# Orthora iOS TIPA Builder
# ==============================================================
# Usage: ./build_tipa.sh [kgvn|kgtw|kgth|all]
#
# Prerequisites:
#   - Theos installed on macOS/iOS
#   - Xcode command line tools
#   - ldid (or similar for signing)
# ==============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
OUTPUT_DIR="$PROJECT_DIR/output"
BUILD_DIR="$PROJECT_DIR/build"
PATCHER_DIR="$PROJECT_DIR/patcher"

# Build the dylib tweak
echo "==> Building orthora.dylib..."
cd "$PROJECT_DIR/../orthora"
make clean 2>/dev/null || true
make package DEBUG=0
cd "$PROJECT_DIR"

# Locate the built dylib
DYLIB_SRC="$PROJECT_DIR/../orthora/.theos/obj/debug/orthora.dylib"
if [ ! -f "$DYLIB_SRC" ]; then
    DYLIB_SRC="$PROJECT_DIR/../orthora/.theos/obj/orthora.dylib"
fi

if [ ! -f "$DYLIB_SRC" ]; then
    echo "ERROR: orthora.dylib not found. Build first!"
    exit 1
fi
echo "   Found dylib: $DYLIB_SRC"

# Build the patcher app
echo "==> Building patcher TIPA..."
cd "$PATCHER_DIR/patchlq"
make clean 2>/dev/null || true
make package DEBUG=0
cd "$PROJECT_DIR"

# Locate the patcher
PATCHER_TIPA="$PATCHER_DIR/patchlq/.theos/_/Payload/patchlq.app"
if [ ! -d "$PATCHER_TIPA" ]; then
    echo "ERROR: Patcher not built correctly"
    exit 1
fi

# Create output structure
rm -rf "$BUILD_DIR" "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR/Payload/patchlq.app/dylibs"
mkdir -p "$BUILD_DIR/Payload/patchlq.app/Frameworks"

# Copy patcher app
echo "==> Assembling TIPA..."
cp -R "$PATCHER_TIPA"/* "$BUILD_DIR/Payload/patchlq.app/"

# Copy insert_dylib and unzip tools
cp "$PROJECT_DIR/tools/insert_dylib" "$BUILD_DIR/Payload/patchlq.app/"
cp "$PROJECT_DIR/tools/unzip" "$BUILD_DIR/Payload/patchlq.app/"

# Create dylib zips for each region
echo "==> Creating dylib packages..."
cp "$DYLIB_SRC" "$BUILD_DIR/Payload/patchlq.app/Frameworks/AWSS3.framework/AWSS3"

# Creating zip files (unzipped - the patcher will use raw files)
# The original patcher unzips, so we need to create .zip files
cd "$BUILD_DIR/Payload/patchlq.app"
mkdir -p "dylibs"

# For each region, create a zip containing AWSS3
for region in kgvn kgtw kgth; do
    mkdir -p "_temp/AWSS3.framework"
    cp "Frameworks/AWSS3.framework/AWSS3" "_temp/AWSS3.framework/"
    cd "_temp"
    zip -r "../dylibs/$region.zip" "AWSS3.framework/"
    cd ..
    rm -rf "_temp"
done

# Remove the raw framework
rm -rf "Frameworks"

# Sign with TrollStore-compatible signature
echo "==> Signing..."
if command -v ldid &> /dev/null; then
    ldid -S "$BUILD_DIR/Payload/patchlq.app/patchlq"
fi

# Create TIPA (rename from .ipa to .tipa)
cd "$BUILD_DIR"
zip -r "orthora.ipa" "Payload/"
mv "orthora.ipa" "orthora.tipa"

# Copy to output
mkdir -p "$OUTPUT_DIR"
cp "orthora.tipa" "$OUTPUT_DIR/"
cp "$DYLIB_SRC" "$OUTPUT_DIR/orthora.dylib"

echo ""
echo "========================================="
echo "  TIPA built successfully!"
echo "  Location: $OUTPUT_DIR/orthora.tipa"
echo "  Size: $(du -h "$OUTPUT_DIR/orthora.tipa" | cut -f1)"
echo "========================================="
echo ""
echo "Install via TrollStore:"
echo "  1. AirDrop orthora.tipa to your device"
echo "  2. Open in TrollStore"
echo "  3. Tap 'Patch Hack to [region]'"
echo ""
