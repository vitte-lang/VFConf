#!/usr/bin/env bash

set -Eeuo pipefail

IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../../.." && pwd -P)"

DIST_DIR="${PROJECT_ROOT}/dist"

OUTPUT_DIR="${DIST_DIR}/rpm"

PACKAGE_NAME="vfconf"

SUMMARY="Vitte Foundation Configuration Language"

LICENSE="MIT"

VENDOR="Vitte Foundation"

PACKAGER="Vincent Rousseau"

BINARIES=(

    vfconf

    vfconf-check

    vfconf-dump

    vfconf-fmt

)

# VFConf architecture -> RPM architecture

ARCHITECTURES=(

    "x86_64:x86_64"

    "i686:i686"

    "i586:i586"

    "i486:i486"

    "i386:i386"

    "aarch64:aarch64"

    "armv7:armv7hl"

    "armv6:armv6hl"

    "armv5:armv5tel"

    "ppc64le:ppc64le"

    "ppc64:ppc64"

    "powerpc:ppc"

    "riscv64:riscv64"

    "s390x:s390x"

    "mips64:mips64"

    "mips64el:mips64el"

    "mips:mips"

    "mipsel:mipsel"

    "sparc64:sparc64"

    "sparc:sparc"

)

log() {

    printf '[vfconf-rpm] %s\n' "$*"

}

warn() {

    printf '[vfconf-rpm] warning: %s\n' "$*" >&2

}

die() {

    printf '[vfconf-rpm] error: %s\n' "$*" >&2

    exit 1

}

project_version() {

    local version=""

    if [[ -s "${PROJECT_ROOT}/VERSION" ]]; then

        version="$(tr -d '[:space:]' < "${PROJECT_ROOT}/VERSION")"

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

    [[ -n "$version" ]] ||

        die "unable to determine VFConf version"

    printf '%s\n' "$version"

}

require_tools() {

    command -v rpmbuild >/dev/null 2>&1 ||

        die "rpmbuild is required"

    command -v install >/dev/null 2>&1 ||

        die "install is required"

    command -v tar >/dev/null 2>&1 ||

        die "tar is required"

}

find_binary_directory() {

    local architecture="$1"

    local candidate

    for candidate in \

        "${DIST_DIR}/vfconf-linux-${architecture}/bin" \

        "${DIST_DIR}/linux-${architecture}/bin" \

        "${DIST_DIR}/${architecture}/bin"

    do

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

    local destination="${root}/usr/share/doc/vfconf"

    local file

    mkdir -p "$destination"

    for file in \

        README.md \

        LICENSE \

        CHANGELOG.md \

        VERSION

    do

        if [[ -f "${PROJECT_ROOT}/${file}" ]]; then

            cp \

                "${PROJECT_ROOT}/${file}" \

                "${destination}/${file}"

        fi

    done

    if [[ -d "${PROJECT_ROOT}/docs" ]]; then

        cp -R \

            "${PROJECT_ROOT}/docs" \

            "${destination}/docs"

    fi

}

create_payload() {

    local architecture="$1"

    local binary_directory="$2"

    local version="$3"

    local work="$4"

    local source_root="${work}/${PACKAGE_NAME}-${version}"

    local binary

    mkdir -p \

        "${source_root}/usr/bin" \

        "${source_root}/usr/share/vfconf" \

        "${source_root}/usr/share/doc/vfconf"

    for binary in "${BINARIES[@]}"; do

        install \

            -m 0755 \

            "${binary_directory}/${binary}" \

            "${source_root}/usr/bin/${binary}"

    done

    copy_runtime_data "$source_root"

    copy_documentation "$source_root"

    cat > "${source_root}/BUILD-INFO" <<EOF

project=VFConf

version=${version}

platform=linux

architecture=${architecture}

package=rpm

EOF

    tar \

        -C "$work" \

        -czf "${work}/${PACKAGE_NAME}-${version}.tar.gz" \

        "${PACKAGE_NAME}-${version}"

    printf '%s\n' "${work}/${PACKAGE_NAME}-${version}.tar.gz"

}

create_spec() {

    local version="$1"

    local rpm_arch="$2"

    local spec="$3"

    cat > "$spec" <<EOF

Name:           ${PACKAGE_NAME}

Version:        ${version}

Release:        1%{?dist}

Summary:        ${SUMMARY}

License:        ${LICENSE}

BuildArch:      ${rpm_arch}

Source0:        %{name}-%{version}.tar.gz

%description

VFConf is the Vitte Foundation Configuration Language.

This package provides:

- vfconf

- vfconf-check

- vfconf-dump

- vfconf-fmt

%prep

%setup -q

%build

# Precompiled VFConf binaries.

%install

rm -rf %{buildroot}

mkdir -p %{buildroot}/usr/bin

mkdir -p %{buildroot}/usr/share/vfconf

mkdir -p %{buildroot}/usr/share/doc/vfconf

cp -a usr/bin/. %{buildroot}/usr/bin/

if [ -d usr/share/vfconf ]; then

    cp -a usr/share/vfconf/. %{buildroot}/usr/share/vfconf/

fi

if [ -d usr/share/doc/vfconf ]; then

    cp -a usr/share/doc/vfconf/. %{buildroot}/usr/share/doc/vfconf/

fi

%files

%defattr(-,root,root,-)

/usr/bin/vfconf

/usr/bin/vfconf-check

/usr/bin/vfconf-dump

/usr/bin/vfconf-fmt

%dir /usr/share/vfconf

/usr/share/vfconf/*

%dir /usr/share/doc/vfconf

/usr/share/doc/vfconf/*

%changelog

* Thu Sep 24 2026 Vincent Rousseau <packaging@localhost> - ${version}-1

- VFConf ${version}

EOF

}

build_rpm() {

    local source_arch="$1"

    local rpm_arch="$2"

    local version="$3"

    local binary_directory

    local work

    local topdir

    local spec

    local source_archive

    binary_directory="$(find_binary_directory "$source_arch")" || {

        warn "${source_arch}: compiled distribution unavailable — skipped"

        return 0

    }

    verify_binary_set "$binary_directory" || {

        warn "${source_arch}: incomplete binary set — skipped"

        return 0

    }

    work="$(

        mktemp -d \

            "${TMPDIR:-/tmp}/vfconf-rpm-${source_arch}.XXXXXX"

    )"

    topdir="${work}/rpmbuild"

    mkdir -p \

        "${topdir}/BUILD" \

        "${topdir}/BUILDROOT" \

        "${topdir}/RPMS" \

        "${topdir}/SOURCES" \

        "${topdir}/SPECS" \

        "${topdir}/SRPMS"

    source_archive="$(

        create_payload \

            "$source_arch" \

            "$binary_directory" \

            "$version" \

            "$work"

    )"

    cp \

        "$source_archive" \

        "${topdir}/SOURCES/${PACKAGE_NAME}-${version}.tar.gz"

    spec="${topdir}/SPECS/${PACKAGE_NAME}.spec"

    create_spec \

        "$version" \

        "$rpm_arch" \

        "$spec"

    log "Building ${rpm_arch} RPM from ${source_arch}"

    rpmbuild \

        --define "_topdir ${topdir}" \

        --target "$rpm_arch" \

        -bb \

        "$spec"

    local rpm

    local found=0

    while IFS= read -r rpm; do

        [[ -f "$rpm" ]] || continue

        cp \

            "$rpm" \

            "$OUTPUT_DIR/"

        log "Created: ${OUTPUT_DIR}/$(basename "$rpm")"

        found=1

    done < <(

        find "${topdir}/RPMS" \

            -type f \

            -name '*.rpm' \

            -print

    )

    (( found )) ||

        die "rpmbuild produced no RPM for ${rpm_arch}"

    rm -rf "$work"

}

create_checksums() {

    command -v sha256sum >/dev/null 2>&1 || {

        warn "sha256sum unavailable; checksum manifest skipped"

        return 0

    }

    local manifest="${OUTPUT_DIR}/SHA256SUMS"

    : > "$manifest"

    local rpm

    while IFS= read -r rpm; do

        (

            cd "$OUTPUT_DIR"

            sha256sum "$(basename "$rpm")"

        ) >> "$manifest"

    done < <(

        find "$OUTPUT_DIR" \

            -maxdepth 1 \

            -type f \

            -name '*.rpm' \

            -print |

        LC_ALL=C sort

    )

    log "Created: $manifest"

}

main() {

    require_tools

    local version

    version="$(project_version)"

    mkdir -p "$OUTPUT_DIR"

    echo "============================================================"

    echo " VFConf RPM multi-architecture packaging"

    echo "============================================================"

    printf ' Version: %s\n' "$version"

    printf ' Output:  %s\n' "$OUTPUT_DIR"

    echo "============================================================"

    local entry

    local source_arch

    local rpm_arch

    for entry in "${ARCHITECTURES[@]}"; do

        source_arch="${entry%%:*}"

        rpm_arch="${entry#*:}"

        build_rpm \

            "$source_arch" \

            "$rpm_arch" \

            "$version"

    done

    create_checksums

    echo

    echo "============================================================"

    echo " VFConf RPM packaging completed"

    echo "============================================================"

    find "$OUTPUT_DIR" \

        -maxdepth 1 \

        -type f \

        \( -name '*.rpm' -o -name 'SHA256SUMS' \) \

        -print 2>/dev/null || true

}