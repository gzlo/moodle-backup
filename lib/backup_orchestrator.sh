#!/bin/bash
# =============================================================================
# ORQUESTADOR DE BACKUP COMPLETO - Moodle Backup CLI
# =============================================================================
# Ejecuta secuencialmente Fase 1 (BD+App) y Fase 2 (moodledata streaming).
# Maneja retención y notificaciones.
# =============================================================================

# Limpiar backups antiguos según retención
cleanup_old_backups() {
    log_message "INFO" "Verificando retención de backups..."
    
    local cloud_path="${CLOUD_REMOTE}:${CLOUD_BASE_PATH}/${INSTANCE_NAME}"
    local retention="${RETENTION_COPIES:-2}"
    
    # Verificar acceso primero (INC-005: rclone lsf antes de verificar acceso)
    if ! rclone lsf "$cloud_path" --dirs-only --format "t,f" >/dev/null 2>&1; then
        log_message "WARNING" "No se pudo acceder a cloud storage para retención"; return 0
    fi
    
    local backup_folders
    backup_folders=$(rclone lsf "$cloud_path" --dirs-only --format "t,f" 2>/dev/null | sort -k1,1) || true
    
    local folder_count
    folder_count=$(echo "$backup_folders" | grep -c '^[0-9]' 2>/dev/null || echo "0")
    
    log_message "INFO" "Carpetas encontradas: $folder_count (retención: $retention)"
    
    if [ "$folder_count" -le "$retention" ]; then
        log_message "INFO" "Retención OK, no se requiere limpieza"
        return 0
    fi
    
    local folders_to_delete=$((folder_count - retention + 1))
    log_message "WARNING" "Eliminando $folders_to_delete carpetas antiguas"
    
    echo "$backup_folders" | head -n "$folders_to_delete" | while IFS=$'\t' read -r _timestamp folder_name; do
        [ -n "$folder_name" ] || continue
        if rclone purge "${cloud_path}/${folder_name}" 2>/dev/null; then
            log_message "SUCCESS" "Eliminado: $folder_name"
        else
            log_message "ERROR" "Error eliminando: $folder_name"
        fi
    done
}

# Ejecutar backup completo (Fase 1 + Fase 2)
HEARTBEAT_DIR="${HEARTBEAT_DIR:-/var/log/moodle-backup/heartbeats}"

write_heartbeat() {
    local instance="$1" status="$2" elapsed="$3" p1="$4" p2="$5"
    mkdir -p "$HEARTBEAT_DIR" && chmod 700 "$HEARTBEAT_DIR"
    local hb_file="${HEARTBEAT_DIR}/heartbeat_${instance}"
    printf "%s|%s|%s|%s|%s\n" "$(date -Iseconds)" "$status" "$elapsed" "$p1" "$p2" > "$hb_file"
}

check_heartbeat() {
    local instance="$1"
    local max_hours="${2:-24}"
    local hb_file="${HEARTBEAT_DIR}/heartbeat_${instance}"

    if [ ! -f "$hb_file" ]; then
        echo "HEARTBEAT: never"
        return 2
    fi

    local ts status elapsed p1 p2
    IFS='|' read -r ts status elapsed p1 p2 < "$hb_file"
    local now_epoch ts_epoch hours
    now_epoch=$(date +%s)
    ts_epoch=$(date -d "$ts" +%s 2>/dev/null || echo 0)
    hours=$(( (now_epoch - ts_epoch) / 3600 ))

    echo "HEARTBEAT: $status | last: $ts (${hours}h ago) | elapsed: $elapsed | phase1: $p1 | phase2: $p2"

    if [ "$hours" -gt "$max_hours" ]; then
        return 1
    fi
    return 0
}

run_full_backup() {
    local config_name="$1"
    local start_time
    start_time=$(date +%s)
    ORCHESTRATOR_LOG="/tmp/backup_orquestador_${INSTANCE_NAME}_$(date +%d-%m-%Y_%H%M%S).log"

    if [ "${DRY_RUN:-false}" = "true" ]; then
        init_logging "$ORCHESTRATOR_LOG"
        log_message "INFO" "====== DRY-RUN: VALIDANDO SIN EJECUTAR ======"
        log_message "INFO" "Configuracion: $config_name | Instancia: $INSTANCE_NAME"
        log_message "INFO" "Moodle: $SRC_APP | BD: $DB_NAME@${DB_HOST:-localhost}"
        log_message "INFO" "Cloud: ${CLOUD_REMOTE}:${CLOUD_BASE_PATH}/${INSTANCE_NAME}"
        log_message "INFO" "Notificaciones: ${NOTIFICATION_EMAIL}"
        log_message "INFO" "Cifrado: ${ENCRYPT_BACKUPS:-false} | Incremental: ${INCREMENTAL_BACKUP:-false}"
        log_message "INFO" "Retencion: ${RETENTION_COPIES:-2} copias"

        log_message "INFO" "--- Plan de ejecucion ---"
        log_message "INFO" "1. Validar requisitos (mysql, rclone, mantenimiento)"
        log_message "INFO" "2. Activar modo mantenimiento"
        log_message "INFO" "3. Backup BD → ${BACKUP_BASE}/${INSTANCE_NAME}/fecha/"
        log_message "INFO" "4. Backup App → ${BACKUP_BASE}/${INSTANCE_NAME}/fecha/"
        log_message "INFO" "5. Desactivar modo mantenimiento"
        log_message "INFO" "6. Subir a ${CLOUD_REMOTE}:${CLOUD_BASE_PATH}/${INSTANCE_NAME}/fecha/"
        log_message "INFO" "7. Streaming moodledata → ${CLOUD_REMOTE}:${CLOUD_BASE_PATH}/${INSTANCE_NAME}/fecha/"

        if validate_phase1_requirements 2>/dev/null; then
            log_message "SUCCESS" "====== DRY-RUN: VALIDACION OK ======"
            rm -f "$ORCHESTRATOR_LOG"
            return 0
        else
            log_message "ERROR" "====== DRY-RUN: VALIDACION FALLIDA ======"
            rm -f "$ORCHESTRATOR_LOG"
            return 1
        fi
    fi

    acquire_lock "$INSTANCE_NAME" || return 1
    ORCHESTRATOR_SUCCESS=false
    # shellcheck disable=SC2329,SC2317
    _orchestrator_cleanup() {
        release_lock "$INSTANCE_NAME"
        if [ "$ORCHESTRATOR_SUCCESS" != "true" ]; then
            rm -f "$ORCHESTRATOR_LOG" 2>/dev/null || true
        fi
    }
    trap _orchestrator_cleanup EXIT

    init_logging "$ORCHESTRATOR_LOG"
    
    log_message "INFO" "====== INICIANDO BACKUP COMPLETO ======"
    log_message "INFO" "Configuración: $config_name | Instancia: $INSTANCE_NAME"
    
    # Retención
    cleanup_old_backups
    
    # === FASE 1 ===
    log_message "INFO" "====== FASE 1: BACKUP BD + APP ======"
    send_progress_notification "Fase 1 - Backup BD + App" "INICIADO" "$(get_elapsed_time "$start_time")"
    
    local phase1_start
    phase1_start=$(date +%s)
    local phase1_success=false phase1_result
    
    if run_phase1 "$config_name"; then
        phase1_result="EXITOSO ($(get_elapsed_time "$phase1_start"))"
        phase1_success=true
    else
        phase1_result="FALLÓ ($(get_elapsed_time "$phase1_start"))"
    fi
    
    # === FASE 2 ===
    log_message "INFO" "====== FASE 2: STREAMING MOODLEDATA ======"
    local phase2_success=false phase2_result
    
    if [ "$phase1_success" = true ]; then
        send_progress_notification "Fase 2 - Streaming moodledata" "INICIADO" "$(get_elapsed_time "$start_time")"
        
        local phase2_start
        phase2_start=$(date +%s)
        if run_phase2 "$config_name"; then
            phase2_result="EXITOSO ($(get_elapsed_time "$phase2_start"))"
            phase2_success=true
        else
            phase2_result="FALLÓ ($(get_elapsed_time "$phase2_start"))"
        fi
    else
        phase2_result="SALTADO - Error en Fase 1"
        log_message "WARNING" "Saltando Fase 2 por fallo en Fase 1"
    fi
    
    # === RESUMEN ===
    local total_elapsed
    total_elapsed=$(get_elapsed_time "$start_time")
    log_message "INFO" "====== RESUMEN ======"
    log_message "INFO" "Tiempo total: $total_elapsed"
    log_message "INFO" "Fase 1: $phase1_result"
    log_message "INFO" "Fase 2: $phase2_result"
    
    if [ "$phase1_success" = true ] && [ "$phase2_success" = true ]; then
        ORCHESTRATOR_SUCCESS=true
        write_heartbeat "$INSTANCE_NAME" "success" "$total_elapsed" "$phase1_result" "$phase2_result"
        log_message "SUCCESS" "====== BACKUP COMPLETO EXITOSO ======"
        send_final_notification "true" "$phase1_result" "$phase2_result" "$total_elapsed"
        return 0
    else
        write_heartbeat "$INSTANCE_NAME" "failed" "$total_elapsed" "$phase1_result" "$phase2_result"
        log_message "ERROR" "====== BACKUP COMPLETO CON ERRORES ======"
        send_final_notification "false" "$phase1_result" "$phase2_result" "$total_elapsed"
        return 1
    fi
}
