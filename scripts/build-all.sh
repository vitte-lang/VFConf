#!/usr/bin/env bash
#
# VFConf — Vitte Foundation Configuration Language
# scripts/build-all.sh
#
# Universal build orchestrator.
#
# IMPORTANT:
#   This script does NOT magically cross-compile VFConf.
#
#   It selects the native builder for the CURRENT host:
#     macOS       -> build-macos.sh
#     Linux       -> build-linux.sh
#     BSD         -> build-bsd.sh
#     Windows     -> build-windows.ps1
#
#   Other targets require native CI runners, virtual machines,
#   containers where applicable, or configured cross-compilers.

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

PROFILE="release"
CLEAN=0
RUN_TESTS=0
RUN_DIAGNOSTICS=1
VERBOSE=0
JOBS=""

log() {
    printf '[vfconf] %s\n' "$*"
}

warn() {
    printf '[vfconf] warning: %s\n' "$*" >&2
}

die() {
    printf '[vfconf] error: %s\n' "$*" >&2
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

        ppc64le)
            printf 'ppc64le\n'
            ;;

        ppc64)
            printf 'ppc64\n'
            ;;

        powerpc|ppc)
            printf 'powerpc\n'
            ;;

        riscv64)
            printf 'riscv64\n'
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
    [[ -f "${PROJECT_ROOT}/dune-project" ]] ||
        die "dune-project not found"

    [[ -f "${PROJECT_ROOT}/lib/dune" ]] ||
        die "lib/dune not found"

    [[ -f "${PROJECT_ROOT}/bin/dune" ]] ||
        die "bin/dune not found"
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

builder_arguments() {
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

    # The universal gate has already run. Child builders should not
    # repeat the same diagnostics audit.
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

run_bash_builder() {
    local name="$1"
    local script="$2"

    echo
    echo "------------------------------------------------------------"
    printf ' VFConf target: %s\n' "$name"
    echo "------------------------------------------------------------"

    [[ -f "$script" ]] ||
        die "${name} builder missing: $script"

    chmod +x "$script"

    "$script" "${BUILDER_ARGS[@]}"

    log "${name}: OK"
}

run_windows_builder() {
    local script="$1"

    echo
    echo "------------------------------------------------------------"
    echo " VFConf target: Windows"
    echo "------------------------------------------------------------"

    [[ -f "$script" ]] ||
        die "Windows builder missing: $script"

    command_exists pwsh ||
        die "PowerShell Core (pwsh) is required"

    # Windows builder may have a different argument syntax.
    # Do not blindly forward Unix builder flags.
    pwsh \
        -NoLogo \
        -NoProfile \
        -File "$script"

    log "Windows: OK"
}

skip_target() {
    local name="$1"
    local reason="$2"

    printf '  %-10s SKIPPED — %s\n' \
        "$name" \
        "$reason"
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
  i686
  i586
  i486
  i386
  aarch64
  armv7
  armv6
  armv5
  ppc64le
  ppc64
  powerpc
  riscv64
  mips64
  mips64el
  mips
  mipsel
  sparc64
  sparc
  s390x

BSD
  amd64
  i386
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
  x64
  x86
  arm64

IMPORTANT

  This matrix describes intended VFConf targets.

  It does NOT mean that the OCaml compiler currently supports
  every listed architecture.

  build-all.sh builds only for the CURRENT host/toolchain.

  Complete multi-platform releases require:
    - native CI runners
    - virtual machines
    - appropriate containers where possible
    - or correctly configured cross-compilers

============================================================
EOF
}

main() {
    parse_arguments "$@"

    cd -- "$PROJECT_ROOT"

    check_project

    local version
    local host_os
    local host_arch
    local normalized_arch

    version="$(project_version)"
    host_os="$(uname -s)"
    host_arch="$(uname -m)"
    normalized_arch="$(normalize_architecture "$host_arch")"

    [[ -n "$version" ]] ||
        die "unable to determine VFConf version"

    mkdir -p -- "$DIST_DIR"

    echo "============================================================"
    echo " VFConf universal build"
    echo "============================================================"
    printf ' Version:      %s\n' "$version"
    printf ' Host OS:      %s\n' "$host_os"
    printf ' Host arch:    %s\n' "$host_arch"
    printf ' Normalized:   %s\n' "$normalized_arch"
    printf ' Profile:      %s\n' "$PROFILE"

    if (( RUN_TESTS )); then
        echo " Tests:        enabled"
    else
        echo " Tests:        disabled"
    fi

    if (( RUN_DIAGNOSTICS )); then
        echo " Diagnostics:  enabled"
    else
        echo " Diagnostics:  disabled"
    fi

    echo "============================================================"

    # Final project-level gate before any release builder starts.
    run_diagnostics_gate

    builder_arguments

    echo
    log "Starting host-native build"

    case "$host_os" in
        Darwin)
            run_bash_builder \
                "macOS" \
                "${SCRIPT_DIR}/build-macos.sh"

            echo
            skip_target \
                "Linux" \
                "requires Linux"

            skip_target \
                "BSD" \
                "requires BSD"

            skip_target \
                "Windows" \
                "requires Windows toolchain"
            ;;

        Linux)
            run_bash_builder \
                "Linux" \
                "${SCRIPT_DIR}/build-linux.sh"

            echo
            skip_target \
                "macOS" \
                "requires macOS"

            skip_target \
                "BSD" \
                "requires BSD"

            skip_target \
                "Windows" \
                "requires Windows toolchain"
            ;;

        FreeBSD|OpenBSD|NetBSD|DragonFly)
            run_bash_builder \
                "BSD" \
                "${SCRIPT_DIR}/build-bsd.sh"

            echo
            skip_target \
                "macOS" \
                "requires macOS"

            skip_target \
                "Linux" \
                "requires Linux"

            skip_target \
                "Windows" \
                "requires Windows toolchain"
            ;;

        MINGW*|MSYS*|CYGWIN*)
            run_windows_builder \
                "${SCRIPT_DIR}/build-windows.ps1"

            echo
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

    print_target_matrix

    echo
    echo "============================================================"
    echo " VFConf build orchestration successful"
    echo "============================================================"
    printf ' Version:      %s\n' "$version"
    printf ' Host:         %s %s\n" "$host_os" "$host_arch"
    printf ' Distribution: %s\n' "$DIST_DIR"

    if (( RUN_DIAGNOSTICS )); then
        echo " Diagnostics:  passed"
    else
        echo " Diagnostics:  skipped"
    fi

    if (( RUN_TESTS )); then
        echo " Tests:        passed"
    else
        echo " Tests:        not requested"
    fi

    echo "============================================================"
}

main "$@"
