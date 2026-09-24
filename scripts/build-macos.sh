#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DIST_DIR="${PROJECT_ROOT}/dist"
VERSION_FILE="${PROJECT_ROOT}/VERSION"

log()  { printf '[vfconf-macos] %s\n' "$*"; }
warn() { printf '[vfconf-macos] warning: %s\n' "$*" >&2; }
die()  { printf '[vfconf-macos] error: %s\n' "$*" >&2; exit 1; }

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ------------------------------------------------------------
# Version
# ------------------------------------------------------------

project_version() {
    local version=""

    if [[ -s "$VERSION_FILE" ]]; then
        version="$(tr -d '[:space:]' < "$VERSION_FILE")"
    fi

    if [[ -z "$version" && -f "${PROJECT_ROOT}/dune-project" ]]; then
        version="$(
            awk '
                /^\(version[[:space:]]+/ {
                    value=$2
                    gsub(/[()]/, "", value)
                    print value
                    exit
                }
            ' "${PROJECT_ROOT}/dune-project"
        )"
    fi

    printf '%s\n' "$version"
}

# ------------------------------------------------------------
# Platform
# ------------------------------------------------------------

check_host() {
    [[ "$(uname -s)" == "Darwin" ]] ||
        die "this builder must run on macOS"
}

detect_architecture() {
    case "$(uname -m)" in
        arm64|aarch64)
            printf 'arm64\n'
            ;;

        x86_64|amd64)
            printf 'x86_64\n'
            ;;

        *)
            uname -m
            ;;
    esac
}

# ------------------------------------------------------------
# Tools
# ------------------------------------------------------------

check_tools() {
    local tools=(
        dune
        ocamlc
        ocamllex
        menhir
        pkgbuild
        tar
    )

    for tool in "${tools[@]}"; do
        command_exists "$tool" ||
            die "required command not found: $tool"
    done

    log "OCaml: $(ocamlc -version)"
    log "Dune:  $(dune --version)"

    if command_exists ocamlopt; then
        log "Native compiler: available"
    else
        warn "ocamlopt unavailable"
    fi
}

# ------------------------------------------------------------
# Build
# ------------------------------------------------------------

build_project() {
    log "Cleaning"
    dune clean

    log "Building release"
    dune build --profile release

    log "Compilation completed"
}

copy_executable() {
    local source="$1"
    local destination="$2"

    [[ -f "$source" ]] ||
        die "missing executable: $source"

    install -m 0755 "$source" "$destination"
}

copy_binaries() {
    local destination="$1"

    mkdir -p "$destination"

    copy_executable \
        "${PROJECT_ROOT}/_build/default/bin/main.exe" \
        "${destination}/vfconf"

    copy_executable \
        "${PROJECT_ROOT}/_build/default/bin/check.exe" \
        "${destination}/vfconf-check"

    copy_executable \
        "${PROJECT_ROOT}/_build/default/bin/dump.exe" \
        "${destination}/vfconf-dump"

    copy_executable \
        "${PROJECT_ROOT}/_build/default/bin/fmt.exe" \
        "${destination}/vfconf-fmt"
}

copy_data() {
    local destination="$1"

    mkdir -p "$destination"

    for directory in \
        config \
        themes \
        schemas \
        examples
    do
        if [[ -d "${PROJECT_ROOT}/${directory}" ]]; then
            cp -R \
                "${PROJECT_ROOT}/${directory}" \
                "$destination/"
        fi
    done
}

# ------------------------------------------------------------
# Portable archive
# ------------------------------------------------------------

create_archive() {
    local version="$1"
    local architecture="$2"

    local name="vfconf-${version}-macos-${architecture}"
    local root="${DIST_DIR}/${name}"

    log "Creating portable archive"

    rm -rf "$root"

    mkdir -p \
        "${root}/bin" \
        "${root}/share/vfconf"

    copy_binaries "${root}/bin"
    copy_data "${root}/share/vfconf"

    for file in \
        README.md \
        LICENSE \
        CHANGELOG.md \
        VERSION
    do
        if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
            cp "${PROJECT_ROOT}/${file}" "$root/"
        fi
    done

    (
        cd "$DIST_DIR"
        tar -czf "${name}.tar.gz" "$name"
    )

    log "Created: dist/${name}.tar.gz"
}

# ------------------------------------------------------------
# macOS .pkg
# ------------------------------------------------------------

create_pkg() {
    local version="$1"
    local architecture="$2"

    local package_root="${DIST_DIR}/.pkg-root"
    local package_name="vfconf-${version}-macos-${architecture}.pkg"
    local package_path="${DIST_DIR}/${package_name}"

    log "Preparing macOS package"

    rm -rf "$package_root"

    mkdir -p \
        "${package_root}/usr/local/bin" \
        "${package_root}/usr/local/share/vfconf"

    copy_binaries \
        "${package_root}/usr/local/bin"

    copy_data \
        "${package_root}/usr/local/share/vfconf"

    log "Creating ${package_name}"

    rm -f "$package_path"

    pkgbuild \
        --root "$package_root" \
        --identifier "org.vitte.vfconf" \
        --version "$version" \
        --install-location "/" \
        "$package_path"

    rm -rf "$package_root"

    log "Created: dist/${package_name}"
}

# ------------------------------------------------------------
# Validation
# ------------------------------------------------------------

validate_binaries() {
    log "Validating executables"

    local executable

    for executable in \
        main.exe \
        check.exe \
        dump.exe \
        fmt.exe
    do
        local path="${PROJECT_ROOT}/_build/default/bin/${executable}"

        [[ -f "$path" ]] ||
            die "missing executable: $path"

        if command_exists file; then
            log "$(file "$path")"
        fi
    done
}

validate_pkg() {
    local version="$1"
    local architecture="$2"

    local package="${DIST_DIR}/vfconf-${version}-macos-${architecture}.pkg"

    [[ -f "$package" ]] ||
        die "package was not generated"

    if command_exists pkgutil; then
        log "Checking package"
        pkgutil --check-signature "$package" || true
    fi
}

# ------------------------------------------------------------
# Main
# ------------------------------------------------------------

main() {
    cd "$PROJECT_ROOT"

    check_host

    local version
    local architecture

    version="$(project_version)"
    architecture="$(detect_architecture)"

    [[ -n "$version" ]] ||
        die "unable to determine VFConf version"

    echo "============================================================"
    echo " VFConf macOS builder"
    echo "============================================================"
    echo " Version:      ${version}"
    echo " Architecture: ${architecture}"
    echo "============================================================"

    check_tools

    mkdir -p "$DIST_DIR"

    build_project
    validate_binaries

    create_archive \
        "$version" \
        "$architecture"

    create_pkg \
        "$version" \
        "$architecture"

    validate_pkg \
        "$version" \
        "$architecture"

    echo
    echo "============================================================"
    echo "[vfconf-macos] Build successful"
    echo "  version:      ${version}"
    echo "  architecture: ${architecture}"
    echo
    echo "  packages:"
    echo "    dist/vfconf-${version}-macos-${architecture}.pkg"
    echo "    dist/vfconf-${version}-macos-${architecture}.tar.gz"
    echo "============================================================"
}

main "$@"