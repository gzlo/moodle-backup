#!/bin/bash
# =============================================================================
# FASE 1: BACKUP BD + APP CON MODO MANTENIMIENTO - Moodle Backup CLI
# =============================================================================
# Ejecuta backup de BD y aplicación Moodle con modo mantenimiento.
# Requiere: variables de config cargadas, lib/logging.sh, lib/notifications.sh
# =============================================================================

# Activar modo mantenimiento de Moodle
enable_maintenance_mode() {
    log_message "INFO" "Activando modo mantenimiento de Moodle..."
    
    local maintenance_cli="$SRC_APP/admin/cli/maintenance.php"
    if [ ! -f "$maintenance_cli" ]; then
        log_message "ERROR" "CLI de mantenimiento no encontrado: $maintenance_cli"
        return 1
    fi
    
    if $PHP_CLI "$maintenance_cli" --enable 2>/dev/null; then
        log_message "SUCCESS" "Modo mantenimiento activado"
        return 0
    else
        log_message "ERROR" "No se pudo activar modo mantenimiento"
        return 1
    fi
}

# Desactivar modo mantenimiento
disable_maintenance_mode() {
    log_message "INFO" "Desactivando modo mantenimiento..."
    
    local maintenance_cli="$SRC_APP/admin/cli/maintenance.php"
    [ ! -f "$maintenance_cli" ] && return 1
    
    if $PHP_CLI "$maintenance_cli" --disable 2>/dev/null; then
        log_message "SUCCESS" "Modo mantenimiento desactivado"
        return 0
    else
        log_message "ERROR" "No se pudo desactivar modo mantenimiento"
        return 1
    fi
}

# Backup de base de datos MySQL
backup_database() {
    local backup_dir="$1"
    local db_backup
    db_backup="${backup_dir}/${INSTANCE_NAME}_database_$(date +%d-%m-%Y).zip"
    local temp_sql="${backup_dir}/temp_database.sql"
    
    log_message "INFO" "Iniciando backup de BD: $DB_NAME"
    
    if mysqldump -h "${DB_HOST:-localhost}" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" > "$temp_sql" 2>/dev/null \
       && [ -f "$temp_sql" ] && [ -s "$temp_sql" ]; then
        log_message "SUCCESS" "Dump de BD creado"
        
        cd "$(dirname "$temp_sql")" || return 1
        if zip -j "$db_backup" "$(basename "$temp_sql")" >/dev/null 2>&1 \
           && [ -f "$db_backup" ]; then
            rm -f "$temp_sql"
            log_message "SUCCESS" "Backup BD: $(get_file_size "$db_backup")"
            echo "$db_backup"
            return 0
        fi
    fi
    
    rm -f "$temp_sql"
    log_message "ERROR" "Falló el backup de BD"
    return 1
}

# Backup de archivos de aplicación
backup_application() {
    local backup_dir="$1"
    local app_backup
    app_backup="${backup_dir}/${INSTANCE_NAME}_app_$(date +%d-%m-%Y).zip"
    
    log_message "INFO" "Iniciando backup de app: $SRC_APP"
    
    if [ ! -d "$SRC_APP" ]; then
        log_message "ERROR" "Directorio no existe: $SRC_APP"
        return 1
    fi
    
    cd "$(dirname "$SRC_APP")" || return 1
    if zip -r "$app_backup" "$(basename "$SRC_APP")" >/dev/null 2>&1 \
       && [ -f "$app_backup" ]; then
        log_message "SUCCESS" "Backup app: $(get_file_size "$app_backup")"
        echo "$app_backup"
        return 0
    fi
    
    log_message "ERROR" "Falló el backup de aplicación"
    return 1
}

# Subir archivos a Google Drive con rclone
upload_to_gdrive() {
    local backup_dir="$1"
    local gdrive_path="$2"
    
    log_message "INFO" "Subiendo a Google Drive: $gdrive_path"
    
    if ! command -v rclone >/dev/null 2>&1; then
        log_message "ERROR" "rclone no instalado"
        return 1
    fi
    
    if ! rclone listremotes | grep -q "${GDRIVE_REMOTE}:"; then
        log_message "ERROR" "Remote '${GDRIVE_REMOTE}' no encontrado en rclone"
        return 1
    fi
    
    rclone mkdir "$gdrive_path" 2>/dev/null
    
    local success=true
    for file in "$backup_dir"/*.zip; do
        [ -f "$file" ] || continue
        log_message "INFO" "Subiendo $(basename "$file")..."
        if rclone move "$file" "$gdrive_path/" --progress 2>>"$MB_LOG_FILE"; then
            log_message "SUCCESS" "$(basename "$file") subido"
        else
            log_message "ERROR" "Falló subida de $(basename "$file")"
            success=false
        fi
    done
    
    # Subir log
    [ -n "$MB_LOG_FILE" ] && [ -f "$MB_LOG_FILE" ] && \
        rclone copy "$MB_LOG_FILE" "$gdrive_path/" 2>/dev/null
    
    [ "$success" = true ]
}

# Validar requisitos para Fase 1
validate_phase1_requirements() {
    log_message "INFO" "Validando requisitos..."
    
    [ ! -d "$SRC_APP" ] && { log_message "ERROR" "App no encontrada: $SRC_APP"; return 1; }
    [ ! -f "$SRC_APP/admin/cli/maintenance.php" ] && { log_message "ERROR" "CLI Moodle no encontrado"; return 1; }
    
    for cmd in mysqldump zip php rclone; do
        command -v "$cmd" >/dev/null 2>&1 || { log_message "ERROR" "Comando requerido: $cmd"; return 1; }
    done
    
    mysql -h "${DB_HOST:-localhost}" -u "$DB_USER" -p"$DB_PASSWORD" -e "USE $DB_NAME;" 2>/dev/null || {
        log_message "ERROR" "No se puede conectar a BD: $DB_NAME"
        return 1
    }
    
    log_message "SUCCESS" "Requisitos validados"
    return 0
}

# Ejecutar Fase 1 completa
run_phase1() {
    local config_name="$1"
    local date_str
    date_str=$(date +%d-%m-%Y)
    local start_time
    start_time=$(date +%s)
    
    local backup_dir="${BACKUP_BASE}/${INSTANCE_NAME}/${date_str}"
    mkdir -p "$backup_dir"
    
    local log_file="${backup_dir}/${INSTANCE_NAME}_backup_log_${date_str}.log"
    init_logging "$log_file"
    
    local gdrive_path="${GDRIVE_REMOTE}:${GDRIVE_BASE_PATH}/${INSTANCE_NAME}/${date_str}"
    
    log_message "INFO" "=== FASE 1: BACKUP BD + APP ==="
    log_message "INFO" "Configuración: $config_name | Instancia: $INSTANCE_NAME"
    
    # Validar
    validate_phase1_requirements || { send_phase1_error "Falla en requisitos" "N/A"; return 1; }
    
    # Modo mantenimiento
    enable_maintenance_mode || { send_phase1_error "No se pudo activar mantenimiento" "N/A"; return 1; }
    
    # Cleanup en caso de error
    local cleanup_needed=true
    trap 'if [ "$cleanup_needed" = true ]; then disable_maintenance_mode; fi' ERR
    
    # Backups
    local db_success=false app_success=false
    local db_backup app_backup
    
    db_backup=$(backup_database "$backup_dir") && db_success=true
    app_backup=$(backup_application "$backup_dir") && app_success=true
    
    # Desactivar mantenimiento
    disable_maintenance_mode
    cleanup_needed=false
    trap - ERR
    
    # Subir a GDrive
    local gdrive_success=false
    if [ "$db_success" = true ] && [ "$app_success" = true ]; then
        upload_to_gdrive "$backup_dir" "$gdrive_path" && gdrive_success=true
    fi
    
    # Resultado
    local elapsed
    elapsed=$(get_elapsed_time "$start_time")
    if [ "$db_success" = true ] && [ "$app_success" = true ] && [ "$gdrive_success" = true ]; then
        log_message "SUCCESS" "=== FASE 1 COMPLETADA ($elapsed) ==="
        send_phase1_success "$elapsed" "$(get_file_size "$db_backup")" "$(get_file_size "$app_backup")"
        return 0
    else
        log_message "ERROR" "=== FASE 1 CON ERRORES ($elapsed) ==="
        send_phase1_error "Errores en backup" "$elapsed"
        return 1
    fi
}
