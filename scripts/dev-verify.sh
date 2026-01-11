#!/bin/bash
# dev-verify.sh - Auto-detect project type and run verification checks
# Returns: 0 = all passed, 1 = failures found
# Output: JSON with results for structured parsing

set -euo pipefail

WORKDIR="${1:-.}"
cd "$WORKDIR"

# Results tracking
declare -A CHECKS
FAILED=0

# Helper functions
run_check() {
    local name="$1"
    local cmd="$2"

    if output=$(eval "$cmd" 2>&1); then
        CHECKS["$name"]="pass"
        echo "  [PASS] $name"
    else
        CHECKS["$name"]="fail"
        FAILED=1
        echo "  [FAIL] $name"
        echo "$output" | head -20 | sed 's/^/         /'
    fi
}

skip_check() {
    local name="$1"
    CHECKS["$name"]="skip"
    echo "  [SKIP] $name (not configured)"
}

echo "=== DEV VERIFICATION ==="
echo "Directory: $WORKDIR"
echo ""

# Detect project type and run appropriate checks
# ---------------------------------------------

# Python project
if [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]] || [[ -f "requirements.txt" ]]; then
    echo "[Python Project Detected]"

    # Ruff (fast linter)
    if command -v ruff &>/dev/null; then
        run_check "lint:ruff" "ruff check . --quiet"
    elif command -v flake8 &>/dev/null; then
        run_check "lint:flake8" "flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics"
    else
        skip_check "lint"
    fi

    # Type checking
    if command -v mypy &>/dev/null && [[ -f "pyproject.toml" ]]; then
        run_check "typecheck:mypy" "mypy . --ignore-missing-imports --no-error-summary 2>/dev/null || true"
    elif command -v pyright &>/dev/null; then
        run_check "typecheck:pyright" "pyright --outputjson 2>/dev/null | jq -e '.generalDiagnostics | length == 0'"
    else
        skip_check "typecheck"
    fi

    # Tests
    if command -v pytest &>/dev/null && [[ -d "tests" || -d "test" ]]; then
        run_check "test:pytest" "pytest --tb=short -q 2>/dev/null"
    else
        skip_check "test"
    fi
fi

# Node.js/TypeScript project
if [[ -f "package.json" ]]; then
    echo "[Node.js Project Detected]"

    # Get package manager
    if [[ -f "pnpm-lock.yaml" ]]; then
        PM="pnpm"
    elif [[ -f "yarn.lock" ]]; then
        PM="yarn"
    elif [[ -f "bun.lockb" ]]; then
        PM="bun"
    else
        PM="npm"
    fi

    # Lint
    if grep -q '"lint"' package.json 2>/dev/null; then
        run_check "lint:$PM" "$PM run lint 2>/dev/null"
    else
        skip_check "lint"
    fi

    # TypeScript check
    if [[ -f "tsconfig.json" ]]; then
        if command -v tsc &>/dev/null; then
            run_check "typecheck:tsc" "tsc --noEmit 2>/dev/null"
        elif grep -q '"typecheck"' package.json 2>/dev/null; then
            run_check "typecheck:$PM" "$PM run typecheck 2>/dev/null"
        else
            skip_check "typecheck"
        fi
    fi

    # Tests
    if grep -q '"test"' package.json 2>/dev/null; then
        run_check "test:$PM" "$PM run test 2>/dev/null || true"
    else
        skip_check "test"
    fi

    # Build
    if grep -q '"build"' package.json 2>/dev/null; then
        run_check "build:$PM" "$PM run build 2>/dev/null"
    else
        skip_check "build"
    fi
fi

# Go project
if [[ -f "go.mod" ]]; then
    echo "[Go Project Detected]"

    if command -v go &>/dev/null; then
        run_check "lint:go-vet" "go vet ./... 2>&1"
        run_check "build:go" "go build ./... 2>&1"
        run_check "test:go" "go test ./... -short 2>&1"
    fi
fi

# Rust project
if [[ -f "Cargo.toml" ]]; then
    echo "[Rust Project Detected]"

    if command -v cargo &>/dev/null; then
        run_check "lint:clippy" "cargo clippy --quiet 2>&1"
        run_check "build:cargo" "cargo build --quiet 2>&1"
        run_check "test:cargo" "cargo test --quiet 2>&1"
    fi
fi

# Git status check (always run)
echo ""
echo "[Git Status]"
if git rev-parse --git-dir &>/dev/null; then
    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        echo "  [INFO] Uncommitted changes:"
        git status --short | head -10 | sed 's/^/         /'
    else
        echo "  [INFO] Working tree clean"
    fi
fi

# Summary
echo ""
echo "=== VERIFICATION SUMMARY ==="
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

for check in "${!CHECKS[@]}"; do
    case "${CHECKS[$check]}" in
        pass) ((PASS_COUNT++)) ;;
        fail) ((FAIL_COUNT++)) ;;
        skip) ((SKIP_COUNT++)) ;;
    esac
done

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
