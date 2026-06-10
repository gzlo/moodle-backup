#!/bin/bash
# =============================================================================
# AUTO-UPDATE DESDE GITHUB - Moodle Backup CLI
# =============================================================================
# Consulta releases de GitHub, compara versiones e instala actualizaciones
# preservando configuraciones existentes.
# =============================================================================

UPDATE_STATE_DIR="${UPDATE_STATE_DIR:-/var/lib/moodle-backup}"
UPDATE_CONFIG_BACKUP_DIR="${UPDATE_CONFIG_BACKUP_DIR:-${UPDATE_STATE_DIR}/config_backups}"
UPDATE_REPO="gzlo/moodle-backup"
UPDATE_CACHE_FILE="${UPDATE_STATE_DIR}/last_check.json"

# ─── HELPERS INTERNOS ─────────────────────────────────────────────────────────

# Obtener la URL de descarga del source tarball de la última release
_fetch_latest_release() {
    local api_url="https://api.github.com/repos/${UPDATE_REPO}/releases/latest"
    local response
    response=$(curl -sL --max-time 15 "$api_url" 2>/dev/null) || return 1

    if echo "$response" | grep -q '"message"\|Not Found\|API rate limit'; then
        return 1
    fi

    local tag_name
    tag_name=$(echo "$response" | grep -oP '"tag_name":\s*"v?\K[^"]+' 2>/dev/null || echo "")

    local tarball_url
    tarball_url=$(echo "$response" | grep -oP '"tarball_url":\s*"\K[^"]+' 2>/dev/null || echo "")

    local html_url
    html_url=$(echo "$response" | grep -oP '"html_url":\s*"\K[^"]+' 2>/dev/null || echo "")

    if [ -z "$tag_name" ] || [ -z "$tarball_url" ]; then
        return 1
    fi

    # Cachear para evitar rate limiting
    mkdir -p "$UPDATE_STATE_DIR"
    cat > "$UPDATE_CACHE_FILE" << CACHEEOF
{
  "tag": "${tag_name}",
  "tarball": "${tarball_url}",
  "html": "${html_url:-https://github.com/${UPDATE_REPO}/releases/latest}",
  "checked_at": "$(date -Iseconds)"
}
CACHEEOF

    echo "$tag_name|$tarball_url|${html_url:-https://github.com/${UPDATE_REPO}/releases/latest}"
    return 0
}

# Comparar dos versiones semánticas (retorna 0 si a < b)
_is_newer_version() {
    local a="$1" b="$2"
    local higher
    higher=$(printf "%s\n%s" "$a" "$b" | sort -V | tail -1)
    [ "$higher" != "$a" ]
}

# Crear backup de configuraciones actuales
_backup_configs() {
    mkdir -p "$UPDATE_CONFIG_BACKUP_DIR"
    local backup_file config_dir
    backup_file="${UPDATE_CONFIG_BACKUP_DIR}/configs_before_$(date +%Y%m%d_%H%M%S).tar.gz"
    config_dir="${MB_INSTALL_DIR}/configs"

    if [ -d "$config_dir" ]; then
        tar czf "$backup_file" -C "$MB_INSTALL_DIR" configs/ 2>/dev/null || return 1
        echo "$backup_file"
        return 0
    fi
    return 1
}

# Descargar e instalar actualización desde tarball
_perform_upgrade() {
    local tarball_url="$1"
    local tmp_dir
    tmp_dir=$(mktemp -d) || return 1

    local tmp_tar="${tmp_dir}/update.tar.gz"
    if ! curl -sL --max-time 120 "$tarball_url" -o "$tmp_tar" 2>/dev/null; then
        rm -rf "$tmp_dir"
        return 1
    fi

    if ! tar xzf "$tmp_tar" -C "$tmp_dir" 2>/dev/null; then
        rm -rf "$tmp_dir"
        return 1
    fi

    local extracted_dir
    extracted_dir=$(find "$tmp_dir" -maxdepth 1 -type d -name '*moodle-backup*' | head -1)
    if [ -z "$extracted_dir" ]; then
        rm -rf "$tmp_dir"
        return 1
    fi

    # Copiar bin/ lib/ scripts/ - preservar configs/
    for dir in bin lib scripts; do
        if [ -d "${extracted_dir}/${dir}" ]; then
            cp -r "${extracted_dir}/${dir}/." "${MB_INSTALL_DIR}/${dir}/"
        fi
    done

    # Copiar moodle.config.example si cambió (no sobreescribe configs existentes)
    if [ -f "${extracted_dir}/configs/available/moodle.config.example" ]; then
        cp "${extracted_dir}/configs/available/moodle.config.example" \
           "${MB_INSTALL_DIR}/configs/available/moodle.config.example"
    fi

    # Asegurar permisos
    chmod +x "${MB_INSTALL_DIR}/bin/mb" 2>/dev/null || true
    chmod +x "${MB_INSTALL_DIR}/lib/"*.sh 2>/dev/null || true
    chmod +x "${MB_INSTALL_DIR}/scripts/"*.sh 2>/dev/null || true

    rm -rf "$tmp_dir"
    return 0
}

# Verificar que el binario funciona post-update
_verify_upgrade() {
    local expected="$1"
    local actual
    actual=$(/usr/local/bin/mb --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "")
    if [ -z "$actual" ]; then
        actual=$("${MB_INSTALL_DIR}/bin/mb" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "")
    fi
    [ "$actual" = "$expected" ]
}

# ─── COMANDOS CLI ─────────────────────────────────────────────────────────────

# mb update check [config_name]
run_update_check() {
    local config_name="${1:-}"

    # Si se pasa config, cargarla para usar el email configurado
    if [ -n "$config_name" ]; then
        load_moodle_config "$config_name" 2>/dev/null || true
    fi

    log_message "INFO" "Verificando actualizaciones desde GitHub..."
    echo "  Repositorio: ${UPDATE_REPO}"
    echo "  Versión actual: v${MB_VERSION}"
    echo ""

    local release_data
    release_data=$(_fetch_latest_release) || {
        local msg="No se pudo consultar GitHub (sin conexion o rate limit)"
        log_message "ERROR" "$msg"
        echo "  ❌ $msg"
        return 1
    }

    local latest_tag html_url
    latest_tag=$(echo "$release_data" | cut -d'|' -f1)
    html_url=$(echo "$release_data" | cut -d'|' -f3)

    echo "  Última versión: v${latest_tag}"

    if _is_newer_version "$MB_VERSION" "$latest_tag"; then
        echo ""
        echo "  ✅ Hay una nueva versión disponible: v${latest_tag}"
        echo "     URL: $html_url"
        echo ""
        echo "  Para instalar: mb update install ${config_name}"

        # Enviar email si hay config_name
        if [ -n "$config_name" ] && [ -n "${NOTIFICATION_EMAIL:-}" ]; then
            send_update_notification "$MB_VERSION" "$latest_tag" "$html_url"
            echo "  📧 Notificación enviada a: $NOTIFICATION_EMAIL"
        fi
        return 0
    else
        echo "  ✅ Ya tienes la última versión."
        return 0
    fi
}

# mb update install [config_name]
run_update_install() {
    local config_name="${1:-}"

    if [ "$(id -u)" -ne 0 ]; then
        show_message "error" "Se requieren permisos root para instalar actualizaciones"
        echo "  Uso: sudo mb update install ${config_name}"
        return 1
    fi

    if [ -n "$config_name" ]; then
        load_moodle_config "$config_name" 2>/dev/null || true
    fi

    echo ""
    echo "━━━ ACTUALIZACIÓN MOODLE BACKUP CLI ━━━"
    echo ""

    # 1. Consultar última versión
    echo "  [1/5] Consultando última versión..."
    local release_data
    release_data=$(_fetch_latest_release) || {
        show_message "error" "No se pudo consultar GitHub"
        return 1
    }

    local latest_tag tarball_url html_url
    latest_tag=$(echo "$release_data" | cut -d'|' -f1)
    tarball_url=$(echo "$release_data" | cut -d'|' -f2)
    html_url=$(echo "$release_data" | cut -d'|' -f3)

    echo "         Versión actual: v${MB_VERSION}"
    echo "         Nueva versión:  v${latest_tag}"

    if ! _is_newer_version "$MB_VERSION" "$latest_tag"; then
        echo ""
        echo "  ✅ Ya tienes la última versión."
        return 0
    fi

    # 2. Backup de configuraciones
    echo ""
    echo "  [2/5] Respaldando configuraciones actuales..."
    local backup_file
    backup_file=$(_backup_configs) || {
        show_message "error" "No se pudo respaldar configuraciones"
        return 1
    }
    echo "         Backup: $backup_file"

    # 3. Descargar e instalar
    echo ""
    echo "  [3/5] Descargando e instalando v${latest_tag}..."
    if ! _perform_upgrade "$tarball_url"; then
        show_message "error" "Falló la descarga/instalación"
        return 1
    fi
    echo "         ✅ Archivos actualizados"

    # 4. Verificar
    echo ""
    echo "  [4/5] Verificando instalación..."
    if _verify_upgrade "$latest_tag"; then
        echo "         ✅ Versión ${latest_tag} instalada correctamente"
    else
        echo "         ⚠️  Verificación falló. Revisa manualmente."
    fi

    # 5. Notificar si hay email configurado
    if [ -n "${NOTIFICATION_EMAIL:-}" ]; then
        local subject="[MB] Actualización completada - v${latest_tag}"
        local body="Moodle Backup CLI actualizado exitosamente.

  Versión anterior: v${MB_VERSION}
  Nueva versión:    v${latest_tag}
  Servidor:         ${SERVER_NAME:-$(hostname)}
  Backup configs:   $backup_file

  URL: $html_url"
        send_email "$subject" "$body" "$NOTIFICATION_EMAIL" 2>/dev/null || true
    fi

    echo ""
    echo "━━━ ✅ ACTUALIZACIÓN COMPLETADA ━━━"
    return 0
}

# mb update rollback
run_update_rollback() {
    echo ""
    echo "━━━ ROLLBACK DE CONFIGURACIONES ━━━"
    echo ""

    if [ "$(id -u)" -ne 0 ]; then
        show_message "error" "Se requieren permisos root"
        return 1
    fi

    local backups
    backups=$(ls -t "${UPDATE_CONFIG_BACKUP_DIR}/"configs_before_*.tar.gz 2>/dev/null)

    if [ -z "$backups" ]; then
        show_message "error" "No hay backups de configuración disponibles"
        return 1
    fi

    local latest_backup
    latest_backup=$(echo "$backups" | head -1)

    echo "  Restaurando: $(basename "$latest_backup")"
    echo ""

    if tar xzf "$latest_backup" -C "$MB_INSTALL_DIR" 2>/dev/null; then
        echo "  ✅ Configuraciones restauradas desde: $latest_backup"
        echo ""
        echo "  Las configuraciones anteriores están de vuelta."
        echo "  Si también necesitas revertir el código, reinstala la versión anterior"
        echo "  manualmente desde GitHub Releases."
        return 0
    else
        show_message "error" "Falló la restauración"
        return 1
    fi
}
