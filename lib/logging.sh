#!/bin/bash
# =============================================================================
# SISTEMA DE LOGGING - Moodle Backup CLI
# =============================================================================

# Stack de archivos de log activos
MB_LOG_FILE="${MB_LOG_FILE:-}"
MB_LOG_STACK=()

# Inicializar logging para una sesión de backup (push al stack)
init_logging() {
    push_log "$1"
}

# Push: agrega un archivo al stack de logs
push_log() {
    local log_file="$1"
    mkdir -p "$(dirname "$log_file")"
    MB_LOG_STACK+=("$log_file")
    MB_LOG_FILE="$log_file"
}

# Pop: remueve el último archivo del stack
pop_log() {
    if [ ${#MB_LOG_STACK[@]} -gt 0 ]; then
        unset 'MB_LOG_STACK[${#MB_LOG_STACK[@]}-1]'
    fi
    if [ ${#MB_LOG_STACK[@]} -gt 0 ]; then
        MB_LOG_FILE="${MB_LOG_STACK[-1]}"
    else
        MB_LOG_FILE=""
    fi
}

# Escribir mensaje a todos los logs del stack + stdout
log_message() {
    local level="$1" message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local line="[$timestamp] [$level] $message"
    
    if [ ${#MB_LOG_STACK[@]} -gt 0 ]; then
        local logf
        for logf in "${MB_LOG_STACK[@]}"; do
            echo "$line" >> "$logf"
        done
        echo "$line"
    elif [ -n "$MB_LOG_FILE" ]; then
        echo "$line" | tee -a "$MB_LOG_FILE"
    else
        echo "$line"
    fi
}

# Extraer lineas ERROR/WARNING de un archivo de log (para incluir en emails)
extract_log_errors() {
    local log_file="$1"
    local max_lines="${2:-10}"
    if [ -f "$log_file" ] && [ -s "$log_file" ]; then
        grep -E '\[ERROR\]|\[WARNING\]' "$log_file" 2>/dev/null | tail -n "$max_lines"
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
