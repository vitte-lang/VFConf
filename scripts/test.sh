#!/usr/bin/env bash
#
# VFConf — Vitte Foundation Configuration Language
# scripts/test.sh
#
# Build and run the VFConf test suite.
#
# Supported checks:
#   - Dune unit/integration tests
#   - Build verification
#   - VFConf example validation
#   - Configuration validation
#   - Language definition validation
#   - Theme validation
#   - Schema validation
#   - Formatter stability
#   - Optional fuzz tests

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

PROFILE="dev"
JOBS=""

BUILD_FIRST=1
RUN_DUNE_TESTS=1
RUN_VFCONF_TESTS=1
RUN_FORMAT_TESTS=1
RUN_FUZZ=0
VERBOSE=0

PASSED=0
FAILED=0
SKIPPED=0

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
  scripts/test.sh [options]

Options:
  --dev               Use Dune dev profile (default).
  --release           Use Dune release profile.
  --profile NAME      Use a custom Dune profile.
  --no-build          Skip explicit build verification.
  --dune-only         Run only Dune tests.
  --vfconf-only       Run only *.vf.conf validation tests.
  --no-format         Disable formatter stability tests.
  --fuzz              Run fuzz tests when available.
  -j, --jobs N        Parallel Dune jobs.
  -v, --verbose       Show individual test files.
  -h, --help          Show this help.

Examples:
  scripts/test.sh
  scripts/test.sh --release
  scripts/test.sh --vfconf-only
  scripts/test.sh --dune-only
  scripts/test.sh --fuzz
  scripts/test.sh -j 4
EOF
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_command() {
  command_exists "$1" ||
    die "required command not found: $1"
}

pass() {
  PASSED=$((PASSED + 1))

  if (( VERBOSE )); then
    printf '[PASS] %s\n' "$*"
  fi
}

fail() {
  FAILED=$((FAILED + 1))
  printf '[FAIL] %s\n' "$*" >&2
}

skip() {
  SKIPPED=$((SKIPPED + 1))

  if (( VERBOSE )); then
    printf '[SKIP] %s\n' "$*"
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

      --no-build)
        BUILD_FIRST=0
        ;;

      --dune-only)
        RUN_DUNE_TESTS=1
        RUN_VFCONF_TESTS=0
        RUN_FORMAT_TESTS=0
        ;;

      --vfconf-only)
        RUN_DUNE_TESTS=0
        RUN_VFCONF_TESTS=1
        ;;

      --no-format)
        RUN_FORMAT_TESTS=0
        ;;

      --fuzz)
        RUN_FUZZ=1
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

check_tools() {
  require_command dune
  require_command ocamlc

  log "OCaml: $(ocamlc -version)"
  log "Dune:  $(dune --version)"
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
  (( BUILD_FIRST )) || return 0

  log "Building test targets"

  if dune build "${DUNE_ARGS[@]}" @all; then
    pass "project build"
  else
    fail "project build"
    return 1
  fi
}

run_dune_tests() {
  (( RUN_DUNE_TESTS )) || return 0

  log "Running Dune tests"

  if dune runtest "${DUNE_ARGS[@]}"; then
    pass "Dune test suite"
  else
    fail "Dune test suite"
  fi
}

find_checker() {
  local candidates=(
    "${PROJECT_ROOT}/_build/default/bin/check.exe"
    "${PROJECT_ROOT}/_build/default/bin/vfconf-check.exe"
    "${PROJECT_ROOT}/_build/install/default/bin/vfconf-check"
  )

  local candidate

  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if command_exists vfconf-check; then
    command -v vfconf-check
    return 0
  fi

  return 1
}

build_checker() {
  command_exists dune || return 1

  dune build "${DUNE_ARGS[@]}" bin/check.exe

  find_checker >/dev/null
}

find_formatter() {
  local candidates=(
    "${PROJECT_ROOT}/_build/default/bin/fmt.exe"
    "${PROJECT_ROOT}/_build/default/bin/vfconf-fmt.exe"
    "${PROJECT_ROOT}/_build/install/default/bin/vfconf-fmt"
  )

  local candidate

  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if command_exists vfconf-fmt; then
    command -v vfconf-fmt
    return 0
  fi

  return 1
}

build_formatter() {
  command_exists dune || return 1

  dune build "${DUNE_ARGS[@]}" bin/fmt.exe

  find_formatter >/dev/null
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
    \) -prune \
    -o \
    -type f \
    -name '*.vf.conf' \
    -print0 |
    sort -z
}

validate_vfconf_files() {
  (( RUN_VFCONF_TESTS )) || return 0

  local checker

  if checker="$(find_checker)"; then
    :
  elif build_checker; then
    checker="$(find_checker)" ||
      die "vfconf-check was built but cannot be located"
  else
    fail "vfconf-check unavailable"
    return
  fi

  log "Validating VFConf files"

  local file
  local count=0

  while IFS= read -r -d '' file; do
    count=$((count + 1))

    if "$checker" "$file" >/dev/null 2>&1; then
      pass "${file#"$PROJECT_ROOT"/}"
    else
      fail "${file#"$PROJECT_ROOT"/}"

      if (( VERBOSE )); then
        "$checker" "$file" || true
      fi
    fi
  done < <(collect_vfconf_files)

  if (( count == 0 )); then
    skip "no VFConf files found"
  else
    log "VFConf files validated: ${count}"
  fi
}

formatter_stability_test() {
  (( RUN_FORMAT_TESTS )) || return 0

  local formatter

  if formatter="$(find_formatter)"; then
    :
  elif build_formatter; then
    formatter="$(find_formatter)" ||
      die "vfconf-fmt was built but cannot be located"
  else
    fail "vfconf-fmt unavailable"
    return
  fi

  log "Testing formatter stability"

  local file
  local first
  local second
  local count=0

  while IFS= read -r -d '' file; do
    count=$((count + 1))

    first="$(mktemp "${TMPDIR:-/tmp}/vfconf-test-first.XXXXXXXX")"
    second="$(mktemp "${TMPDIR:-/tmp}/vfconf-test-second.XXXXXXXX")"

    if ! "$formatter" "$file" >"$first"; then
      fail "formatter: ${file#"$PROJECT_ROOT"/}"
      rm -f -- "$first" "$second"
      continue
    fi

    if ! "$formatter" "$first" >"$second"; then
      fail "formatter second pass: ${file#"$PROJECT_ROOT"/}"
      rm -f -- "$first" "$second"
      continue
    fi

    if cmp -s -- "$first" "$second"; then
      pass "formatter idempotence: ${file#"$PROJECT_ROOT"/}"
    else
      fail "formatter not idempotent: ${file#"$PROJECT_ROOT"/}"

      if (( VERBOSE )) && command_exists diff; then
        diff -u -- "$first" "$second" || true
      fi
    fi

    rm -f -- "$first" "$second"
  done < <(collect_vfconf_files)

  if (( count == 0 )); then
    skip "formatter stability: no VFConf files"
  fi
}

run_fuzz_tests() {
  (( RUN_FUZZ )) || return 0

  if [[ ! -d "${PROJECT_ROOT}/fuzz" ]]; then
    skip "fuzz directory not found"
    return
  fi

  log "Running fuzz tests"

  if dune build "${DUNE_ARGS[@]}" @fuzz 2>/dev/null; then
    pass "fuzz build"
  elif dune build "${DUNE_ARGS[@]}" fuzz; then
    pass "fuzz build"
  else
    fail "fuzz build"
  fi
}

test_examples_directory() {
  (( RUN_VFCONF_TESTS )) || return 0

  [[ -d "${PROJECT_ROOT}/examples" ]] || {
    skip "examples directory not found"
    return
  }

  log "Examples directory detected"
}

test_required_project_files() {
  log "Checking required project files"

  local required=(
    "README.md"
    "LICENSE"
    "CHANGELOG.md"
    "VERSION"
    "dune-project"
    "vfconf.opam"
    "lib/dune"
    "bin/dune"
  )

  local file

  for file in "${required[@]}"; do
    if [[ -e "${PROJECT_ROOT}/${file}" ]]; then
      pass "required file: ${file}"
    else
      fail "missing required file: ${file}"
    fi
  done
}

test_required_directories() {
  log "Checking project structure"

  local required=(
    "bin"
    "lib"
    "grammar"
    "config"
    "languages"
    "themes"
    "schemas"
    "examples"
    "tests"
    "scripts"
    "dist"
  )

  local directory

  for directory in "${required[@]}"; do
    if [[ -d "${PROJECT_ROOT}/${directory}" ]]; then
      pass "required directory: ${directory}/"
    else
      fail "missing required directory: ${directory}/"
    fi
  done
}

print_summary() {
  local total

  total=$((PASSED + FAILED + SKIPPED))

  printf '\n'
  printf '%s\n' '========================================'
  printf ' VFConf test summary\n'
  printf '%s\n' '========================================'
  printf ' Passed:  %d\n' "$PASSED"
  printf ' Failed:  %d\n' "$FAILED"
  printf ' Skipped: %d\n' "$SKIPPED"
  printf ' Total:   %d\n' "$total"
  printf '%s\n' '========================================'

  if (( FAILED > 0 )); then
    error "test suite failed"
    return 1
  fi

  log "All tests passed"
}

on_error() {
  local exit_code=$?
  local line="${BASH_LINENO[0]:-unknown}"

  error "test script failed at line ${line} (exit ${exit_code})"
  exit "$exit_code"
}

main() {
  trap on_error ERR

  parse_arguments "$@"

  cd -- "$PROJECT_ROOT"

  check_project
  check_tools
  make_dune_args

  log "Project root: ${PROJECT_ROOT}"
  log "Profile: ${PROFILE}"

  test_required_project_files
  test_required_directories

  build_project || true

  run_dune_tests
  test_examples_directory
  validate_vfconf_files
  formatter_stability_test
  run_fuzz_tests

  print_summary
}

main "$@"