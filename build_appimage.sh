#!/bin/bash

# Clean previous builds to ensure fresh binaries
echo "Cleaning previous builds..."
flutter clean

# Build the Flutter app for Linux
echo "Building Flutter app for Linux..."
flutter build linux

# Copy external files. Example of windows build
cp -r external_files/* build/linux/x64/release/bundle/

# Bundle system libraries into the Flutter bundle for zip distribution
# This ensures the zip file works on systems without these libraries installed
echo "Bundling system libraries into Flutter bundle for zip..."
mkdir -p build/linux/x64/release/bundle/lib

# Function to copy library and its dependencies (reuse from AppImage bundling)
copy_library_to_bundle() {
    local lib_path="$1"
    local target_dir="build/linux/x64/release/bundle/lib"
    
    if [ ! -f "$lib_path" ]; then
        return 1
    fi
    
    local lib_name=$(basename "$lib_path")
    
    # Skip if already copied
    if [ -f "$target_dir/$lib_name" ]; then
        return 0
    fi
    
    # Copy the library
    cp "$lib_path" "$target_dir/" 2>/dev/null || return 1
    
    # If it's a symlink, copy the real file too
    if [ -L "$lib_path" ]; then
        local real_lib=$(readlink -f "$lib_path")
        if [ -f "$real_lib" ] && [ "$real_lib" != "$lib_path" ]; then
            local real_lib_name=$(basename "$real_lib")
            if [ ! -f "$target_dir/$real_lib_name" ]; then
                cp "$real_lib" "$target_dir/" 2>/dev/null || true
            fi
        fi
    fi
    
    return 0
}

# Copy libkeybinder-3.0.so.0 into the bundle
KEYBINDER_LIB=$(find /usr/lib* /lib* -name "libkeybinder-3.0.so.0" 2>/dev/null | head -1)
if [ -z "$KEYBINDER_LIB" ]; then
    KEYBINDER_LIB=$(ldconfig -p 2>/dev/null | grep "libkeybinder-3.0.so.0" | awk '{print $4}' | head -1)
fi

if [ -n "$KEYBINDER_LIB" ] && [ -f "$KEYBINDER_LIB" ]; then
    echo "  Bundling keybinder library into bundle: $KEYBINDER_LIB"
    copy_library_to_bundle "$KEYBINDER_LIB"
    
    # Copy dependencies of keybinder using ldd
    if command -v ldd >/dev/null 2>&1; then
        ldd "$KEYBINDER_LIB" 2>/dev/null | grep -v "not found" | awk '{print $3}' | grep "^/" | while read -r dep; do
            if [ -f "$dep" ]; then
                dep_name=$(basename "$dep")
                # Skip standard system libraries that should be available everywhere
                if ! echo "$dep" | grep -qE "(libc\.|libm\.|libdl\.|libpthread\.|librt\.|libgcc_s\.|ld-linux)"; then
                    # Only copy if it's not already there
                    if [ ! -f "build/linux/x64/release/bundle/lib/$dep_name" ]; then
                        copy_library_to_bundle "$dep" || true
                    fi
                fi
            fi
        done
    fi
else
    echo "  Warning: libkeybinder-3.0.so.0 not found on system"
fi

# Create temporary AppDir structure
mkdir -p linux-temp-installer/AppDir/usr/bin
mkdir -p linux-temp-installer/AppDir/usr/lib
cp -r build/linux/x64/release/bundle/* linux-temp-installer/AppDir/usr/bin/

# Bundle system libraries (keybinder, GLib, etc.)
echo "Bundling system libraries..."

# Function to copy library and its dependencies
copy_library() {
    local lib_path="$1"
    local target_dir="$2"
    
    if [ ! -f "$lib_path" ]; then
        return 1
    fi
    
    local lib_name=$(basename "$lib_path")
    
    # Skip if already copied
    if [ -f "$target_dir/$lib_name" ]; then
        return 0
    fi
    
    # Copy the library
    cp "$lib_path" "$target_dir/" 2>/dev/null || return 1
    
    # If it's a symlink, copy the real file too
    if [ -L "$lib_path" ]; then
        local real_lib=$(readlink -f "$lib_path")
        if [ -f "$real_lib" ] && [ "$real_lib" != "$lib_path" ]; then
            local real_lib_name=$(basename "$real_lib")
            if [ ! -f "$target_dir/$real_lib_name" ]; then
                cp "$real_lib" "$target_dir/" 2>/dev/null || true
            fi
        fi
    fi
    
    return 0
}

# Copy libkeybinder-3.0.so.0
KEYBINDER_LIB=$(find /usr/lib* /lib* -name "libkeybinder-3.0.so.0" 2>/dev/null | head -1)
if [ -z "$KEYBINDER_LIB" ]; then
    KEYBINDER_LIB=$(ldconfig -p 2>/dev/null | grep "libkeybinder-3.0.so.0" | awk '{print $4}' | head -1)
fi

if [ -n "$KEYBINDER_LIB" ] && [ -f "$KEYBINDER_LIB" ]; then
    echo "  Bundling keybinder library: $KEYBINDER_LIB"
    copy_library "$KEYBINDER_LIB" "linux-temp-installer/AppDir/usr/lib"
    
    # Copy dependencies of keybinder using ldd
    if command -v ldd >/dev/null 2>&1; then
        ldd "$KEYBINDER_LIB" 2>/dev/null | grep -v "not found" | awk '{print $3}' | grep "^/" | while read -r dep; do
            if [ -f "$dep" ]; then
                dep_name=$(basename "$dep")
                # Skip standard system libraries that should be available everywhere
                if ! echo "$dep" | grep -qE "(libc\.|libm\.|libdl\.|libpthread\.|librt\.|libgcc_s\.|ld-linux)"; then
                    # Only copy if it's not already there
                    if [ ! -f "linux-temp-installer/AppDir/usr/lib/$dep_name" ]; then
                        copy_library "$dep" "linux-temp-installer/AppDir/usr/lib" || true
                    fi
                fi
            fi
        done
    fi
else
    echo "  Warning: libkeybinder-3.0.so.0 not found on system"
fi

# Download AppImageTool if not already downloaded
if [ ! -f linux-installer/appimagetool-x86_64.AppImage ]; then
    mkdir -p linux-installer
    wget -O linux-installer/appimagetool-x86_64.AppImage https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x linux-installer/appimagetool-x86_64.AppImage
fi

# Create AppRun script with LD_LIBRARY_PATH set to use bundled libraries
cat > linux-temp-installer/AppDir/AppRun << 'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${HERE}/usr/bin/lib:${LD_LIBRARY_PATH}"
exec "${HERE}/usr/bin/FluentGPT" "$@"
EOF
chmod +x linux-temp-installer/AppDir/AppRun

# Create desktop entry
cat > linux-temp-installer/AppDir/FluentGPT.desktop << 'EOF'
[Desktop Entry]
Name=FluentGPT
Exec=FluentGPT
Icon=fluent_gpt
Type=Application
Categories=Utility;
EOF

# Copy the app icon as fluent_gpt.png to AppDir root
cp assets/app_icon512.png linux-temp-installer/AppDir/fluent_gpt.png
# Also copy to hicolor icons directory for desktop integration
mkdir -p linux-temp-installer/AppDir/usr/share/icons/hicolor/512x512/apps/
cp assets/app_icon512.png linux-temp-installer/AppDir/usr/share/icons/hicolor/512x512/apps/fluent_gpt.png

# Create installers directory if it doesn't exist
mkdir -p installers

# Bundle everything into an AppImage
ARCH=x86_64 linux-installer/appimagetool-x86_64.AppImage linux-temp-installer/AppDir

# Rename the AppImage file
mv FluentGPT-x86_64.AppImage FluentGPT.appimage

# Move the AppImage to the installers directory
mv FluentGPT.appimage installers/

# Create a wrapper script for running from zip (sets LD_LIBRARY_PATH)
cat > build/linux/x64/release/bundle/run_fluent_gpt.sh << 'EOF'
#!/bin/bash
# Wrapper script to run FluentGPT from extracted zip
# Sets LD_LIBRARY_PATH to use bundled libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LD_LIBRARY_PATH="${SCRIPT_DIR}/lib:${LD_LIBRARY_PATH}"
exec "${SCRIPT_DIR}/FluentGPT" "$@"
EOF
chmod +x build/linux/x64/release/bundle/run_fluent_gpt.sh

# Zip the contents of the build/linux/x64/release/bundle folder
# Remove old zip file first to avoid including stale files from previous builds
rm -f installers/fluent-gpt-linux.zip
# Update file timestamps to current time before zipping so zip contains fresh dates
find build/linux/x64/release/bundle -type f -exec touch {} +
# Zip from within the bundle directory to avoid including the full path structure
# Store project root path before changing directory
PROJECT_ROOT="$(pwd)"
cd build/linux/x64/release/bundle
zip -r "${PROJECT_ROOT}/installers/fluent-gpt-linux.zip" .
cd "${PROJECT_ROOT}"

# Clean up temporary directory
rm -rf linux-temp-installer
echo "AppImage and zip file created successfully and moved to installers directory."