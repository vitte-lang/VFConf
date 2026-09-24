#!/usr/bin/env bash
#
# VFConf — Vitte Foundation Configuration Language
# scripts/format.sh
#
# Safe project formatter.
#
# Supported:
#   - OCaml / Dune through @fmt
#   - *.vf.conf through vfconf-fmt
#
# Safety:
#   - never formats _build/, dist/, .git/ or backups
#   - rejects empty formatter output for non-empty input
#   - validates VFConf before and after formatting when vfconf-check exists
#   - writes through a temporary file
#   - keeps a backup when requested
#

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
VERBOSE=0
PROFILE="dev"

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
  scripts/format.sh [options]

Selection:
  --ocaml-only          Format only OCaml/Dune sources.
  --vfconf-only         Format only *.vf.conf files.

Mode:
  --check               Check only; never modify files.
  --backup              Keep FILE.format-backup before modification.
  --no-validate         Do not run vfconf-check around formatting.
  --no-build            Do not build vfconf-fmt automatically.

Build:
  --dev                 Use Dune dev profile (default).
  --release             Use Dune release profile.
  --profile NAME        Use a custom Dune profile.

General:
  -v, --verbose         Show every processed file.
  -h, --help            Show this help.

Examples:
  scripts/format.sh --check
  scripts/format.sh --ocaml-only
  scripts/format.sh --vfconf-only --check
  scripts/format.sh --vfconf-only --backup
  scripts/format.sh --release --check
EOF
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
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

format_ocaml() {
  (( FORMAT_OCAML )) || return 0

  command_exists dune ||
    die "dune is required for OCaml formatting"

  log "Checking OCaml/Dune formatting"

  if (( CHECK_ONLY )); then
    dune build \
      "--profile=${PROFILE}" \
      @fmt

    log "OCaml/Dune formatting check passed"
    return 0
  fi

  dune build \
    "--profile=${PROFILE}" \
    @fmt \
    --auto-promote

  log "OCaml/Dune formatting completed"
}

find_build_executable() {
  local name="$1"
  local candidate

  candidate="${PROJECT_ROOT}/_build/default/bin/${name}.exe"

  if [[ -x "$candidate" ]]; then
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

  [[ -n "$candidate" ]] || return 1

  printf '%s\n' "$candidate"
}

find_vfconf_formatter() {
  local formatter

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
  local checker

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
  (( BUILD_FORMATTER )) || return 1

  command_exists dune ||
    return 1

  log "Building VFConf formatter/checker"

  dune build \
    "--profile=${PROFILE}" \
    bin/fmt.exe \
    bin/check.exe

  find_vfconf_formatter >/dev/null
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

format_vfconf_file() {
  local formatter="$1"
  local checker="$2"
  local file="$3"

  local directory
  local temporary
  local original_size
  local formatted_size

  directory="$(dirname -- "$file")"
  temporary="$(make_temporary_file "$directory")"

  if (( VERBOSE )); then
    log "Processing ${file#"$PROJECT_ROOT"/}"
  fi

  if (( VALIDATE_VFCONF )) && [[ -n "$checker" ]]; then
    if ! validate_file "$checker" "$file"; then
      rm -f -- "$temporary"
      error "input is invalid VFConf: ${file#"$PROJECT_ROOT"/}"
      return 1
    fi
  fi

  if ! "$formatter" "$file" >"$temporary"; then
    rm -f -- "$temporary"
    error "formatter failed: ${file#"$PROJECT_ROOT"/}"
    return 1
  fi

  original_size="$(wc -c <"$file" | tr -d '[:space:]')"
  formatted_size="$(wc -c <"$temporary" | tr -d '[:space:]')"

  if [[ "$original_size" -gt 0 && "$formatted_size" -eq 0 ]]; then
    rm -f -- "$temporary"
    error "formatter produced empty output: ${file#"$PROJECT_ROOT"/}"
    return 1
  fi

  if (( VALIDATE_VFCONF )) && [[ -n "$checker" ]]; then
    if ! validate_file "$checker" "$temporary"; then
      rm -f -- "$temporary"
      error "formatter produced invalid VFConf: ${file#"$PROJECT_ROOT"/}"
      return 1
    fi
  fi

  if cmp -s -- "$file" "$temporary"; then
    rm -f -- "$temporary"

    if (( VERBOSE )); then
      log "Already formatted ${file#"$PROJECT_ROOT"/}"
    fi

    return 0
  fi

  if (( CHECK_ONLY )); then
    error "not formatted: ${file#"$PROJECT_ROOT"/}"

    if command_exists diff; then
      diff -u -- "$file" "$temporary" || true
    fi

    rm -f -- "$temporary"
    return 2
  fi

  if (( KEEP_BACKUPS )); then
    cp -p -- "$file" "${file}.format-backup"
  fi

  chmod --reference="$file" "$temporary" 2>/dev/null || true

  if ! mv -f -- "$temporary" "$file"; then
    rm -f -- "$temporary"
    error "atomic replacement failed: ${file#"$PROJECT_ROOT"/}"
    return 1
  fi

  if (( VERBOSE )); then
    log "Updated ${file#"$PROJECT_ROOT"/}"
  fi

  return 0
}

format_vfconf() {
  (( FORMAT_VFCONF )) || return 0

  local formatter
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
      build_vfconf_tools

      checker="$(find_vfconf_checker)" ||
        die "vfconf-check cannot be located"
    else
      die "vfconf-check unavailable; use --no-validate to bypass"
    fi
  fi

  log "VFConf formatter: ${formatter}"

  if [[ -n "$checker" ]]; then
    log "VFConf validator: ${checker}"
  fi

  local file
  local count=0
  local changed=0
  local failed=0
  local status

  while IFS= read -r -d '' file; do
    count=$((count + 1))

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
        changed=$((changed + 1))
        ;;

      *)
        failed=$((failed + 1))
        ;;
    esac
  done < <(collect_vfconf_files)

  log "VFConf files processed: ${count}"

  if (( CHECK_ONLY && changed > 0 )); then
    error "${changed} VFConf file(s) require formatting"
  fi

  if (( failed > 0 )); then
    error "${failed} VFConf file(s) failed"
  fi

  if (( changed > 0 || failed > 0 )); then
    return 1
  fi

  log "VFConf formatting completed"
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

  log "Project root: ${PROJECT_ROOT}"
  log "Dune profile: ${PROFILE}"

  if (( CHECK_ONLY )); then
    log "Mode: check only"
  else
    log "Mode: format"
  fi

  format_ocaml
  format_vfconf

  if (( CHECK_ONLY )); then
    log "Formatting check successful"
  else
    log "Formatting completed successfully"
  fi
}

main "$@"
