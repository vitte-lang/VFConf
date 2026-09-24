set -Eeuo pipefail

IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd -P)"

DIST_DIR="${PROJECT_ROOT}/dist"

OUTPUT_DIR="${DIST_DIR}/deb"

PACKAGE_NAME="vfconf"

MAINTAINER="Vincent Rousseau"

DESCRIPTION="Vitte Foundation Configuration Language"

BINARIES=(

    vfconf

    vfconf-check

    vfconf-dump

    vfconf-fmt

)

# VFConf architecture name -> Debian architecture name

ARCHITECTURES=(

    "x86_64:amd64"

    "i686:i386"

    "i586:i386"

    "i486:i386"

    "i386:i386"

    "aarch64:arm64"

    "armv7:armhf"

    "armv6:armel"

    "armv5:armel"

    "ppc64le:ppc64el"

    "ppc64:ppc64"

    "powerpc:powerpc"

    "riscv64:riscv64"

    "mips64el:mips64el"

    "mipsel:mipsel"

    "s390x:s390x"

)

log() {

    printf '[vfconf-deb] %s\n' "$*"

}

warn() {

    printf '[vfconf-deb] warning: %s\n' "$*" >&2

}

die() {

    printf '[vfconf-deb] error: %s\n' "$*" >&2

    exit 1

}

version() {

    local value=""

    if [[ -s "${PROJECT_ROOT}/VERSION" ]]; then

        value="$(tr -d '[:space:]' < "${PROJECT_ROOT}/VERSION")"

    fi

    if [[ -z "$value" && -f "${PROJECT_ROOT}/dune-project" ]]; then

        value="$(

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

    [[ -n "$value" ]] ||

        die "unable to determine VFConf version"

    printf '%s\n' "$value"

}

require_tools() {

    command -v dpkg-deb >/dev/null 2>&1 ||

        die "dpkg-deb is required"

    command -v install >/dev/null 2>&1 ||

        die "install is required"

}

copy_runtime_data() {

    local root="$1"

    local directory

    mkdir -p "${root}/usr/share/vfconf"

    for directory in \

        config \

        languages \

        themes \

        schemas

    do

        if [[ -d "${PROJECT_ROOT}/${directory}" ]]; then

            cp -R \

                "${PROJECT_ROOT}/${directory}" \

                "${root}/usr/share/vfconf/${directory}"

        fi

    done

}

copy_documentation() {

    local root="$1"

    local doc_dir="${root}/usr/share/doc/vfconf"

    local file

    mkdir -p "$doc_dir"

    for file in \

        README.md \

        LICENSE \

        CHANGELOG.md \

        VERSION

    do

        if [[ -f "${PROJECT_ROOT}/${file}" ]]; then

            cp \

                "${PROJECT_ROOT}/${file}" \

                "${doc_dir}/${file}"

        fi

    done

    if [[ -d "${PROJECT_ROOT}/docs" ]]; then

        cp -R \

            "${PROJECT_ROOT}/docs" \

            "${doc_dir}/docs"

    fi

}

find_binary_directory() {

    local architecture="$1"

    local candidates=(

        "${DIST_DIR}/vfconf-linux-${architecture}/bin"

        "${DIST_DIR}/linux-${architecture}/bin"

        "${DIST_DIR}/${architecture}/bin"

    )

    local candidate

    for candidate in "${candidates[@]}"; do

        if [[ -d "$candidate" ]]; then

            printf '%s\n' "$candidate"

            return 0

        fi

    done

    return 1

}

verify_binary_set() {

    local directory="$1"

    local binary

    for binary in "${BINARIES[@]}"; do

        [[ -s "${directory}/${binary}" ]] ||

            return 1

    done

    return 0

}

build_package() {

    local source_arch="$1"

    local deb_arch="$2"

    local version="$3"

    local binary_dir

    local staging

    local package

    binary_dir="$(find_binary_directory "$source_arch")" || {

        warn "${source_arch}: binaries unavailable — skipped"

        return 0

    }

    verify_binary_set "$binary_dir" || {

        warn "${source_arch}: incomplete binary set — skipped"

        return 0

    }

    staging="$(

        mktemp -d \

            "${TMPDIR:-/tmp}/vfconf-deb-${source_arch}.XXXXXX"

    )"

    trap 'rm -rf "${staging:-}"' RETURN

    mkdir -p \

        "${staging}/DEBIAN" \

        "${staging}/usr/bin"

    local binary

    for binary in "${BINARIES[@]}"; do

        install \

            -m 0755 \

            "${binary_dir}/${binary}" \

            "${staging}/usr/bin/${binary}"

    done

    copy_runtime_data "$staging"

    copy_documentation "$staging"

    cat > "${staging}/DEBIAN/control" <<EOF

Package: ${PACKAGE_NAME}

Version: ${version}

Section: devel

Priority: optional

Architecture: ${deb_arch}

Maintainer: ${MAINTAINER}

Description: ${DESCRIPTION}

 VFConf is the Vitte Foundation Configuration Language.

 This package contains the VFConf command-line tools and runtime data.

EOF

    package="${OUTPUT_DIR}/${PACKAGE_NAME}_${version}_${deb_arch}.deb"

    rm -f "$package"

    log "Building ${deb_arch} package from ${source_arch}"

    if dpkg-deb --help 2>&1 | grep -q -- '--root-owner-group'; then

        dpkg-deb \

            --root-owner-group \

            --build \

            "$staging" \

            "$package"

    else

        dpkg-deb \

            --build \

            "$staging" \

            "$package"

    fi

    [[ -s "$package" ]] ||

        die "package creation failed: $package"

    log "Created: $package"

    rm -rf "$staging"

    trap - RETURN

}

main() {

    require_tools

    local version

    version="$(version)"

    mkdir -p "$OUTPUT_DIR"

    echo "============================================================"

    echo " VFConf Debian multi-architecture packaging"

    echo "============================================================"

    printf ' Version: %s\n' "$version"

    printf ' Output:  %s\n' "$OUTPUT_DIR"

    echo "============================================================"

    local entry

    local source_arch

    local deb_arch

    for entry in "${ARCHITECTURES[@]}"; do

        source_arch="${entry%%:*}"

        deb_arch="${entry#*:}"

        build_package \

            "$source_arch" \

            "$deb_arch" \

            "$version"

    done

    echo

    echo "============================================================"

    echo " VFConf Debian packaging completed"

    echo "============================================================"

    find "$OUTPUT_DIR" \

        -maxdepth 1 \

        -type f \

        -name '*.deb' \

        -print 2>/dev/null || true

}

main "$@"

SH

chmod +x packaging/linux/deb/universal.sh

bash -n packaging/linux/deb/universal.sh &&

echo "[OK] packaging/linux/deb/universal.sh syntax valid"