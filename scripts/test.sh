#!/usr/bin/env bash
#
# VFConf — Vitte Foundation Configuration Language
# scripts/test.sh
#
# Complete VFConf test and validation runner.
#
# Checks:
#   - project structure
#   - all 20 CLI executables
#   - Dune unit/integration tests
#   - diagnostics gate
#   - valid VFConf files
#   - intentionally invalid VFConf files
#   - examples
#   - configuration files
#   - language definitions
#   - themes
#   - schemas
#   - formatter output safety
#   - formatter validity
#   - formatter idempotence
#   - CLI smoke tests
#   - optional fuzz targets
#
# Exit:
#   0  all requested tests passed
#   1  one or more tests failed

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
RUN_DIAGNOSTICS=1
RUN_CLI_TESTS=1
RUN_FUZZ=0
VERBOSE=0

PASSED=0
FAILED=0
SKIPPED=0

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
    printf '[vfconf-test] %s\n' "$*"
}

warn() {
    printf '[vfconf-test] warning: %s\n' "$*" >&2
}

error() {
    printf '[vfconf-test] error: %s\n' "$*" >&2
}

die() {
    error "$*"
    exit 1
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

usage() {
    cat <<'EOF'
Usage:
  scripts/test.sh [options]

Build:
  --dev                 Use Dune dev profile (default).
  --release             Use Dune release profile.
  --profile NAME        Use a custom Dune profile.
  --no-build            Skip explicit build verification.
  -j, --jobs N          Parallel Dune jobs.

Tests:
  --dune-only           Run project/build + Dune tests only.
  --vfconf-only         Run VFConf validation/formatter tests only.
  --no-format           Disable formatter tests.
  --no-diagnostics      Disable diagnostics gate.
  --no-cli              Disable CLI smoke tests.
  --fuzz                Run fuzz tests when available.

General:
  -v, --verbose         Show individual tests and diagnostics.
  -h, --help            Show this help.

Examples:
  scripts/test.sh
  scripts/test.sh --release
  scripts/test.sh --vfconf-only
  scripts/test.sh --dune-only
  scripts/test.sh --no-format
  scripts/test.sh --no-diagnostics
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
                RUN_DIAGNOSTICS=0
                RUN_CLI_TESTS=0
                RUN_FUZZ=0
                ;;

            --vfconf-only)
                RUN_DUNE_TESTS=0
                RUN_VFCONF_TESTS=1
                RUN_CLI_TESTS=1
                ;;

            --no-format)
                RUN_FORMAT_TESTS=0
                ;;

            --no-diagnostics)
                RUN_DIAGNOSTICS=0
                ;;

            --no-cli)
                RUN_CLI_TESTS=0
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
    require_command dune
    require_command ocamlc
    require_command find
    require_command sort
    require_command cmp
    require_command mktemp

    log "OCaml: $(ocamlc -version)"
    log "Dune:  $(dune --version)"

    if command_exists menhir; then
        log "Menhir: $(menhir --version 2>/dev/null || printf 'available')"
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

find_built_binary() {
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

build_project() {
    (( BUILD_FIRST )) || {
        log "Explicit build skipped"
        return 0
    }

    log "Building ${#VFCONF_EXECUTABLES[@]} VFConf executables"

    local targets=()
    local entry
    local build_name

    for entry in "${VFCONF_EXECUTABLES[@]}"; do
        build_name="${entry%%:*}"
        targets+=("bin/${build_name}.exe")
    done

    if dune build \
        "${DUNE_ARGS[@]}" \
        "${targets[@]}"
    then
        pass "VFConf executable build"
    else
        fail "VFConf executable build"
        return 1
    fi
}

verify_executables() {
    (( BUILD_FIRST )) || return 0

    log "Verifying compiled executables"

    local entry
    local build_name
    local public_name
    local path

    for entry in "${VFCONF_EXECUTABLES[@]}"; do
        build_name="${entry%%:*}"
        public_name="${entry#*:}"

        if path="$(find_built_binary "$build_name")"; then
            if [[ -s "$path" && -x "$path" ]]; then
                pass "executable: ${public_name}"
            else
                fail "invalid executable: ${public_name}"
            fi
        else
            fail "missing executable: ${public_name}"
        fi
    done
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

run_diagnostics_gate() {
    (( RUN_DIAGNOSTICS )) || return 0

    log "Running diagnostics gate"

    if [[ -x "${PROJECT_ROOT}/scripts/check-diagnostics.sh" ]]; then
        if "${PROJECT_ROOT}/scripts/check-diagnostics.sh"; then
            pass "diagnostics gate"
        else
            fail "diagnostics gate"
        fi

        return 0
    fi

    if [[ -f "${PROJECT_ROOT}/scripts/audit-diagnostics.py" ]]; then
        if ! command_exists python3; then
            fail "python3 required for diagnostics audit"
            return 0
        fi

        if python3 "${PROJECT_ROOT}/scripts/audit-diagnostics.py"; then
            pass "diagnostics static audit"
        else
            fail "diagnostics static audit"
        fi

        return 0
    fi

    skip "diagnostics gate unavailable"
}

find_checker() {
    local checker=""

    if checker="$(find_built_binary check)"; then
        printf '%s\n' "$checker"
        return 0
    fi

    if command_exists vfconf-check; then
        command -v vfconf-check
        return 0
    fi

    return 1
}

find_formatter() {
    local formatter=""

    if formatter="$(find_built_binary fmt)"; then
        printf '%s\n' "$formatter"
        return 0
    fi

    if command_exists vfconf-fmt; then
        command -v vfconf-fmt
        return 0
    fi

    return 1
}

build_checker() {
    dune build \
        "${DUNE_ARGS[@]}" \
        bin/check.exe

    find_checker >/dev/null
}

build_formatter() {
    dune build \
        "${DUNE_ARGS[@]}" \
        bin/fmt.exe

    find_formatter >/dev/null
}

is_expected_invalid_file() {
     local file="$1"
     local relative="${file#"$PROJECT_ROOT"/}"
 
     case "$relative" in
         languages/error.vf.conf)
             return 0
             ;;
 
         *.invalid.vf.conf)
             return 0
             ;;
 
         *.error.vf.conf)
             return 0
             ;;
     esac
 
     case "$relative" in
         */invalid/* | */errors/*)
             return 0
             ;;
     esac
 
     return 1
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
             -o -path "${PROJECT_ROOT}/.kilo" \
             -o -path "${PROJECT_ROOT}/.kilo/*" \
             -o -name '*.format-backup' \
             -o -name '*.backup-*' \
         \) -prune \
         -o \
         -type f \
         -name '*.vf.conf' \
         -print0 |
         sort -z
 }

validate_vfconf_files() {
    (( RUN_VFCONF_TESTS )) || return 0

    local checker=""

    if checker="$(find_checker)"; then
        :
    elif build_checker; then
        checker="$(find_checker)" ||
            die "vfconf-check was built but cannot be located"
    else
        fail "vfconf-check unavailable"
        return 0
    fi

    log "Validating VFConf files"

    local file
    local count=0
    local valid_count=0
    local invalid_count=0
    local status

    while IFS= read -r -d '' file; do
        count=$((count + 1))

        set +e
        "$checker" "$file" >/dev/null 2>&1
        status=$?
        set -e

        if is_expected_invalid_file "$file"; then
            invalid_count=$((invalid_count + 1))

            if (( status != 0 )); then
                pass "expected invalid: ${file#"$PROJECT_ROOT"/}"
            else
                fail "invalid file unexpectedly accepted: ${file#"$PROJECT_ROOT"/}"
            fi

            continue
        fi

        valid_count=$((valid_count + 1))

        if (( status == 0 )); then
            pass "valid VFConf: ${file#"$PROJECT_ROOT"/}"
        else
            fail "VFConf validation: ${file#"$PROJECT_ROOT"/}"

            if (( VERBOSE )); then
                "$checker" "$file" || true
            fi
        fi
    done < <(collect_vfconf_files)

    if (( count == 0 )); then
        skip "no VFConf files found"
        return 0
    fi

    log "VFConf files: ${count}"
    log "Expected valid: ${valid_count}"
    log "Expected invalid: ${invalid_count}"
}

validate_directory() {
    local checker="$1"
    local directory="$2"
    local label="$3"

    [[ -d "${PROJECT_ROOT}/${directory}" ]] || {
        skip "${label}: directory unavailable"
        return 0
    }

    local file
    local count=0

    while IFS= read -r -d '' file; do
        if is_expected_invalid_file "$file"; then
            continue
        fi

        count=$((count + 1))

        if "$checker" "$file" >/dev/null 2>&1; then
            pass "${label}: ${file#"$PROJECT_ROOT"/}"
        else
            fail "${label}: ${file#"$PROJECT_ROOT"/}"

            if (( VERBOSE )); then
                "$checker" "$file" || true
            fi
        fi
    done < <(
        find "${PROJECT_ROOT}/${directory}" \
            -type f \
            -name '*.vf.conf' \
            -print0 |
            sort -z
    )

    if (( count == 0 )); then
        skip "${label}: no VFConf files"
    fi
}

validate_project_categories() {
    (( RUN_VFCONF_TESTS )) || return 0

    local checker=""

    if checker="$(find_checker)"; then
        :
    else
        skip "category validation: vfconf-check unavailable"
        return 0
    fi

    log "Validating VFConf categories"

    validate_directory "$checker" "examples" "example"
    validate_directory "$checker" "config" "configuration"
    validate_directory "$checker" "languages" "language"
    validate_directory "$checker" "themes" "theme"
    validate_directory "$checker" "schemas" "schema"
}

formatter_stability_test() {
    (( RUN_FORMAT_TESTS )) || return 0

    local formatter=""
    local checker=""

    if formatter="$(find_formatter)"; then
        :
    elif build_formatter; then
        formatter="$(find_formatter)" ||
            die "vfconf-fmt was built but cannot be located"
    else
        fail "vfconf-fmt unavailable"
        return 0
    fi

    checker="$(find_checker || true)"

    log "Testing formatter safety and idempotence"

    local file
    local first
    local second
    local original_size
    local first_size
    local count=0

    while IFS= read -r -d '' file; do
        if is_expected_invalid_file "$file"; then
            continue
        fi

        count=$((count + 1))

        first="$(mktemp "${TMPDIR:-/tmp}/vfconf-first.XXXXXXXX.vf.conf")"
        second="$(mktemp "${TMPDIR:-/tmp}/vfconf-second.XXXXXXXX.vf.conf")"

        if ! "$formatter" "$file" >"$first"; then
            fail "formatter first pass: ${file#"$PROJECT_ROOT"/}"
            rm -f -- "$first" "$second"
            continue
        fi

        original_size="$(wc -c <"$file" | tr -d '[:space:]')"
        first_size="$(wc -c <"$first" | tr -d '[:space:]')"

        if [[ "$original_size" -gt 0 && "$first_size" -eq 0 ]]; then
            fail "formatter produced empty output: ${file#"$PROJECT_ROOT"/}"
            rm -f -- "$first" "$second"
            continue
        fi

        if [[ -n "$checker" ]]; then
            if ! "$checker" "$first" >/dev/null 2>&1; then
                fail "formatter produced invalid VFConf: ${file#"$PROJECT_ROOT"/}"

                if (( VERBOSE )); then
                    "$checker" "$first" || true
                fi

                rm -f -- "$first" "$second"
                continue
            fi
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
        skip "formatter stability: no valid VFConf files"
    else
        log "Formatter files tested: ${count}"
    fi
}

run_cli_smoke_tests() {
    (( RUN_CLI_TESTS )) || return 0

    log "Running CLI smoke tests"

    local entry
    local build_name
    local public_name
    local executable
    local status

    for entry in "${VFCONF_EXECUTABLES[@]}"; do
        build_name="${entry%%:*}"
        public_name="${entry#*:}"

        executable="$(find_built_binary "$build_name" || true)"

        if [[ -z "$executable" ]]; then
            skip "CLI unavailable: ${public_name}"
            continue
        fi

        set +e
        "$executable" --help >/dev/null 2>&1
        status=$?
        set -e

        if (( status == 0 )); then
            pass "CLI help: ${public_name}"
        else
            fail "CLI help: ${public_name} (exit ${status})"
        fi
    done
}

run_core_cli_tests() {
    (( RUN_CLI_TESTS )) || return 0

    local checker
    local dumper
    local stats
    local temporary

    checker="$(find_built_binary check || true)"
    dumper="$(find_built_binary dump || true)"
    stats="$(find_built_binary stats || true)"

    [[ -n "$checker" ]] || {
        skip "core CLI smoke test: checker unavailable"
        return 0
    }

    temporary="$(mktemp "${TMPDIR:-/tmp}/vfconf-test.XXXXXXXX.vf.conf")"

    printf '%s\n' \
        '[test]' \
        'name = "vfconf"' \
        'enabled = true' \
        >"$temporary"

    if "$checker" "$temporary" >/dev/null 2>&1; then
        pass "CLI check valid file"
    else
        fail "CLI check valid file"
    fi

    if [[ -n "$dumper" ]]; then
        if "$dumper" "$temporary" >/dev/null 2>&1; then
            pass "CLI dump valid file"
        else
            fail "CLI dump valid file"
        fi
    else
        skip "CLI dump unavailable"
    fi

    if [[ -n "$stats" ]]; then
        if "$stats" "$temporary" >/dev/null 2>&1; then
            pass "CLI stats valid file"
        else
            fail "CLI stats valid file"
        fi
    else
        skip "CLI stats unavailable"
    fi

    rm -f -- "$temporary"
}

run_fuzz_tests() {
    (( RUN_FUZZ )) || return 0

    if [[ ! -d "${PROJECT_ROOT}/fuzz" ]]; then
        skip "fuzz directory not found"
        return 0
    fi

    log "Running fuzz tests"

    if dune build "${DUNE_ARGS[@]}" @fuzz 2>/dev/null; then
        pass "fuzz build"
        return 0
    fi

    if dune build "${DUNE_ARGS[@]}" fuzz 2>/dev/null; then
        pass "fuzz build"
        return 0
    fi

    fail "fuzz build"
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

test_dune_executable_declarations() {
    log "Checking executable declarations"

    local entry
    local build_name

    for entry in "${VFCONF_EXECUTABLES[@]}"; do
        build_name="${entry%%:*}"

        if [[ -f "${PROJECT_ROOT}/bin/${build_name}.ml" ]]; then
            pass "source executable: bin/${build_name}.ml"
        else
            fail "missing executable source: bin/${build_name}.ml"
        fi
    done
}

print_summary() {
    local total

    total=$((PASSED + FAILED + SKIPPED))

    printf '\n'
    printf '%s\n' '============================================================'
    printf '%s\n' ' VFConf test summary'
    printf '%s\n' '============================================================'
    printf ' Profile:    %s\n' "$PROFILE"
    printf ' Commands:   %d\n' "${#VFCONF_EXECUTABLES[@]}"
    printf ' Passed:     %d\n' "$PASSED"
    printf ' Failed:     %d\n' "$FAILED"
    printf ' Skipped:    %d\n' "$SKIPPED"
    printf ' Total:      %d\n' "$total"
    printf '%s\n' '============================================================'

    if (( FAILED > 0 )); then
        error "test suite failed with ${FAILED} failure(s)"
        return 1
    fi

    log "All requested tests passed"
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
    log "VFConf executables: ${#VFCONF_EXECUTABLES[@]}"

    test_required_project_files
    test_required_directories
    test_dune_executable_declarations

    build_project || true
    verify_executables

    run_dune_tests
    run_diagnostics_gate

    validate_vfconf_files
    validate_project_categories

    formatter_stability_test

    run_cli_smoke_tests
    run_core_cli_tests

    run_fuzz_tests

    print_summary
}

main "$@"