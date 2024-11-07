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
  RECIPE_RELEASE=${RECIPE_RELEASE:-1}
  PKG_LICENSE=$(yq eval '.metadata.license // "UNKNOWN"' "$RECIPE_FILE")
  PKG_DESCRIPTION=$(yq eval '.metadata.description // "No description available."' "$RECIPE_FILE")
  MAINTAINER=$(yq eval '.metadata.maintainer // "Unknown Maintainer"' "$RECIPE_FILE")
  SOURCE_URL="https://github.com/ilya-zlobintsev/LACT/archive/refs/tags/v${RECIPE_VERSION}.tar.gz"

  # Collect Fedora-specific dependencies safely
  PKG_DEPENDS=$(yq eval 'select(.depends != null) | (.depends | with_entries(select(.key | test("fedora")))) | .[] // [] | join(", ")' "$RECIPE_FILE" | tr -s ' ' | tr '\n' ' ')
  PKG_BUILD_DEPENDS=$(yq eval 'select(.build_depends != null) | (.build_depends | with_entries(select(.key | test("fedora")))) | .[] // [] | join(", ")' "$RECIPE_FILE" | tr -s ' ' | tr '\n' ' ')

  # Ensure dependencies from the 'all' key are included only if they exist
  PKG_DEPENDS="$PKG_DEPENDS $(yq eval 'select(.depends.all != null) | .depends.all | join(", ")' "$RECIPE_FILE" | tr -s ' ' | tr '\n' ' ')"
  PKG_BUILD_DEPENDS="$PKG_BUILD_DEPENDS $(yq eval 'select(.build_depends.all != null) | .build_depends.all | join(", ")' "$RECIPE_FILE" | tr -s ' ' | tr '\n' ' ')"

  # Trim any leading or trailing whitespace
  PKG_DEPENDS=$(echo "$PKG_DEPENDS" | xargs)
  PKG_BUILD_DEPENDS=$(echo "$PKG_BUILD_DEPENDS" | xargs)

  # Generate the spec file
  SPEC_FILE="${SPEC_OUTPUT_DIR}/${RECIPE_NAME}.spec"
  cat <<EOF >"$SPEC_FILE"
Name:           $RECIPE_NAME
Version:        $RECIPE_VERSION
Release:        $RECIPE_RELEASE%{?dist}
Summary:        $PKG_DESCRIPTION
License:        $PKG_LICENSE
URL:            https://github.com/ilya-zlobintsev/LACT
Source0:        $SOURCE_URL

BuildArch:      x86_64
BuildRequires:  $PKG_BUILD_DEPENDS
Requires:       $PKG_DEPENDS

%description
$PKG_DESCRIPTION

%prep
%setup -q

%build
make %{?_smp_mflags}

%install
make install DESTDIR=%{buildroot}

%files
%license LICENSE
%doc README.md
/usr/bin/$RECIPE_NAME

%changelog
* $(date +"%a %b %d %Y") $MAINTAINER - $RECIPE_VERSION-$RECIPE_RELEASE
- Initial build
EOF

  echo "Spec file created at $SPEC_FILE"
done
