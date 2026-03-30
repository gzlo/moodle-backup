#!/bin/bash
# =============================================================================
# SERVER DETECTION - Moodle Backup CLI
# =============================================================================
# Detecta panel de control, web server, entorno y rutas de Moodle
# Soporta: cPanel/WHM, Plesk, HestiaCP, CyberPanel, CloudPanel,
#          DirectAdmin, Webmin/Virtualmin, ISPConfig, Docker, bare-metal
# =============================================================================

# shellcheck disable=SC2155

# --- Detección de panel de control ---
detect_control_panel() {
    if [ -d "/usr/local/cpanel" ]; then
        if [ -d "/usr/local/cpanel/whostmgr" ] || [ -f "/usr/local/cpanel/bin/whmapi1" ]; then
            echo "cpanel-whm"
        else
            echo "cpanel"
        fi
    elif [ -d "/usr/local/psa" ]; then
        echo "plesk"
    elif [ -d "/usr/local/hestia" ]; then
        echo "hestiacp"
    elif [ -d "/usr/local/CyberCP" ] || [ -d "/usr/local/CyberPanel" ]; then
        echo "cyberpanel"
    elif [ -d "/home/clp" ] && [ -f "/home/clp/htdocs/app/files/.env" ] 2>/dev/null; then
        echo "cloudpanel"
    elif [ -d "/usr/local/directadmin" ]; then
        echo "directadmin"
    elif [ -d "/usr/local/ispconfig" ]; then
        echo "ispconfig"
    elif [ -d "/usr/share/webmin" ]; then
        if [ -d "/usr/share/webmin/virtual-server" ]; then
            echo "virtualmin"
        else
            echo "webmin"
        fi
    elif [ -f "/.dockerenv" ] || grep -q 'docker\|containerd' /proc/1/cgroup 2>/dev/null; then
        echo "docker"
    else
        echo "none"
    fi
}

# --- Detección de web server ---
detect_web_server() {
    local ws="unknown"
    local version=""

    if command -v httpd >/dev/null 2>&1; then
        ws="apache"
        version=$(httpd -v 2>/dev/null | head -1 | grep -oP 'Apache/\K[0-9.]+' || true)
    elif command -v apache2 >/dev/null 2>&1; then
        ws="apache"
        version=$(apache2 -v 2>/dev/null | head -1 | grep -oP 'Apache/\K[0-9.]+' || true)
    elif command -v nginx >/dev/null 2>&1; then
        ws="nginx"
        version=$(nginx -v 2>&1 | grep -oP 'nginx/\K[0-9.]+' || true)
    elif command -v litespeed >/dev/null 2>&1 || [ -d "/usr/local/lsws" ]; then
        if [ -f "/usr/local/lsws/bin/openlitespeed" ]; then
            ws="openlitespeed"
        else
            ws="litespeed"
        fi
        version=$(cat /usr/local/lsws/VERSION 2>/dev/null || true)
    fi

    if [ -n "$version" ]; then
        echo "${ws} ${version}"
    else
        echo "$ws"
    fi
}

# --- Detección de entorno ---
detect_environment() {
    if [ -f "/.dockerenv" ] || grep -q 'docker\|containerd' /proc/1/cgroup 2>/dev/null; then
        echo "docker"
    elif grep -q 'lxc' /proc/1/cgroup 2>/dev/null; then
        echo "lxc"
    elif [ -d "/proc/vz" ] && [ ! -d "/proc/bc" ]; then
        echo "openvz"
    elif command -v systemd-detect-virt >/dev/null 2>&1; then
        local virt
        virt=$(systemd-detect-virt 2>/dev/null || true)
        case "$virt" in
            none) echo "dedicated" ;;
            kvm|qemu|vmware|xen|microsoft|oracle) echo "vps" ;;
            *) echo "vps" ;;
        esac
    else
        echo "unknown"
    fi
}

# --- Rutas de búsqueda por panel ---
get_panel_search_paths() {
    local panel="${1:-none}"

    case "$panel" in
        cpanel|cpanel-whm)
            echo "/home/*/public_html"
            ;;
        plesk)
            echo "/var/www/vhosts/*/httpdocs"
            ;;
        hestiacp)
            echo "/home/*/web/*/public_html"
            ;;
        cyberpanel)
            echo "/home/*/public_html"
            ;;
        cloudpanel)
            echo "/home/*/htdocs/*"
            ;;
        directadmin)
            echo "/home/*/domains/*/public_html"
            ;;
        ispconfig)
            echo "/var/www/*/web"
            ;;
        webmin|virtualmin)
            echo "/home/*/public_html"
            ;;
        docker)
            echo "/var/www/html"
            echo "/opt/bitnami/moodle"
            echo "/var/www/moodle"
            ;;
        none|*)
            echo "/var/www/html"
            echo "/var/www"
            echo "/opt/moodle"
            echo "/srv/www"
            echo "/home/*/public_html"
            ;;
    esac
}

# --- Detectar instalaciones de Moodle ---
detect_moodle_installations() {
    local panel
    panel=$(detect_control_panel)
    local search_paths
    search_paths=$(get_panel_search_paths "$panel")

    local -a found=()

    while IFS= read -r base_pattern; do
        [ -z "$base_pattern" ] && continue
        # Expandir globs
        local expanded
        # shellcheck disable=SC2086
        # shellcheck disable=SC2116
        expanded=$(echo $base_pattern 2>/dev/null)
        for base in $expanded; do
            [ -d "$base" ] || continue
            # Buscar config.php hasta 3 niveles
            while IFS= read -r config_file; do
                # Verificar que es un config.php de Moodle
                if grep -q 'CFG->dbname\|CFG->dataroot' "$config_file" 2>/dev/null; then
                    found+=("$(dirname "$config_file")")
                fi
            done < <(find "$base" -maxdepth 3 -name "config.php" -type f 2>/dev/null)
        done
    done <<< "$search_paths"

    # Deduplicar
    if [ ${#found[@]} -gt 0 ]; then
        printf '%s\n' "${found[@]}" | sort -u
    fi
}

# --- Obtener versión de Moodle desde directorio ---
get_moodle_version() {
    local moodle_dir="$1"
    local version_file="$moodle_dir/version.php"
    if [ -f "$version_file" ]; then
        grep -oP "\\\$release\s*=\s*['\"]?\K[0-9]+\.[0-9]+(\.[0-9]+)?" "$version_file" 2>/dev/null || echo "?"
    else
        echo "?"
    fi
}

# --- Detectar motor de BD ---
detect_database_engine() {
    if command -v mysql >/dev/null 2>&1; then
        local ver
        ver=$(mysql --version 2>/dev/null || true)
        if echo "$ver" | grep -qi mariadb; then
            echo "MariaDB $(echo "$ver" | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
        else
            echo "MySQL $(echo "$ver" | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
        fi
    elif command -v mariadb >/dev/null 2>&1; then
        echo "MariaDB $(mariadb --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    else
        echo "no detectado"
    fi
}

# --- Detectar PHP ---
detect_php_version() {
    if command -v php >/dev/null 2>&1; then
        php -r 'echo PHP_VERSION;' 2>/dev/null || echo "?"
    else
        echo "no instalado"
    fi
}

# --- Resumen completo del servidor ---
show_server_info() {
    local panel
    panel=$(detect_control_panel)
    local web_server
    web_server=$(detect_web_server)
    local environment
    environment=$(detect_environment)
    local php_ver
    php_ver=$(detect_php_version)
    local db_engine
    db_engine=$(detect_database_engine)
    local os_info
    if [ -f /etc/os-release ]; then
        os_info=$(. /etc/os-release && echo "${PRETTY_NAME:-$ID $VERSION_ID}")
    else
        os_info=$(uname -s)
    fi

    local panel_display
    case "$panel" in
        cpanel)       panel_display="cPanel" ;;
        cpanel-whm)   panel_display="cPanel/WHM" ;;
        plesk)        panel_display="Plesk" ;;
        hestiacp)     panel_display="HestiaCP" ;;
        cyberpanel)   panel_display="CyberPanel" ;;
        cloudpanel)   panel_display="CloudPanel" ;;
        directadmin)  panel_display="DirectAdmin" ;;
        ispconfig)    panel_display="ISPConfig" ;;
        webmin)       panel_display="Webmin" ;;
        virtualmin)   panel_display="Virtualmin" ;;
        docker)       panel_display="Docker" ;;
        none)         panel_display="Sin panel (bare-metal)" ;;
        *)            panel_display="$panel" ;;
    esac

    echo ""
    echo "🔍 Detección de servidor"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "  %-20s %s\n" "Sistema:" "$os_info"
    printf "  %-20s %s\n" "Panel de control:" "$panel_display"
    printf "  %-20s %s\n" "Web server:" "$web_server"
    printf "  %-20s %s\n" "Entorno:" "$environment"
    printf "  %-20s %s\n" "PHP:" "$php_ver"
    printf "  %-20s %s\n" "Base de datos:" "$db_engine"
    echo ""

    echo "📂 Instalaciones Moodle encontradas:"
    local installations
    installations=$(detect_moodle_installations)
    if [ -z "$installations" ]; then
        echo "  (ninguna detectada)"
    else
        local i=1
        while IFS= read -r moodle_path; do
            local ver
            ver=$(get_moodle_version "$moodle_path")
            printf "  %d. %s (v%s)\n" "$i" "$moodle_path" "$ver"
            i=$((i + 1))
        done <<< "$installations"
    fi
    echo ""
}
