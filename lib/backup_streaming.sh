#!/bin/bash
# =============================================================================
# FASE 2: BACKUP STREAMING MOODLEDATA → CLOUD STORAGE - Moodle Backup CLI
# =============================================================================
# Comprime y envía moodledata directamente a cloud storage sin espacio local.
# Requiere: variables de config cargadas, lib/logging.sh, lib/notifications.sh
# =============================================================================

# Verificar prerequisitos para streaming
check_streaming_prerequisites() {
    log_message "INFO" "Verificando prerequisites para streaming..."
    
    [ ! -d "$SRC_DATA" ] && { log_message "ERROR" "Directorio moodledata no existe: $SRC_DATA"; return 1; }
    command -v rclone >/dev/null 2>&1 || { log_message "ERROR" "rclone no instalado"; return 1; }
    command -v tar >/dev/null 2>&1 || { log_message "ERROR" "tar no disponible"; return 1; }
    rclone lsd "${CLOUD_REMOTE}:" >/dev/null 2>&1 || { log_message "ERROR" "Remote ${CLOUD_REMOTE} no funciona"; return 1; }
    
    log_message "SUCCESS" "Prerequisites OK"
    return 0
}

# Ejecutar backup streaming
perform_streaming_backup() {
    local cloud_path="$1"
    local checksum_file="$2"
    local start_time="${3:-$(date +%s)}"
    
    log_message "INFO" "Ejecutando compresion y envio streaming..."
    
    # Heartbeat: still-alive cada 5 minutos
    local _hb_pid
    (
        while true; do
            sleep 300
            log_message "INFO" "[Progress] Streaming en curso... ($(get_elapsed_time "$start_time"))"
        done
    ) &
    _hb_pid=$!
    
    # Construir exclusiones
    local exclude_params=""
    if [ -n "$MOODLEDATA_EXCLUDES" ]; then
        for exclude in $MOODLEDATA_EXCLUDES; do
            exclude_params="$exclude_params --exclude='$exclude'"
        done
    fi

    # Soporte incremental
    if [ "${INCREMENTAL_BACKUP:-false}" = "true" ] && should_incremental "$INSTANCE_NAME"; then
        local newer_args
        newer_args=$(build_find_newer_args "$(get_last_backup_time "$INSTANCE_NAME")" 2>/dev/null || echo "")
        [ -n "$newer_args" ] && exclude_params="$exclude_params $newer_args"
        log_message "INFO" "Modo incremental activado"
    fi
    
    local tar_cmd
    tar_cmd="tar $exclude_params -czf - -C $(dirname "$SRC_DATA") $(basename "$SRC_DATA")/"
    local rclone_cmd="rclone rcat '$cloud_path' --bwlimit '${UPLOAD_BANDWIDTH_LIMIT:-0}'"
    local encrypt="${ENCRYPT_BACKUPS:-false}"
    local gpg_pass="${GPG_PASSPHRASE:-}"
    local tee_cmd=""
    local _stream_ok=false
    local _gpg_clean=""

    if [ -n "$checksum_file" ]; then
        tee_cmd="tee >(sha256sum > \"$checksum_file\")"
    fi

    if [ "$encrypt" = "true" ] && [ -n "$gpg_pass" ]; then
        log_message "INFO" "Streaming con cifrado GPG"
        local gpg_passfile
        gpg_passfile=$(mktemp)
        chmod 600 "$gpg_passfile"
        echo -n "$gpg_pass" > "$gpg_passfile"
        _gpg_clean="$gpg_passfile"
        if [ -n "$checksum_file" ]; then
            if eval "$tar_cmd" | gpg --batch --passphrase-file "$gpg_passfile" --symmetric --cipher-algo AES256 2>/dev/null | eval "$tee_cmd" | eval "$rclone_cmd"; then
                _stream_ok=true
            fi
        else
            if eval "$tar_cmd" | gpg --batch --passphrase-file "$gpg_passfile" --symmetric --cipher-algo AES256 2>/dev/null | eval "$rclone_cmd"; then
                _stream_ok=true
            fi
        fi
    else
        log_message "INFO" "Comando: $tar_cmd | $rclone_cmd"
        if [ -n "$checksum_file" ]; then
            if eval "$tar_cmd" | eval "$tee_cmd" | eval "$rclone_cmd"; then
                _stream_ok=true
            fi
        else
            if eval "$tar_cmd" | eval "$rclone_cmd"; then
                _stream_ok=true
            fi
        fi
    fi

    # Detener heartbeat
    kill "$_hb_pid" 2>/dev/null || true
    wait "$_hb_pid" 2>/dev/null || true

    # Limpiar passfile GPG
    [ -n "$_gpg_clean" ] && rm -f "$_gpg_clean"

    if [ "$_stream_ok" = true ]; then
        if [ -n "$checksum_file" ]; then
            log_message "SUCCESS" "Streaming completado (checksum generado)"
        else
            log_message "SUCCESS" "Streaming completado"
        fi
        return 0
    fi

    log_message "ERROR" "Fallo el streaming"
    return 1
}

# Verificar archivo en cloud storage con checksum SHA256
verify_streaming_backup() {
    local cloud_path="$1"
    local checksum_cloud_path="${cloud_path}.sha256"
    
    log_message "INFO" "Verificando integridad en cloud storage..."
    
    local file_info
    file_info=$(rclone ls "$cloud_path" 2>/dev/null)
    
    if [ -z "$file_info" ]; then
        log_message "ERROR" "No se pudo verificar archivo en cloud"
        return 1
    fi
    
    local size size_mb size_gb
    size=$(echo "$file_info" | awk '{print $1}')
    size_mb=$((size / 1024 / 1024))
    size_gb=$((size_mb / 1024))
    
    local checksum_info
    checksum_info=$(rclone ls "$checksum_cloud_path" 2>/dev/null)
    if [ -n "$checksum_info" ]; then
        local tmp_checksum
        tmp_checksum=$(mktemp)
        if rclone cat "$checksum_cloud_path" > "$tmp_checksum" 2>/dev/null; then
            if rclone cat "$cloud_path" 2>/dev/null | sha256sum -c "$tmp_checksum" --status 2>/dev/null; then
                log_message "SUCCESS" "Integridad verificada: ${size_gb}GB (${size_mb}MB)"
                rm -f "$tmp_checksum"
                echo "${size_gb}GB"
                return 0
            else
                log_message "ERROR" "Fallo verificacion de integridad SHA256"
                rm -f "$tmp_checksum"
                return 1
            fi
        fi
        rm -f "$tmp_checksum" 2>/dev/null || true
    fi
    
    log_message "SUCCESS" "Archivo existe en cloud: ${size_gb}GB (${size_mb}MB) (sin checksum)"
    echo "${size_gb}GB"
    return 0
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
    
     local backup_ext="tar.gz"
    [ "${ENCRYPT_BACKUPS:-false}" = "true" ] && [ -n "${GPG_PASSPHRASE:-}" ] && backup_ext="tar.gz.gpg"
    local backup_name="${INSTANCE_NAME}_moodledata_${date_str}_${time_str}.${backup_ext}"
    PHASE2_CLOUD_PATH="${CLOUD_REMOTE}:${CLOUD_BASE_PATH}/${INSTANCE_NAME}/${date_str}/${backup_name}"
    PHASE2_CHECKSUM_FILE="/tmp/backup_stream_checksum_${INSTANCE_NAME}_${date_str}_${time_str}.sha256"
    local log_file="${BACKUP_BASE}/${INSTANCE_NAME}/stream_backup_${date_str}_${time_str}.log"
    PHASE2_PID_FILE="/tmp/backup_stream_${INSTANCE_NAME}.pid"
    
    mkdir -p "$(dirname "$log_file")"
    push_log "$log_file"
    
    log_message "INFO" "=== FASE 2: STREAMING MOODLEDATA ==="
    log_message "INFO" "Configuración: $config_name | Fuente: $SRC_DATA"
    log_message "INFO" "Destino: $PHASE2_CLOUD_PATH"
    
    # Verificar que no hay otro proceso
    if [ -f "$PHASE2_PID_FILE" ]; then
        local old_pid
        old_pid=$(cat "$PHASE2_PID_FILE")
        if ps -p "$old_pid" >/dev/null 2>&1; then
            log_message "ERROR" "Otro backup en curso (PID: $old_pid)"
            send_phase2_error "Backup en curso (PID: $old_pid)" "N/A"
            pop_log
            return 1
        fi
        rm -f "$PHASE2_PID_FILE"
    fi
    
    echo $$ > "$PHASE2_PID_FILE"
    PHASE2_SUCCESS=false
    
    # Prerequisites
    check_streaming_prerequisites || { send_phase2_error "Falla en prerequisites" "N/A"; pop_log; return 1; }
    
    # Crear dir en GDrive
    rclone mkdir "${CLOUD_REMOTE}:${CLOUD_BASE_PATH}/${INSTANCE_NAME}/${date_str}/" 2>/dev/null
    retry_with_backoff "${MAX_RETRIES:-3}" "${RETRY_INITIAL_WAIT:-5}" \
        rclone mkdir "${CLOUD_REMOTE}:${CLOUD_BASE_PATH}/${INSTANCE_NAME}/${date_str}/" 2>/dev/null || true
    
    # Ejecutar streaming
    if ! perform_streaming_backup "$PHASE2_CLOUD_PATH" "$PHASE2_CHECKSUM_FILE" "$start_time"; then
        local elapsed
        elapsed=$(get_elapsed_time "$start_time")
        send_phase2_error "Fallo streaming" "$elapsed"
        _run_phase2_cleanup
        pop_log
        return 1
    fi

    # Subir checksum a cloud
    if [ -f "$PHASE2_CHECKSUM_FILE" ] && [ -s "$PHASE2_CHECKSUM_FILE" ]; then
        rclone move "$PHASE2_CHECKSUM_FILE" "${PHASE2_CLOUD_PATH}.sha256" 2>/dev/null || true
        log_message "INFO" "Checksum SHA256 subido a cloud"
    fi
    
    # Verificar
    local final_size
    if final_size=$(verify_streaming_backup "$PHASE2_CLOUD_PATH"); then
        PHASE2_SUCCESS=true
        local elapsed
        elapsed=$(get_elapsed_time "$start_time")

        # Métricas de rendimiento
        local stream_size
        stream_size=$(rclone ls "$PHASE2_CLOUD_PATH" 2>/dev/null | awk '{print $1}')
        local stream_elapsed=$(( $(date +%s) - start_time ))
        local speed="N/A"
        if [ "$stream_elapsed" -gt 0 ] && [ -n "$stream_size" ] && [ "$stream_size" -gt 0 ]; then
            speed=$(echo "scale=2; $stream_size / 1048576 / $stream_elapsed" | bc 2>/dev/null || echo "N/A")
            log_message "INFO" "[Metrics] Streaming: $(echo "scale=1; $stream_size / 1073741824" | bc 2>/dev/null)G en ${elapsed} (${speed}MB/s)"
        fi

        log_message "SUCCESS" "=== FASE 2 COMPLETADA ($elapsed) ==="
        send_phase2_success "$elapsed" "$final_size" "$PHASE2_CLOUD_PATH"
        _run_phase2_cleanup
        pop_log
        return 0
    else
        local elapsed
        elapsed=$(get_elapsed_time "$start_time")
        send_phase2_error "Verificación falló" "$elapsed"
        _run_phase2_cleanup
        pop_log
        return 1
    fi
}

# Cleanup explícito de Fase 2 (sin trap EXIT para no sobrescribir el del orquestador)
_run_phase2_cleanup() {
    rm -f "$PHASE2_PID_FILE" "$PHASE2_CHECKSUM_FILE"
    if [ "${PHASE2_SUCCESS:-false}" != "true" ]; then
        log_message "WARNING" "Limpiando archivo parcial en cloud: $PHASE2_CLOUD_PATH"
        rclone delete "$PHASE2_CLOUD_PATH" 2>/dev/null || true
        rclone delete "${PHASE2_CLOUD_PATH}.sha256" 2>/dev/null || true
    fi
}
