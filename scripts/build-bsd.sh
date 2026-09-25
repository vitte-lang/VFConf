#!/usr/bin/env bash
#
# VFConf — Vitte Foundation Configuration Language
# scripts/build-bsd.sh
#
# Native BSD release builder.
#
# Supported hosts:
#   FreeBSD
#   OpenBSD
#   NetBSD
#   DragonFly BSD
#
# Produces:
#   dist/vfconf-VERSION-BSD-ARCH/
#   dist/vfconf-VERSION-BSD-ARCH.tar.gz
#   SHA-256 checksums
#
# FreeBSD additionally supports pkg package generation.

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
CREATE_NATIVE_PACKAGE=1
CHECKSUMS=1
VERBOSE=0
JOBS=""

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
    printf '[vfconf-bsd] %s\n' "$*"
}

warn() {
    printf '[vfconf-bsd] warning: %s\n' "$*" >&2
}

die() {
    printf '[vfconf-bsd] error: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage:
  scripts/build-bsd.sh [options]

Build:
  --dev                 Dune dev profile.
  --release             Dune release profile (default).
  --profile NAME        Custom Dune profile.
  --clean               Clean first (default).
  --no-clean            Keep current _build.
  -j, --jobs N          Parallel Dune jobs.

Validation:
  --test                Run dune runtest.
  --diagnostics         Run diagnostics gate (default).
  --no-diagnostics      Skip diagnostics gate.

Packaging:
  --native-package      Build native package when supported.
  --no-native-package   Disable native package.
  --no-checksum         Disable SHA-256 generation.

General:
  -v, --verbose         Verbose Dune output.
  -h, --help            Show this help.

Examples:
  scripts/build-bsd.sh
  scripts/build-bsd.sh --test
  scripts/build-bsd.sh --no-diagnostics
  scripts/build-bsd.sh --release --test
  scripts/build-bsd.sh -j 4
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

            --native-package)
                CREATE_NATIVE_PACKAGE=1
                ;;

            --no-native-package)
                CREATE_NATIVE_PACKAGE=0
                ;;

            --no-checksum)
                CHECKSUMS=0
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

detect_bsd() {
    case "$(uname -s)" in
        FreeBSD)
            printf 'freebsd\n'
            ;;
        OpenBSD)
            printf 'openbsd\n'
            ;;
        NetBSD)
            printf 'netbsd\n'
            ;;
        DragonFly)
            printf 'dragonflybsd\n'
            ;;
        *)
            return 1
            ;;
    esac
}

detect_architecture() {
    case "$(uname -m)" in
        x86_64|amd64)
            printf 'amd64\n'
            ;;

        i386|i486|i586|i686)
            printf 'i386\n'
            ;;

        arm64|aarch64)
            printf 'arm64\n'
            ;;

        armv7*)
            printf 'armv7\n'
            ;;

        armv6*)
            printf 'armv6\n'
            ;;

        armv5*)
            printf 'armv5\n'
            ;;

        powerpc64le|ppc64le)
            printf 'powerpc64le\n'
            ;;

        powerpc64|ppc64)
            printf 'powerpc64\n'
            ;;

        powerpc|ppc)
            printf 'powerpc\n'
            ;;

        riscv64)
            printf 'riscv64\n'
            ;;

        sparc64)
            printf 'sparc64\n'
            ;;

        sparc)
            printf 'sparc\n'
            ;;

        mips64el)
            printf 'mips64el\n'
            ;;

        mips64)
            printf 'mips64\n'
            ;;

        mipsel)
            printf 'mipsel\n'
            ;;

        mips)
            printf 'mips\n'
            ;;

        *)
            uname -m
            ;;
    esac
}

check_host() {
    detect_bsd >/dev/null ||
        die "this builder must run on FreeBSD, OpenBSD, NetBSD or DragonFly BSD"
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

verify_binaries() {
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
    local bsd="$2"
    local architecture="$3"
    local version="$4"

    local commit="unknown"
    local dirty="unknown"

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
os=${bsd}
architecture=${architecture}
profile=${PROFILE}
ocaml=$(ocamlc -version)
dune=$(dune --version)
git_commit=${commit}
git_dirty=${dirty}
EOF
}

sha256() {
    local file="$1"

    if command_exists sha256; then
        sha256 -q "$file"
        return 0
    fi

    if command_exists sha256sum; then
        sha256sum "$file" |
            awk '{print $1}'
        return 0
    fi

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

    printf '%s  %s\n' \
        "$hash" \
        "$(basename -- "$file")" \
        > "${file}.sha256"
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
    local bsd="$1"
    local architecture="$2"
    local version="$3"

    local name="vfconf-${version}-${bsd}-${architecture}"
    local destination="${DIST_DIR}/${name}"
    local archive="${DIST_DIR}/${name}.tar.gz"

    log "Creating portable BSD distribution"
    log "Destination: ${destination}"

    rm -rf -- "$destination"

    mkdir -p \
        "${destination}/bin"

    install_all_executables \
        "${destination}/bin"

    copy_runtime_data "$destination"
    copy_documentation "$destination"

    write_build_info \
        "$destination" \
        "$bsd" \
        "$architecture" \
        "$version"

    create_manifest "$destination"

    (
        cd -- "$DIST_DIR"

        rm -f -- "${name}.tar.gz"

        tar \
            -czf "${name}.tar.gz" \
            "$name"
    )

    [[ -s "$archive" ]] ||
        die "archive creation failed"

    checksum_file "$archive"

    log "Created: dist/${name}.tar.gz"
}

create_freebsd_package() {
    local architecture="$1"
    local version="$2"

    (( CREATE_NATIVE_PACKAGE )) || {
        log "FreeBSD native package disabled"
        return 0
    }

    if ! command_exists pkg; then
        warn "FreeBSD pkg unavailable; skipping native package"
        return 0
    fi

    local root="${DIST_DIR}/.vfconf-freebsd-root"
    local manifest="${DIST_DIR}/.vfconf-freebsd-manifest"
    local output="${DIST_DIR}/packages"

    rm -rf -- \
        "$root" \
        "$output" \
        "$manifest"

    mkdir -p \
        "${root}/usr/local/bin" \
        "${root}/usr/local/share/vfconf" \
        "${root}/usr/local/share/doc/vfconf" \
        "$output"

    install_all_executables \
        "${root}/usr/local/bin"

    local directory

    for directory in \
        config \
        languages \
        themes \
        schemas
    do
        if [[ -d "${PROJECT_ROOT}/${directory}" ]]; then
            cp -R \
                "${PROJECT_ROOT}/${directory}" \
                "${root}/usr/local/share/vfconf/"
        fi
    done

    local file

    for file in \
        README.md \
        LICENSE \
        CHANGELOG.md
    do
        if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
            cp -- \
                "${PROJECT_ROOT}/${file}" \
                "${root}/usr/local/share/doc/vfconf/"
        fi
    done

    cat > "$manifest" <<EOF
name: vfconf
version: "${version}"
origin: devel/vfconf
comment: "Vitte Foundation Configuration Language"
maintainer: "Vincent Rousseau"
www: "https://github.com/vitte-lang/vfconf"
prefix: /usr/local
arch: "${architecture}"
licenselogic: single
licenses:
  - MIT
desc: |
  VFConf is the Vitte Foundation Configuration Language.
  It provides structured configuration through .vf.conf files.
EOF

    log "Creating FreeBSD package"

    pkg create \
        -M "$manifest" \
        -r "$root" \
        -o "$output"

    rm -rf -- \
        "$root" \
        "$manifest"

    local package

    while IFS= read -r -d '' package; do
        checksum_file "$package"
        log "Created: ${package#"$PROJECT_ROOT"/}"
    done < <(
        find "$output" \
            -type f \
            -print0
    )

    log "FreeBSD package generation completed"
}

main() {
    parse_arguments "$@"

    cd -- "$PROJECT_ROOT"

    check_host
    check_project

    local version
    local bsd
    local architecture

    version="$(project_version)"
    bsd="$(detect_bsd)"
    architecture="$(detect_architecture)"

    [[ -n "$version" ]] ||
        die "unable to determine VFConf version"

    echo "============================================================"
    echo " VFConf BSD builder"
    echo "============================================================"
    echo " Version:      ${version}"
    echo " BSD:          ${bsd}"
    echo " Architecture: ${architecture}"
    echo " Profile:      ${PROFILE}"
    echo " Commands:     ${#VFCONF_EXECUTABLES[@]}"
    echo "============================================================"

    check_tools
    make_dune_args

    mkdir -p -- "$DIST_DIR"

    build_project
    verify_binaries

    run_tests
    run_diagnostics

    create_portable_distribution \
        "$bsd" \
        "$architecture" \
        "$version"

    case "$bsd" in
        freebsd)
            create_freebsd_package \
                "$architecture" \
                "$version"
            ;;

        openbsd)
            log "Portable OpenBSD distribution generated"
            ;;

        netbsd)
            log "Portable NetBSD distribution generated"
            ;;

        dragonflybsd)
            log "Portable DragonFly BSD distribution generated"
            ;;
    esac

    echo
    echo "============================================================"
    echo " VFConf BSD build successful"
    echo "============================================================"
    printf '  version:      %s\n' "$version"
    printf '  BSD:          %s\n' "$bsd"
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

    echo "============================================================"
}

main "$@"