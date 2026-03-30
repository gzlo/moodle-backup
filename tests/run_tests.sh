#!/bin/bash
# =============================================================================
# TEST RUNNER - Moodle Backup CLI
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check BATS
if ! command -v bats >/dev/null 2>&1; then
    echo "❌ BATS no instalado. Ejecuta: make dev-setup"
    exit 1
fi

echo "=== Moodle Backup CLI - Test Suite ==="
echo "Proyecto: $PROJECT_DIR"
echo ""

# Run unit tests
echo "--- Unit Tests ---"
bats "$SCRIPT_DIR/unit/"

echo ""

# Run integration tests
echo "--- Integration Tests ---"
bats "$SCRIPT_DIR/integration/"

echo ""
echo "✅ Todos los tests completados"
