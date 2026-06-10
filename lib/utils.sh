#!/bin/bash
# =============================================================================
# UTILIDADES COMUNES - Moodle Backup CLI
# =============================================================================

# Versión del CLI
export MB_VERSION="5.2.0"

# Detectar soporte de colores
detect_color_support() {
    [ -n "${NO_COLOR:-}" ] && return 1
    [[ " $* " == *" --no-color "* ]] && return 1
    [ -t 1 ] && [ -n "${TERM:-}" ] && return 0
    return 1
}

# Configurar colores
setup_colors() {
    if detect_color_support "$@"; then
        RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
        BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
    else
        RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
        # usada externamente via source por bin/mb y otros scripts
        # shellcheck disable=SC2034
        BOLD=''
    fi
}

# Mostrar mensajes formateados
show_message() {
    local type="$1" message="$2"
    case "$type" in
        "error")   echo -e "${RED}[ERROR]${NC} $message" >&2 ;;
        "success") echo -e "${GREEN}[OK]${NC} $message" ;;
        "warning") echo -e "${YELLOW}[WARNING]${NC} $message" ;;
        "info")    echo -e "${BLUE}[INFO]${NC} $message" ;;
        *)         echo "$message" ;;
    esac
}

# Calcular tiempo transcurrido (HH:MM:SS)
get_elapsed_time() {
    local start_time="$1"
    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    printf "%02d:%02d:%02d" $((elapsed/3600)) $(((elapsed%3600)/60)) $((elapsed%60))
}

# Obtener tamaño de archivo legible
get_file_size() {
    local file="$1"
    [ -f "$file" ] && du -sh "$file" | cut -f1 || echo "N/A"
}

# Mes en español
month_spanish() {
    local month="${1:-$(date +%m)}"
    local months=("" "Enero" "Febrero" "Marzo" "Abril" "Mayo" "Junio"
                  "Julio" "Agosto" "Septiembre" "Octubre" "Noviembre" "Diciembre")
    echo "${months[$((10#$month))]}"
}

# Reintentar comando con backoff exponencial
retry_with_backoff() {
    local max_retries="${1:-3}"
    local initial_wait="${2:-5}"
    shift 2

    local attempt=1 wait=$initial_wait

    while [ $attempt -le "$max_retries" ]; do
        if "$@"; then
            return 0
        fi

        if [ $attempt -lt "$max_retries" ]; then
            log_message "WARNING" "Intento $attempt/$max_retries fallo. Reintentando en ${wait}s..."
            sleep "$wait"
            wait=$((wait * 2))
        fi
        attempt=$((attempt + 1))
    done

    log_message "ERROR" "Agotados $max_retries intentos"
    return 1
}

# Inicializar colores por defecto
setup_colors "$@"
