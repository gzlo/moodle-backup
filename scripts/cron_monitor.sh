#!/bin/bash
# =============================================================================
# MONITOR DE CRON - Moodle Backup CLI
# =============================================================================

LOG_DIR="/var/log/moodle-backup"
MAIN_LOG="$LOG_DIR/cron_wrapper.log"

echo "━━━ ESTADO CRON MOODLE BACKUP ━━━"
echo ""

echo "🔧 Configuración Cron:"
if crontab -l 2>/dev/null | grep -q "cron_wrapper.sh\|moodle-backup"; then
    echo "✅ Cron job configurado"
    crontab -l 2>/dev/null | grep "cron_wrapper.sh\|moodle-backup"
else
    echo "❌ Cron job NO encontrado"
fi
echo ""

echo "📋 Estado de Logs:"
if [ -f "$MAIN_LOG" ]; then
    local_lines=$(wc -l < "$MAIN_LOG")
    local_size=$(du -h "$MAIN_LOG" | cut -f1)
    echo "✅ Log: $local_lines líneas, $local_size"
else
    echo "⚠️  Log no existe: $MAIN_LOG"
fi
echo ""

echo "📄 Últimas Entradas:"
if [ -f "$MAIN_LOG" ]; then
    tail -n 10 "$MAIN_LOG"
else
    echo "   No hay entradas"
fi
echo ""

echo "━━━ COMANDOS ÚTILES ━━━"
echo "  Ver log:              tail -f $MAIN_LOG"
echo "  Ejecutar manual:      mb backup <config>"
echo "  Estado del sistema:   mb status"
