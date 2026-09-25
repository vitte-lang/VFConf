#!/usr/bin/env bash
#
# VFConf — Vitte Foundation Configuration Language
# scripts/build-macos.sh
#
# Native macOS release builder.
#
# Supported architectures:
#   arm64
#   x86_64
#
# Produces:
#   dist/vfconf-VERSION-macos-ARCH/
#   dist/vfconf-VERSION-macos-ARCH.tar.gz
#   dist/VFConf-VERSION-macos-ARCH.pkg
#   SHA-256 checksums
#
# Builds for the CURRENT macOS architecture/toolchain.
# Universal 2 builds are handled separately by:
#   packaging/macos/make-universall.sh

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1
    pwd -P
)"

readonly PROJECT_ROOT="$(
    cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1
    pwd -P
)"

readonly DIST_DIR="${PROJECT_ROOT}/dist"
readonly VERSION_FILE="${PROJECT_ROOT}/VERSION"

PROFILE="release"
CLEAN=1
RUN_TESTS=0
RUN_DIAGNOSTICS=1
CREATE_PKG=1
CHECKSUMS=1
VERBOSE=0
JOBS=""
PKG_IDENTIFIER="org.vitte-foundation.vfconf"
INSTALL_PREFIX="/usr/local"

DUNE_ARGS=()

readonly VFCONF_EXECUTABLES=(
    "main:vfconf"
    "check:vfconf-check"
    "dump:vfconf-dump"
    "fmt:vfconf-fmt"
    "fmt_all:vfconf-fmt-all"
    "get:vfconf-get"
    "set_cmd:vfconf-set"
    "unset:vfconf-unset"
    "exists:vfconf-exists"
    "list_cmd:vfconf-list"
    "tree_cmd:vfconf-tree"
    "diff_cmd:vfconf-diff"
    "merge_cmd:vfconf-merge"
    "resolve_cmd:vfconf-resolve"
    "eval_cmd:vfconf-eval"
    "query_cmd:vfconf-query"
    "diagnostics:vfconf-diagnostics"
    "explain:vfconf-explain"
    "stats:vfconf-stats"
    "check_all:vfconf-check-all"
)

log() {
    printf '[vfconf-macos] %s\n' "$*"
}

warn() {
    printf '[vfconf-macos] warning: %s\n' "$*" >&2
}

die() {
    printf '[vfconf-macos] error: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    rm -rf -- \
        "${DIST_DIR}/.vfconf-pkg-root" \
        "${DIST_DIR}/.vfconf-pkg-scripts"
}

trap cleanup EXIT

usage() {
    cat <<'EOF'
Usage:
  scripts/build-macos.sh [options]

Build:
  --dev                 Use Dune dev profile.
  --release             Use Dune release profile (default).
  --profile NAME        Use custom Dune profile.
  --clean               Clean before build (default).
  --no-clean            Do not run dune clean.
  -j, --jobs N          Parallel Dune jobs.

Validation:
  --test                Run dune runtest.
  --diagnostics         Run diagnostics gate (default).
  --no-diagnostics      Skip diagnostics gate.

Packaging:
  --pkg                 Build macOS .pkg installer (default).
  --no-pkg              Do not build macOS .pkg installer.
  --no-checksum         Disable SHA-256 generation.
  --identifier ID       Override macOS package identifier.
  --prefix PATH         Installation prefix (default: /usr/local).

General:
  -v, --verbose         Verbose Dune output.
  -h, --help            Show this help.

Examples:
  scripts/build-macos.sh
  scripts/build-macos.sh --test
  scripts/build-macos.sh --release --test
  scripts/build-macos.sh --no-diagnostics
  scripts/build-macos.sh --no-pkg
  scripts/build-macos.sh -j 4

Installation:
  sudo installer -pkg dist/VFConf-VERSION-macos-ARCH.pkg -target /

Universal 2:
  packaging/macos/make-universall.sh
EOF
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_command() {
    command_exists "$1" ||
        die "required command not found: $1"
}

parse_arguments() {
    while (($# > 0)); do
        case "$1" in
            --dev)
                PROFILE="dev"
                ;;

            --release)
                PROFILE="release"
                ;;

            --profile)
                (($# >= 2)) ||
                    die "--profile requires an argument"

                PROFILE="$2"
                shift
                ;;

            --clean)
                CLEAN=1
                ;;

            --no-clean)
                CLEAN=0
                ;;

            --test)
                RUN_TESTS=1
                ;;

            --diagnostics)
                RUN_DIAGNOSTICS=1
                ;;

            --no-diagnostics)
                RUN_DIAGNOSTICS=0
                ;;

            --pkg)
                CREATE_PKG=1
                ;;

            --no-pkg)
                CREATE_PKG=0
                ;;

            --no-checksum)
                CHECKSUMS=0
                ;;

            --identifier)
                (($# >= 2)) ||
                    die "--identifier requires an argument"

                PKG_IDENTIFIER="$2"
                shift
                ;;

            --prefix)
                (($# >= 2)) ||
                    die "--prefix requires an argument"

                INSTALL_PREFIX="$2"
                shift
                ;;

            -j|--jobs)
                (($# >= 2)) ||
                    die "$1 requires an argument"

                [[ "$2" =~ ^[1-9][0-9]*$ ]] ||
                    die "invalid job count: $2"

                JOBS="$2"
                shift
                ;;

            -v|--verbose)
                VERBOSE=1
                ;;

            -h|--help)
                usage
                exit 0
                ;;

            --)
                shift
                break
                ;;

            *)
                die "unknown option: $1"
                ;;
        esac

        shift
    done
}

project_version() {
    local version=""

    if [[ -s "$VERSION_FILE" ]]; then
        version="$(
            tr -d '[:space:]' < "$VERSION_FILE"
        )"
    fi

    if [[ -z "$version" &&
          -f "${PROJECT_ROOT}/dune-project" ]]; then
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

check_host() {
    [[ "$(uname -s)" == "Darwin" ]] ||
        die "this builder must run on macOS"
}

check_project() {
    [[ -f "${PROJECT_ROOT}/dune-project" ]] ||
        die "dune-project not found"

    [[ -f "${PROJECT_ROOT}/lib/dune" ]] ||
        die "lib/dune not found"

    [[ -f "${PROJECT_ROOT}/bin/dune" ]] ||
        die "bin/dune not found"
}

check_tools() {
    local tools=(
        dune
        ocamlc
        ocamllex
        menhir
        tar
        install
        file
        shasum
    )

    local tool

    for tool in "${tools[@]}"; do
        require_command "$tool"
    done

    log "OCaml:  $(ocamlc -version)"
    log "Dune:   $(dune --version)"
    log "Menhir: $(menhir --version 2>/dev/null || printf 'available')"

    if command_exists ocamlopt; then
        log "Native compiler: available"
    else
        warn "ocamlopt unavailable; native build may fail"
    fi

    if (( CREATE_PKG )); then
        require_command pkgbuild
        require_command installer
    fi

    if (( RUN_DIAGNOSTICS )) &&
       [[ -f "${PROJECT_ROOT}/scripts/audit-diagnostics.py" ]]; then
        require_command python3
    fi
}

make_dune_args() {
    DUNE_ARGS=(
        "--profile=${PROFILE}"
    )

    if [[ -n "$JOBS" ]]; then
        DUNE_ARGS+=(
            "-j"
            "$JOBS"
        )
    fi

    if (( VERBOSE )); then
        DUNE_ARGS+=("--display=verbose")
    else
        DUNE_ARGS+=("--display=short")
    fi
}

build_project() {
    if (( CLEAN )); then
        log "Cleaning previous build"
        dune clean
    fi

    log "Building ${PROFILE}"

    local targets=()
    local entry
    local build_name

    for entry in "${VFCONF_EXECUTABLES[@]}"; do
        build_name="${entry%%:*}"
        targets+=("bin/${build_name}.exe")
    done

    dune build \
        "${DUNE_ARGS[@]}" \
        "${targets[@]}"

    log "Compilation completed"
}

run_tests() {
    (( RUN_TESTS )) || return 0

    log "Running tests"

    dune runtest "${DUNE_ARGS[@]}"

    log "Tests passed"
}

run_diagnostics() {
    (( RUN_DIAGNOSTICS )) || {
        warn "diagnostics gate skipped"
        return 0
    }

    log "Running diagnostics gate"

    if [[ -x "${PROJECT_ROOT}/scripts/check-diagnostics.sh" ]]; then
        "${PROJECT_ROOT}/scripts/check-diagnostics.sh"
        log "Diagnostics gate passed"
        return 0
    fi

    if [[ -f "${PROJECT_ROOT}/scripts/audit-diagnostics.py" ]]; then
        require_command python3

        warn "full diagnostics gate unavailable; running static audit"

        python3 \
            "${PROJECT_ROOT}/scripts/audit-diagnostics.py"

        log "Diagnostics audit passed"
        return 0
    fi

    die "diagnostics requested but diagnostics gate unavailable"
}

find_built_binary() {
    local name="$1"
    local candidate

    candidate="${PROJECT_ROOT}/_build/default/bin/${name}.exe"

    if [[ -f "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    candidate="$(
        find "${PROJECT_ROOT}/_build" \
            -type f \
            -path "*/bin/${name}.exe" \
            -print \
            -quit \
            2>/dev/null || true
    )"

    [[ -n "$candidate" ]] ||
        return 1

    printf '%s\n' "$candidate"
}

verify_macho_architecture() {
    local binary="$1"
    local expected_arch="$2"
    local description

    description="$(file "$binary")"

    case "$expected_arch" in
        arm64)
            grep -q 'arm64' <<<"$description" ||
                die "binary is not arm64: $binary"
            ;;

        x86_64)
            grep -q 'x86_64' <<<"$description" ||
                die "binary is not x86_64: $binary"
            ;;

        *)
            warn "architecture verification unavailable for ${expected_arch}"
            ;;
    esac
}

verify_binaries() {
    local architecture="$1"

    log "Verifying binaries"

    local entry
    local binary
    local public_name
    local path

    for entry in "${VFCONF_EXECUTABLES[@]}"; do
        binary="${entry%%:*}"
        public_name="${entry#*:}"

        path="$(find_built_binary "$binary")" ||
            die "compiled binary unavailable: ${binary}.exe (${public_name})"

        [[ -s "$path" ]] ||
            die "compiled binary is empty: $path"

        [[ -x "$path" ]] ||
            die "compiled binary is not executable: $path"

        verify_macho_architecture \
            "$path" \
            "$architecture"
    done

    log "All ${#VFCONF_EXECUTABLES[@]} binaries verified"
}

copy_executable() {
    local build_name="$1"
    local destination="$2"
    local source

    source="$(find_built_binary "$build_name")" ||
        die "executable unavailable: ${build_name}.exe"

    install \
        -m 0755 \
        "$source" \
        "$destination"
}

install_all_executables() {
    local destination="$1"
    local entry
    local build_name
    local public_name

    mkdir -p -- "$destination"

    for entry in "${VFCONF_EXECUTABLES[@]}"; do
        build_name="${entry%%:*}"
        public_name="${entry#*:}"

        copy_executable \
            "$build_name" \
            "${destination}/${public_name}"
    done
}

verify_installed_executables() {
    local directory="$1"
    local entry
    local public_name
    local path
    local count=0

    for entry in "${VFCONF_EXECUTABLES[@]}"; do
        public_name="${entry#*:}"
        path="${directory}/${public_name}"

        [[ -f "$path" ]] ||
            die "packaged executable missing: $path"

        [[ -s "$path" ]] ||
            die "packaged executable is empty: $path"

        [[ -x "$path" ]] ||
            die "packaged executable is not executable: $path"

        ((count += 1))
    done

    [[ "$count" -eq "${#VFCONF_EXECUTABLES[@]}" ]] ||
        die "packaged executable count mismatch"
}

copy_runtime_data() {
    local destination="$1"

    mkdir -p \
        "${destination}/share/vfconf"

    local directory

    for directory in \
        config \
        languages \
        themes \
        schemas \
        examples
    do
        if [[ -d "${PROJECT_ROOT}/${directory}" ]]; then
            cp -R \
                "${PROJECT_ROOT}/${directory}" \
                "${destination}/share/vfconf/"
        fi
    done
}

copy_documentation() {
    local destination="$1"

    mkdir -p -- "$destination"

    local file

    for file in \
        README.md \
        LICENSE \
        CHANGELOG.md \
        VERSION
    do
        if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
            cp -- \
                "${PROJECT_ROOT}/${file}" \
                "$destination/"
        fi
    done

    if [[ -d "${PROJECT_ROOT}/docs" ]]; then
        cp -R \
            "${PROJECT_ROOT}/docs" \
            "${destination}/docs"
    fi
}

write_build_info() {
    local destination="$1"
    local version="$2"
    local architecture="$3"

    local commit="unknown"
    local dirty="unknown"
    local macos_version="unknown"
    local macos_build="unknown"

    if command_exists sw_vers; then
        macos_version="$(
            sw_vers -productVersion 2>/dev/null ||
            printf 'unknown'
        )"

        macos_build="$(
            sw_vers -buildVersion 2>/dev/null ||
            printf 'unknown'
        )"
    fi

    if command_exists git &&
       git -C "$PROJECT_ROOT" rev-parse \
           --is-inside-work-tree >/dev/null 2>&1
    then
        commit="$(
            git -C "$PROJECT_ROOT" rev-parse HEAD
        )"

        if git -C "$PROJECT_ROOT" diff \
            --quiet \
            --ignore-submodules \
            HEAD -- 2>/dev/null
        then
            dirty="false"
        else
            dirty="true"
        fi
    fi

    cat > "${destination}/BUILD-INFO" <<EOF
project=vfconf
version=${version}
os=macos
macos_version=${macos_version}
macos_build=${macos_build}
architecture=${architecture}
profile=${PROFILE}
ocaml=$(ocamlc -version)
dune=$(dune --version)
git_commit=${commit}
git_dirty=${dirty}
executables=${#VFCONF_EXECUTABLES[@]}
EOF
}

sha256() {
    local file="$1"

    if command_exists shasum; then
        shasum -a 256 "$file" |
            awk '{print $1}'
        return 0
    fi

    return 1
}

checksum_file() {
    local file="$1"

    (( CHECKSUMS )) || return 0

    local hash

    hash="$(sha256 "$file")" || {
        warn "SHA-256 utility unavailable"
        return 0
    }

    (
        cd -- "$(dirname -- "$file")"

        printf '%s  %s\n' \
            "$hash" \
            "$(basename -- "$file")" \
            > "$(basename -- "$file").sha256"
    )
}

create_manifest() {
    local destination="$1"

    (( CHECKSUMS )) || return 0

    local manifest="${destination}/SHA256SUMS"
    local file
    local hash

    : > "$manifest"

    while IFS= read -r -d '' file; do
        hash="$(sha256 "$file")" || {
            warn "SHA-256 utility unavailable"
            rm -f -- "$manifest"
            return 0
        }

        printf '%s  %s\n' \
            "$hash" \
            "${file#"${destination}/"}" \
            >> "$manifest"

    done < <(
        find "${destination}/bin" \
            -type f \
            -print0 |
            sort -z
    )
}

create_portable_distribution() {
    local version="$1"
    local architecture="$2"

    local name="vfconf-${version}-macos-${architecture}"
    local destination="${DIST_DIR}/${name}"
    local archive="${DIST_DIR}/${name}.tar.gz"

    log "Creating portable distribution: ${name}"

    rm -rf -- "$destination"

    mkdir -p \
        "${destination}/bin" \
        "${destination}/share"

    install_all_executables \
        "${destination}/bin"

    verify_installed_executables \
        "${destination}/bin"

    copy_runtime_data "$destination"
    copy_documentation "$destination"

    write_build_info \
        "$destination" \
        "$version" \
        "$architecture"

    create_manifest "$destination"

    (
        cd -- "$DIST_DIR"

        rm -f -- "${name}.tar.gz"

        tar \
            -czf "${name}.tar.gz" \
            "$name"
    )

    [[ -s "$archive" ]] ||
        die "portable archive creation failed"

    checksum_file "$archive"

    log "Created: dist/${name}.tar.gz"
}

copy_pkg_runtime_data() {
    local root="$1"

    local destination="${root}${INSTALL_PREFIX}/share/vfconf"

    mkdir -p -- "$destination"

    local directory

    for directory in \
        config \
        languages \
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

copy_pkg_documentation() {
    local root="$1"

    local destination="${root}${INSTALL_PREFIX}/share/doc/vfconf"

    mkdir -p -- "$destination"

    local file

    for file in \
        README.md \
        LICENSE \
        CHANGELOG.md \
        VERSION
    do
        if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
            cp -- \
                "${PROJECT_ROOT}/${file}" \
                "$destination/"
        fi
    done

    if [[ -d "${PROJECT_ROOT}/docs" ]]; then
        cp -R \
            "${PROJECT_ROOT}/docs" \
            "${destination}/docs"
    fi
}

create_pkg_scripts() {
    local scripts="$1"

    mkdir -p -- "$scripts"

    cat > "${scripts}/postinstall" <<'EOF'
#!/bin/sh
set -eu

BIN_DIR="/usr/local/bin"

if [ -d "$BIN_DIR" ]; then
    /bin/chmod 755 "$BIN_DIR"/vfconf 2>/dev/null || true

    for file in "$BIN_DIR"/vfconf-*; do
        [ -e "$file" ] || continue
        /bin/chmod 755 "$file" 2>/dev/null || true
    done
fi

exit 0
EOF

    chmod 0755 "${scripts}/postinstall"
}

verify_pkg_payload() {
    local root="$1"
    local bin_dir="${root}${INSTALL_PREFIX}/bin"

    verify_installed_executables "$bin_dir"

    [[ -d "${root}${INSTALL_PREFIX}/share/vfconf" ]] ||
        die "package runtime data directory missing"

    log "Package payload verified"
}

create_pkg() {
    local version="$1"
    local architecture="$2"

    (( CREATE_PKG )) || {
        log "macOS package disabled"
        return 0
    }

    local root="${DIST_DIR}/.vfconf-pkg-root"
    local scripts="${DIST_DIR}/.vfconf-pkg-scripts"
    local output="${DIST_DIR}/VFConf-${version}-macos-${architecture}.pkg"
    local bin_dir="${root}${INSTALL_PREFIX}/bin"

    log "Creating macOS installer package"

    rm -rf -- \
        "$root" \
        "$scripts"

    rm -f -- "$output"

    mkdir -p \
        "$bin_dir" \
        "${root}${INSTALL_PREFIX}/share/vfconf" \
        "${root}${INSTALL_PREFIX}/share/doc/vfconf"

    install_all_executables \
        "$bin_dir"

    copy_pkg_runtime_data "$root"
    copy_pkg_documentation "$root"
    create_pkg_scripts "$scripts"

    verify_pkg_payload "$root"

    pkgbuild \
        --root "$root" \
        --scripts "$scripts" \
        --identifier "$PKG_IDENTIFIER" \
        --version "$version" \
        --install-location "/" \
        "$output"

    [[ -s "$output" ]] ||
        die "macOS package creation failed"

    checksum_file "$output"

    log "Created: ${output#"$PROJECT_ROOT"/}"
}

verify_portable_archive() {
    local version="$1"
    local architecture="$2"

    local name="vfconf-${version}-macos-${architecture}"
    local archive="${DIST_DIR}/${name}.tar.gz"

    [[ -s "$archive" ]] ||
        die "portable archive missing"

    local listing

    listing="$(tar -tzf "$archive")"

    local entry
    local public_name

    for entry in "${VFCONF_EXECUTABLES[@]}"; do
        public_name="${entry#*:}"

        grep -Fxq \
            "${name}/bin/${public_name}" \
            <<<"$listing" ||
            die "portable archive missing ${public_name}"
    done

    log "Portable archive verified"
}

verify_pkg_metadata() {
    local version="$1"
    local architecture="$2"

    (( CREATE_PKG )) || return 0

    local pkg="${DIST_DIR}/VFConf-${version}-macos-${architecture}.pkg"

    [[ -s "$pkg" ]] ||
        die "package missing after creation"

    if command_exists pkgutil; then
        log "Package metadata:"
        pkgutil --check-signature "$pkg" 2>/dev/null || true
    fi
}

show_artifacts() {
    local version="$1"
    local architecture="$2"

    echo
    echo "Artifacts:"
    echo

    local portable="${DIST_DIR}/vfconf-${version}-macos-${architecture}.tar.gz"
    local package="${DIST_DIR}/VFConf-${version}-macos-${architecture}.pkg"

    if [[ -f "$portable" ]]; then
        printf '  %s\n' "${portable#"$PROJECT_ROOT"/}"
    fi

    if [[ -f "${portable}.sha256" ]]; then
        printf '  %s\n' "${portable#"$PROJECT_ROOT"/}.sha256"
    fi

    if [[ -f "$package" ]]; then
        printf '  %s\n' "${package#"$PROJECT_ROOT"/}"
    fi

    if [[ -f "${package}.sha256" ]]; then
        printf '  %s\n' "${package#"$PROJECT_ROOT"/}.sha256"
    fi
}

main() {
    parse_arguments "$@"

    cd -- "$PROJECT_ROOT"

    check_host
    check_project

    local version
    local architecture

    version="$(project_version)"
    architecture="$(detect_architecture)"

    [[ -n "$version" ]] ||
        die "unable to determine VFConf version"

    case "$architecture" in
        arm64|x86_64)
            ;;
        *)
            warn "unusual macOS architecture: ${architecture}"
            ;;
    esac

    echo "============================================================"
    echo " VFConf macOS builder"
    echo "============================================================"
    echo " Version:      ${version}"
    echo " Architecture: ${architecture}"
    echo " Profile:      ${PROFILE}"
    echo " Prefix:       ${INSTALL_PREFIX}"
    echo " Commands:     ${#VFCONF_EXECUTABLES[@]}"
    echo " Package ID:   ${PKG_IDENTIFIER}"
    echo "============================================================"

    check_tools
    make_dune_args

    mkdir -p -- "$DIST_DIR"

    build_project
    verify_binaries "$architecture"

    run_tests
    run_diagnostics

    create_portable_distribution \
        "$version" \
        "$architecture"

    verify_portable_archive \
        "$version" \
        "$architecture"

    create_pkg \
        "$version" \
        "$architecture"

    verify_pkg_metadata \
        "$version" \
        "$architecture"

    echo
    echo "============================================================"
    echo " VFConf macOS build successful"
    echo "============================================================"
    printf '  version:      %s\n' "$version"
    printf '  architecture: %s\n' "$architecture"
    printf '  profile:      %s\n' "$PROFILE"
    printf '  executables:  %s\n' "${#VFCONF_EXECUTABLES[@]}"

    if (( RUN_TESTS )); then
        printf '  tests:        passed\n'
    else
        printf '  tests:        not requested\n'
    fi

    if (( RUN_DIAGNOSTICS )); then
        printf '  diagnostics:  passed\n'
    else
        printf '  diagnostics:  skipped\n'
    fi

    if (( CREATE_PKG )); then
        printf '  pkg:          created\n'
    else
        printf '  pkg:          disabled\n'
    fi

    echo "============================================================"

    show_artifacts \
        "$version" \
        "$architecture"
}

main "$@"