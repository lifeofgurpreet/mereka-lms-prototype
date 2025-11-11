#!/usr/bin/env bash
# Clone/update key Open edX MFEs locally and wire in the shared Mereka theme assets.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV_ROOT="$REPO_ROOT/tutor_env/dev"
THEME_IMPORT="\$mereka-font-path: \"/fonts\";\n\n@import \"../../../../../ops/themes/mereka/scss/theme\";\n"
LOGO_HORIZONTAL="$REPO_ROOT/assets/branding/logo-horizontal.png"
LOGO_SQUARE="$REPO_ROOT/assets/branding/logo-square.png"
FAVICON_ICO="$REPO_ROOT/assets/branding/favicon.ico"
APPS=(
  frontend-app-learning
  frontend-app-account
  frontend-app-authn
  frontend-app-profile
  frontend-app-gradebook
  frontend-app-course-authoring
)

BRAND_FONT_SRC="$REPO_ROOT/assets/branding/fonts"

if [[ ! -d "$BRAND_FONT_SRC" ]]; then
  echo "Missing font source directory: $BRAND_FONT_SRC" >&2
  exit 1
fi

mkdir -p "$DEV_ROOT"

for app in "${APPS[@]}"; do
  target="$DEV_ROOT/$app"
  repo="https://github.com/openedx/$app.git"

  if [ -d "$target/.git" ]; then
    git -C "$target" fetch --quiet origin
    git -C "$target" checkout --quiet master
    git -C "$target" pull --quiet --ff-only origin master
  else
    git clone "$repo" "$target"
  fi

  mkdir -p "$target/public/fonts" "$target/public/images"
  cp "$BRAND_FONT_SRC"/*.woff2 "$target/public/fonts/"

  if [[ -f "$LOGO_HORIZONTAL" ]]; then
    cp "$LOGO_HORIZONTAL" "$target/public/images/logo-horizontal.png"
    cp "$LOGO_HORIZONTAL" "$target/public/logo.png"
  fi
  if [[ -f "$LOGO_SQUARE" ]]; then
    cp "$LOGO_SQUARE" "$target/public/images/logo-square.png"
    cp "$LOGO_SQUARE" "$target/public/logo-square.png"
    cp "$LOGO_SQUARE" "$target/public/favicon.png"
  fi
  if [[ -f "$FAVICON_ICO" ]]; then
    cp "$FAVICON_ICO" "$target/public/favicon.ico"
  fi

  mkdir -p "$target/src/styles"
  printf "%b" "$THEME_IMPORT" > "$target/src/styles/mereka.scss"

  index_file="$target/src/index.scss"
  import_line='@import "./styles/mereka.scss";'
  if [ -f "$index_file" ]; then
    if ! grep -Fxq "$import_line" "$index_file"; then
      tmp="$index_file.tmp"
      printf "%s\n\n" "$import_line" > "$tmp"
      cat "$index_file" >> "$tmp"
      mv "$tmp" "$index_file"
    fi
  else
    printf "%s\n\n" "$import_line" > "$index_file"
  fi
done

echo "✅ MFEs cloned/updated under tutor_env/dev. Run npm install inside each repo as needed."
