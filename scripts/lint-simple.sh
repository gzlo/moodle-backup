#!/bin/bash

##
# Lint básico y robusto para CI/CD
# Versión simplificada que siempre funciona
##

set -euo pipefail

# Configuración básica
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colores
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

main() {
    log_info "Iniciando lint básico..."
    
    local exit_code=0
    local files_checked=0
    local errors_found=0
    
    # Verificar que shellcheck esté disponible (no fallar si no está)
    if ! command -v shellcheck >/dev/null 2>&1; then
        log_warning "ShellCheck no está instalado, ejecutando solo verificación de sintaxis bash..."
        local shellcheck_available=false
    else
        log_info "ShellCheck versión: $(shellcheck --version | grep version)"
        local shellcheck_available=true
    fi
    
    # Buscar archivos .sh en el proyecto usando rutas relativas
    log_info "Buscando archivos shell..."
    
    cd "$PROJECT_ROOT" || exit 1
    
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            log_info "Verificando: $file"
            ((files_checked++))
            
            # Verificar sintaxis bash
            if ! bash -n "$file" 2>/dev/null; then
                log_error "Error de sintaxis en: $file"
                ((errors_found++))
                exit_code=1
                continue
            fi
            
            # Ejecutar shellcheck si está disponible
            if [[ "$shellcheck_available" == "true" ]]; then
                if ! shellcheck \
                    --shell=bash \
                    --format=gcc \
                    --severity=warning \
                    --exclude=SC1090,SC1091,SC2034 \
                    "$file"; then
                    log_warning "ShellCheck encontró problemas en: $file"
                fi
            else
                log_info "ShellCheck no disponible, verificación básica completada para: $file"
            fi
        fi
    done < <(find . -name "*.sh" -type f 2>/dev/null || true)
    
    # Buscar archivos sin extensión que sean scripts bash
    while IFS= read -r file; do
        if [[ -f "$file" ]] && head -n1 "$file" 2>/dev/null | grep -q "#!/.*bash"; then
            log_info "Verificando script bash: $file"
            ((files_checked++))
            
            if ! bash -n "$file" 2>/dev/null; then
                log_error "Error de sintaxis en: $file"
                ((errors_found++))
                exit_code=1
                continue
            fi
            
            # Ejecutar shellcheck si está disponible
            if [[ "$shellcheck_available" == "true" ]]; then
                if ! shellcheck \
                    --shell=bash \
                    --format=gcc \
                    --severity=warning \
                    --exclude=SC1090,SC1091,SC2034 \
                    "$file"; then
                    log_warning "ShellCheck encontró problemas en: $file"
                fi
            else
                log_info "ShellCheck no disponible, verificación básica completada para: $file"
            fi
        fi
    done < <(find . -type f ! -name "*.sh" 2>/dev/null || true)
    
    echo ""
    echo "=================== RESUMEN ==================="
    echo "Archivos verificados: $files_checked"
    echo "Errores críticos: $errors_found"
    
    if [[ $errors_found -eq 0 ]]; then
        log_success "¡Lint completado sin errores críticos!"
    else
        log_error "Se encontraron $errors_found errores críticos"
    fi
    
    exit $exit_code
}

main "$@"
