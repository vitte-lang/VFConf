#!/usr/bin/env bash
#
# VFConf — Vitte Foundation Configuration Language
# scripts/clean.sh
#
# Clean VFConf build, generated, temporary, packaging and distribution
# artifacts without touching project source files.
#
# By default only Dune build artifacts are removed.
#
# Supported cleanup targets:
#   - Dune build tree
#   - release distributions and archives
#   - macOS package roots / .pkg staging
#   - Linux Debian/RPM/APK staging
#   - BSD / FreeBSD package staging
#   - generated lexer/parser artifacts
#   - OCaml compilation artifacts outside _build
#   - project caches
#   - coverage data
#   - generated documentation
#   - temporary/editor files

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

CLEAN_BUILD=1
CLEAN_DIST=0
CLEAN_GENERATED=0
CLEAN_CACHE=0
CLEAN_COVERAGE=0
CLEAN_DOCS=0
CLEAN_TEMP=0
CLEAN_PACKAGING=0
CLEAN_ALL=0
DRY_RUN=0
VERBOSE=0

REMOVED_COUNT=0

log() {
    printf '[vfconf-clean] %s\n' "$*"
}

warn() {
    printf '[vfconf-clean] warning: %s\n' "$*" >&2
}

error() {
    printf '[vfconf-clean] error: %s\n' "$*" >&2
}

die() {
    error "$*"
    exit 1
}

usage() {
    cat <<'EOF'
Usage:
  scripts/clean.sh [options]

Cleanup:
  --build           Clean Dune build artifacts (default).
  --dist            Clean generated distributions in dist/.
  --packaging       Clean package staging directories.
  --generated       Clean generated lexer/parser and OCaml artifacts.
  --cache           Clean project caches.
  --coverage        Clean coverage artifacts.
  --docs            Clean generated documentation.
  --temp            Clean temporary/editor files.
  --all             Clean all generated artifacts, including dist/.

Safety:
  --dry-run         Show what would be removed without removing it.

General:
  -v, --verbose     Show every removed path.
  -h, --help        Show this help.

Examples:
  scripts/clean.sh
  scripts/clean.sh --dist
  scripts/clean.sh --packaging
  scripts/clean.sh --generated
  scripts/clean.sh --coverage
  scripts/clean.sh --all
  scripts/clean.sh --all --dry-run
  scripts/clean.sh --dist --packaging --verbose

Important:
  Source files are never intentionally removed.
  The dist/ directory itself is preserved.
  --dist and --all remove only contents of dist/.
  .git/ is never traversed or removed.
EOF
}

parse_arguments() {
    while (($# > 0)); do
        case "$1" in
            --build)
                CLEAN_BUILD=1
                ;;

            --dist)
                CLEAN_DIST=1
                ;;

            --packaging)
                CLEAN_PACKAGING=1
                ;;

            --generated)
                CLEAN_GENERATED=1
                ;;

            --cache)
                CLEAN_CACHE=1
                ;;

            --coverage)
                CLEAN_COVERAGE=1
                ;;

            --docs)
                CLEAN_DOCS=1
                ;;

            --temp)
                CLEAN_TEMP=1
                ;;

            --all)
                CLEAN_ALL=1
                CLEAN_BUILD=1
                CLEAN_DIST=1
                CLEAN_PACKAGING=1
                CLEAN_GENERATED=1
                CLEAN_CACHE=1
                CLEAN_COVERAGE=1
                CLEAN_DOCS=1
                CLEAN_TEMP=1
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

check_project_root() {
    [[ -n "$PROJECT_ROOT" ]] ||
        die "empty project root"

    [[ "$PROJECT_ROOT" != "/" ]] ||
        die "invalid project root"

    [[ -d "$PROJECT_ROOT" ]] ||
        die "project root does not exist: ${PROJECT_ROOT}"

    [[ -f "${PROJECT_ROOT}/dune-project" ]] ||
        die "dune-project not found in ${PROJECT_ROOT}"

    [[ -f "${PROJECT_ROOT}/lib/dune" ]] ||
        die "lib/dune not found in ${PROJECT_ROOT}"

    [[ -f "${PROJECT_ROOT}/bin/dune" ]] ||
        die "bin/dune not found in ${PROJECT_ROOT}"

    [[ "$DIST_DIR" == "${PROJECT_ROOT}/dist" ]] ||
        die "invalid dist path"
}

safe_path() {
    local path="$1"

    [[ -n "$path" ]] || return 1
    [[ "$path" != "/" ]] || return 1
    [[ "$path" != "$PROJECT_ROOT" ]] || return 1
    [[ "$path" != "${PROJECT_ROOT}/.git" ]] || return 1
    [[ "$path" != "$DIST_DIR" ]] || return 1
    [[ "$path" == "${PROJECT_ROOT}/"* ]] || return 1

    return 0
}

remove_path() {
    local path="$1"

    safe_path "$path" ||
        die "refusing to remove unsafe path: ${path}"

    [[ -e "$path" || -L "$path" ]] ||
        return 0

    if (( DRY_RUN )); then
        printf '[dry-run] rm -rf -- %q\n' "$path"
        ((REMOVED_COUNT += 1))
        return 0
    fi

    if (( VERBOSE )); then
        log "Removing ${path#"$PROJECT_ROOT"/}"
    fi

    rm -rf -- "$path"

    ((REMOVED_COUNT += 1))
}

remove_matching_files() {
    local base="$1"
    shift

    [[ -d "$base" ]] || return 0

    local path

    while IFS= read -r -d '' path; do
        remove_path "$path"
    done < <(
        find "$base" \
            \( \
                -path "${PROJECT_ROOT}/.git" \
                -o -path "${PROJECT_ROOT}/_build" \
                -o -path "${PROJECT_ROOT}/dist" \
            \) -prune \
            -o \
            -type f \
            \( "$@" \) \
            -print0 \
            2>/dev/null
    )
}

clean_build() {
    (( CLEAN_BUILD )) || return 0

    log "Cleaning Dune build artifacts"

    if [[ ! -d "${PROJECT_ROOT}/_build" ]]; then
        (( VERBOSE )) &&
            log "No _build directory"
        return 0
    fi

    if (( DRY_RUN )); then
        printf '[dry-run] dune clean\n'
        ((REMOVED_COUNT += 1))
        return 0
    fi

    if command -v dune >/dev/null 2>&1; then
        (
            cd -- "$PROJECT_ROOT"
            dune clean
        )

        ((REMOVED_COUNT += 1))
    else
        warn "dune not found; removing _build directly"
        remove_path "${PROJECT_ROOT}/_build"
    fi
}

clean_dist() {
    (( CLEAN_DIST )) || return 0

    log "Cleaning distribution artifacts"

    if [[ ! -d "$DIST_DIR" ]]; then
        (( DRY_RUN )) || mkdir -p -- "$DIST_DIR"
        return 0
    fi

    local path

    while IFS= read -r -d '' path; do
        remove_path "$path"
    done < <(
        find "$DIST_DIR" \
            -mindepth 1 \
            -maxdepth 1 \
            -print0 \
            2>/dev/null
    )

    log "dist/ preserved"
}

clean_packaging() {
    (( CLEAN_PACKAGING )) || return 0

    log "Cleaning packaging staging artifacts"

    local paths=(
        "${PROJECT_ROOT}/pkgroot"
        "${PROJECT_ROOT}/package-root"
        "${PROJECT_ROOT}/package_root"
        "${PROJECT_ROOT}/pkg-root"
        "${PROJECT_ROOT}/installer-root"
        "${PROJECT_ROOT}/installer"
        "${PROJECT_ROOT}/packages"
        "${PROJECT_ROOT}/.pkg"
        "${PROJECT_ROOT}/.pkgroot"
        "${PROJECT_ROOT}/.package-root"
        "${PROJECT_ROOT}/.vfconf-pkg-root"
        "${PROJECT_ROOT}/.vfconf-deb-root"
        "${PROJECT_ROOT}/.vfconf-rpm-root"
        "${PROJECT_ROOT}/.vfconf-apk-root"
        "${PROJECT_ROOT}/.vfconf-freebsd-root"
        "${PROJECT_ROOT}/.vfconf-freebsd-manifest"
        "${PROJECT_ROOT}/.vfconf-macos-root"
        "${PROJECT_ROOT}/.vfconf-macos-pkgroot"
        "${PROJECT_ROOT}/.vfconf-macos-scripts"
    )

    local path

    for path in "${paths[@]}"; do
        remove_path "$path"
    done

    if [[ -d "$DIST_DIR" ]]; then
        while IFS= read -r -d '' path; do
            remove_path "$path"
        done < <(
            find "$DIST_DIR" \
                -mindepth 1 \
                -maxdepth 1 \
                \( \
                    -name '.vfconf-*' \
                    -o -name '*.pkgroot' \
                    -o -name '*.staging' \
                    -o -name '.pkg-*' \
                \) \
                -print0 \
                2>/dev/null
        )
    fi
}

clean_generated() {
    (( CLEAN_GENERATED )) || return 0

    log "Cleaning generated lexer/parser artifacts"

    local generated_files=(
        "${PROJECT_ROOT}/lib/lexer/lexer.ml"
        "${PROJECT_ROOT}/lib/parser/parser.ml"
        "${PROJECT_ROOT}/lib/parser/parser.mli"
        "${PROJECT_ROOT}/lib/parser/parser.conflicts"
        "${PROJECT_ROOT}/lib/parser/parser.automaton"
        "${PROJECT_ROOT}/lib/parser/parser.cmly"
    )

    local path

    for path in "${generated_files[@]}"; do
        remove_path "$path"
    done

    log "Cleaning OCaml compilation artifacts outside _build"

    while IFS= read -r -d '' path; do
        remove_path "$path"
    done < <(
        find "$PROJECT_ROOT" \
            \( \
                -path "${PROJECT_ROOT}/.git" \
                -o -path "${PROJECT_ROOT}/_build" \
                -o -path "${PROJECT_ROOT}/dist" \
            \) -prune \
            -o \
            -type f \
            \( \
                -name '*.cmi' \
                -o -name '*.cmo' \
                -o -name '*.cmx' \
                -o -name '*.cmxa' \
                -o -name '*.cma' \
                -o -name '*.cmxs' \
                -o -name '*.annot' \
                -o -name '*.cmt' \
                -o -name '*.cmti' \
                -o -name '*.o' \
                -o -name '*.obj' \
                -o -name '*.a' \
                -o -name '*.lib' \
            \) \
            -print0 \
            2>/dev/null
    )
}

clean_cache() {
    (( CLEAN_CACHE )) || return 0

    log "Cleaning project caches"

    local paths=(
        "${PROJECT_ROOT}/.cache"
        "${PROJECT_ROOT}/.vfconf-cache"
        "${PROJECT_ROOT}/.dune"
        "${PROJECT_ROOT}/tmp"
        "${PROJECT_ROOT}/.tmp"
        "${PROJECT_ROOT}/.pytest_cache"
        "${PROJECT_ROOT}/.mypy_cache"
        "${PROJECT_ROOT}/.ruff_cache"
    )

    local path

    for path in "${paths[@]}"; do
        remove_path "$path"
    done

    while IFS= read -r -d '' path; do
        remove_path "$path"
    done < <(
        find "$PROJECT_ROOT" \
            \( \
                -path "${PROJECT_ROOT}/.git" \
                -o -path "${PROJECT_ROOT}/_build" \
                -o -path "${PROJECT_ROOT}/dist" \
            \) -prune \
            -o \
            -type d \
            -name '__pycache__' \
            -print0 \
            2>/dev/null
    )
}

clean_coverage() {
    (( CLEAN_COVERAGE )) || return 0

    log "Cleaning coverage artifacts"

    local paths=(
        "${PROJECT_ROOT}/_coverage"
        "${PROJECT_ROOT}/coverage"
        "${PROJECT_ROOT}/coverage.html"
        "${PROJECT_ROOT}/coverage.json"
        "${PROJECT_ROOT}/bisect"
        "${PROJECT_ROOT}/bisect-report"
        "${PROJECT_ROOT}/bisect-report.html"
    )

    local path

    for path in "${paths[@]}"; do
        remove_path "$path"
    done

    while IFS= read -r -d '' path; do
        remove_path "$path"
    done < <(
        find "$PROJECT_ROOT" \
            \( \
                -path "${PROJECT_ROOT}/.git" \
                -o -path "${PROJECT_ROOT}/_build" \
                -o -path "${PROJECT_ROOT}/dist" \
            \) -prune \
            -o \
            -type f \
            \( \
                -name 'bisect*.coverage' \
                -o -name '*.coverage' \
                -o -name '.coverage' \
                -o -name '.coverage.*' \
            \) \
            -print0 \
            2>/dev/null
    )
}

clean_docs() {
    (( CLEAN_DOCS )) || return 0

    log "Cleaning generated documentation"

    local paths=(
        "${PROJECT_ROOT}/_doc"
        "${PROJECT_ROOT}/docs/_build"
        "${PROJECT_ROOT}/docs/generated"
        "${PROJECT_ROOT}/docs/html"
        "${PROJECT_ROOT}/docs/api"
    )

    local path

    for path in "${paths[@]}"; do
        remove_path "$path"
    done
}

clean_temp() {
    (( CLEAN_TEMP )) || return 0

    log "Cleaning temporary and editor files"

    local path

    while IFS= read -r -d '' path; do
        remove_path "$path"
    done < <(
        find "$PROJECT_ROOT" \
            \( \
                -path "${PROJECT_ROOT}/.git" \
                -o -path "${PROJECT_ROOT}/_build" \
                -o -path "${PROJECT_ROOT}/dist" \
            \) -prune \
            -o \
            \( \
                -name '.DS_Store' \
                -o -name 'Thumbs.db' \
                -o -name '*~' \
                -o -name '*.swp' \
                -o -name '*.swo' \
                -o -name '*.swn' \
                -o -name '*.tmp' \
                -o -name '*.temp' \
                -o -name '*.bak' \
                -o -name '*.orig' \
                -o -name '*.rej' \
            \) \
            -print0 \
            2>/dev/null
    )
}

ensure_dist() {
    (( DRY_RUN )) && return 0

    mkdir -p -- "$DIST_DIR"
}

print_summary() {
    printf '\n'

    if (( DRY_RUN )); then
        log "Dry run completed; nothing was removed"
        printf '  candidates: %d\n' "$REMOVED_COUNT"
    else
        log "VFConf clean completed"
        printf '  removed:    %d\n' "$REMOVED_COUNT"
    fi

    printf '  build:      %s\n' "$(
        (( CLEAN_BUILD )) && printf 'cleaned' || printf 'preserved'
    )"

    printf '  dist:       %s\n' "$(
        (( CLEAN_DIST )) && printf 'cleaned' || printf 'preserved'
    )"

    printf '  packaging:  %s\n' "$(
        (( CLEAN_PACKAGING )) && printf 'cleaned' || printf 'preserved'
    )"

    printf '  generated:  %s\n' "$(
        (( CLEAN_GENERATED )) && printf 'cleaned' || printf 'preserved'
    )"

    printf '  cache:      %s\n' "$(
        (( CLEAN_CACHE )) && printf 'cleaned' || printf 'preserved'
    )"

    printf '  coverage:   %s\n' "$(
        (( CLEAN_COVERAGE )) && printf 'cleaned' || printf 'preserved'
    )"

    printf '  docs:       %s\n' "$(
        (( CLEAN_DOCS )) && printf 'cleaned' || printf 'preserved'
    )"

    printf '  temp:       %s\n' "$(
        (( CLEAN_TEMP )) && printf 'cleaned' || printf 'preserved'
    )"

    if (( CLEAN_DIST )); then
        log "dist/ preserved and ready for new release artifacts"
    fi
}

on_error() {
    local exit_code=$?
    local line="${BASH_LINENO[0]:-unknown}"

    error "clean failed at line ${line} (exit ${exit_code})"
    exit "$exit_code"
}

main() {
    trap on_error ERR

    parse_arguments "$@"
    check_project_root

    cd -- "$PROJECT_ROOT"

    log "Project root: ${PROJECT_ROOT}"

    if (( DRY_RUN )); then
        log "Dry-run mode enabled"
    fi

    clean_build
    clean_dist
    clean_packaging
    clean_generated
    clean_cache
    clean_coverage
    clean_docs
    clean_temp

    ensure_dist
    print_summary
}

main "$@"