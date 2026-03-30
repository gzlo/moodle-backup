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
    
    if source "$config_file"; then
        validate_config_variables
        return $?
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
        local name=$(basename "$config" .config)
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

# Crear nueva configuración desde template
create_config() {
    local name="$1"
    local template="${CONFIG_AVAILABLE_DIR}/moodle.config.example"
    local target="${CONFIG_AVAILABLE_DIR}/${name}.config"
    
    if [ -f "$target" ]; then
        echo "ERROR: Configuración '$name' ya existe" >&2
        return 1
    fi
    
    if [ ! -f "$template" ]; then
        echo "ERROR: Template no encontrado: $template" >&2
        return 1
    fi
    
    cp "$template" "$target"
    sed -i "s/INSTANCE_NAME=\"mi-instalacion\"/INSTANCE_NAME=\"${name}\"/" "$target"
    echo "OK: Configuración '$name' creada en: $target"
    echo "    Edita el archivo y luego habilita con: mb moodlesite enable $name"
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
        if rclone listremotes 2>/dev/null | grep -q "${GDRIVE_REMOTE:-gdrive}:"; then
            echo "✅ rclone configurado con remote '${GDRIVE_REMOTE:-gdrive}'"
        else
            echo "❌ rclone remote '${GDRIVE_REMOTE:-gdrive}' no encontrado"
            errors=$((errors + 1))
        fi
    else
        echo "⚠️  rclone no instalado"
    fi
    
    [ $errors -eq 0 ] && echo "✅ Configuración válida" || echo "❌ $errors errores encontrados"
    return $errors
}
