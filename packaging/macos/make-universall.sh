#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
DIST_DIR="${PROJECT_ROOT}/dist"

ARM64_DIR="${DIST_DIR}/vfconf-macos-arm64"
X86_64_DIR="${DIST_DIR}/vfconf-macos-x86_64"
UNIVERSAL_DIR="${DIST_DIR}/vfconf-macos-universal2"

BINARIES=(
    vfconf
    vfconf-check
    vfconf-dump
    vfconf-fmt
)

log() {
    printf '[vfconf-universal] %s\n' "$*"
}

die() {
    printf '[vfconf-universal] error: %s\n' "$*" >&2
    exit 1
}

command -v lipo >/dev/null 2>&1 ||
    die "lipo is required (install Xcode Command Line Tools)"

mkdir -p "${UNIVERSAL_DIR}/bin"

for binary in "${BINARIES[@]}"; do
    arm="${ARM64_DIR}/bin/${binary}"
    intel="${X86_64_DIR}/bin/${binary}"
    output="${UNIVERSAL_DIR}/bin/${binary}"

    [[ -f "$arm" ]] ||
        die "missing ARM64 binary: $arm"

    [[ -f "$intel" ]] ||
        die "missing x86_64 binary: $intel"

    log "Creating Universal 2 binary: ${binary}"

    lipo \
        -create \
        "$arm" \
        "$intel" \
        -output "$output"

    chmod +x "$output"

    architectures="$(lipo -archs "$output")"

    [[ "$architectures" == *arm64* ]] ||
        die "${binary}: arm64 slice missing"

    [[ "$architectures" == *x86_64* ]] ||
        die "${binary}: x86_64 slice missing"

    file "$output"
    lipo -info "$output"
done

for directory in config languages themes schemas; do
    if [[ -d "${PROJECT_ROOT}/${directory}" ]]; then
        cp -R \
            "${PROJECT_ROOT}/${directory}" \
            "${UNIVERSAL_DIR}/${directory}"
    fi
done

for file in README.md LICENSE CHANGELOG.md VERSION; do
    if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
        cp \
            "${PROJECT_ROOT}/${file}" \
            "${UNIVERSAL_DIR}/${file}"
    fi
done

if [[ -d "${PROJECT_ROOT}/docs" ]]; then
    cp -R \
        "${PROJECT_ROOT}/docs" \
        "${UNIVERSAL_DIR}/docs"
fi

VERSION="unknown"

if [[ -s "${PROJECT_ROOT}/VERSION" ]]; then
    VERSION="$(tr -d '[:space:]' < "${PROJECT_ROOT}/VERSION")"
fi

cat > "${UNIVERSAL_DIR}/BUILD-INFO" <<EOF
project=VFConf
version=${VERSION}
platform=macOS
architecture=universal2
architectures=arm64,x86_64
EOF

ARCHIVE="${DIST_DIR}/vfconf-${VERSION}-macos-universal2.tar.gz"

rm -f "$ARCHIVE"

tar \
    -C "$DIST_DIR" \
    -czf "$ARCHIVE" \
    "$(basename "$UNIVERSAL_DIR")"

if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$ARCHIVE" > "${ARCHIVE}.sha256"
fi

echo
log "Universal 2 build successful"
printf '  output:  %s\n' "$UNIVERSAL_DIR"
printf '  archive: %s\n' "$ARCHIVE"

echo
log "Architectures:"
for binary in "${BINARIES[@]}"; do
    printf '  %-14s ' "$binary"
    lipo -archs "${UNIVERSAL_DIR}/bin/${binary}"
done
