#!/bin/bash

# Claude Code Post-Tool Hook: Python Linting & Formatting
# Runs ruff check, ruff format, and mypy on modified Python files

set -e  # Exit on error

# Get the list of file paths from Claude Code
FILES="$1"

# Check if we have files to process
if [ -z "$FILES" ]; then
    echo "No files provided to python-lint hook"
    exit 0
fi

# Convert space-separated paths to array and filter for Python files
PYTHON_FILES=()
for file in $FILES; do
    if [[ "$file" == *.py ]]; then
        # Check if file exists (might be deleted)
        if [ -f "$file" ]; then
            PYTHON_FILES+=("$file")
        fi
    fi
done

# Exit if no Python files to process
if [ ${#PYTHON_FILES[@]} -eq 0 ]; then
    echo "No Python files to lint"
    exit 0
fi

echo "🐍 Running Python linting on ${#PYTHON_FILES[@]} file(s)..."

# Change to project directory for proper context
cd "$CLAUDE_PROJECT_DIR"

# Initialize status tracking
RUFF_CHECK_FAILED=false
RUFF_FORMAT_FAILED=false
MYPY_FAILED=false

# Run ruff check
echo "📋 Running ruff check..."
if uv run ruff check "${PYTHON_FILES[@]}" 2>&1; then
    echo "✅ ruff check passed"
else
    echo "❌ ruff check found issues"
    RUFF_CHECK_FAILED=true
fi

# Run ruff format (auto-fix formatting)
echo "🎨 Running ruff format..."
if uv run ruff format "${PYTHON_FILES[@]}" 2>&1; then
    echo "✅ ruff format completed"
else
    echo "❌ ruff format failed"
    RUFF_FORMAT_FAILED=true
fi

# Run mypy on each file individually (mypy can be picky about imports)
echo "🔍 Running mypy..."
MYPY_SUCCESS=true
for file in "${PYTHON_FILES[@]}"; do
    if uv run mypy "$file" --ignore-missing-imports 2>&1; then
        echo "✅ mypy passed for $file"
    else
        echo "❌ mypy found issues in $file"
        MYPY_SUCCESS=false
    fi
done

if [ "$MYPY_SUCCESS" = true ]; then
    echo "✅ mypy passed for all files"
else
    MYPY_FAILED=true
fi

# Summary
echo ""
echo "🎯 Python Linting Summary:"
echo "  ruff check: $([ "$RUFF_CHECK_FAILED" = false ] && echo "✅ PASSED" || echo "❌ FAILED")"
echo "  ruff format: $([ "$RUFF_FORMAT_FAILED" = false ] && echo "✅ PASSED" || echo "❌ FAILED")"
echo "  mypy: $([ "$MYPY_FAILED" = false ] && echo "✅ PASSED" || echo "❌ FAILED")"

# Note: We don't exit with error code to avoid blocking Claude Code operations
# The output will show in Claude Code's hook execution results
exit 0