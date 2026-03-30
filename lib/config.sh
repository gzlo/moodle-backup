#!/bin/bash
# =============================================================================
# GESTIÓN DE CONFIGURACIONES - Moodle Backup CLI
# =============================================================================

# Directorios de configuración (se setean al cargar desde MB_INSTALL_DIR)
_mb_config_dirs_init() {
    MB_INSTALL_DIR="${MB_INSTALL_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    CONFIG_BASE_DIR="${CONFIG_BASE_DIR:-${MB_INSTALL_DIR}/configs}"
    CONFIG_AVAILABLE_DIR="${CONFIG_AVAILABLE_DIR:-${CONFIG_BASE_DIR}/available}"
    CONFIG_ENABLED_DIR="${CONFIG_ENABLED_DIR:-${CONFIG_BASE_DIR}/enabled}"
}
_mb_config_dirs_init


# Backward compatibility: GDRIVE_* → CLOUD_*
_mb_cloud_compat() {
    CLOUD_REMOTE="${CLOUD_REMOTE:-${GDRIVE_REMOTE:-}}"
    CLOUD_BASE_PATH="${CLOUD_BASE_PATH:-${GDRIVE_BASE_PATH:-}}"
    STREAM_TO_CLOUD="${STREAM_TO_CLOUD:-${STREAM_TO_GDRIVE:-true}}"
    export CLOUD_REMOTE CLOUD_BASE_PATH STREAM_TO_CLOUD
}
# Cargar configuración de Moodle por nombre
load_moodle_config() {
    local config_name="$1"
    
    if [ -z "$config_name" ]; then
        echo "ERROR: Debe especificar un nombre de configuración" >&2
        return 1
    fi
    
    # Buscar en enabled primero, luego en available
    local config_file="${CONFIG_ENABLED_DIR}/${config_name}.config"
    [ ! -f "$config_file" ] && config_file="${CONFIG_AVAILABLE_DIR}/${config_name}.config"
    
    if [ ! -f "$config_file" ]; then
        echo "ERROR: Configuración '${config_name}' no encontrada" >&2
        return 1
    fi
    
    # shellcheck disable=SC1090
    if source "$config_file"; then
        validate_config_variables
        local rc=$?
        _mb_cloud_compat
        return $rc
    else
        echo "ERROR: No se pudo cargar: $config_file" >&2
        return 1
    fi
}

# Validar variables obligatorias de configuración
validate_config_variables() {
    local errors=0
    local required_vars=(
        "INSTANCE_NAME" "SRC_APP" "DB_NAME" "DB_USER" 
        "DB_PASSWORD" "NOTIFICATION_EMAIL" "SERVER_NAME"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo "ERROR: Variable obligatoria no definida: $var" >&2
            errors=$((errors + 1))
        fi
    done
    
    # Defaults
    [ -z "$RETENTION_COPIES" ] && export RETENTION_COPIES="2"
    [ -z "$DB_HOST" ] && export DB_HOST="localhost"
    [ -z "$PHP_CLI" ] && export PHP_CLI="/usr/bin/php"
    
    return $errors
}

# Listar configuraciones disponibles
list_available_configs() {
    echo "Configuraciones disponibles:"
    
    if [ ! -d "$CONFIG_AVAILABLE_DIR" ]; then
        echo "  No hay directorio de configuraciones: $CONFIG_AVAILABLE_DIR"
        return
    fi
    
    local found=false
    for config in "$CONFIG_AVAILABLE_DIR"/*.config; do
        [ -f "$config" ] || continue
        [[ "$config" == *"*.config"* ]] && continue
        found=true
        local name
        name=$(basename "$config" .config)
        local enabled=""
        [ -L "${CONFIG_ENABLED_DIR}/${name}.config" ] && enabled=" [HABILITADA]"
        echo "  - ${name}${enabled}"
    done
    
    if [ "$found" = false ]; then
        echo "  No hay configuraciones disponibles"
    fi
}

# Listar solo configuraciones habilitadas
list_enabled_configs() {
    echo "Configuraciones habilitadas:"
    
    if [ ! -d "$CONFIG_ENABLED_DIR" ]; then
        echo "  No hay directorio de configuraciones habilitadas"
        return
    fi
    
    local found=false
    for config in "$CONFIG_ENABLED_DIR"/*.config; do
        [ -L "$config" ] || continue
        [[ "$config" == *"*.config"* ]] && continue
        found=true
        echo "  - $(basename "$config" .config)"
    done
    
    [ "$found" = false ] && echo "  No hay configuraciones habilitadas"
}

# Habilitar configuración (crear symlink)
enable_config() {
    local name="$1"
    local source="${CONFIG_AVAILABLE_DIR}/${name}.config"
    local target="${CONFIG_ENABLED_DIR}/${name}.config"
    
    if [ ! -f "$source" ]; then
        echo "ERROR: Configuración '$name' no existe en available/" >&2
        return 1
    fi
    
    if [ -L "$target" ]; then
        echo "INFO: Configuración '$name' ya está habilitada"
        return 0
    fi
    
    mkdir -p "$CONFIG_ENABLED_DIR"
    ln -s "$source" "$target"
    echo "OK: Configuración '$name' habilitada"
}

# Deshabilitar configuración (eliminar symlink)
disable_config() {
    local name="$1"
    local target="${CONFIG_ENABLED_DIR}/${name}.config"
    
    if [ ! -L "$target" ]; then
        echo "ERROR: Configuración '$name' no está habilitada" >&2
        return 1
    fi
    
    rm -f "$target"
    echo "OK: Configuración '$name' deshabilitada"
}

# Pedir input al usuario con valor por defecto
_ask() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    local value=""
    
    if [ -n "$default" ]; then
        printf "  %s [%s]: " "$prompt" "$default" >&2
    else
        printf "  %s: " "$prompt" >&2
    fi
    
    read -r value
    value="${value:-$default}"
    eval "$var_name=\"$value\""
}

# Detectar automáticamente rutas de Moodle
_detect_moodle() {
    local found=""
    for path in /var/www/html/moodle /var/www/moodle /home/*/public_html/moodle /opt/moodle; do
        if [ -f "$path/config.php" ] 2>/dev/null; then
            found="$path"
            break
        fi
    done
    echo "$found"
}

# Detectar moodledata desde config.php
_detect_moodledata() {
    local moodle_dir="$1"
    if [ -f "$moodle_dir/config.php" ]; then
        grep -oP "dataroot\s*=\s*['\"]?\K[^'\";\s]+" "$moodle_dir/config.php" 2>/dev/null || echo ""
    fi
}

# Detectar datos de BD desde config.php
_detect_db_from_config() {
    local moodle_dir="$1"
    local field="$2"
    if [ -f "$moodle_dir/config.php" ]; then
        grep -oP "\\\$CFG->db${field}\s*=\s*['\"]?\K[^'\";\s]+" "$moodle_dir/config.php" 2>/dev/null || echo ""
    fi
}

# Crear nueva configuración con wizard interactivo
create_config() {
    local name="$1"
    local target="${CONFIG_AVAILABLE_DIR}/${name}.config"
    
    if [ -f "$target" ]; then
        echo "ERROR: Configuración '$name' ya existe" >&2
        return 1
    fi
    
    # Check for --quiet flag (non-interactive, for tests)
    if [[ "${2:-}" == "--quiet" ]]; then
        local template="${CONFIG_AVAILABLE_DIR}/moodle.config.example"
        if [ ! -f "$template" ]; then
            echo "ERROR: Template no encontrado: $template" >&2
            return 1
        fi
        cp "$template" "$target"
        sed -i "s/INSTANCE_NAME=\"mi-instalacion\"/INSTANCE_NAME=\"${name}\"/" "$target"
        echo "OK: Configuración '$name' creada en: $target"
        return 0
    fi
    
    echo ""
    echo "━━━ Wizard: Nueva configuración '$name' ━━━"
    echo ""
    
    # Step 1: Detectar Moodle
    echo "📂 Paso 1/4: Rutas de Moodle"
    local detected_moodle
    detected_moodle=$(_detect_moodle)
    local src_app="" src_data="" backup_base=""
    
    _ask "Directorio de Moodle (donde está config.php)" "$detected_moodle" "src_app"
    
    if [ ! -d "$src_app" ]; then
        echo "  ⚠️  Directorio no existe: $src_app (se usará igual)"
    fi
    
    # Intentar detectar moodledata
    local detected_data
    detected_data=$(_detect_moodledata "$src_app")
    _ask "Directorio moodledata" "${detected_data:-/var/moodledata}" "src_data"
    _ask "Directorio base para backups locales" "/var/backups/moodle" "backup_base"
    
    echo ""
    
    # Step 2: Base de datos
    echo "🗄️  Paso 2/4: Base de datos"
    local db_name="" db_user="" db_pass="" db_host=""
    
    local detected_dbname
    detected_dbname=$(_detect_db_from_config "$src_app" "name")
    local detected_dbuser
    detected_dbuser=$(_detect_db_from_config "$src_app" "user")
    local detected_dbhost
    detected_dbhost=$(_detect_db_from_config "$src_app" "host")
    
    _ask "Nombre de la base de datos" "${detected_dbname:-moodle}" "db_name"
    _ask "Usuario de BD" "${detected_dbuser:-moodle_user}" "db_user"
    _ask "Contraseña de BD" "" "db_pass"
    _ask "Host de BD" "${detected_dbhost:-localhost}" "db_host"
    
    echo ""
    
    # Step 3: Cloud Storage
    echo "☁️  Paso 3/4: Cloud Storage (rclone)"
    local cloud_remote="" cloud_path=""
    
    # Detectar remotes de rclone
    local rclone_remotes=""
    if command -v rclone >/dev/null 2>&1; then
        local remote_list
        remote_list=$(rclone listremotes --long 2>/dev/null)
        if [ -n "$remote_list" ]; then
            echo "  Remotes disponibles:"
            echo "$remote_list" | while read -r line; do
                echo "    - $line"
            done
        fi
        rclone_remotes=$(rclone listremotes 2>/dev/null | head -1 | tr -d ':')
    fi
    
    _ask "Nombre del remote rclone" "${rclone_remotes:-gdrive}" "cloud_remote"
    _ask "Ruta base en cloud storage" "moodle_backups/${name}" "cloud_path"
    
    echo ""
    
    # Step 4: Notificaciones y Email
    echo "📧 Paso 4/5: Notificaciones"
    local email="" server_name="" system_user=""
    
    _ask "Email para notificaciones" "admin@$(hostname -d 2>/dev/null || echo 'ejemplo.com')" "email"
    _ask "Nombre del servidor" "$(hostname -s 2>/dev/null || echo 'mi-servidor')" "server_name"
    _ask "Usuario del sistema (owner de Moodle)" "www-data" "system_user"
    
    echo ""
    
    # Step 5: Transporte de email
    echo "✉️  Paso 5/5: Transporte de email"
    echo "  Opciones:"
    echo "    auto  = detecta el mejor disponible (recomendado)"
    echo "    smtp  = SMTP directo con curl (Gmail, SendGrid, etc.)"
    echo "    mailx = comando mail del sistema (cPanel)"
    echo "    api   = HTTP API (SendGrid/Mailgun)"
    
    local email_transport="" smtp_host="" smtp_port="" smtp_user="" smtp_pass=""
    _ask "Transporte" "auto" "email_transport"
    
    if [ "$email_transport" = "smtp" ]; then
        echo ""
        echo "  Configuración SMTP:"
        _ask "  Host SMTP" "smtp.gmail.com" "smtp_host"
        _ask "  Puerto" "587" "smtp_port"
        _ask "  Usuario SMTP" "" "smtp_user"
        _ask "  Contraseña SMTP" "" "smtp_pass"
    fi
    
    echo ""
    
    # Generar config
    mkdir -p "$(dirname "$target")"
    cat > "$target" << CONFIGEOF
# =============================================================================
# CONFIGURACIÓN MOODLE BACKUP: ${name}
# Generada por: mb moodlesite create
# =============================================================================

# Identificación
INSTANCE_NAME="${name}"
SERVER_NAME="${server_name}"

# Rutas de Moodle
SRC_APP="${src_app}"
SRC_DATA="${src_data}"
BACKUP_BASE="${backup_base}"

# Base de datos
DB_NAME="${db_name}"
DB_USER="${db_user}"
DB_PASSWORD="${db_pass}"
DB_HOST="${db_host}"

# PHP
PHP_CLI="/usr/bin/php"

# Cloud Storage (rclone)
CLOUD_REMOTE="${cloud_remote}"
CLOUD_BASE_PATH="${cloud_path}"

# Notificaciones
NOTIFICATION_EMAIL="${email}"
NOTIFICATION_FROM="backup-noreply@\$(hostname -d 2>/dev/null || echo 'localhost')"

# Transporte de email (auto|smtp|msmtp|ssmtp|mailx|sendmail|api)
EMAIL_TRANSPORT="${email_transport}"
SMTP_HOST="${smtp_host}"
SMTP_PORT="${smtp_port:-587}"
SMTP_USER="${smtp_user}"
SMTP_PASSWORD="${smtp_pass}"
SMTP_TLS="yes"

# Cron (1=diario, 2=cada 2 días, 3=cada 5 días, 4=semanal, 5=quincenal, 6=mensual, 7=custom)
CRON_SCHEDULE="7"

# Retención (cantidad de backups a mantener en GDrive)
RETENTION_COPIES="2"

# Exclusiones para moodledata streaming
MOODLEDATA_EXCLUDES="cache/* sessions/* temp/* trashdir/*"

# Usuario del sistema
SYSTEM_USER="${system_user}"
CONFIGEOF

    echo "━━━ Resumen ━━━"
    echo "  📁 Moodle:    $src_app"
    echo "  🗄️  BD:        $db_name@$db_host"
    echo "  ☁️  Cloud:     ${cloud_remote}:${cloud_path}"
    echo "  📧 Email:     $email"
    echo "  ✉️  Transporte: $email_transport"
    echo ""
    echo "✅ Configuración creada: $target"
    echo ""
    
    # Preguntar si habilitar
    printf "¿Habilitar ahora? [S/n]: " >&2
    local enable_now=""
    read -r enable_now
    enable_now="${enable_now:-S}"
    
    if [[ "$enable_now" =~ ^[Ss]$ ]]; then
        enable_config "$name"
        echo ""
        echo "🚀 Listo. Ejecuta: mb test $name"
    else
        echo ""
        echo "Para habilitar después: mb moodlesite enable $name"
    fi
}

# Mostrar información de una configuración
show_config_info() {
    local name="$1"
    local config_file="${CONFIG_AVAILABLE_DIR}/${name}.config"
    
    [ ! -f "$config_file" ] && config_file="${CONFIG_ENABLED_DIR}/${name}.config"
    
    if [ ! -f "$config_file" ]; then
        echo "ERROR: Configuración '$name' no encontrada" >&2
        return 1
    fi
    
    echo "=== CONFIGURACIÓN: $name ==="
    echo "Archivo: $config_file"
    
    # Cargar en subshell para no contaminar
    (
        # shellcheck disable=SC1090
        source "$config_file"
        echo "Instancia: ${INSTANCE_NAME:-N/A}"
        echo "Moodle: ${SRC_APP:-N/A}"
        echo "Base de datos: ${DB_NAME:-N/A}"
        echo "Email: ${NOTIFICATION_EMAIL:-N/A}"
        echo "Servidor: ${SERVER_NAME:-N/A}"
        
        if [ -L "${CONFIG_ENABLED_DIR}/${name}.config" ]; then
            echo "Estado: HABILITADA"
        else
            echo "Estado: DISPONIBLE (no habilitada)"
        fi
    )
}

# Probar configuración (validar conectividad)
test_config() {
    local name="$1"
    echo "=== PROBANDO CONFIGURACIÓN: $name ==="
    
    if ! load_moodle_config "$name" 2>/dev/null; then
        echo "❌ Error cargando configuración"
        return 1
    fi
    
    local errors=0
    
    # Test directorio app
    if [ -d "$SRC_APP" ]; then
        echo "✅ Directorio app existe: $SRC_APP"
    else
        echo "❌ Directorio app no existe: $SRC_APP"
        errors=$((errors + 1))
    fi
    
    # Test MySQL
    if command -v mysql >/dev/null 2>&1; then
        # shellcheck disable=SC2153
        if mysql -h "${DB_HOST:-localhost}" -u "$DB_USER" -p"$DB_PASSWORD" -e "USE $DB_NAME;" 2>/dev/null; then
            echo "✅ Conexión a base de datos OK"
        else
            echo "❌ No se puede conectar a la base de datos"
            errors=$((errors + 1))
        fi
    else
        echo "⚠️  mysql client no instalado"
    fi
    
    # Test rclone
    if command -v rclone >/dev/null 2>&1; then
        if rclone listremotes 2>/dev/null | grep -q "${CLOUD_REMOTE:-gdrive}:"; then
            echo "✅ rclone configurado con remote '${CLOUD_REMOTE:-gdrive}'"
        else
            echo "❌ rclone remote '${CLOUD_REMOTE:-gdrive}' no encontrado"
            errors=$((errors + 1))
        fi
    else
        echo "⚠️  rclone no instalado"
    fi
    
    # Test email transport
    show_email_transport_info 2>/dev/null || true
    
    [ $errors -eq 0 ] && echo "✅ Configuración válida" || echo "❌ $errors errores encontrados"
    echo ""
    echo "💡 Para probar envío de email: mb test-email $name"
    return $errors
}
