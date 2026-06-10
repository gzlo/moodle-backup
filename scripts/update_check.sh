#!/bin/bash
# =============================================================================
# CRON WRAPPER PARA VERIFICACIÓN DE ACTUALIZACIONES - Moodle Backup CLI
# =============================================================================
# Llamado por cron. Verifica si hay nueva versión en GitHub y envía email.
# USO: crontab: 0 6 * * 1 /opt/moodle-backup/scripts/update_check.sh academia
# =============================================================================

MB_SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || echo "$0")"
MB_INSTALL_DIR="$(cd "$(dirname "$MB_SCRIPT_PATH")/.." && pwd)"
export MB_INSTALL_DIR

# Cargar librerías necesarias
source "${MB_INSTALL_DIR}/lib/utils.sh"
source "${MB_INSTALL_DIR}/lib/logging.sh"
source "${MB_INSTALL_DIR}/lib/config.sh"
source "${MB_INSTALL_DIR}/lib/i18n.sh"
source "${MB_INSTALL_DIR}/lib/notifications.sh"
source "${MB_INSTALL_DIR}/lib/update.sh"

CONFIG="${1:-}"
LOG_DIR="/var/log/moodle-backup"
LOG_FILE="$LOG_DIR/update_check.log"

mkdir -p "$LOG_DIR"

log_check() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

if [ -z "$CONFIG" ]; then
    log_check "❌ Uso: $0 <config>"
    exit 1
fi

log_check "=== INICIO VERIFICACIÓN DE ACTUALIZACIÓN ==="
log_check "Configuración: $CONFIG"

# Cargar config para obtener email de notificación
if ! load_moodle_config "$CONFIG" 2>/dev/null; then
    log_check "❌ No se pudo cargar configuración: $CONFIG"
    exit 1
fi

log_check "Email de notificación: ${NOTIFICATION_EMAIL:-no configurado}"

# Verificar actualización
log_check "Consultando GitHub..."
OUTPUT=$(run_update_check "$CONFIG" 2>&1)
LOG_RESULT=$?

echo "$OUTPUT" >> "$LOG_FILE"

if [ $LOG_RESULT -eq 0 ]; then
    if echo "$OUTPUT" | grep -q "nueva versión"; then
        log_check "✅ Notificación de update enviada"
    else
        log_check "✅ Sin actualizaciones pendientes"
    fi
else
    log_check "❌ Falló la verificación"
fi

log_check "=== FIN VERIFICACIÓN DE ACTUALIZACIÓN ==="
