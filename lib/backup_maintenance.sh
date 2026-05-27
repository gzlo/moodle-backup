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

# Crear archivo temporal de opciones MySQL (.cnf) para --defaults-extra-file
# Resuelve INC-001 (MYSQL_PWD incompatible con MariaDB 10.11) e INC-003 (comillas en .cnf)
_create_mysql_cnf() {
    local tmp_cnf
    tmp_cnf=$(mktemp "${TMPDIR:-/tmp}/.mysql_backup_${$}_XXXXXX.cnf")
    chmod 600 "$tmp_cnf"
    cat > "$tmp_cnf" <<EOF
[client]
user=$DB_USER
password=$DB_PASSWORD
EOF
    echo "$tmp_cnf"
}

# Backup de base de datos (MySQL/MariaDB o PostgreSQL)
backup_database() {
    local backup_dir="$1"
    local db_backup
    db_backup="${backup_dir}/${INSTANCE_NAME}_database_$(date +%d-%m-%Y).zip"
    local temp_sql="${backup_dir}/temp_database.sql"
    local engine="${DB_ENGINE:-mysql}"
    local host="${DB_HOST:-localhost}"
    local port="${DB_PORT:-}"
    
    log_message "INFO" "Iniciando backup de BD ($engine): $DB_NAME"
    [ "${INCREMENTAL_BACKUP:-false}" = "true" ] && log_message "INFO" "BD: dump completo (incremental no soportado en BD)"

    local dump_success=false
    case "$engine" in
        pgsql|postgresql|postgres)
            [ -n "$port" ] && host="${host}:${port}"
            if PGPASSWORD="$DB_PASSWORD" pg_dump -h "$host" -U "$DB_USER" "$DB_NAME" > "$temp_sql" 2>/dev/null \
               && [ -f "$temp_sql" ] && [ -s "$temp_sql" ]; then
                dump_success=true
            fi
            ;;
        *)
            local tmp_cnf
            tmp_cnf=$(_create_mysql_cnf)
            local mysqldump_exit=0
            mysqldump --defaults-extra-file="$tmp_cnf" -h "$host" ${port:+--port="$port"} "$DB_NAME" > "$temp_sql" 2>/dev/null || mysqldump_exit=$?
            rm -f "$tmp_cnf"
            if { [ "$mysqldump_exit" -eq 0 ] || [ "$mysqldump_exit" -eq 5 ]; } && [ -f "$temp_sql" ] && [ -s "$temp_sql" ]; then
                dump_success=true
            fi
            ;;
    esac

    if [ "$dump_success" = true ]; then
        log_message "SUCCESS" "Dump de BD creado"
        
         cd "$(dirname "$temp_sql")" || return 1
        if zip -j "$db_backup" "$(basename "$temp_sql")" >/dev/null 2>&1 \
           && [ -f "$db_backup" ]; then
            rm -f "$temp_sql"
            { cd "$(dirname "$db_backup")" && sha256sum "$(basename "$db_backup")" > "${db_backup}.sha256"; } 2>/dev/null || true

            if [ "${ENCRYPT_BACKUPS:-false}" = "true" ]; then
                if encrypt_file "$db_backup" "${db_backup}.gpg"; then
                    rm -f "${db_backup}.sha256" 2>/dev/null || true
                    { cd "$(dirname "$db_backup")" && sha256sum "$(basename "$db_backup").gpg" > "${db_backup}.gpg.sha256"; } 2>/dev/null || true
                    log_message "SUCCESS" "Backup BD cifrado: $(get_file_size "${db_backup}.gpg")"
                    echo "${db_backup}.gpg"
                    return 0
                fi
            fi

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

    local zip_success=false
    if [ "${INCREMENTAL_BACKUP:-false}" = "true" ] && should_incremental "$INSTANCE_NAME"; then
        local last_time newer_args
        last_time=$(get_last_backup_time "$INSTANCE_NAME")
        newer_args=$(build_find_newer_args "$last_time" 2>/dev/null || echo "")
        if [ -n "$newer_args" ]; then
            log_message "INFO" "Backup incremental de app desde: $last_time"
            local newer_iso
            newer_iso=$(date -d "$last_time" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "")
            if [ -n "$newer_iso" ] && find "$(basename "$SRC_APP")" -newermt "$newer_iso" -type f 2>/dev/null | zip -q "$app_backup" -@ >/dev/null 2>&1; then
                zip_success=true
            fi
        fi
    fi

    if [ "$zip_success" != "true" ]; then
        if zip -r "$app_backup" "$(basename "$SRC_APP")" >/dev/null 2>&1; then
            zip_success=true
        fi
    fi

    if [ "$zip_success" = "true" ] && [ -f "$app_backup" ]; then
        { cd "$(dirname "$app_backup")" && sha256sum "$(basename "$app_backup")" > "${app_backup}.sha256"; } 2>/dev/null || true

        if [ "${ENCRYPT_BACKUPS:-false}" = "true" ]; then
            if encrypt_file "$app_backup" "${app_backup}.gpg"; then
                rm -f "${app_backup}.sha256" 2>/dev/null || true
                { cd "$(dirname "$app_backup")" && sha256sum "$(basename "$app_backup").gpg" > "${app_backup}.gpg.sha256"; } 2>/dev/null || true
                log_message "SUCCESS" "Backup app cifrado: $(get_file_size "${app_backup}.gpg")"
                echo "${app_backup}.gpg"
                return 0
            fi
        fi

        log_message "SUCCESS" "Backup app: $(get_file_size "$app_backup")"
        echo "$app_backup"
        return 0
    fi
    
    log_message "ERROR" "Falló el backup de aplicación"
    return 1
}

# Subir archivos a Cloud Storage con rclone
upload_to_cloud() {
    local backup_dir="$1"
    local cloud_path="$2"
    
    log_message "INFO" "Subiendo a cloud storage: $cloud_path"
    
    if ! command -v rclone >/dev/null 2>&1; then
        log_message "ERROR" "rclone no instalado"
        return 1
    fi
    
    if ! rclone listremotes | grep -q "${CLOUD_REMOTE}:"; then
        log_message "ERROR" "Remote '${CLOUD_REMOTE}' no encontrado en rclone"
        return 1
    fi
    
    rclone mkdir "$cloud_path" 2>/dev/null
    
   local success=true
    local uploaded_files=""
    for pattern in "*.zip" "*.gpg"; do
        for file in "$backup_dir"/$pattern; do
            [ -f "$file" ] || continue
            log_message "INFO" "Subiendo $(basename "$file")..."
            if retry_with_backoff "${MAX_RETRIES:-3}" "${RETRY_INITIAL_WAIT:-5}" \
                rclone move "$file" "$cloud_path/" --bwlimit "${UPLOAD_BANDWIDTH_LIMIT:-0}" --progress 2>>"$MB_LOG_FILE"; then
                log_message "SUCCESS" "$(basename "$file") subido"
                uploaded_files="$uploaded_files $cloud_path/$(basename "$file")"
            else
                log_message "ERROR" "Falló subida de $(basename "$file")"
                success=false
            fi
        done
    done

    for checksum in "$backup_dir"/*.sha256; do
        [ -f "$checksum" ] || continue
        log_message "INFO" "Subiendo checksum $(basename "$checksum")..."
        rclone move "$checksum" "$cloud_path/" 2>>"$MB_LOG_FILE" || true
    done
    
    # Rollback en fallo parcial: eliminar archivos ya subidos
    if [ "$success" != "true" ] && [ -n "$uploaded_files" ]; then
        log_message "WARNING" "Upload parcial. Revirtiendo archivos ya subidos..."
        for uploaded in $uploaded_files; do
            rclone delete "$uploaded" 2>/dev/null || true
        done
    fi
    
    # Subir log
    [ -n "$MB_LOG_FILE" ] && [ -f "$MB_LOG_FILE" ] && \
        rclone copy "$MB_LOG_FILE" "$cloud_path/" 2>/dev/null
    
    [ "$success" = true ]
}

# Validar requisitos para Fase 1
validate_phase1_requirements() {
    log_message "INFO" "Validando requisitos..."
    local engine="${DB_ENGINE:-mysql}"
    local host="${DB_HOST:-localhost}"
    
    [ ! -d "$SRC_APP" ] && { log_message "ERROR" "App no encontrada: $SRC_APP"; return 1; }
    [ ! -f "$SRC_APP/admin/cli/maintenance.php" ] && { log_message "ERROR" "CLI Moodle no encontrado"; return 1; }
    
    for cmd in zip php rclone; do
        command -v "$cmd" >/dev/null 2>&1 || { log_message "ERROR" "Comando requerido: $cmd"; return 1; }
    done

    case "$engine" in
        pgsql|postgresql|postgres)
            command -v pg_dump >/dev/null 2>&1 || { log_message "ERROR" "pg_dump requerido para PostgreSQL"; return 1; }
            PGPASSWORD="$DB_PASSWORD" psql -h "$host" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1 || {
                log_message "ERROR" "No se puede conectar a PostgreSQL: $DB_NAME@$host"
                return 1
            }
            ;;
        *)
            command -v mysqldump >/dev/null 2>&1 || { log_message "ERROR" "mysqldump requerido"; return 1; }
            local tmp_cnf
            tmp_cnf=$(_create_mysql_cnf)
            mysql --defaults-extra-file="$tmp_cnf" -h "$host" -e "USE $DB_NAME;" 2>/dev/null || {
                rm -f "$tmp_cnf"
                log_message "ERROR" "No se puede conectar a BD: $DB_NAME@$host"
                return 1
            }
            rm -f "$tmp_cnf"
            ;;
    esac
    
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
    
    local cloud_path="${CLOUD_REMOTE}:${CLOUD_BASE_PATH}/${INSTANCE_NAME}/${date_str}"
    
    log_message "INFO" "=== FASE 1: BACKUP BD + APP ==="
    log_message "INFO" "Configuración: $config_name | Instancia: $INSTANCE_NAME"
    
    # Validar
    validate_phase1_requirements || { send_phase1_error "Falla en requisitos" "N/A"; return 1; }
    
    # Modo mantenimiento
    enable_maintenance_mode || { send_phase1_error "No se pudo activar mantenimiento" "N/A"; return 1; }
    
    # Cleanup en caso de error
    local phase1_success=false
    # shellcheck disable=SC2329,SC2317
    _phase1_cleanup() {
        if [ "$phase1_success" != "true" ]; then
            log_message "WARNING" "Limpiando archivos parciales de Fase 1..."
            disable_maintenance_mode 2>/dev/null || true
            rm -f "$backup_dir"/temp_database.sql 2>/dev/null || true
            rm -f "$backup_dir"/*.zip 2>/dev/null || true
        fi
        # Limpiar archivos .cnf temporales de credenciales (seguridad)
        rm -f "${TMPDIR:-/tmp}"/.mysql_backup_"$$"_*.cnf 2>/dev/null || true
    }
    trap _phase1_cleanup EXIT
    
    # Backups
    local db_success=false app_success=false
    local db_backup app_backup
    
    db_backup=$(backup_database "$backup_dir") && db_success=true
    app_backup=$(backup_application "$backup_dir") && app_success=true
    
    # Desactivar mantenimiento
    disable_maintenance_mode
    
    # Subir a cloud
    local cloud_success=false
    if [ "$db_success" = true ] && [ "$app_success" = true ]; then
        upload_to_cloud "$backup_dir" "$cloud_path" && cloud_success=true
    fi
    
    # Resultado
    local elapsed
    elapsed=$(get_elapsed_time "$start_time")
    if [ "$db_success" = true ] && [ "$app_success" = true ] && [ "$cloud_success" = true ]; then
        phase1_success=true
        log_message "SUCCESS" "=== FASE 1 COMPLETADA ($elapsed) ==="
        send_phase1_success "$elapsed" "$(get_file_size "$db_backup")" "$(get_file_size "$app_backup")"
        return 0
    else
        log_message "ERROR" "=== FASE 1 CON ERRORES ($elapsed) ==="
        send_phase1_error "Errores en backup" "$elapsed"
        return 1
    fi
}
