#!/usr/bin/env bash
# @covers AC-007
# @spec: specs/oep48-brand-package_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

ASSET_FONTS_DIR="$REPO_ROOT/assets/branding/fonts"

FONT_FILES=(
  Poppins-Regular.woff2
  Poppins-SemiBold.woff2
  Poppins-Bold.woff2
  Lato-Regular.woff2
  Lato-Bold.woff2
  Lato-Italic.woff2
  Lato-BoldItalic.woff2
  Lato-Black.woff2
  Lato-BlackItalic.woff2
)

IMAGE_FILES=(
  logo.png
  logo-white.png
  logo.svg
  logo-white.svg
  favicon.ico
)

usage() {
  cat <<'EOF'
Usage: sync-brand-package.sh [--all] [--brand <slug>]

Sync OEP-48 brand packages from canonical asset sources.

Options:
  --all            Sync all supported brand packages (default)
  --brand <slug>   Sync a single brand slug (mereka|biji-biji|skillourfuture)
  -h, --help       Show this help
EOF
}

brand_source_dir() {
  local brand="$1"
  case "$brand" in
    mereka)
      echo "$REPO_ROOT/assets/branding"
      ;;
    biji-biji)
      echo "$REPO_ROOT/assets/branding/tenants/biji-biji"
      ;;
    skillourfuture)
      echo "$REPO_ROOT/assets/branding/tenants/skillourfuture"
      ;;
    *)
      return 1
      ;;
  esac
}

brand_package_dir() {
  local brand="$1"
  echo "$REPO_ROOT/infrastructure/tutor/brand-${brand}"
}

validate_shared_fonts() {
  if [[ ! -d "$ASSET_FONTS_DIR" ]]; then
    echo "Source font directory not found: $ASSET_FONTS_DIR" >&2
    exit 1
  fi

  local font source
  for font in "${FONT_FILES[@]}"; do
    source="$ASSET_FONTS_DIR/$font"
    if [[ ! -f "$source" ]]; then
      echo "Missing shared font source: $source" >&2
      exit 1
    fi
  done
}

validate_brand_images() {
  local source_dir="$1"
  local image source
  for image in "${IMAGE_FILES[@]}"; do
    source="$source_dir/$image"
    if [[ ! -f "$source" ]]; then
      echo "Missing brand source image: $source" >&2
      exit 1
    fi
  done
}

sync_single_brand_package() {
  local brand="$1"
  local source_dir package_dir
  source_dir="$(brand_source_dir "$brand")"
  package_dir="$(brand_package_dir "$brand")"

  if [[ ! -d "$source_dir" ]]; then
    echo "Brand source directory not found for '$brand': $source_dir" >&2
    exit 1
  fi
  if [[ ! -d "$package_dir" ]]; then
    echo "Brand package directory not found for '$brand': $package_dir" >&2
    exit 1
  fi

  validate_brand_images "$source_dir"

  mkdir -p "$package_dir/fonts"
  rm -f "$package_dir/fonts/"*.woff2
  cp "$ASSET_FONTS_DIR"/*.woff2 "$package_dir/fonts/"

  local image
  for image in "${IMAGE_FILES[@]}"; do
    cp "$source_dir/$image" "$package_dir/$image"
  done

  # OEP-48 compatibility aliases:
  # - logo_white.* (underscore form)
  # - favicon.png (png alias for 256x256 favicon)
  cp "$source_dir/logo-white.png" "$package_dir/logo_white.png"
  cp "$source_dir/logo-white.svg" "$package_dir/logo_white.svg"
  if [[ -f "$source_dir/favicon-256x256.png" ]]; then
    cp "$source_dir/favicon-256x256.png" "$package_dir/favicon.png"
  else
    cp "$source_dir/favicon.ico" "$package_dir/favicon.png"
  fi

  # Trademark aliases: preserve dedicated files if they exist in source;
  # otherwise keep deterministic fallback to primary logo assets.
  if [[ -f "$source_dir/logo-trademark.png" ]]; then
    cp "$source_dir/logo-trademark.png" "$package_dir/logo-trademark.png"
  else
    cp "$source_dir/logo.png" "$package_dir/logo-trademark.png"
  fi
  if [[ -f "$source_dir/logo-trademark.svg" ]]; then
    cp "$source_dir/logo-trademark.svg" "$package_dir/logo-trademark.svg"
  else
    cp "$source_dir/logo.svg" "$package_dir/logo-trademark.svg"
  fi

  # Keep @edx/brand JS exports deterministic after every sync.
  cat > "$package_dir/logo.js" <<'EOF'
export { default as logo } from './logo.png';
export { default as logoWhite } from './logo_white.png';
export { default as logoTrademark } from './logo-trademark.png';
export { default as favicon } from './favicon.png';
export { default } from './logo.png';
EOF

  echo "  ✓ Synced brand package: brand-${brand} <- ${source_dir#"$REPO_ROOT/"}"
}

main() {
  local brands=()
  if [[ "$#" -eq 0 ]]; then
    brands=(mereka biji-biji skillourfuture)
  else
    while [[ "$#" -gt 0 ]]; do
      case "$1" in
        --all)
          brands=(mereka biji-biji skillourfuture)
          shift
          ;;
        --brand)
          if [[ "$#" -lt 2 ]]; then
            echo "Missing value for --brand" >&2
            usage
            exit 1
          fi
          brands=("$2")
          shift 2
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          echo "Unknown argument: $1" >&2
          usage
          exit 1
          ;;
      esac
    done
  fi

  validate_shared_fonts
  local brand
  for brand in "${brands[@]}"; do
    sync_single_brand_package "$brand"
  done
  echo "Synced OEP-48 brand package assets from canonical sources."
}

main "$@"
