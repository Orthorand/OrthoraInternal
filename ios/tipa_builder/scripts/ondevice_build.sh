#!/bin/bash
# ==============================================================
# On-device build script for Orthora TIPA
# Run directly on jailbroken iOS device via SSH/NewTerm
# ==============================================================
# Requirements:
#   - Jailbroken iOS device (arm64)
#   - Theos installed ($THEOS set)
#   - Build tools: make, clang, ldid, zip, plutil
# ==============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
ORTHORA_DIR="$PROJECT_DIR/../orthora"
OUTPUT_DIR="$PROJECT_DIR/output"

echo "========================================="
echo "  Orthora iOS - On-device TIPA Builder"
echo "========================================="

# 1. Build the inject dylib
echo ""
echo "[1/3] Building orthora.dylib..."
cd "$ORTHORA_DIR"
make clean 2>/dev/null || true
make package FINALPACKAGE=1

# Find the built dylib
DYLIB=$(find .theos -name "*.dylib" -type f | head -1)
if [ -z "$DYLIB" ]; then
    echo "ERROR: dylib not built!"
    exit 1
fi
echo "  -> Built: $DYLIB"

# 2. Prepare dylib zips
echo ""
echo "[2/3] Preparing dylib packages..."
rm -rf "$PROJECT_DIR/dylibs" "$PROJECT_DIR/tools"
mkdir -p "$PROJECT_DIR/dylibs" "$PROJECT_DIR/tools"

for region in kgvn kgtw kgth; do
    mkdir -p /tmp/orthora_zip/AWSS3.framework
    cp "$DYLIB" /tmp/orthora_zip/AWSS3.framework/AWSS3
    cd /tmp/orthora_zip
    zip -r "$PROJECT_DIR/dylibs/$region.zip" "AWSS3.framework/"
    cd /
    rm -rf /tmp/orthora_zip
    echo "  -> $region.zip created"
done

# Copy tools
cp /usr/bin/unzip "$PROJECT_DIR/tools/" 2>/dev/null || echo "  (using system unzip)"
# Build insert_dylib if not present
if [ ! -f "$PROJECT_DIR/tools/insert_dylib" ]; then
    echo "  -> Building insert_dylib..."
    cd /tmp
    git clone https://github.com/Tyilo/insert_dylib.git 2>/dev/null || true
    cd insert_dylib
    clang -O2 -arch arm64 insert_dylib.c -o insert_dylib -framework CoreFoundation
    cp insert_dylib "$PROJECT_DIR/tools/"
fi

# 3. Build patcher app
echo ""
echo "[3/3] Building patcher TIPA..."
cd "$PROJECT_DIR/patcher/patchlq"
make clean 2>/dev/null || true
make package FINALPACKAGE=1

# 4. Assemble final TIPA
echo ""
echo "Assembling final TIPA..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Find the built patcher .app
PATCHER_APP=$(find .theos -name "*.app" -type d | head -1)
if [ -z "$PATCHER_APP" ]; then
    echo "ERROR: Patcher app not built!"
    exit 1
fi

# Create Payload
PAYLOAD="$OUTPUT_DIR/Payload"
rm -rf "$PAYLOAD"
mkdir -p "$PAYLOAD"
cp -R "$PATCHER_APP" "$PAYLOAD/patchlq.app"

# Copy tools and dylibs into app
cp "$PROJECT_DIR/tools/insert_dylib" "$PAYLOAD/patchlq.app/"
cp "$PROJECT_DIR/tools/unzip" "$PAYLOAD/patchlq.app/" 2>/dev/null || cp /usr/bin/unzip "$PAYLOAD/patchlq.app/"
chmod +x "$PAYLOAD/patchlq.app/insert_dylib" "$PAYLOAD/patchlq.app/unzip"

mkdir -p "$PAYLOAD/patchlq.app/dylibs"
for region in kgvn kgtw kgth; do
    cp "$PROJECT_DIR/dylibs/$region.zip" "$PAYLOAD/patchlq.app/dylibs/"
done

# Sign with ldid
ldid -S "$PAYLOAD/patchlq.app/patchlq"

# Create TIPA
cd "$OUTPUT_DIR"
zip -r "orthora.tipa" "Payload/"
rm -rf "Payload"

echo ""
echo "========================================="
echo "  SUCCESS!"
echo "  TIPA: $OUTPUT_DIR/orthora.tipa"
echo "  Size: $(du -h "$OUTPUT_DIR/orthora.tipa" | cut -f1)"
echo "========================================="
echo ""
echo "Install:"
echo "  1. Copy orthora.tipa to device"
echo "  2. Open in TrollStore"
echo "  3. Tap 'Patch Hack' for your region"
echo "  4. Open the game - Orthora injects automatically"
echo ""
