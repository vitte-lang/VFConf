#!/usr/bin/env bash
#
# VFConf — Vitte Foundation Configuration Language
# scripts/build-linux.sh
#
# Native Linux release builder.
#
# Produces:
#   - portable tar.gz
#   - Debian package when dpkg-deb is available
#   - SHA-256 checksums
#
# Builds only for the CURRENT Linux architecture/toolchain.

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
CREATE_DEB=1
CHECKSUMS=1
VERBOSE=0
JOBS=""

DUNE_ARGS=()

log() {
    printf '[vfconf-linux] %s\n' "$*"
}

warn() {
    printf '[vfconf-linux] warning: %s\n' "$*" >&2
}

die() {
    printf '[vfconf-linux] error: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage:
  scripts/build-linux.sh [options]

Options:
  --dev                 Use Dune dev profile.
  --release             Use Dune release profile (default).
  --profile NAME        Use custom Dune profile.

  --clean               Clean before build (default).
  --no-clean            Do not run dune clean.

  --test                Run dune runtest.

  --diagnostics         Run diagnostics gate (default).
  --no-diagnostics      Skip diagnostics gate.

  --deb                 Build Debian package (default).
  --no-deb              Do not build Debian package.

  --no-checksum         Disable SHA-256 generation.

  -j, --jobs N          Parallel Dune jobs.
  -v, --verbose         Verbose Dune output.
  -h, --help            Show this help.

Examples:
  scripts/build-linux.sh
  scripts/build-linux.sh --test
  scripts/build-linux.sh --no-diagnostics
  scripts/build-linux.sh --release --test
  scripts/build-linux.sh -j 4
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

            --deb)
                CREATE_DEB=1
                ;;

            --no-deb)
                CREATE_DEB=0
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

detect_architecture() {
    case "$(uname -m)" in
        x86_64|amd64)       printf 'x86_64\n' ;;
        i686)               printf 'i686\n' ;;
        i586)               printf 'i586\n' ;;
        i486)               printf 'i486\n' ;;
        i386)               printf 'i386\n' ;;
        aarch64|arm64)      printf 'aarch64\n' ;;
        armv8*)             printf 'armv8\n' ;;
        armv7*|armhf)       printf 'armv7\n' ;;
        armv6*)             printf 'armv6\n' ;;
        armv5*)             printf 'armv5\n' ;;
        ppc64le)            printf 'ppc64le\n' ;;
        ppc64)              printf 'ppc64\n' ;;
        powerpc|ppc)        printf 'powerpc\n' ;;
        riscv64)            printf 'riscv64\n' ;;
        riscv32)            printf 'riscv32\n' ;;
        mips64el)           printf 'mips64el\n' ;;
        mips64)             printf 'mips64\n' ;;
        mipsel)             printf 'mipsel\n' ;;
        mips)               printf 'mips\n' ;;
        sparc64)            printf 'sparc64\n' ;;
        sparc)              printf 'sparc\n' ;;
        s390x)              printf 's390x\n' ;;
        *)                  uname -m ;;
    esac
}

detect_libc() {
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

check_host() {
    [[ "$(uname -s)" == "Linux" ]] ||
        die "this builder must run on Linux"
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
        log "Cleaning"
        dune clean
    fi

    log "Building ${PROFILE}"

    dune build \
        "${DUNE_ARGS[@]}" \
        bin/main.exe \
        bin/check.exe \
        bin/dump.exe \
        bin/fmt.exe

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
        warn "full diagnostics gate unavailable; using static audit"

        python3 \
            "${PROJECT_ROOT}/scripts/audit-diagnostics.py"

        log "Diagnostics audit passed"
        return 0
    fi

    die "diagnostics requested but diagnostics gate is unavailable"
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

    local binary
    local path

    for binary in main check dump fmt; do
        path="$(find_built_binary "$binary")" ||
            die "compiled binary not found: ${binary}.exe"

        [[ -s "$path" ]] ||
            die "compiled binary is empty: $path"

        [[ -x "$path" ]] ||
            die "compiled binary is not executable: $path"
    done

    log "Binaries verified"
}

copy_executable() {
    local build_name="$1"
    local destination="$2"
    local source

    source="$(find_built_binary "$build_name")" ||
        die "missing executable: ${build_name}.exe"

    install -m 0755 \
        "$source" \
        "$destination"
}

copy_data() {
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
    local libc="$4"

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
os=linux
architecture=${architecture}
libc=${libc}
profile=${PROFILE}
ocaml=$(ocamlc -version)
dune=$(dune --version)
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

create_portable() {
    local version="$1"
    local architecture="$2"
    local libc="$3"

    local name="vfconf-${version}-linux-${architecture}-${libc}"
    local destination="${DIST_DIR}/${name}"
    local archive="${DIST_DIR}/${name}.tar.gz"

    log "Creating portable distribution: ${name}"

    rm -rf -- "$destination"

    mkdir -p \
        "${destination}/bin"

    copy_executable \
        main \
        "${destination}/bin/vfconf"

    copy_executable \
        check \
        "${destination}/bin/vfconf-check"

    copy_executable \
        dump \
        "${destination}/bin/vfconf-dump"

    copy_executable \
        fmt \
        "${destination}/bin/vfconf-fmt"

    copy_data "$destination"

    write_build_info \
        "$destination" \
        "$version" \
        "$architecture" \
        "$libc"

    create_manifest "$destination"

    log "Creating tar.gz"

    (
        cd -- "$DIST_DIR"

        rm -f -- "${name}.tar.gz"

        tar -czf \
            "${name}.tar.gz" \
            "$name"
    )

    [[ -s "$archive" ]] ||
        die "portable archive was not created"

    checksum_file "$archive"

    log "Created: dist/${name}.tar.gz"
}

debian_architecture() {
    case "$1" in
        x86_64)
            printf 'amd64\n'
            ;;

        i686|i586|i486|i386)
            printf 'i386\n'
            ;;

        aarch64|armv8)
            printf 'arm64\n'
            ;;

        armv7)
            printf 'armhf\n'
            ;;

        armv6|armv5)
            printf 'armel\n'
            ;;

        ppc64le)
            printf 'ppc64el\n'
            ;;

        ppc64)
            printf 'ppc64\n'
            ;;

        powerpc)
            printf 'powerpc\n'
            ;;

        riscv64)
            printf 'riscv64\n'
            ;;

        s390x)
            printf 's390x\n'
            ;;

        mips64el)
            printf 'mips64el\n'
            ;;

        mipsel)
            printf 'mipsel\n'
            ;;

        *)
            return 1
            ;;
    esac
}

create_deb() {
    (( CREATE_DEB )) || {
        log "Debian package disabled"
        return 0
    }

    local version="$1"
    local architecture="$2"

    if ! command_exists dpkg-deb; then
        warn "dpkg-deb unavailable; skipping .deb"
        return 0
    fi

    local deb_arch

    deb_arch="$(debian_architecture "$architecture")" || {
        warn "no Debian architecture mapping for ${architecture}"
        return 0
    }

    local root="${DIST_DIR}/.vfconf-deb-root"
    local output="${DIST_DIR}/vfconf_${version}_${deb_arch}.deb"

    log "Creating Debian package (${deb_arch})"

    rm -rf -- "$root"

    mkdir -p \
        "${root}/DEBIAN" \
        "${root}/usr/bin" \
        "${root}/usr/share/vfconf" \
        "${root}/usr/share/doc/vfconf"

    cat > "${root}/DEBIAN/control" <<EOF
Package: vfconf
Version: ${version}
Section: devel
Priority: optional
Architecture: ${deb_arch}
Maintainer: Vincent Rousseau
Description: Vitte Foundation Configuration Language
 VFConf is a structured configuration language using .vf.conf files.
EOF

    copy_executable \
        main \
        "${root}/usr/bin/vfconf"

    copy_executable \
        check \
        "${root}/usr/bin/vfconf-check"

    copy_executable \
        dump \
        "${root}/usr/bin/vfconf-dump"

    copy_executable \
        fmt \
        "${root}/usr/bin/vfconf-fmt"

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
                "${root}/usr/share/vfconf/"
        fi
    done

    local file

    for file in \
        README.md \
        CHANGELOG.md \
        LICENSE
    do
        if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
            cp -- \
                "${PROJECT_ROOT}/${file}" \
                "${root}/usr/share/doc/vfconf/"
        fi
    done

    rm -f -- "$output"

    dpkg-deb \
        --root-owner-group \
        --build \
        "$root" \
        "$output"

    rm -rf -- "$root"

    [[ -s "$output" ]] ||
        die "Debian package creation failed"

    checksum_file "$output"

    log "Created: ${output#"$PROJECT_ROOT"/}"
}

create_rpm_notice() {
    if command_exists rpmbuild; then
        log "rpmbuild detected; dedicated vfconf.spec required"
    else
        warn "rpmbuild unavailable; skipping RPM"
    fi
}

create_apk_notice() {
    if command_exists abuild; then
        log "Alpine abuild detected; dedicated APKBUILD required"
    else
        warn "abuild unavailable; skipping APK"
    fi
}

main() {
    parse_arguments "$@"

    cd -- "$PROJECT_ROOT"

    check_host
    check_project

    local version
    local architecture
    local libc

    version="$(project_version)"
    architecture="$(detect_architecture)"
    libc="$(detect_libc)"

    [[ -n "$version" ]] ||
        die "unable to determine VFConf version"

    echo "============================================================"
    echo " VFConf Linux builder"
    echo "============================================================"
    echo " Version:      ${version}"
    echo " Architecture: ${architecture}"
    echo " libc:         ${libc}"
    echo " Profile:      ${PROFILE}"
    echo "============================================================"

    check_tools
    make_dune_args

    mkdir -p -- "$DIST_DIR"

    build_project
    verify_binaries

    run_tests
    run_diagnostics

    # Release artifacts are created only after validation.
    create_portable \
        "$version" \
        "$architecture" \
        "$libc"

    create_deb \
        "$version" \
        "$architecture"

    create_rpm_notice
    create_apk_notice

    echo
    echo "============================================================"
    echo " VFConf Linux build successful"
    echo "============================================================"
    printf '  version:      %s\n' "$version"
    printf '  architecture: %s\n' "$architecture"
    printf '  libc:         %s\n' "$libc"
    printf '  profile:      %s\n' "$PROFILE"

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
