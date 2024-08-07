Name:           fluent_gpt
Version:        0.9.9
Release:        10%{?dist}
Summary:        Fluent GPT App

License:        MIT
Source0:        %{name}-%{version}.tar.gz

Requires:       libayatana-appindicator-gtk3, ayatana-appindicator3, keybinder3

%description
Fluent GPT App is an open-source, multi-platform desktop application that brings the power of GPT models to your fingertips.

%prep
%setup -q

%build
# No building necessary, just packaging the app

%install
install -d %{buildroot}/usr/share/applications
install -m 644 %{name}.desktop %{buildroot}/usr/share/applications/

install -d %{buildroot}/usr/local/bin
install -m 755 FluentGPT %{buildroot}/usr/local/bin/

install -d %{buildroot}/usr/local/share/fluent_gpt/data/flutter_assets/assets
install -m 644 data/flutter_assets/assets/app_icon.png %{buildroot}/usr/local/share/fluent_gpt/data/flutter_assets/assets/

%files
/usr/share/applications/%{name}.desktop
/usr/local/bin/FluentGPT
/usr/local/share/fluent_gpt/data/flutter_assets/assets/app_icon.png

%changelog
* Wed Aug 07 2024 Alex 1realkalash@gmail.com - 0.9.9-10
- Initial package
