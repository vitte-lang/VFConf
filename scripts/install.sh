#!/usr/bin/env bash
#
# VFConf — Vitte Foundation Configuration Language
# scripts/install.sh
#
# Build, validate and install VFConf on the current operating system.
#
# Installs:
#   - all VFConf command-line executables
#   - runtime configuration data
#   - languages, themes and schemas
#   - examples
#   - documentation
#
# Default installation prefix:
#   $HOME/.local
#
# The installation is performed directly from Dune build outputs.

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

readonly PROJECT_NAME="vfconf"

PROFILE="release"
PREFIX=""
JOBS=""
BUILD_FIRST=1
RUN_TESTS=0
RUN_DIAGNOSTICS=1
INSTALL_DATA=1
INSTALL_DOCS=1
DRY_RUN=0
VERBOSE=0

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
    printf '[vfconf-install] %s\n' "$*"
}

warn() {
    printf '[vfconf-install] warning: %s\n' "$*" >&2
}

error() {
    printf '[vfconf-install] error: %s\n' "$*" >&2
}

die() {
    error "$*"
    exit 1
}

usage() {
    cat <<'EOF'
Usage:
  scripts/install.sh [options]

Build:
  --dev                 Use Dune dev profile.
  --release             Use Dune release profile (default).
  --profile NAME        Use another Dune profile.
  --no-build            Do not build before installation.
  --test                Run dune runtest.
  -j, --jobs N          Parallel build jobs.

Diagnostics:
  --diagnostics         Run final diagnostics gate (default).
  --no-diagnostics      Skip diagnostics gate.

Installation:
  --prefix PATH         Installation prefix.
  --no-data             Do not install runtime data.
  --no-docs             Do not install documentation.

General:
  --dry-run             Show installation operations.
  -v, --verbose         Verbose Dune output.
  -h, --help            Show this help.

Default prefix:
  $HOME/.local

Examples:
  scripts/install.sh
  scripts/install.sh --test
  scripts/install.sh --prefix /usr/local
  scripts/install.sh --prefix "$HOME/.local"
  scripts/install.sh --no-diagnostics
  scripts/install.sh --no-build
  scripts/install.sh --dry-run
  scripts/install.sh -j 4

Installed executables:
  vfconf
  vfconf-check
  vfconf-dump
  vfconf-fmt
  vfconf-fmt-all
  vfconf-get
  vfconf-set
  vfconf-unset
  vfconf-exists
  vfconf-list
  vfconf-tree
  vfconf-diff
  vfconf-merge
  vfconf-resolve
  vfconf-eval
  vfconf-query
  vfconf-diagnostics
  vfconf-explain
  vfconf-stats
  vfconf-check-all
EOF
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_command() {
    command_exists "$1" ||
        die "required command not found: $1"
}

detect_os() {
    case "$(uname -s)" in
        Linux)
            printf 'linux\n'
            ;;
        Darwin)
            printf 'macos\n'
            ;;
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
        CYGWIN*|MINGW*|MSYS*)
            printf 'windows\n'
            ;;
        *)
            uname -s | tr '[:upper:]' '[:lower:]'
            ;;
    esac
}

detect_architecture() {
    case "$(uname -m)" in
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
        riscv64)
            printf 'riscv64\n'
            ;;
        riscv32)
            printf 'riscv32\n'
            ;;
        ppc64le)
            printf 'powerpc64le\n'
            ;;
        ppc64)
            printf 'powerpc64\n'
            ;;
        ppc*)
            printf 'powerpc\n'
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
            uname -m | tr '[:upper:]' '[:lower:]'
            ;;
    esac
}

default_prefix() {
    if [[ -n "${HOME:-}" ]]; then
        printf '%s/.local\n' "$HOME"
    else
        printf '/usr/local\n'
    fi
}

normalize_prefix() {
    [[ -n "$PREFIX" ]] ||
        PREFIX="$(default_prefix)"

    if [[ "$PREFIX" == "~" ]]; then
        [[ -n "${HOME:-}" ]] ||
            die "HOME is not defined"

        PREFIX="$HOME"

    elif [[ "$PREFIX" == "~/"* ]]; then
        [[ -n "${HOME:-}" ]] ||
            die "HOME is not defined"

        PREFIX="${HOME}/${PREFIX#~/}"
    fi

    if [[ "$PREFIX" != /* ]]; then
        PREFIX="${PROJECT_ROOT}/${PREFIX}"
    fi

    while [[ "$PREFIX" != "/" && "$PREFIX" == */ ]]; do
        PREFIX="${PREFIX%/}"
    done

    [[ -n "$PREFIX" ]] ||
        die "invalid empty installation prefix"

    [[ "$PREFIX" != "/" ]] ||
        die "refusing to use / as installation prefix"
}

executable_suffix() {
    if [[ "$(detect_os)" == "windows" ]]; then
        printf '.exe\n'
    else
        printf '\n'
    fi
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

            --prefix)
                (($# >= 2)) ||
                    die "--prefix requires an argument"

                PREFIX="$2"
                shift
                ;;

            --no-build)
                BUILD_FIRST=0
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

            --no-data)
                INSTALL_DATA=0
                ;;

            --no-docs)
                INSTALL_DOCS=0
                ;;

            -j|--jobs)
                (($# >= 2)) ||
                    die "$1 requires an argument"

                [[ "$2" =~ ^[1-9][0-9]*$ ]] ||
                    die "invalid job count: $2"

                JOBS="$2"
                shift
                ;;

            --dry-run)
                DRY_RUN=1
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
}

check_tools() {
    if (( BUILD_FIRST || RUN_TESTS || RUN_DIAGNOSTICS )); then
        require_command dune
    fi

    if (( BUILD_FIRST )); then
        require_command ocamlc
        require_command ocamllex
        require_command menhir

        log "OCaml:  $(ocamlc -version)"
        log "Dune:   $(dune --version)"
        log "Menhir: $(menhir --version 2>/dev/null || printf 'available')"

        if command_exists ocamlopt; then
            log "Native compiler: available"
        else
            warn "ocamlopt unavailable; native compilation may fail"
        fi
    fi

    if (( RUN_DIAGNOSTICS )) &&
       [[ -f "${PROJECT_ROOT}/scripts/audit-diagnostics.py" ]]; then
        require_command python3
    fi

    require_command install
    require_command find
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
    (( BUILD_FIRST )) || {
        log "Build skipped"
        return 0
    }

    log "Building VFConf (${PROFILE})"
    log "Executables: ${#VFCONF_EXECUTABLES[@]}"

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

    log "Build completed"
}

run_tests() {
    (( RUN_TESTS )) || return 0

    log "Running VFConf tests"

    dune runtest "${DUNE_ARGS[@]}"

    log "Tests completed"
}

run_diagnostics_gate() {
    (( RUN_DIAGNOSTICS )) || {
        warn "diagnostics gate skipped"
        return 0
    }

    log "Running final diagnostics gate"

    if [[ -x "${PROJECT_ROOT}/scripts/check-diagnostics.sh" ]]; then
        "${PROJECT_ROOT}/scripts/check-diagnostics.sh"

        log "Diagnostics gate passed"
        return 0
    fi

    if [[ -f "${PROJECT_ROOT}/scripts/audit-diagnostics.py" ]]; then
        warn "full diagnostics gate unavailable; running static audit"

        python3 \
            "${PROJECT_ROOT}/scripts/audit-diagnostics.py"

        log "Static diagnostics audit passed"
        return 0
    fi

    die "diagnostics requested but no diagnostics gate is available"
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

ensure_build_exists() {
    log "Verifying compiled executables"

    local entry
    local build_name
    local public_name
    local path
    local count=0

    for entry in "${VFCONF_EXECUTABLES[@]}"; do
        build_name="${entry%%:*}"
        public_name="${entry#*:}"

        path="$(find_built_binary "$build_name")" ||
            die "compiled executable not found: ${build_name}.exe (${public_name})"

        [[ -s "$path" ]] ||
            die "compiled executable is empty: $path"

        if [[ "$(detect_os)" != "windows" ]]; then
            [[ -x "$path" ]] ||
                die "compiled executable is not executable: $path"
        fi

        ((count += 1))
    done

    [[ "$count" -eq "${#VFCONF_EXECUTABLES[@]}" ]] ||
        die "compiled executable count mismatch"

    log "All ${count} executables verified"
}

install_directory() {
    local directory="$1"

    if (( DRY_RUN )); then
        printf '[dry-run] mkdir -p -- %q\n' "$directory"
        return 0
    fi

    mkdir -p -- "$directory"
}

install_file() {
    local source="$1"
    local destination="$2"
    local mode="${3:-0644}"

    [[ -f "$source" ]] ||
        die "installation source does not exist: $source"

    if (( DRY_RUN )); then
        printf '[dry-run] install -m %q -- %q %q\n' \
            "$mode" \
            "$source" \
            "$destination"

        return 0
    fi

    install \
        -m "$mode" \
        "$source" \
        "$destination"
}

install_binary() {
    local build_name="$1"
    local installed_name="$2"

    local source
    local suffix

    source="$(find_built_binary "$build_name")" ||
        die "cannot locate compiled binary: ${build_name}.exe"

    suffix="$(executable_suffix)"

    install_file \
        "$source" \
        "${PREFIX}/bin/${installed_name}${suffix}" \
        0755
}

install_binaries() {
    log "Installing ${#VFCONF_EXECUTABLES[@]} executables"

    install_directory "${PREFIX}/bin"

    local entry
    local build_name
    local installed_name

    for entry in "${VFCONF_EXECUTABLES[@]}"; do
        build_name="${entry%%:*}"
        installed_name="${entry#*:}"

        install_binary \
            "$build_name" \
            "$installed_name"
    done

    log "Executables installed"
}

copy_directory() {
    local source="$1"
    local destination="$2"

    [[ -d "$source" ]] ||
        return 0

    if (( DRY_RUN )); then
        printf '[dry-run] copy %q -> %q\n' \
            "$source" \
            "$destination"

        return 0
    fi

    rm -rf -- "$destination"

    mkdir -p \
        -- "$(dirname -- "$destination")"

    cp -R \
        "$source" \
        "$destination"
}

install_runtime_data() {
    (( INSTALL_DATA )) || {
        log "Runtime data installation disabled"
        return 0
    }

    log "Installing runtime data"

    local share="${PREFIX}/share/vfconf"

    install_directory "$share"

    local directory

    for directory in \
        config \
        languages \
        themes \
        schemas \
        examples
    do
        copy_directory \
            "${PROJECT_ROOT}/${directory}" \
            "${share}/${directory}"
    done

    if [[ -f "${PROJECT_ROOT}/VERSION" ]]; then
        install_file \
            "${PROJECT_ROOT}/VERSION" \
            "${share}/VERSION"
    fi

    log "Runtime data installed"
}

install_documentation() {
    (( INSTALL_DOCS )) || {
        log "Documentation installation disabled"
        return 0
    }

    log "Installing documentation"

    local destination="${PREFIX}/share/doc/vfconf"

    install_directory "$destination"

    local file

    for file in \
        README.md \
        CHANGELOG.md \
        LICENSE \
        VERSION
    do
        if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
            install_file \
                "${PROJECT_ROOT}/${file}" \
                "${destination}/${file}"
        fi
    done

    if [[ -d "${PROJECT_ROOT}/docs" ]]; then
        copy_directory \
            "${PROJECT_ROOT}/docs" \
            "${destination}/docs"
    fi

    log "Documentation installed"
}

verify_binary() {
    local name="$1"

    local suffix
    local path

    suffix="$(executable_suffix)"
    path="${PREFIX}/bin/${name}${suffix}"

    if [[ "$(detect_os)" == "windows" ]]; then
        [[ -f "$path" ]] || {
            warn "executable not found after installation: $path"
            return 1
        }
    else
        [[ -x "$path" ]] || {
            warn "executable not found or not executable: $path"
            return 1
        }
    fi

    if (( VERBOSE )); then
        printf '  %-24s %s\n' "$name" "$path"
    fi

    return 0
}

verify_installation() {
    (( DRY_RUN )) && return 0

    log "Verifying installation"

    local failures=0
    local count=0
    local entry
    local installed_name

    for entry in "${VFCONF_EXECUTABLES[@]}"; do
        installed_name="${entry#*:}"

        if verify_binary "$installed_name"; then
            ((count += 1))
        else
            ((failures += 1))
        fi
    done

    (( failures == 0 )) ||
        die "${failures} executable(s) failed installation verification"

    [[ "$count" -eq "${#VFCONF_EXECUTABLES[@]}" ]] ||
        die "installed executable count mismatch"

    log "All ${count} installed executables verified"
}

verify_cli_help() {
    (( DRY_RUN )) && return 0

    local suffix
    local executable

    suffix="$(executable_suffix)"
    executable="${PREFIX}/bin/vfconf${suffix}"

    [[ -f "$executable" ]] || return 0

    log "Testing installed vfconf CLI"

    if ! "$executable" --help >/dev/null 2>&1; then
        die "installed vfconf --help failed"
    fi

    log "vfconf --help passed"
}

verify_cli() {
    (( DRY_RUN )) && return 0

    local suffix
    local checker
    local temporary

    suffix="$(executable_suffix)"
    checker="${PREFIX}/bin/vfconf-check${suffix}"

    [[ -f "$checker" ]] ||
        return 0

    log "Running installed VFConf smoke test"

    temporary="$(
        mktemp "${TMPDIR:-/tmp}/vfconf-install.XXXXXXXX.vf.conf"
    )"

    printf 'name = "vfconf"\n' > "$temporary"

    if ! "$checker" "$temporary" >/dev/null; then
        rm -f -- "$temporary"

        die "installed vfconf-check failed smoke test"
    fi

    rm -f -- "$temporary"

    log "VFConf smoke test passed"
}

verify_runtime_data() {
    (( DRY_RUN )) && return 0
    (( INSTALL_DATA )) || return 0

    local share="${PREFIX}/share/vfconf"

    [[ -d "$share" ]] ||
        die "runtime data directory missing after installation"

    log "Runtime data verified"
}

verify_documentation() {
    (( DRY_RUN )) && return 0
    (( INSTALL_DOCS )) || return 0

    local destination="${PREFIX}/share/doc/vfconf"

    [[ -d "$destination" ]] ||
        die "documentation directory missing after installation"

    log "Documentation verified"
}

print_environment_hint() {
    (( DRY_RUN )) && return 0

    case ":${PATH}:" in
        *":${PREFIX}/bin:"*)
            return 0
            ;;
    esac

    printf '\n'
    log "Add VFConf to PATH:"

    case "$(detect_os)" in
        windows)
            printf '  Add %s/bin to your Windows PATH.\n' "$PREFIX"
            ;;

        *)
            printf '  export PATH="%s/bin:$PATH"\n' "$PREFIX"
            ;;
    esac
}

print_summary() {
    printf '\n'

    log "Installation summary"

    printf '  OS:            %s\n' "$(detect_os)"
    printf '  architecture:  %s\n' "$(detect_architecture)"
    printf '  profile:       %s\n' "$PROFILE"
    printf '  prefix:        %s\n' "$PREFIX"
    printf '  executables:   %s\n' "${#VFCONF_EXECUTABLES[@]}"
    printf '  binaries:      %s/bin\n' "$PREFIX"

    if (( INSTALL_DATA )); then
        printf '  data:          %s/share/vfconf\n' "$PREFIX"
    else
        printf '  data:          disabled\n'
    fi

    if (( INSTALL_DOCS )); then
        printf '  documentation: %s/share/doc/vfconf\n' "$PREFIX"
    else
        printf '  documentation: disabled\n'
    fi

    if (( RUN_TESTS )); then
        printf '  tests:         passed\n'
    else
        printf '  tests:         not requested\n'
    fi

    if (( RUN_DIAGNOSTICS )); then
        printf '  diagnostics:   passed\n'
    else
        printf '  diagnostics:   skipped\n'
    fi

    if (( DRY_RUN )); then
        printf '  mode:          dry-run\n'
        log "Dry run completed"
    else
        printf '  mode:          installed\n'
        log "VFConf installation successful"
    fi
}

on_error() {
    local exit_code=$?
    local line="${BASH_LINENO[0]:-unknown}"

    error "installation failed at line ${line} (exit ${exit_code})"

    exit "$exit_code"
}

main() {
    trap on_error ERR

    parse_arguments "$@"

    cd -- "$PROJECT_ROOT"

    check_project
    normalize_prefix
    check_tools
    make_dune_args

    log "Project root: ${PROJECT_ROOT}"
    log "Installation prefix: ${PREFIX}"
    log "Profile: ${PROFILE}"
    log "Executables: ${#VFCONF_EXECUTABLES[@]}"

    if (( DRY_RUN )); then
        log "Dry-run mode enabled"
    fi

    build_project
    run_tests
    run_diagnostics_gate

    ensure_build_exists

    install_binaries
    install_runtime_data
    install_documentation

    verify_installation
    verify_runtime_data
    verify_documentation
    verify_cli_help
    verify_cli

    print_environment_hint
    print_summary
}

main "$@"