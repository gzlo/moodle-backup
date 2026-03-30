#!/bin/bash
# =============================================================================
# TEST HELPER - Setup BATS environment with mocks
# =============================================================================

# Detectar directorio del proyecto
export MB_PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export MB_INSTALL_DIR="$MB_PROJECT_DIR"

# Agregar mocks al PATH (interceptan comandos reales)
export PATH="${MB_PROJECT_DIR}/tests/mocks:$PATH"

# Crear directorio temporal para tests
setup_test_env() {
    export MB_TEST_DIR=$(mktemp -d)
    export MB_TEST_CONFIGS="$MB_TEST_DIR/configs"
    mkdir -p "$MB_TEST_CONFIGS/available" "$MB_TEST_CONFIGS/enabled"
    
    # Copiar fixture de config
    if [ -f "${MB_PROJECT_DIR}/tests/fixtures/valid.config" ]; then
        cp "${MB_PROJECT_DIR}/tests/fixtures/valid.config" "$MB_TEST_CONFIGS/available/test-moodle.config"
    fi
}

teardown_test_env() {
    [ -n "${MB_TEST_DIR:-}" ] && rm -rf "$MB_TEST_DIR"
}

# Cargar librerías del proyecto
load_lib() {
    local lib="$1"
    source "${MB_PROJECT_DIR}/lib/${lib}.sh"
}

# Override config dirs para tests
setup_test_configs() {
    export CONFIG_BASE_DIR="$MB_TEST_CONFIGS"
    export CONFIG_AVAILABLE_DIR="$MB_TEST_CONFIGS/available"
    export CONFIG_ENABLED_DIR="$MB_TEST_CONFIGS/enabled"
}
