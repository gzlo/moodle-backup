#!/bin/bash
# =============================================================================
# SISTEMA DE LOGGING - Moodle Backup CLI
# =============================================================================

# Variable global para archivo de log actual
MB_LOG_FILE="${MB_LOG_FILE:-}"

# Inicializar logging para una sesión de backup
init_logging() {
    local log_file="$1"
    MB_LOG_FILE="$log_file"
    mkdir -p "$(dirname "$MB_LOG_FILE")"
}

# Escribir mensaje al log y stdout
log_message() {
    local level="$1" message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local line="[$timestamp] [$level] $message"
    
    if [ -n "$MB_LOG_FILE" ]; then
        echo "$line" | tee -a "$MB_LOG_FILE"
    else
        echo "$line"
    fi
}

# Rotar logs antiguos (mantener N días)
rotate_logs() {
    local log_dir="$1"
    local retention_days="${2:-30}"
    
    if [ -d "$log_dir" ] && [ "$retention_days" -gt 0 ]; then
        find "$log_dir" -name "*.log" -type f -mtime +"$retention_days" -delete 2>/dev/null
    fi
}
