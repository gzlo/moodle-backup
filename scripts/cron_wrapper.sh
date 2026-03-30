#!/bin/bash
# =============================================================================
# CRON WRAPPER PARA BACKUP MOODLE - EJECUCIÓN AUTOMÁTICA
# =============================================================================
# Llamado por cron. Resuelve rutas y ejecuta backup.
# USO: crontab: 0 2 28 * * /opt/moodle-backup/scripts/cron_wrapper.sh ivama
# =============================================================================

MB_INSTALL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export MB_INSTALL_DIR

# Cargar librerías
source "${MB_INSTALL_DIR}/lib/utils.sh"
source "${MB_INSTALL_DIR}/lib/logging.sh"
source "${MB_INSTALL_DIR}/lib/config.sh"

CONFIG="${1:-}"
LOG_DIR="/var/log/moodle-backup"
LOG_FILE="$LOG_DIR/cron_wrapper.log"

mkdir -p "$LOG_DIR"

log_cron() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

if [ -z "$CONFIG" ]; then
    log_cron "❌ Debe especificar configuración: $0 <config>"
    exit 1
fi

log_cron "=== INICIO CRON BACKUP ==="
log_cron "Configuración: $CONFIG"

# Cargar config
config_file="${MB_INSTALL_DIR}/configs/enabled/${CONFIG}.config"
if [ ! -f "$config_file" ]; then
    log_cron "❌ Config no encontrada: $config_file"
    exit 1
fi
source "$config_file"

# Verificar periodicidad
should_run() {
    local schedule="${CRON_SCHEDULE:-7}"
    local today=$(date '+%Y-%m-%d')
    local last_run_file="/tmp/mb_last_run_${CONFIG}"

    case "$schedule" in
        1) echo "$today" > "$last_run_file"; return 0 ;;
        2) local days=2 ;;
        3) local days=5 ;;
        4) [ "$(date '+%u')" = "7" ] && { echo "$today" > "$last_run_file"; return 0; }; return 1 ;;
        5) local d=$(date '+%d'); [ "$d" = "01" ] || [ "$d" = "15" ] && { echo "$today" > "$last_run_file"; return 0; }; return 1 ;;
        6) [ "$(date '+%d')" = "01" ] && { echo "$today" > "$last_run_file"; return 0; }; return 1 ;;
        7) echo "$today" > "$last_run_file"; return 0 ;;
        *) log_cron "❌ CRON_SCHEDULE inválido: $schedule"; return 1 ;;
    esac

    # Para schedules 2,3 (cada X días)
    if [ -n "${days:-}" ]; then
        if [ ! -f "$last_run_file" ]; then
            echo "$today" > "$last_run_file"; return 0
        fi
        local last=$(cat "$last_run_file" 2>/dev/null || echo "1970-01-01")
        local diff=$(( ($(date -d "$today" +%s) - $(date -d "$last" +%s 2>/dev/null || echo 0)) / 86400 ))
        [ $diff -ge $days ] && { echo "$today" > "$last_run_file"; return 0; }
        return 1
    fi
}

if should_run; then
    log_cron "✅ Ejecutando backup"
    if "${MB_INSTALL_DIR}/bin/mb" backup "$CONFIG" >> "$LOG_FILE" 2>&1; then
        log_cron "✅ Backup completado"
    else
        log_cron "❌ Backup falló (código: $?)"
    fi
else
    log_cron "⏭️ Saltando según periodicidad"
fi

log_cron "=== FIN CRON BACKUP ==="
