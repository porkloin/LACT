Name:           lact
Version:        0.6.0
Release:        1
Summary:        AMDGPU control utility
License:        MIT
URL:            https://github.com/ilya-zlobintsev/LACT
Source0:        https://github.com/ilya-zlobintsev/LACT/archive/refs/tags/v0.6.0.tar.gz

BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
ExclusiveArch:  x86_64
BuildRequires:  gtk4-devel gcc libdrm-devel blueprint-compiler dbus curl make clang git
Requires:       gtk4 libdrm hwdata

%description
AMDGPU control utility

%prep
%setup -q

%build
make %{?_smp_mflags}

%install
rm -rf %{buildroot}
make install DESTDIR=%{buildroot}

%files
%defattr(-,root,root,-)
%license LICENSE
%doc README.md
/usr/bin/lact

%changelog
* Sat Nov 09 2024 - ilya-zlobintsev - v0.6.0 - v0.6.0
- Autogenerated from CI, please see  for detailed changelog.

