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
    
    local gdrive_path="${GDRIVE_REMOTE}:${GDRIVE_BASE_PATH}/${INSTANCE_NAME}"
    local retention="${RETENTION_COPIES:-2}"
    
    local backup_folders
    backup_folders=$(rclone lsf "$gdrive_path" --dirs-only --format "t,f" 2>/dev/null | sort -k1,1)
    
    [ $? -ne 0 ] && { log_message "WARNING" "No se pudo acceder a GDrive para retención"; return 0; }
    
    local folder_count=$(echo "$backup_folders" | grep -c '^[0-9]' 2>/dev/null || echo "0")
    
    log_message "INFO" "Carpetas encontradas: $folder_count (retención: $retention)"
    
    if [ "$folder_count" -le "$retention" ]; then
        log_message "INFO" "Retención OK, no se requiere limpieza"
        return 0
    fi
    
    local folders_to_delete=$((folder_count - retention + 1))
    log_message "WARNING" "Eliminando $folders_to_delete carpetas antiguas"
    
    echo "$backup_folders" | head -n "$folders_to_delete" | while IFS=$'\t' read -r timestamp folder_name; do
        [ -n "$folder_name" ] || continue
        if rclone purge "${gdrive_path}/${folder_name}" 2>/dev/null; then
            log_message "SUCCESS" "Eliminado: $folder_name"
        else
            log_message "ERROR" "Error eliminando: $folder_name"
        fi
    done
}

# Ejecutar backup completo (Fase 1 + Fase 2)
run_full_backup() {
    local config_name="$1"
    local start_time=$(date +%s)
    local orchestrator_log="/tmp/backup_orquestador_${INSTANCE_NAME}_$(date +%d-%m-%Y_%H%M%S).log"
    
    init_logging "$orchestrator_log"
    
    log_message "INFO" "====== INICIANDO BACKUP COMPLETO ======"
    log_message "INFO" "Configuración: $config_name | Instancia: $INSTANCE_NAME"
    
    # Retención
    cleanup_old_backups
    
    # === FASE 1 ===
    log_message "INFO" "====== FASE 1: BACKUP BD + APP ======"
    send_progress_notification "Fase 1 - Backup BD + App" "INICIADO" "$(get_elapsed_time $start_time)"
    
    local phase1_start=$(date +%s)
    local phase1_success=false phase1_result
    
    if run_phase1 "$config_name"; then
        phase1_result="EXITOSO ($(get_elapsed_time $phase1_start))"
        phase1_success=true
    else
        phase1_result="FALLÓ ($(get_elapsed_time $phase1_start))"
    fi
    
    # === FASE 2 ===
    log_message "INFO" "====== FASE 2: STREAMING MOODLEDATA ======"
    local phase2_success=false phase2_result
    
    if [ "$phase1_success" = true ]; then
        send_progress_notification "Fase 2 - Streaming moodledata" "INICIADO" "$(get_elapsed_time $start_time)"
        
        local phase2_start=$(date +%s)
        if run_phase2 "$config_name"; then
            phase2_result="EXITOSO ($(get_elapsed_time $phase2_start))"
            phase2_success=true
        else
            phase2_result="FALLÓ ($(get_elapsed_time $phase2_start))"
        fi
    else
        phase2_result="SALTADO - Error en Fase 1"
        log_message "WARNING" "Saltando Fase 2 por fallo en Fase 1"
    fi
    
    # === RESUMEN ===
    local total_elapsed=$(get_elapsed_time $start_time)
    log_message "INFO" "====== RESUMEN ======"
    log_message "INFO" "Tiempo total: $total_elapsed"
    log_message "INFO" "Fase 1: $phase1_result"
    log_message "INFO" "Fase 2: $phase2_result"
    
    if [ "$phase1_success" = true ] && [ "$phase2_success" = true ]; then
        log_message "SUCCESS" "====== BACKUP COMPLETO EXITOSO ======"
        send_final_notification "true" "$phase1_result" "$phase2_result" "$total_elapsed"
        return 0
    else
        log_message "ERROR" "====== BACKUP COMPLETO CON ERRORES ======"
        send_final_notification "false" "$phase1_result" "$phase2_result" "$total_elapsed"
        return 1
    fi
}
