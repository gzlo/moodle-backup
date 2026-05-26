#!/bin/bash
# =============================================================================
# BACKUP INCREMENTAL - Moodle Backup CLI
# =============================================================================
# Detecta el ultimo backup exitoso y permite backup incremental (solo
# archivos modificados desde entonces) para moodledata y app.
# La base de datos siempre hace dump completo (no soporta binlog).
# =============================================================================

get_last_backup_time() {
    local instance="$1"
    local hb_file="${HEARTBEAT_DIR:-/var/log/moodle-backup/heartbeats}/heartbeat_${instance}"

    if [ -f "$hb_file" ]; then
        head -1 "$hb_file" 2>/dev/null | cut -d'|' -f1
    fi
}

should_incremental() {
    local last_time
    last_time=$(get_last_backup_time "$1")

    if [ -z "$last_time" ]; then
        log_message "INFO" "No hay backup previo. Se realizara backup completo."
        return 1
    fi

    log_message "INFO" "Backup incremental desde: $last_time"
    return 0
}

build_find_newer_args() {
    local last_time="$1"

    local newer=""
    newer=$(date -d "$last_time" +%s 2>/dev/null || echo "")
    if [ -z "$newer" ] || [ "$newer" -le 0 ]; then
        return 1
    fi

    local newer_iso
    newer_iso=$(date -d "@$newer" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")
    if [ -z "$newer_iso" ]; then
        return 1
    fi

    echo "--newer='$newer_iso'"
    return 0
}
