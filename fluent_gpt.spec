# Disable automatic debuginfo package generation
%global debug_package %{nil}
# Disable automatic dependency generation - we'll bundle everything
%global __requires_exclude_from ^/usr/local/.*$

Name:           fluent_gpt
Version:        1.0.73
Release:        10%{?dist}
Summary:        Fluent GPT App

License:        MIT
Source0:        %{name}-%{version}.tar.gz

# Base system dependencies
Requires:       gtk3, libayatana-appindicator-gtk3, ayatana-appindicator3, keybinder3

%description
Fluent GPT App is an open-source, multi-platform desktop application that brings the power of GPT models to your fingertips.

%prep
%setup -q

%build
# Create wrapper script
cat > FluentGPT-wrapper << 'EOF'
#!/bin/bash
export LD_LIBRARY_PATH="/usr/local/lib/fluent_gpt:$LD_LIBRARY_PATH"
exec /usr/local/lib/fluent_gpt/FluentGPT "$@"
EOF

%install
# Install desktop file
install -d %{buildroot}/usr/share/applications
install -m 644 %{name}.desktop %{buildroot}/usr/share/applications/

# Install executable wrapper
install -d %{buildroot}/usr/local/bin
install -m 755 FluentGPT-wrapper %{buildroot}/usr/local/bin/FluentGPT

# Install real executable and all libraries
install -d %{buildroot}/usr/local/lib/fluent_gpt
install -m 755 FluentGPT %{buildroot}/usr/local/lib/fluent_gpt/

# Copy all necessary libraries
if [ -d "lib" ]; then
    cp -r lib/* %{buildroot}/usr/local/lib/fluent_gpt/
fi

# Install assets directory
install -d %{buildroot}/usr/local/share/fluent_gpt/data/flutter_assets
cp -r assets %{buildroot}/usr/local/share/fluent_gpt/data/flutter_assets/

# Copy data directory if it exists
if [ -d "data" ]; then
    cp -r data/* %{buildroot}/usr/local/share/fluent_gpt/data/
fi

%files
/usr/share/applications/%{name}.desktop
/usr/local/bin/FluentGPT
/usr/local/lib/fluent_gpt/
/usr/local/share/fluent_gpt/

%changelog
* Wed Aug 07 2024 Alex 1realkalash@gmail.com - 1.0.73-10
- Initial package