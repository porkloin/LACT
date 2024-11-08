#!/bin/bash

if ! command -v yq &>/dev/null; then
  echo "yq not found. Please install yq to proceed."
  exit 1
fi

RECIPES_DIR="pkg/recipes"
SPEC_OUTPUT_DIR="pkg/fedora-spec"
mkdir -p $SPEC_OUTPUT_DIR

for RECIPE_PATH in "$RECIPES_DIR"/*/; do
  RECIPE_NAME=$(basename "$RECIPE_PATH")
  RECIPE_FILE="${RECIPE_PATH}recipe.yml"

  if [ ! -f "$RECIPE_FILE" ]; then
    echo "No recipe.yml found in $RECIPE_PATH, skipping."
    continue
  fi

  RECIPE_VERSION=$(yq eval '.metadata.version // "0.0.1"' "$RECIPE_FILE")
  # Use GHA_RUN_NUMBER or default to 1
  RECIPE_RELEASE=${GHA_RUN_NUMBER:-1}
  PKG_LICENSE=$(yq eval '.metadata.license // "UNKNOWN"' "$RECIPE_FILE")
  PKG_DESCRIPTION=$(yq eval '.metadata.description // "No description available."' "$RECIPE_FILE")
  MAINTAINER=$(yq eval '.metadata.maintainer // "Unknown Maintainer"' "$RECIPE_FILE")
  SOURCE_URL="https://github.com/ilya-zlobintsev/LACT/archive/refs/tags/v${RECIPE_VERSION}.tar.gz"

  # Collect Fedora-specific dependencies safely
  PKG_DEPENDS=$(yq eval '.metadata.depends | with_entries(select(.key | contains("fedora"))) | .[] | join(" ")' "$RECIPE_FILE" | xargs)
  PKG_BUILD_DEPENDS=$(yq eval '.metadata.build_depends | with_entries(select(.key | contains("fedora"))) | .[] | join(" ")' "$RECIPE_FILE" | xargs)

  # Include dependencies from the 'all' key if they exist
  ALL_DEPENDS=$(yq eval 'select(.metadata.depends.all != null) | .metadata.depends.all | join(" ")' "$RECIPE_FILE" | xargs)
  ALL_BUILD_DEPENDS=$(yq eval 'select(.metadata.build_depends.all != null) | .metadata.build_depends.all | join(" ")' "$RECIPE_FILE" | xargs)

  PKG_DEPENDS="${PKG_DEPENDS} ${ALL_DEPENDS}"
  PKG_BUILD_DEPENDS="${PKG_BUILD_DEPENDS} ${ALL_BUILD_DEPENDS}"

  # Trim any leading or trailing whitespace
  PKG_DEPENDS=$(echo "$PKG_DEPENDS" | xargs)
  PKG_BUILD_DEPENDS=$(echo "$PKG_BUILD_DEPENDS" | xargs)

  # Generate the spec file
  SPEC_FILE="${SPEC_OUTPUT_DIR}/${RECIPE_NAME}.spec"
  cat <<EOF >"$SPEC_FILE"
Name:           $RECIPE_NAME
Version:        $RECIPE_VERSION
Release:        $RECIPE_RELEASE
Summary:        $PKG_DESCRIPTION
License:        $PKG_LICENSE
URL:            https://github.com/ilya-zlobintsev/LACT
Source0:        $SOURCE_URL

BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
ExclusiveArch:  x86_64
BuildRequires:  $PKG_BUILD_DEPENDS
Requires:       $PKG_DEPENDS

%description
$PKG_DESCRIPTION

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
/usr/bin/$RECIPE_NAME

%changelog
* $(date +"%a %b %d %Y") $MAINTAINER - $RECIPE_VERSION-$RECIPE_RELEASE
- Initial package version $RECIPE_VERSION
- Built with release $RECIPE_RELEASE
EOF

  echo "Spec file created at $SPEC_FILE"
  cat "$SPEC_FILE"
done
