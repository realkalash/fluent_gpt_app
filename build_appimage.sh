#!/bin/bash

# Build the Flutter app for Linux
flutter build linux

# Copy external files. Example of windows build
cp -r external_files/* build/linux/x64/release/bundle/


# Create temporary AppDir structure
mkdir -p linux-temp-installer/AppDir/usr/bin
cp -r build/linux/x64/release/bundle/* linux-temp-installer/AppDir/usr/bin/

# Download AppImageTool if not already downloaded
if [ ! -f linux-installer/appimagetool-x86_64.AppImage ]; then
    mkdir -p linux-installer
    wget -O linux-installer/appimagetool-x86_64.AppImage https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x linux-installer/appimagetool-x86_64.AppImage
fi

# Create AppRun script
cat > linux-temp-installer/AppDir/AppRun << 'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "${0}")")"
exec "${HERE}/usr/bin/FluentGPT"
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

# Zip the contents of the build/linux/x64/release/bundle folder
zip -r installers/fluent-gpt-linux.zip build/linux/x64/release/bundle

# Clean up temporary directory
rm -rf linux-temp-installer
echo "AppImage and zip file created successfully and moved to installers directory."