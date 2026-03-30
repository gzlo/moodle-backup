.PHONY: install uninstall test test-docker lint help

INSTALL_DIR ?= /opt/moodle-backup
SHELL := /bin/bash

help: ## Mostrar ayuda
@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Instalar en $(INSTALL_DIR) (requiere root)
@sudo bash scripts/install.sh

uninstall: ## Desinstalar (requiere root)
@sudo bash scripts/uninstall.sh

test: ## Ejecutar tests con BATS
@bash tests/run_tests.sh

test-unit: ## Ejecutar solo tests unitarios
@bats tests/unit/

test-integration: ## Ejecutar solo tests de integración
@bats tests/integration/

test-docker: ## Ejecutar tests en Docker
@docker compose -f tests/docker/docker-compose.test.yml up --build --abort-on-container-exit
@docker compose -f tests/docker/docker-compose.test.yml down -v

lint: ## Ejecutar shellcheck
@echo "=== ShellCheck ==="
@shellcheck -x bin/mb lib/*.sh scripts/*.sh 2>/dev/null || { \
echo "Instalar shellcheck: apt install shellcheck / brew install shellcheck"; \
exit 1; \
}
@echo "✅ Sin errores de lint"

check-deps: ## Verificar dependencias del sistema
@bash scripts/check_dependencies.sh

dev-setup: ## Configurar entorno de desarrollo
@echo "Instalando BATS..."
@git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-install 2>/dev/null && \
cd /tmp/bats-install && sudo ./install.sh /usr/local && rm -rf /tmp/bats-install || true
@echo "Instalando bats-support y bats-assert..."
@mkdir -p tests/lib
@git clone --depth 1 https://github.com/bats-core/bats-support.git tests/lib/bats-support 2>/dev/null || true
@git clone --depth 1 https://github.com/bats-core/bats-assert.git tests/lib/bats-assert 2>/dev/null || true
@echo "✅ Entorno de desarrollo listo"
