#!/usr/bin/env bash
#
# VFConf — Vitte Foundation Configuration Language
# scripts/format.sh
#
# Safe project formatter and formatting validator.
#
# Supported:
#   - OCaml / Dune sources through Dune @fmt
#   - *.vf.conf files through vfconf-fmt
#
# Safety:
#   - never traverses .git/, _build/ or dist/
#   - ignores formatter backups and temporary files
#   - validates VFConf before formatting
#   - validates formatter output before replacement
#   - rejects empty formatter output for non-empty input
#   - uses temporary files in the source directory
#   - preserves file permissions when possible
#   - performs atomic replacement on the same filesystem
#   - backups are disabled unless explicitly requested
#   - check mode never modifies VFConf files
#
# Exit status:
#   0  formatting is valid / formatting completed
#   1  formatting, validation or internal operation failed

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

CHECK_ONLY=0
FORMAT_OCAML=1
FORMAT_VFCONF=1
BUILD_FORMATTER=1
VALIDATE_VFCONF=1
KEEP_BACKUPS=0
SHOW_DIFF=1
VERBOSE=0
PROFILE="dev"
JOBS=""

DUNE_ARGS=()

VFCONF_TOTAL=0
VFCONF_CHANGED=0
VFCONF_UNCHANGED=0
VFCONF_FAILED=0

log() {
    printf '[vfconf-format] %s\n' "$*"
}

warn() {
    printf '[vfconf-format] warning: %s\n' "$*" >&2
}

error() {
    printf '[vfconf-format] error: %s\n' "$*" >&2
}

die() {
    error "$*"
    exit 1
}

usage() {
    cat <<'EOF'
Usage:
  scripts/format.sh [options]

Selection:
  --ocaml-only          Format only OCaml/Dune sources.
  --vfconf-only         Format only *.vf.conf files.

Mode:
  --check               Check formatting without modifying files.
  --backup              Keep FILE.format-backup before modification.
  --no-diff             Do not display unified diffs in check mode.
  --no-validate         Do not validate VFConf before/after formatting.
  --no-build            Do not build vfconf-fmt/vfconf-check automatically.

Build:
  --dev                 Use Dune dev profile (default).
  --release             Use Dune release profile.
  --profile NAME        Use a custom Dune profile.
  -j, --jobs N          Parallel Dune jobs.

General:
  -v, --verbose         Show every processed file.
  -h, --help            Show this help.

Examples:
  scripts/format.sh
  scripts/format.sh --check
  scripts/format.sh --ocaml-only
  scripts/format.sh --vfconf-only
  scripts/format.sh --vfconf-only --check
  scripts/format.sh --vfconf-only --backup
  scripts/format.sh --release --check
  scripts/format.sh --check --no-diff
  scripts/format.sh -j 4

Safety:
  Backups are not created unless --backup is explicitly requested.
  Check mode never modifies VFConf source files.
  Invalid VFConf files are never replaced.
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
            --check)
                CHECK_ONLY=1
                ;;

            --ocaml-only)
                FORMAT_OCAML=1
                FORMAT_VFCONF=0
                ;;

            --vfconf-only)
                FORMAT_OCAML=0
                FORMAT_VFCONF=1
                ;;

            --no-build)
                BUILD_FORMATTER=0
                ;;

            --no-validate)
                VALIDATE_VFCONF=0
                ;;

            --backup)
                KEEP_BACKUPS=1
                ;;

            --no-diff)
                SHOW_DIFF=0
                ;;

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

    [[ -d "$PROJECT_ROOT" ]] ||
        die "project root not found: ${PROJECT_ROOT}"

    [[ -f "${PROJECT_ROOT}/dune-project" ]] ||
        die "dune-project not found"

    [[ -f "${PROJECT_ROOT}/lib/dune" ]] ||
        die "lib/dune not found"

    [[ -f "${PROJECT_ROOT}/bin/dune" ]] ||
        die "bin/dune not found"
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

format_ocaml() {
    (( FORMAT_OCAML )) || return 0

    require_command dune

    if (( CHECK_ONLY )); then
        log "Checking OCaml/Dune formatting"

        dune build \
            "${DUNE_ARGS[@]}" \
            @fmt

        log "OCaml/Dune formatting check passed"
        return 0
    fi

    log "Formatting OCaml/Dune sources"

    dune build \
        "${DUNE_ARGS[@]}" \
        @fmt \
        --auto-promote

    log "OCaml/Dune formatting completed"
}

find_build_executable() {
    local name="$1"
    local candidate

    candidate="${PROJECT_ROOT}/_build/default/bin/${name}.exe"

    if [[ -f "$candidate" && -x "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    candidate="$(
        find "${PROJECT_ROOT}/_build" \
            -type f \
            -path "*/bin/${name}.exe" \
            -perm -111 \
            -print \
            -quit \
            2>/dev/null || true
    )"

    [[ -n "$candidate" ]] ||
        return 1

    printf '%s\n' "$candidate"
}

find_vfconf_formatter() {
    local formatter=""

    if formatter="$(find_build_executable fmt)"; then
        printf '%s\n' "$formatter"
        return 0
    fi

    if command_exists vfconf-fmt; then
        command -v vfconf-fmt
        return 0
    fi

    return 1
}

find_vfconf_checker() {
    local checker=""

    if checker="$(find_build_executable check)"; then
        printf '%s\n' "$checker"
        return 0
    fi

    if command_exists vfconf-check; then
        command -v vfconf-check
        return 0
    fi

    return 1
}

build_vfconf_tools() {
    (( BUILD_FORMATTER )) ||
        return 1

    command_exists dune ||
        return 1

    log "Building VFConf formatter"

    local targets=(
        bin/fmt.exe
    )

    if (( VALIDATE_VFCONF )); then
        targets+=(
            bin/check.exe
        )
    fi

    dune build \
        "${DUNE_ARGS[@]}" \
        "${targets[@]}"

    find_vfconf_formatter >/dev/null ||
        return 1

    if (( VALIDATE_VFCONF )); then
        find_vfconf_checker >/dev/null ||
            return 1
    fi

    return 0
}

collect_vfconf_files() {
    find "$PROJECT_ROOT" \
        \( \
            -path "${PROJECT_ROOT}/_build" \
            -o -path "${PROJECT_ROOT}/_build/*" \
            -o -path "${PROJECT_ROOT}/dist" \
            -o -path "${PROJECT_ROOT}/dist/*" \
            -o -path "${PROJECT_ROOT}/.git" \
            -o -path "${PROJECT_ROOT}/.git/*" \
            -o -name '*.backup-*' \
            -o -name '*.format-backup' \
            -o -name '.vfconf-format.*' \
        \) -prune \
        -o \
        -type f \
        -name '*.vf.conf' \
        -print0 |
        sort -z
}

make_temporary_file() {
    local directory="$1"

    mktemp "${directory}/.vfconf-format.XXXXXXXX"
}

validate_file() {
    local checker="$1"
    local file="$2"

    "$checker" "$file" >/dev/null
}

file_size() {
    local file="$1"

    wc -c <"$file" |
        tr -d '[:space:]'
}

show_file_diff() {
    local original="$1"
    local formatted="$2"

    (( SHOW_DIFF )) || return 0

    command_exists diff || {
        warn "diff unavailable; cannot display formatting difference"
        return 0
    }

    diff -u \
        --label "${original#"$PROJECT_ROOT"/}" \
        --label "${original#"$PROJECT_ROOT"/} (formatted)" \
        -- \
        "$original" \
        "$formatted" ||
        true
}

preserve_permissions() {
    local source="$1"
    local destination="$2"

    if chmod --reference="$source" "$destination" 2>/dev/null; then
        return 0
    fi

    if command_exists stat; then
        local mode=""

        case "$(uname -s)" in
            Darwin|FreeBSD|OpenBSD|NetBSD|DragonFly)
                mode="$(stat -f '%Lp' "$source" 2>/dev/null || true)"
                ;;

            *)
                mode="$(stat -c '%a' "$source" 2>/dev/null || true)"
                ;;
        esac

        if [[ -n "$mode" ]]; then
            chmod "$mode" "$destination" 2>/dev/null || true
        fi
    fi
}

format_vfconf_file() {
    local formatter="$1"
    local checker="$2"
    local file="$3"

    local directory
    local temporary
    local original_size
    local formatted_size

    directory="$(dirname -- "$file")"

    temporary="$(make_temporary_file "$directory")" ||
        {
            error "cannot create temporary file: ${file#"$PROJECT_ROOT"/}"
            return 1
        }

    if (( VERBOSE )); then
        log "Processing ${file#"$PROJECT_ROOT"/}"
    fi

    if (( VALIDATE_VFCONF )) &&
       [[ -n "$checker" ]]
    then
        if ! validate_file "$checker" "$file"; then
            rm -f -- "$temporary"

            error \
                "input is invalid VFConf: ${file#"$PROJECT_ROOT"/}"

            return 1
        fi
    fi

    if ! "$formatter" "$file" >"$temporary"; then
        rm -f -- "$temporary"

        error \
            "formatter failed: ${file#"$PROJECT_ROOT"/}"

        return 1
    fi

    original_size="$(file_size "$file")"
    formatted_size="$(file_size "$temporary")"

    [[ "$original_size" =~ ^[0-9]+$ ]] || {
        rm -f -- "$temporary"
        error "cannot determine input size: ${file#"$PROJECT_ROOT"/}"
        return 1
    }

    [[ "$formatted_size" =~ ^[0-9]+$ ]] || {
        rm -f -- "$temporary"
        error "cannot determine formatter output size: ${file#"$PROJECT_ROOT"/}"
        return 1
    }

    if (( original_size > 0 && formatted_size == 0 )); then
        rm -f -- "$temporary"

        error \
            "formatter produced empty output: ${file#"$PROJECT_ROOT"/}"

        return 1
    fi

    if (( VALIDATE_VFCONF )) &&
       [[ -n "$checker" ]]
    then
        if ! validate_file "$checker" "$temporary"; then
            rm -f -- "$temporary"

            error \
                "formatter produced invalid VFConf: ${file#"$PROJECT_ROOT"/}"

            return 1
        fi
    fi

    if cmp -s -- "$file" "$temporary"; then
        rm -f -- "$temporary"

        VFCONF_UNCHANGED=$((VFCONF_UNCHANGED + 1))

        if (( VERBOSE )); then
            log "Already formatted ${file#"$PROJECT_ROOT"/}"
        fi

        return 0
    fi

    VFCONF_CHANGED=$((VFCONF_CHANGED + 1))

    if (( CHECK_ONLY )); then
        error "not formatted: ${file#"$PROJECT_ROOT"/}"

        show_file_diff \
            "$file" \
            "$temporary"

        rm -f -- "$temporary"

        return 2
    fi

    if (( KEEP_BACKUPS )); then
        cp -p \
            -- \
            "$file" \
            "${file}.format-backup" ||
            {
                rm -f -- "$temporary"
                error "backup creation failed: ${file#"$PROJECT_ROOT"/}"
                return 1
            }
    fi

    preserve_permissions \
        "$file" \
        "$temporary"

    if ! mv -f -- "$temporary" "$file"; then
        rm -f -- "$temporary"

        error \
            "atomic replacement failed: ${file#"$PROJECT_ROOT"/}"

        return 1
    fi

    if (( VALIDATE_VFCONF )) &&
       [[ -n "$checker" ]]
    then
        if ! validate_file "$checker" "$file"; then
            error \
                "post-write validation failed: ${file#"$PROJECT_ROOT"/}"

            return 1
        fi
    fi

    if (( VERBOSE )); then
        log "Updated ${file#"$PROJECT_ROOT"/}"
    fi

    return 0
}

format_vfconf() {
    (( FORMAT_VFCONF )) || return 0

    require_command find
    require_command sort
    require_command mktemp
    require_command cmp
    require_command wc

    local formatter=""
    local checker=""

    if formatter="$(find_vfconf_formatter)"; then
        :
    elif build_vfconf_tools; then
        formatter="$(find_vfconf_formatter)" ||
            die "vfconf-fmt was built but cannot be located"
    else
        die "vfconf-fmt is unavailable"
    fi

    if (( VALIDATE_VFCONF )); then
        if checker="$(find_vfconf_checker)"; then
            :
        elif (( BUILD_FORMATTER )); then
            build_vfconf_tools ||
                die "unable to build VFConf formatter/checker"

            checker="$(find_vfconf_checker)" ||
                die "vfconf-check cannot be located"
        else
            die \
                "vfconf-check unavailable; use --no-validate to bypass"
        fi
    fi

    log "VFConf formatter: ${formatter}"

    if [[ -n "$checker" ]]; then
        log "VFConf validator: ${checker}"
    else
        warn "VFConf validation disabled"
    fi

    local file
    local status

    while IFS= read -r -d '' file; do
        VFCONF_TOTAL=$((VFCONF_TOTAL + 1))

        set +e

        format_vfconf_file \
            "$formatter" \
            "$checker" \
            "$file"

        status=$?

        set -e

        case "$status" in
            0)
                ;;

            2)
                ;;

            *)
                VFCONF_FAILED=$((VFCONF_FAILED + 1))
                ;;
        esac
    done < <(collect_vfconf_files)

    log "VFConf files processed: ${VFCONF_TOTAL}"

    printf '  unchanged: %d\n' "$VFCONF_UNCHANGED"
    printf '  changed:   %d\n' "$VFCONF_CHANGED"
    printf '  failed:    %d\n' "$VFCONF_FAILED"

    if (( VFCONF_FAILED > 0 )); then
        error "${VFCONF_FAILED} VFConf file(s) failed"
        return 1
    fi

    if (( CHECK_ONLY && VFCONF_CHANGED > 0 )); then
        error "${VFCONF_CHANGED} VFConf file(s) require formatting"
        return 1
    fi

    if (( CHECK_ONLY )); then
        log "VFConf formatting check passed"
    else
        log "VFConf formatting completed"
    fi

    return 0
}

print_summary() {
    printf '\n'

    log "Formatting summary"

    if (( FORMAT_OCAML )); then
        printf '  OCaml/Dune: enabled\n'
    else
        printf '  OCaml/Dune: disabled\n'
    fi

    if (( FORMAT_VFCONF )); then
        printf '  VFConf:     enabled\n'
        printf '  processed:  %d\n' "$VFCONF_TOTAL"
        printf '  unchanged:  %d\n' "$VFCONF_UNCHANGED"
        printf '  changed:    %d\n' "$VFCONF_CHANGED"
        printf '  failed:     %d\n' "$VFCONF_FAILED"
    else
        printf '  VFConf:     disabled\n'
    fi

    if (( CHECK_ONLY )); then
        printf '  mode:       check\n'
    else
        printf '  mode:       format\n'
    fi

    printf '  profile:    %s\n' "$PROFILE"

    if (( KEEP_BACKUPS )); then
        printf '  backups:    enabled\n'
    else
        printf '  backups:    disabled\n'
    fi

    if (( VALIDATE_VFCONF )); then
        printf '  validation: enabled\n'
    else
        printf '  validation: disabled\n'
    fi
}

on_error() {
    local exit_code=$?
    local line="${BASH_LINENO[0]:-unknown}"

    error "format failed at line ${line} (exit ${exit_code})"
    exit "$exit_code"
}

main() {
    trap on_error ERR

    parse_arguments "$@"

    cd -- "$PROJECT_ROOT"

    check_project
    make_dune_args

    log "Project root: ${PROJECT_ROOT}"
    log "Dune profile: ${PROFILE}"

    if (( CHECK_ONLY )); then
        log "Mode: check only"
    else
        log "Mode: format"
    fi

    format_ocaml
    format_vfconf

    print_summary

    if (( CHECK_ONLY )); then
        log "Formatting check successful"
    else
        log "Formatting completed successfully"
    fi
}

main "$@"