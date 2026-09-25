#!/usr/bin/env bash
#
# VFConf — Vitte Foundation Configuration Language
# scripts/build-all.sh
#
# Universal host-native build orchestrator.
#
# IMPORTANT:
#   This script does NOT magically cross-compile VFConf.
#
#   It selects the native builder for the CURRENT host:
#
#     macOS       -> scripts/build-macos.sh
#     Linux       -> scripts/build-linux.sh
#     BSD         -> scripts/build-bsd.sh
#     Windows     -> scripts/build-windows.ps1
#
#   Other operating systems and architectures require:
#     - native CI runners
#     - virtual machines
#     - appropriate containers
#     - or correctly configured cross-compilers
#
# VFConf currently exposes 20 command-line executables.

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
readonly PROJECT_NAME="vfconf"

PROFILE="release"
CLEAN=0
RUN_TESTS=0
RUN_DIAGNOSTICS=1
VERBOSE=0
JOBS=""

BUILDER_ARGS=()

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
    printf '[vfconf-all] %s\n' "$*"
}

warn() {
    printf '[vfconf-all] warning: %s\n' "$*" >&2
}

error() {
    printf '[vfconf-all] error: %s\n' "$*" >&2
}

die() {
    error "$*"
    exit 1
}

usage() {
    cat <<'EOF'
Usage:
  scripts/build-all.sh [options]

Build:
  --dev                 Use Dune dev profile.
  --release             Use Dune release profile (default).
  --profile NAME        Use custom Dune profile.
  --clean               Request clean build.
  -j, --jobs N          Parallel build jobs.

Validation:
  --test                Run tests.
  --diagnostics         Enable diagnostics gate (default).
  --no-diagnostics      Disable diagnostics gate.

General:
  -v, --verbose         Verbose builder output.
  -h, --help            Show this help.

Examples:
  scripts/build-all.sh
  scripts/build-all.sh --clean
  scripts/build-all.sh --release --test
  scripts/build-all.sh --clean --release --test --diagnostics
  scripts/build-all.sh --no-diagnostics
  scripts/build-all.sh -j 4

Host-native builders:
  macOS       scripts/build-macos.sh
  Linux       scripts/build-linux.sh
  BSD         scripts/build-bsd.sh
  Windows     scripts/build-windows.ps1

Important:
  build-all.sh orchestrates the CURRENT host toolchain only.
  It does not imply that all listed platforms or architectures
  can be cross-compiled from the current machine.
EOF
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

project_version() {
    local version=""

    if [[ -s "${PROJECT_ROOT}/VERSION" ]]; then
        version="$(
            tr -d '[:space:]' \
                < "${PROJECT_ROOT}/VERSION"
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

normalize_architecture() {
    case "$1" in
        x86_64|amd64)
            printf 'x86_64\n'
            ;;

        i386|i486|i586|i686)
            printf 'x86\n'
            ;;

        arm64|aarch64|armv8*)
            printf 'arm64\n'
            ;;

        armv7*|armhf)
            printf 'armv7\n'
            ;;

        armv6*)
            printf 'armv6\n'
            ;;

        armv5*)
            printf 'armv5\n'
            ;;

        ppc64le|powerpc64le)
            printf 'powerpc64le\n'
            ;;

        ppc64|powerpc64)
            printf 'powerpc64\n'
            ;;

        powerpc|ppc)
            printf 'powerpc\n'
            ;;

        riscv64)
            printf 'riscv64\n'
            ;;

        riscv32)
            printf 'riscv32\n'
            ;;

        mips64el)
            printf 'mips64el\n'
            ;;

        mips64*)
            printf 'mips64\n'
            ;;

        mipsel)
            printf 'mipsel\n'
            ;;

        mips*)
            printf 'mips\n'
            ;;

        sparc64)
            printf 'sparc64\n'
            ;;

        sparc*)
            printf 'sparc\n'
            ;;

        s390x)
            printf 's390x\n'
            ;;

        *)
            printf '%s\n' "$1"
            ;;
    esac
}

detect_host_family() {
    case "$(uname -s)" in
        Darwin)
            printf 'macos\n'
            ;;

        Linux)
            printf 'linux\n'
            ;;

        FreeBSD|OpenBSD|NetBSD|DragonFly)
            printf 'bsd\n'
            ;;

        MINGW*|MSYS*|CYGWIN*)
            printf 'windows\n'
            ;;

        *)
            printf 'unknown\n'
            ;;
    esac
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

                [[ -n "$2" ]] ||
                    die "--profile cannot be empty"

                PROFILE="$2"
                shift
                ;;

            --clean)
                CLEAN=1
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

check_project() {
    [[ -n "$PROJECT_ROOT" ]] ||
        die "empty project root"

    [[ "$PROJECT_ROOT" != "/" ]] ||
        die "invalid project root"

    [[ -f "${PROJECT_ROOT}/dune-project" ]] ||
        die "dune-project not found"

    [[ -f "${PROJECT_ROOT}/lib/dune" ]] ||
        die "lib/dune not found"

    [[ -f "${PROJECT_ROOT}/bin/dune" ]] ||
        die "bin/dune not found"

    [[ -d "${PROJECT_ROOT}/scripts" ]] ||
        die "scripts directory not found"

    local version

    version="$(project_version)"

    [[ -n "$version" ]] ||
        die "unable to determine VFConf version"
}

check_builder_files() {
    log "Checking native builder scripts"

    local files=(
        "${SCRIPT_DIR}/build-macos.sh"
        "${SCRIPT_DIR}/build-linux.sh"
        "${SCRIPT_DIR}/build-bsd.sh"
        "${SCRIPT_DIR}/build-windows.ps1"
    )

    local file

    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            if (( VERBOSE )); then
                printf '  available: %s\n' "${file#"$PROJECT_ROOT"/}"
            fi
        else
            warn "builder unavailable: ${file#"$PROJECT_ROOT"/}"
        fi
    done
}

run_diagnostics_gate() {
    (( RUN_DIAGNOSTICS )) || {
        warn "diagnostics gate disabled"
        return 0
    }

    log "Running universal diagnostics gate"

    if [[ -x "${SCRIPT_DIR}/check-diagnostics.sh" ]]; then
        "${SCRIPT_DIR}/check-diagnostics.sh"

        log "Diagnostics gate passed"
        return 0
    fi

    if [[ -f "${SCRIPT_DIR}/audit-diagnostics.py" ]]; then
        command_exists python3 ||
            die "python3 required for diagnostics audit"

        warn "full diagnostics gate unavailable; using static audit"

        python3 \
            "${SCRIPT_DIR}/audit-diagnostics.py"

        log "Static diagnostics audit passed"
        return 0
    fi

    die "diagnostics requested but no diagnostics gate exists"
}

build_unix_arguments() {
    BUILDER_ARGS=()

    case "$PROFILE" in
        dev)
            BUILDER_ARGS+=("--dev")
            ;;

        release)
            BUILDER_ARGS+=("--release")
            ;;

        *)
            BUILDER_ARGS+=(
                "--profile"
                "$PROFILE"
            )
            ;;
    esac

    if (( CLEAN )); then
        BUILDER_ARGS+=("--clean")
    fi

    if (( RUN_TESTS )); then
        BUILDER_ARGS+=("--test")
    fi

    BUILDER_ARGS+=("--no-diagnostics")

    if [[ -n "$JOBS" ]]; then
        BUILDER_ARGS+=(
            "--jobs"
            "$JOBS"
        )
    fi

    if (( VERBOSE )); then
        BUILDER_ARGS+=("--verbose")
    fi
}

print_target_header() {
    local name="$1"

    printf '\n'
    printf '%s\n' '------------------------------------------------------------'
    printf ' VFConf target: %s\n' "$name"
    printf '%s\n' '------------------------------------------------------------'
}

run_bash_builder() {
    local name="$1"
    local script="$2"

    print_target_header "$name"

    [[ -f "$script" ]] ||
        die "${name} builder missing: $script"

    command_exists bash ||
        die "bash is required for ${name} builder"

    build_unix_arguments

    bash \
        "$script" \
        "${BUILDER_ARGS[@]}"

    log "${name}: OK"
}

run_windows_builder() {
    local script="$1"

    print_target_header "Windows"

    [[ -f "$script" ]] ||
        die "Windows builder missing: $script"

    command_exists pwsh ||
        die "PowerShell Core (pwsh) is required"

    local args=(
        "-NoLogo"
        "-NoProfile"
        "-File"
        "$script"
        "-Profile"
        "$PROFILE"
    )

    if (( CLEAN )); then
        args+=("-Clean")
    fi

    if (( RUN_TESTS )); then
        args+=("-Test")
    fi

    if (( ! RUN_DIAGNOSTICS )); then
        args+=("-NoDiagnostics")
    else
        # Diagnostics already ran at the orchestrator level.
        # Prevent duplicate execution in the Windows child builder.
        args+=("-NoDiagnostics")
    fi

    if [[ -n "$JOBS" ]]; then
        args+=(
            "-Jobs"
            "$JOBS"
        )
    fi

    if (( VERBOSE )); then
        args+=("-VerboseBuild")
    fi

    pwsh "${args[@]}"

    log "Windows: OK"
}

skip_target() {
    local name="$1"
    local reason="$2"

    printf '  %-10s SKIPPED — %s\n' \
        "$name" \
        "$reason"
}

verify_distribution_output() {
    local version="$1"
    local host_family="$2"
    local normalized_arch="$3"

    log "Checking distribution output"

    [[ -d "$DIST_DIR" ]] ||
        die "distribution directory does not exist: $DIST_DIR"

    local pattern=""

    case "$host_family" in
        macos)
            pattern="${PROJECT_NAME}-${version}-macos-*"
            ;;

        linux)
            pattern="${PROJECT_NAME}-${version}-linux-*"
            ;;

        bsd)
            pattern="${PROJECT_NAME}-${version}-*bsd-*"
            ;;

        windows)
            pattern="${PROJECT_NAME}-${version}-windows-*"
            ;;

        *)
            return 0
            ;;
    esac

    local result=""

    result="$(
        find "$DIST_DIR" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -name "$pattern" \
            -print \
            -quit \
            2>/dev/null || true
    )"

    if [[ -z "$result" ]]; then
        warn "no distribution directory matching ${pattern}"
        return 0
    fi

    log "Distribution detected: ${result#"$PROJECT_ROOT"/}"

    if (( VERBOSE )); then
        printf '  architecture requested: %s\n' "$normalized_arch"
    fi
}

print_target_matrix() {
    cat <<'EOF'

============================================================
 VFConf target architecture matrix
============================================================

macOS
  arm64
  x86_64

Linux
  x86_64
  x86
  arm64
  armv7
  armv6
  armv5
  powerpc64le
  powerpc64
  powerpc
  riscv64
  riscv32
  mips64
  mips64el
  mips
  mipsel
  sparc64
  sparc
  s390x

BSD
  amd64 / x86_64
  i386 / x86
  arm64
  armv7
  armv6
  armv5
  powerpc
  powerpc64
  powerpc64le
  riscv64
  sparc64
  sparc
  mips
  mipsel
  mips64
  mips64el

Windows
  x64 / x86_64
  x86
  arm64

============================================================
 IMPORTANT
============================================================

This matrix describes intended VFConf release targets.

It does NOT guarantee that:
  - OCaml supports every listed architecture,
  - Dune supports every listed environment,
  - VFConf has been tested on every target,
  - a binary can be cross-compiled from the current host.

build-all.sh builds only with the CURRENT native toolchain.

Complete multi-platform releases require suitable:
  - native CI runners,
  - virtual machines,
  - containers where applicable,
  - or configured cross-compilers.

============================================================
EOF
}

print_executable_matrix() {
    printf '\n'
    printf '%s\n' '============================================================'
    printf ' VFConf executables (%d)\n' "${#VFCONF_EXECUTABLES[@]}"
    printf '%s\n' '============================================================'

    local entry
    local public_name

    for entry in "${VFCONF_EXECUTABLES[@]}"; do
        public_name="${entry#*:}"
        printf '  %s\n' "$public_name"
    done

    printf '%s\n' '============================================================'
}

print_summary() {
    local version="$1"
    local host_os="$2"
    local host_arch="$3"
    local normalized_arch="$4"
    local host_family="$5"

    printf '\n'
    printf '%s\n' '============================================================'
    printf '%s\n' ' VFConf build orchestration successful'
    printf '%s\n' '============================================================'
    printf ' Version:       %s\n' "$version"
    printf ' Host OS:       %s\n' "$host_os"
    printf ' Host family:   %s\n' "$host_family"
    printf ' Host arch:     %s\n' "$host_arch"
    printf ' Normalized:    %s\n' "$normalized_arch"
    printf ' Profile:       %s\n' "$PROFILE"
    printf ' Executables:   %d\n' "${#VFCONF_EXECUTABLES[@]}"
    printf ' Distribution:  %s\n' "$DIST_DIR"

    if (( RUN_DIAGNOSTICS )); then
        printf ' Diagnostics:   passed\n'
    else
        printf ' Diagnostics:   skipped\n'
    fi

    if (( RUN_TESTS )); then
        printf ' Tests:         passed\n'
    else
        printf ' Tests:         not requested\n'
    fi

    printf '%s\n' '============================================================'
}

on_error() {
    local exit_code=$?
    local line="${BASH_LINENO[0]:-unknown}"

    error "build orchestration failed at line ${line} (exit ${exit_code})"

    exit "$exit_code"
}

main() {
    trap on_error ERR

    parse_arguments "$@"

    cd -- "$PROJECT_ROOT"

    check_project
    check_builder_files

    local version
    local host_os
    local host_family
    local host_arch
    local normalized_arch

    version="$(project_version)"
    host_os="$(uname -s)"
    host_family="$(detect_host_family)"
    host_arch="$(uname -m)"
    normalized_arch="$(normalize_architecture "$host_arch")"

    mkdir -p -- "$DIST_DIR"

    printf '%s\n' '============================================================'
    printf '%s\n' ' VFConf universal build orchestrator'
    printf '%s\n' '============================================================'
    printf ' Version:       %s\n' "$version"
    printf ' Host OS:       %s\n' "$host_os"
    printf ' Host family:   %s\n' "$host_family"
    printf ' Host arch:     %s\n' "$host_arch"
    printf ' Normalized:    %s\n' "$normalized_arch"
    printf ' Profile:       %s\n' "$PROFILE"
    printf ' Executables:   %d\n' "${#VFCONF_EXECUTABLES[@]}"

    if (( RUN_TESTS )); then
        printf ' Tests:         enabled\n'
    else
        printf ' Tests:         disabled\n'
    fi

    if (( RUN_DIAGNOSTICS )); then
        printf ' Diagnostics:   enabled\n'
    else
        printf ' Diagnostics:   disabled\n'
    fi

    printf '%s\n' '============================================================'

    run_diagnostics_gate

    printf '\n'
    log "Starting host-native build"

    case "$host_family" in
        macos)
            run_bash_builder \
                "macOS" \
                "${SCRIPT_DIR}/build-macos.sh"

            printf '\n'

            skip_target \
                "Linux" \
                "requires Linux"

            skip_target \
                "BSD" \
                "requires BSD"

            skip_target \
                "Windows" \
                "requires Windows"
            ;;

        linux)
            run_bash_builder \
                "Linux" \
                "${SCRIPT_DIR}/build-linux.sh"

            printf '\n'

            skip_target \
                "macOS" \
                "requires macOS"

            skip_target \
                "BSD" \
                "requires BSD"

            skip_target \
                "Windows" \
                "requires Windows"
            ;;

        bsd)
            run_bash_builder \
                "BSD" \
                "${SCRIPT_DIR}/build-bsd.sh"

            printf '\n'

            skip_target \
                "macOS" \
                "requires macOS"

            skip_target \
                "Linux" \
                "requires Linux"

            skip_target \
                "Windows" \
                "requires Windows"
            ;;

        windows)
            run_windows_builder \
                "${SCRIPT_DIR}/build-windows.ps1"

            printf '\n'

            skip_target \
                "macOS" \
                "requires macOS"

            skip_target \
                "Linux" \
                "requires Linux"

            skip_target \
                "BSD" \
                "requires BSD"
            ;;

        *)
            die "unsupported host: ${host_os}"
            ;;
    esac

    verify_distribution_output \
        "$version" \
        "$host_family" \
        "$normalized_arch"

    print_executable_matrix
    print_target_matrix

    print_summary \
        "$version" \
        "$host_os" \
        "$host_arch" \
        "$normalized_arch" \
        "$host_family"
}

main "$@"