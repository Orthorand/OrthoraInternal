# Orthora iOS TIPA Builder

## Project Structure

```
típa_builder/
├── patcher/patchlq/          # Patcher iOS app (Theos project)
│   ├── Makefile
│   ├── Info.plist
│   ├── entitlements.plist
│   ├── main.m
│   ├── AppDelegate.h/m
│   ├── ViewController.h/m    # UI with patch/unpatch buttons
│   └── Patcher.h/m           # Core patching logic
├── scripts/
│   ├── build_tipa.sh         # macOS build script
│   └── ondevice_build.sh     # iOS on-device build script
├── dylibs/                   # Generated dylib zips
├── tools/                    # insert_dylib + unzip
└── output/                   # Final .tipa file
```

## How the Patcher Works

1. User opens app, selects game region (KGVN/KGTW/KGTH)
2. App locates the game's .app bundle on device
3. Unzips `dylibs/{region}.zip` → extracts `AWSS3.framework/AWSS3` (our dylib)
4. Copies dylib to game's `Frameworks/AWSS3.framework/AWSS3`
5. Runs `insert_dylib` to add `@executable_path/Frameworks/AWSS3.framework/AWSS3` load command
6. Game loads our dylib on next launch

## Build Instructions

### Option 1: GitHub Actions (recommended from Windows)
```bash
# Push to GitHub, workflow builds automatically
git push origin main
# Download .tipa from Actions → Artifacts
```

### Option 2: On-device (jailbroken iOS)
```bash
ssh root@device
cd /path/to/ios/tipa_builder
bash scripts/ondevice_build.sh
# Output: output/orthora.tipa
```

## Installing

1. AirDrop the `.tipa` file to your device
2. Open in **TrollStore**
3. Tap **Install**
4. Open the "Orthora Patch" app
5. Select your game region → tap **Patch Hack**
6. Open the game - Orthora dylib loads automatically

## Uninstalling

1. Open "Orthora Patch" app
2. Tap **Unpatch Hack**
3. Or re-install the original game from App Store
