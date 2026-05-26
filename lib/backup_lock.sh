#!/bin/bash
# =============================================================================
# LOCK FILE GLOBAL - Moodle Backup CLI
# =============================================================================
# Previene ejecucion concurrente de backups sobre la misma instancia.
# Usa /tmp/backup_${INSTANCE_NAME}.lock con PID + timestamp.
# =============================================================================

# Adquirir lock para una instancia
acquire_lock() {
    local instance="$1"
    local lock_file="/tmp/backup_${instance}.lock"
    local timeout="${BACKUP_LOCK_TIMEOUT:-3600}"

    if [ -f "$lock_file" ]; then
        local old_pid
        old_pid=$(head -1 "$lock_file" 2>/dev/null)
        local old_time
        old_time=$(sed -n '2p' "$lock_file" 2>/dev/null)

        if [ -n "$old_pid" ] && ps -p "$old_pid" >/dev/null 2>&1; then
            log_message "ERROR" "Backup ya en ejecucion (PID: $old_pid, inicio: ${old_time:-?})"
            return 1
        fi

        local now
        now=$(date +%s)
        local lock_age=0
        if [ -n "$old_time" ] && [[ "$old_time" =~ ^[0-9]+$ ]]; then
            lock_age=$(( (now - old_time) / 60 ))
        fi

        if [ "$lock_age" -gt "$timeout" ]; then
            log_message "WARNING" "Lock stale detectado (>$timeout segundos, antiguedad: ${lock_age}min). Forzando liberacion."
            rm -f "$lock_file"
        else
            log_message "ERROR" "Lock activo. Antiguedad: ${lock_age}min (timeout: $((timeout / 60))min)"
            return 1
        fi
    fi

    printf "%s\n%s\n" "$$" "$(date +%s)" > "$lock_file"
    log_message "INFO" "Lock adquirido: $lock_file (PID: $$)"
    return 0
}

# Liberar lock
release_lock() {
    local instance="$1"
    local lock_file="/tmp/backup_${instance}.lock"

    if [ -f "$lock_file" ]; then
        local stored_pid
        stored_pid=$(head -1 "$lock_file" 2>/dev/null)
        if [ "$stored_pid" = "$$" ]; then
            rm -f "$lock_file"
            log_message "INFO" "Lock liberado: $lock_file"
        else
            log_message "WARNING" "Lock contiene PID $stored_pid, actual es $$. No se libera."
        fi
    fi
}

# Verificar si hay backup en curso
is_backup_running() {
    local instance="$1"
    local lock_file="/tmp/backup_${instance}.lock"
    local timeout="${BACKUP_LOCK_TIMEOUT:-3600}"

    if [ ! -f "$lock_file" ]; then
        return 1
    fi

    local stored_pid
    stored_pid=$(head -1 "$lock_file" 2>/dev/null)
    local stored_time
    stored_time=$(sed -n '2p' "$lock_file" 2>/dev/null)

    if [ -z "$stored_pid" ]; then
        rm -f "$lock_file"
        return 1
    fi

    if ps -p "$stored_pid" >/dev/null 2>&1; then
        return 0
    fi

    local now
    now=$(date +%s)
    local lock_age=0
    if [ -n "$stored_time" ] && [[ "$stored_time" =~ ^[0-9]+$ ]]; then
        lock_age=$((now - stored_time))
    fi

    if [ "$lock_age" -gt "$timeout" ]; then
        rm -f "$lock_file"
        return 1
    fi

    return 1
}

# Esperar a que se libere un lock (con timeout)
wait_for_lock() {
    local instance="$1"
    local max_wait="${2:-300}"

    local waited=0
    while is_backup_running "$instance"; do
        if [ "$waited" -ge "$max_wait" ]; then
            log_message "ERROR" "Timeout esperando liberacion de lock ($max_wait segundos)"
            return 1
        fi
        sleep 5
        waited=$((waited + 5))
    done
    return 0
}
