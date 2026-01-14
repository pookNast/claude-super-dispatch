#!/bin/bash
# dev-verify.sh - tldr-powered verification with structured output
# Returns: 0 = all passed, 1 = failures found

set -euo pipefail

WORKDIR="${1:-.}"
cd "$WORKDIR"

FAILED=0
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

echo "=== DEV VERIFICATION (tldr-powered) ==="
echo "Directory: $WORKDIR"
echo ""

# Check tldr availability
if ! command -v tldr &>/dev/null; then
    echo "[ERROR] tldr not found on PATH"
    echo "Install: pip install tldr-cli"
    exit 1
fi

# Helper functions
pass_check() {
    echo "  [PASS] $1"
    ((PASS_COUNT++))
}

fail_check() {
    echo "  [FAIL] $1"
    echo "$2" | head -15 | sed 's/^/         /'
    ((FAIL_COUNT++))
    FAILED=1
}

skip_check() {
    echo "  [SKIP] $1 (not applicable)"
    ((SKIP_COUNT++))
}

# Detect language
detect_lang() {
    if [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] || [[ -f "requirements.txt" ]]; then
        echo "python"
    elif [[ -f "package.json" ]]; then
        echo "typescript"
    elif [[ -f "go.mod" ]]; then
        echo "go"
    elif [[ -f "Cargo.toml" ]]; then
        echo "rust"
    else
        echo "unknown"
    fi
}

LANG=$(detect_lang)
echo "[Project: $LANG]"
echo ""

# =============================================================================
# DIAGNOSTICS (Type check + Lint)
# =============================================================================
echo "[Diagnostics]"

if [[ "$LANG" != "unknown" ]]; then
    DIAG_OUTPUT=$(tldr diagnostics . --lang "$LANG" --format text 2>&1) || true

    # Parse tldr diagnostics output
    ERROR_COUNT=$(echo "$DIAG_OUTPUT" | grep -cE "^(error|Error|ERROR)" || echo "0")

    if [[ "$ERROR_COUNT" -eq 0 ]] && [[ -n "$DIAG_OUTPUT" ]]; then
        pass_check "diagnostics:tldr"
    elif [[ -z "$DIAG_OUTPUT" ]]; then
        pass_check "diagnostics:tldr (no issues)"
    else
        fail_check "diagnostics:tldr" "$DIAG_OUTPUT"
    fi
else
    skip_check "diagnostics"
fi

# =============================================================================
# DEAD CODE DETECTION
# =============================================================================
echo ""
echo "[Dead Code]"

if [[ "$LANG" != "unknown" ]]; then
    DEAD_OUTPUT=$(tldr dead . --lang "$LANG" 2>&1) || true

    # Parse JSON output for dead functions
    DEAD_COUNT=$(echo "$DEAD_OUTPUT" | jq -r '.dead_functions | length' 2>/dev/null || echo "0")

    if [[ "$DEAD_COUNT" -eq 0 ]] || [[ "$DEAD_COUNT" == "null" ]]; then
        pass_check "dead-code:tldr"
    else
        # Show first few dead functions as warning (not failure)
        DEAD_LIST=$(echo "$DEAD_OUTPUT" | jq -r '.dead_functions[:5] | .[] | "  - \(.name) (\(.file):\(.line))"' 2>/dev/null || echo "")
        echo "  [WARN] dead-code:tldr ($DEAD_COUNT unused functions)"
        echo "$DEAD_LIST" | sed 's/^/         /'
        # Don't fail on dead code, just warn
        ((PASS_COUNT++))
    fi
else
    skip_check "dead-code"
fi

# =============================================================================
# TESTS (Change-impact based)
# =============================================================================
echo ""
echo "[Tests]"

# Check if tests directory exists
if [[ -d "tests" ]] || [[ -d "test" ]] || [[ -d "spec" ]] || grep -q '"test"' package.json 2>/dev/null; then
    # Use change-impact for selective testing
    IMPACT_OUTPUT=$(tldr change-impact --session 2>&1) || true
    AFFECTED_TESTS=$(echo "$IMPACT_OUTPUT" | jq -r '.affected_tests | length' 2>/dev/null || echo "0")

    if [[ "$AFFECTED_TESTS" -gt 0 ]] && [[ "$AFFECTED_TESTS" != "null" ]]; then
        echo "  [INFO] Running $AFFECTED_TESTS affected tests (change-impact)"
        TEST_OUTPUT=$(tldr change-impact --run 2>&1) || true
        TEST_EXIT=$(echo "$TEST_OUTPUT" | jq -r '.exit_code' 2>/dev/null || echo "1")

        if [[ "$TEST_EXIT" -eq 0 ]]; then
            pass_check "test:tldr-change-impact"
        else
            FAILURES=$(echo "$TEST_OUTPUT" | jq -r '.failures // "see output"' 2>/dev/null)
            fail_check "test:tldr-change-impact" "$FAILURES"
        fi
    else
        # No affected tests or change-impact unavailable, run full suite
        echo "  [INFO] No change-impact data, running full test suite"

        case "$LANG" in
            python)
                if command -v pytest &>/dev/null; then
                    if TEST_OUT=$(pytest --tb=short -q 2>&1); then
                        pass_check "test:pytest"
                    else
                        fail_check "test:pytest" "$TEST_OUT"
                    fi
                else
                    skip_check "test (pytest not found)"
                fi
                ;;
            typescript)
                PM="npm"
                [[ -f "pnpm-lock.yaml" ]] && PM="pnpm"
                [[ -f "yarn.lock" ]] && PM="yarn"
                [[ -f "bun.lockb" ]] && PM="bun"

                if TEST_OUT=$($PM run test 2>&1); then
                    pass_check "test:$PM"
                else
                    fail_check "test:$PM" "$TEST_OUT"
                fi
                ;;
            go)
                if TEST_OUT=$(go test ./... -short 2>&1); then
                    pass_check "test:go"
                else
                    fail_check "test:go" "$TEST_OUT"
                fi
                ;;
            rust)
                if TEST_OUT=$(cargo test --quiet 2>&1); then
                    pass_check "test:cargo"
                else
                    fail_check "test:cargo" "$TEST_OUT"
                fi
                ;;
            *)
                skip_check "test"
                ;;
        esac
    fi
else
    skip_check "test (no test directory)"
fi

# =============================================================================
# BUILD CHECK (language-specific)
# =============================================================================
echo ""
echo "[Build]"

case "$LANG" in
    typescript)
        if [[ -f "tsconfig.json" ]]; then
            if BUILD_OUT=$(tsc --noEmit 2>&1); then
                pass_check "build:tsc"
            else
                fail_check "build:tsc" "$BUILD_OUT"
            fi
        elif grep -q '"build"' package.json 2>/dev/null; then
            PM="npm"
            [[ -f "pnpm-lock.yaml" ]] && PM="pnpm"
            [[ -f "yarn.lock" ]] && PM="yarn"

            if BUILD_OUT=$($PM run build 2>&1); then
                pass_check "build:$PM"
            else
                fail_check "build:$PM" "$BUILD_OUT"
            fi
        else
            skip_check "build"
        fi
        ;;
    go)
        if BUILD_OUT=$(go build ./... 2>&1); then
            pass_check "build:go"
        else
            fail_check "build:go" "$BUILD_OUT"
        fi
        ;;
    rust)
        if BUILD_OUT=$(cargo build --quiet 2>&1); then
            pass_check "build:cargo"
        else
            fail_check "build:cargo" "$BUILD_OUT"
        fi
        ;;
    python)
        # Python doesn't need build, but check for syntax errors
        if command -v python3 &>/dev/null; then
            if BUILD_OUT=$(python3 -m py_compile $(find . -name "*.py" -not -path "./.*" | head -20) 2>&1); then
                pass_check "syntax:python"
            else
                fail_check "syntax:python" "$BUILD_OUT"
            fi
        else
            skip_check "syntax"
        fi
        ;;
    *)
        skip_check "build"
        ;;
esac

# =============================================================================
# GIT STATUS
# =============================================================================
echo ""
echo "[Git Status]"
if git rev-parse --git-dir &>/dev/null; then
    CHANGES=$(git status --porcelain 2>/dev/null | wc -l)
    if [[ "$CHANGES" -gt 0 ]]; then
        echo "  [INFO] $CHANGES uncommitted changes:"
        git status --short | head -10 | sed 's/^/         /'
    else
        echo "  [INFO] Working tree clean"
    fi
fi

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo "=== VERIFICATION SUMMARY ==="
echo "Passed: $PASS_COUNT | Failed: $FAIL_COUNT | Skipped: $SKIP_COUNT"

if [[ $FAILED -eq 0 ]]; then
    echo ""
    echo "STATUS: ALL CHECKS PASSED"
    exit 0
else
    echo ""
    echo "STATUS: VERIFICATION FAILED"
    exit 1
fi
