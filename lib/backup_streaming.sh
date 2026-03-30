#!/bin/bash
# =============================================================================
# FASE 2: BACKUP STREAMING MOODLEDATA → GOOGLE DRIVE - Moodle Backup CLI
# =============================================================================
# Comprime y envía moodledata directamente a GDrive sin espacio local.
# Requiere: variables de config cargadas, lib/logging.sh, lib/notifications.sh
# =============================================================================

# Verificar prerequisitos para streaming
check_streaming_prerequisites() {
    log_message "INFO" "Verificando prerequisites para streaming..."
    
    [ ! -d "$SRC_DATA" ] && { log_message "ERROR" "Directorio moodledata no existe: $SRC_DATA"; return 1; }
    command -v rclone >/dev/null 2>&1 || { log_message "ERROR" "rclone no instalado"; return 1; }
    command -v tar >/dev/null 2>&1 || { log_message "ERROR" "tar no disponible"; return 1; }
    rclone lsd "${GDRIVE_REMOTE}:" >/dev/null 2>&1 || { log_message "ERROR" "Remote ${GDRIVE_REMOTE} no funciona"; return 1; }
    
    log_message "SUCCESS" "Prerequisites OK"
    return 0
}

# Ejecutar backup streaming
perform_streaming_backup() {
    local gdrive_path="$1"
    
    log_message "INFO" "Ejecutando compresión y envío streaming..."
    
    # Construir exclusiones
    local exclude_params=""
    if [ -n "$MOODLEDATA_EXCLUDES" ]; then
        for exclude in $MOODLEDATA_EXCLUDES; do
            exclude_params="$exclude_params --exclude='$exclude'"
        done
    fi
    
    local tar_cmd
    tar_cmd="tar $exclude_params -czf - -C $(dirname "$SRC_DATA") $(basename "$SRC_DATA")/"
    local rclone_cmd="rclone rcat '$gdrive_path'"
    
    log_message "INFO" "Comando: $tar_cmd | $rclone_cmd"
    
    if eval "$tar_cmd" | eval "$rclone_cmd"; then
        log_message "SUCCESS" "Streaming completado"
        return 0
    else
        log_message "ERROR" "Falló el streaming"
        return 1
    fi
}

# Verificar archivo en GDrive
verify_streaming_backup() {
    local gdrive_path="$1"
    
    log_message "INFO" "Verificando backup en Google Drive..."
    
    local file_info
    file_info=$(rclone ls "$gdrive_path" 2>/dev/null)
    
    if [ -n "$file_info" ]; then
        local size
        size=$(echo "$file_info" | awk '{print $1}')
        local size_mb=$((size / 1024 / 1024))
        local size_gb=$((size_mb / 1024))
        
        log_message "SUCCESS" "Verificado: ${size_gb}GB (${size_mb}MB)"
        echo "${size_gb}GB"
        return 0
    else
        log_message "ERROR" "No se pudo verificar archivo"
        return 1
    fi
}

# Ejecutar Fase 2 completa
run_phase2() {
    local config_name="$1"
    local date_str
    date_str=$(date +%d-%m-%Y)
    local time_str
    time_str=$(date +%H%M%S)
    local start_time
    start_time=$(date +%s)
    
    local backup_name="${INSTANCE_NAME}_moodledata_${date_str}_${time_str}.tar.gz"
    local gdrive_path="${GDRIVE_REMOTE}:${GDRIVE_BASE_PATH}/${INSTANCE_NAME}/${date_str}/${backup_name}"
    local log_file="${BACKUP_BASE}/${INSTANCE_NAME}/stream_backup_${date_str}_${time_str}.log"
    local pid_file="/tmp/backup_stream_${INSTANCE_NAME}.pid"
    
    mkdir -p "$(dirname "$log_file")"
    init_logging "$log_file"
    
    log_message "INFO" "=== FASE 2: STREAMING MOODLEDATA ==="
    log_message "INFO" "Configuración: $config_name | Fuente: $SRC_DATA"
    log_message "INFO" "Destino: $gdrive_path"
    
    # Verificar que no hay otro proceso
    if [ -f "$pid_file" ]; then
        local old_pid
        old_pid=$(cat "$pid_file")
        if ps -p "$old_pid" >/dev/null 2>&1; then
            log_message "ERROR" "Otro backup en curso (PID: $old_pid)"
            return 1
        fi
        rm -f "$pid_file"
    fi
    
    echo $$ > "$pid_file"
    trap 'rm -f "$pid_file"' EXIT
    
    # Prerequisites
    check_streaming_prerequisites || { send_phase2_error "Falla en prerequisites" "N/A"; return 1; }
    
    # Crear dir en GDrive
    rclone mkdir "${GDRIVE_REMOTE}:${GDRIVE_BASE_PATH}/${INSTANCE_NAME}/${date_str}/" 2>/dev/null
    
    # Ejecutar streaming
    if ! perform_streaming_backup "$gdrive_path"; then
        local elapsed
        elapsed=$(get_elapsed_time "$start_time")
        send_phase2_error "Falló streaming" "$elapsed"
        return 1
    fi
    
    # Verificar
    local final_size
    if final_size=$(verify_streaming_backup "$gdrive_path"); then
        local elapsed
        elapsed=$(get_elapsed_time "$start_time")
        log_message "SUCCESS" "=== FASE 2 COMPLETADA ($elapsed) ==="
        send_phase2_success "$elapsed" "$final_size" "$gdrive_path"
        return 0
    else
        local elapsed
        elapsed=$(get_elapsed_time "$start_time")
        send_phase2_error "Verificación falló" "$elapsed"
        return 1
    fi
}
