#!/usr/bin/env bash
#
# VFConf — Vitte Foundation Configuration Language
# scripts/build.sh
#
# Build, validate, test and package VFConf for the CURRENT host.
#
# Cross-platform releases must be produced by the corresponding
# native toolchain, CI runner or correctly configured cross-compiler.

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
readonly VERSION_FILE="${PROJECT_ROOT}/VERSION"

PROFILE="release"
CLEAN=0
RUN_TESTS=0
RUN_DIAGNOSTICS=1
BUILD_DOCS=0
PACKAGE=1
CREATE_ARCHIVE=1
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
    printf '[vfconf] %s\n' "$*"
}

warn() {
    printf '[vfconf] warning: %s\n' "$*" >&2
}

error() {
    printf '[vfconf] error: %s\n' "$*" >&2
}

die() {
    error "$*"
    exit 1
}

usage() {
    cat <<'EOF'
Usage:
  scripts/build.sh [options]

Build:
  --dev                 Dune dev profile.
  --release             Dune release profile (default).
  --profile NAME        Custom Dune profile.
  --clean               Run dune clean first.
  --no-clean            Do not clean before build.
  -j, --jobs N          Parallel build jobs.

Validation:
  --test                Run dune runtest.
  --diagnostics         Run final diagnostics gate (default).
  --no-diagnostics      Skip final diagnostics gate.

Documentation:
  --docs                Build Dune documentation.

Packaging:
  --package             Export dist/ distribution (default).
  --no-package          Do not export dist/ distribution.
  --archive             Create release archive (default).
  --no-archive          Keep distribution directory only.
  --checksum            Generate SHA-256 files (default).
  --no-checksum         Do not generate SHA-256 files.

General:
  -v, --verbose         Verbose Dune output.
  -h, --help            Show this help.

Examples:
  scripts/build.sh
  scripts/build.sh --clean --release
  scripts/build.sh --release --test
  scripts/build.sh --clean --release --test --docs
  scripts/build.sh --no-diagnostics
  scripts/build.sh --no-package
  scripts/build.sh -j 4
EOF
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_command() {
    command_exists "$1" ||
        die "required command not found: $1"
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

detect_libc() {
    [[ "$(detect_os)" == "linux" ]] || {
        printf 'native\n'
        return
    }

    if command_exists ldd; then
        local output
        output="$(ldd --version 2>&1 || true)"

        if grep -qi musl <<<"$output"; then
            printf 'musl\n'
            return
        fi

        if grep -Eqi \
            'glibc|GNU libc|GNU C Library' \
            <<<"$output"
        then
            printf 'gnu\n'
            return
        fi
    fi

    if find /lib /usr/lib \
        -maxdepth 2 \
        -name 'ld-musl-*.so.1' \
        -print \
        -quit \
        2>/dev/null |
        grep -q .
    then
        printf 'musl\n'
        return
    fi

    printf 'gnu\n'
}

executable_suffix() {
    if [[ "$(detect_os)" == "windows" ]]; then
        printf '.exe\n'
    else
        printf '\n'
    fi
}

platform_name() {
    local os
    local arch
    local libc

    os="$(detect_os)"
    arch="$(detect_architecture)"

    if [[ "$os" == "linux" ]]; then
        libc="$(detect_libc)"
        printf '%s-%s-%s\n' "$os" "$arch" "$libc"
    else
        printf '%s-%s\n' "$os" "$arch"
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

            --docs)
                BUILD_DOCS=1
                ;;

            --package)
                PACKAGE=1
                ;;

            --no-package)
                PACKAGE=0
                ;;

            --archive)
                CREATE_ARCHIVE=1
                ;;

            --no-archive)
                CREATE_ARCHIVE=0
                ;;

            --checksum)
                CHECKSUMS=1
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

check_project() {
    [[ -f "${PROJECT_ROOT}/dune-project" ]] ||
        die "dune-project not found"

    [[ -f "${PROJECT_ROOT}/lib/dune" ]] ||
        die "lib/dune not found"

    [[ -f "${PROJECT_ROOT}/bin/dune" ]] ||
        die "bin/dune not found"

    local version
    version="$(project_version)"

    [[ -n "$version" ]] ||
        die "unable to determine VFConf version"
}

check_tools() {
    local tools=(
        dune
        ocamlc
        ocamllex
        menhir
        find
        sort
    )

    local tool

    for tool in "${tools[@]}"; do
        require_command "$tool"
    done

    if (( PACKAGE && CREATE_ARCHIVE )); then
        require_command tar
    fi

    log "OCaml:  $(ocamlc -version)"
    log "Dune:   $(dune --version)"
    log "Menhir: $(menhir --version 2>/dev/null || printf 'available')"

    if command_exists ocamlopt; then
        log "Native compiler: available"
    else
        warn "ocamlopt unavailable; native compilation may fail"
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

clean_project() {
    (( CLEAN )) || return 0

    log "Cleaning previous build"
    dune clean
}

build_project() {
    log "Building VFConf"
    log "Profile: ${PROFILE}"
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

    log "Compilation completed"
}

run_tests() {
    (( RUN_TESTS )) || return 0

    log "Running tests"

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
        require_command python3

        warn "full diagnostics gate unavailable; running static audit only"

        python3 \
            "${PROJECT_ROOT}/scripts/audit-diagnostics.py"

        log "Static diagnostics audit passed"
        return 0
    fi

    die "diagnostics requested but no diagnostics gate is available"
}

build_documentation() {
    (( BUILD_DOCS )) || return 0

    log "Building documentation"

    dune build \
        "${DUNE_ARGS[@]}" \
        @doc

    log "Documentation completed"
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

verify_build_outputs() {
    log "Verifying compiled executables"

    local entry
    local binary
    local public_name
    local path
    local count=0

    for entry in "${VFCONF_EXECUTABLES[@]}"; do
        binary="${entry%%:*}"
        public_name="${entry#*:}"

        path="$(find_built_binary "$binary")" ||
            die "compiled executable unavailable: ${binary}.exe (${public_name})"

        [[ -s "$path" ]] ||
            die "compiled executable is empty: $path"

        if [[ "$(detect_os)" != "windows" ]]; then
            [[ -x "$path" ]] ||
                die "compiled executable is not executable: $path"
        fi

        if (( VERBOSE )); then
            printf '  %-24s %s\n' "$public_name" "$path"
        fi

        ((count += 1))
    done

    [[ "$count" -eq "${#VFCONF_EXECUTABLES[@]}" ]] ||
        die "compiled executable count mismatch"

    log "All ${count} compiled executables verified"
}

copy_executable() {
    local build_name="$1"
    local destination="$2"
    local source

    source="$(find_built_binary "$build_name")" ||
        die "cannot locate ${build_name}.exe"

    cp -- "$source" "$destination"

    if [[ "$(detect_os)" != "windows" ]]; then
        chmod 0755 "$destination"
    fi
}

install_all_executables() {
    local destination="$1"
    local suffix="$2"

    local entry
    local build_name
    local public_name

    mkdir -p -- "$destination"

    for entry in "${VFCONF_EXECUTABLES[@]}"; do
        build_name="${entry%%:*}"
        public_name="${entry#*:}"

        copy_executable \
            "$build_name" \
            "${destination}/${public_name}${suffix}"
    done
}

verify_distribution_executables() {
    local destination="$1"
    local suffix="$2"

    local entry
    local public_name
    local path
    local count=0

    for entry in "${VFCONF_EXECUTABLES[@]}"; do
        public_name="${entry#*:}"
        path="${destination}/${public_name}${suffix}"

        [[ -f "$path" ]] ||
            die "distribution executable missing: $path"

        [[ -s "$path" ]] ||
            die "distribution executable is empty: $path"

        if [[ "$(detect_os)" != "windows" ]]; then
            [[ -x "$path" ]] ||
                die "distribution executable is not executable: $path"
        fi

        ((count += 1))
    done

    [[ "$count" -eq "${#VFCONF_EXECUTABLES[@]}" ]] ||
        die "distribution executable count mismatch"
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
        CHANGELOG.md \
        LICENSE \
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

write_build_metadata() {
    local destination="$1"

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
project=${PROJECT_NAME}
version=$(project_version)
profile=${PROFILE}
os=$(detect_os)
architecture=$(detect_architecture)
libc=$(detect_libc)
platform=$(platform_name)
ocaml=$(ocamlc -version)
dune=$(dune --version)
executables=${#VFCONF_EXECUTABLES[@]}
git_commit=${commit}
git_dirty=${dirty}
EOF
}

sha256() {
    local file="$1"

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

    (
        cd -- "$(dirname -- "$file")"

        printf '%s  %s\n' \
            "$hash" \
            "$(basename -- "$file")" \
            > "$(basename -- "$file").sha256"
    )
}

create_binary_manifest() {
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

create_archive() {
    local directory="$1"
    local os="$2"

    (( CREATE_ARCHIVE )) || {
        log "Archive creation disabled"
        return 0
    }

    local parent
    local name
    local archive

    parent="$(dirname -- "$directory")"
    name="$(basename -- "$directory")"

    if [[ "$os" == "windows" ]] &&
       command_exists zip
    then
        archive="${parent}/${name}.zip"

        log "Creating ZIP archive"

        (
            cd -- "$parent"

            rm -f -- "${name}.zip"

            zip -qr \
                "${name}.zip" \
                "$name"
        )
    else
        archive="${parent}/${name}.tar.gz"

        log "Creating tar.gz archive"

        (
            cd -- "$parent"

            rm -f -- "${name}.tar.gz"

            tar -czf \
                "${name}.tar.gz" \
                "$name"
        )
    fi

    [[ -s "$archive" ]] ||
        die "archive creation failed: $archive"

    checksum_file "$archive"

    log "Archive: ${archive#"$PROJECT_ROOT"/}"
}

export_distribution() {
    (( PACKAGE )) || {
        log "Packaging disabled"
        return 0
    }

    local version
    local os
    local platform
    local suffix
    local destination

    version="$(project_version)"
    os="$(detect_os)"
    platform="$(platform_name)"
    suffix="$(executable_suffix)"

    destination="${DIST_DIR}/${PROJECT_NAME}-${version}-${platform}"

    log "Creating distribution"
    log "Platform: ${platform}"
    log "Destination: ${destination}"

    rm -rf -- "$destination"

    mkdir -p \
        "${destination}/bin"

    install_all_executables \
        "${destination}/bin" \
        "$suffix"

    verify_distribution_executables \
        "${destination}/bin" \
        "$suffix"

    copy_runtime_data "$destination"
    copy_documentation "$destination"
    write_build_metadata "$destination"
    create_binary_manifest "$destination"

    create_archive \
        "$destination" \
        "$os"

    log "Distribution created with ${#VFCONF_EXECUTABLES[@]} executables"
}

print_result() {
    local version
    local platform
    local os

    version="$(project_version)"
    platform="$(platform_name)"
    os="$(detect_os)"

    printf '\n'

    log "Build successful"

    printf '  version:      %s\n' "$version"
    printf '  OS:           %s\n' "$os"
    printf '  architecture: %s\n' "$(detect_architecture)"

    if [[ "$os" == "linux" ]]; then
        printf '  libc:         %s\n' "$(detect_libc)"
    fi

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

    if (( BUILD_DOCS )); then
        printf '  documentation: built\n'
    else
        printf '  documentation: not requested\n'
    fi

    if (( PACKAGE )); then
        printf '  distribution: dist/%s-%s-%s\n' \
            "$PROJECT_NAME" \
            "$version" \
            "$platform"

        if (( CREATE_ARCHIVE )); then
            printf '  archive:      created\n'
        else
            printf '  archive:      disabled\n'
        fi
    else
        printf '  distribution: disabled\n'
    fi
}

on_error() {
    local exit_code=$?
    local line="${BASH_LINENO[0]:-unknown}"

    error "build failed at line ${line} (exit ${exit_code})"

    exit "$exit_code"
}

main() {
    trap on_error ERR

    parse_arguments "$@"

    cd -- "$PROJECT_ROOT"

    check_project
    check_tools
    make_dune_args

    mkdir -p -- "$DIST_DIR"

    log "Project root: ${PROJECT_ROOT}"
    log "Platform: $(platform_name)"
    log "VFConf executables: ${#VFCONF_EXECUTABLES[@]}"

    clean_project
    build_project
    verify_build_outputs
    run_tests
    run_diagnostics_gate
    build_documentation

    export_distribution

    print_result
}

main "$@"