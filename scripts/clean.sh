#!/usr/bin/env bash
#
# VFConf — Vitte Foundation Configuration Language
# scripts/clean.sh
#
# Clean VFConf build, generated, temporary and distribution artifacts.

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
CLEAN_ALL=0
DRY_RUN=0
VERBOSE=0

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
  scripts/clean.sh [options]

Options:
  --build           Clean Dune build artifacts (default).
  --dist            Clean generated distributions in dist/.
  --generated       Clean generated lexer/parser artifacts.
  --cache           Clean project caches.
  --coverage        Clean coverage artifacts.
  --docs            Clean generated documentation.
  --temp            Clean temporary/editor files.
  --all             Clean everything, including dist/.
  --dry-run         Show what would be removed.
  -v, --verbose     Show every removed path.
  -h, --help        Show this help.

Examples:
  scripts/clean.sh
  scripts/clean.sh --dist
  scripts/clean.sh --generated
  scripts/clean.sh --coverage
  scripts/clean.sh --all
  scripts/clean.sh --all --dry-run

Important:
  The dist/ directory itself is preserved.
  --dist and --all remove only its contents.
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
  [[ -f "${PROJECT_ROOT}/dune-project" ]] ||
    die "dune-project not found in ${PROJECT_ROOT}"

  [[ "$PROJECT_ROOT" != "/" ]] ||
    die "invalid project root"

  [[ -n "$PROJECT_ROOT" ]] ||
    die "empty project root"
}

safe_path() {
  local path="$1"

  [[ -n "$path" ]] || return 1
  [[ "$path" == "${PROJECT_ROOT}/"* ]] || return 1
  [[ "$path" != "$PROJECT_ROOT" ]] || return 1
  [[ "$path" != "/" ]] || return 1

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
    return 0
  fi

  if (( VERBOSE )); then
    log "Removing ${path#"$PROJECT_ROOT"/}"
  fi

  rm -rf -- "$path"
}

clean_build() {
  (( CLEAN_BUILD )) || return 0

  log "Cleaning build artifacts"

  if (( DRY_RUN )); then
    printf '[dry-run] dune clean\n'
    return 0
  fi

  if command -v dune >/dev/null 2>&1; then
    (
      cd -- "$PROJECT_ROOT"
      dune clean
    )
  else
    warn "dune not found; removing _build directly"
    remove_path "${PROJECT_ROOT}/_build"
  fi
}

clean_dist() {
  (( CLEAN_DIST )) || return 0

  log "Cleaning distribution artifacts"

  mkdir -p -- "$DIST_DIR"

  local path

  while IFS= read -r -d '' path; do
    remove_path "$path"
  done < <(
    find "$DIST_DIR" \
      -mindepth 1 \
      -maxdepth 1 \
      -print0 2>/dev/null
  )

  log "dist/ preserved"
}

clean_generated() {
  (( CLEAN_GENERATED )) || return 0

  log "Cleaning generated OCaml lexer/parser files"

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

  while IFS= read -r -d '' path; do
    remove_path "$path"
  done < <(
    find "$PROJECT_ROOT" \
      -type f \
      \( \
        -name '*.cmi' \
        -o -name '*.cmo' \
        -o -name '*.cmx' \
        -o -name '*.cmxa' \
        -o -name '*.cma' \
        -o -name '*.cmxs' \
        -o -name '*.annot' \
        -o -name '*.o' \
        -o -name '*.a' \
      \) \
      ! -path "${PROJECT_ROOT}/_build/*" \
      ! -path "${PROJECT_ROOT}/dist/*" \
      -print0 2>/dev/null
  )
}

clean_cache() {
  (( CLEAN_CACHE )) || return 0

  log "Cleaning caches"

  local paths=(
    "${PROJECT_ROOT}/.cache"
    "${PROJECT_ROOT}/.vfconf-cache"
    "${PROJECT_ROOT}/.dune"
    "${PROJECT_ROOT}/tmp"
    "${PROJECT_ROOT}/.tmp"
  )

  local path

  for path in "${paths[@]}"; do
    remove_path "$path"
  done
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
  )

  local path

  for path in "${paths[@]}"; do
    remove_path "$path"
  done

  while IFS= read -r -d '' path; do
    remove_path "$path"
  done < <(
    find "$PROJECT_ROOT" \
      -type f \
      \( \
        -name 'bisect*.coverage' \
        -o -name '*.coverage' \
        -o -name '.coverage' \
        -o -name '.coverage.*' \
      \) \
      ! -path "${PROJECT_ROOT}/dist/*" \
      -print0 2>/dev/null
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
  )

  local path

  for path in "${paths[@]}"; do
    remove_path "$path"
  done
}

clean_temp() {
  (( CLEAN_TEMP )) || return 0

  log "Cleaning temporary files"

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
        -o -name '*~' \
        -o -name '*.swp' \
        -o -name '*.swo' \
        -o -name '*.tmp' \
        -o -name '*.temp' \
        -o -name '*.bak' \
      \) \
      -print0 2>/dev/null
  )
}

ensure_dist() {
  if (( DRY_RUN )); then
    return 0
  fi

  mkdir -p -- "$DIST_DIR"
}

print_summary() {
  printf '\n'

  if (( DRY_RUN )); then
    log "Dry run completed; nothing was removed"
  else
    log "VFConf clean completed"
  fi

  if (( CLEAN_DIST )); then
    log "dist/ is empty and ready for new builds"
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

  clean_build
  clean_dist
  clean_generated
  clean_cache
  clean_coverage
  clean_docs
  clean_temp

  ensure_dist
  print_summary
}

main "$@"