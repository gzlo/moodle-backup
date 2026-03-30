#!/bin/bash

# =============================================================================
# VERIFICADOR DE DEPENDENCIAS - SISTEMA DE BACKUP MOODLE
# =============================================================================
#
# DESCRIPCIÓN:
#   Script para verificar que todas las dependencias del sistema estén
#   instaladas y configuradas correctamente antes de la primera ejecución
#
# USO:
#   ./check_dependencies.sh
#
# VERSION: 1.0
# =============================================================================

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Contadores
DEPENDENCIES_OK=0
DEPENDENCIES_FAILED=0
OPTIONAL_OK=0
OPTIONAL_FAILED=0

# Función para mostrar mensajes
show_message() {
    local type="$1"
    local message="$2"
    case "$type" in
        "error")   echo -e "${RED}❌ [ERROR]${NC} $message" ;;
        "success") echo -e "${GREEN}✅ [OK]${NC} $message" ;;
        "warning") echo -e "${YELLOW}⚠️  [WARNING]${NC} $message" ;;
        "info")    echo -e "${BLUE}ℹ️  [INFO]${NC} $message" ;;
        *)         echo "$message" ;;
    esac
}

# Verificar comando
check_command() {
    local cmd="$1"
    local description="$2"
    local is_optional="$3"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        show_message "success" "$description"
        if [ "$is_optional" = "true" ]; then
            ((OPTIONAL_OK++))
        else
            ((DEPENDENCIES_OK++))
        fi
        return 0
    else
        if [ "$is_optional" = "true" ]; then
            show_message "warning" "$description (OPCIONAL)"
            ((OPTIONAL_FAILED++))
        else
            show_message "error" "$description (REQUERIDO)"
            ((DEPENDENCIES_FAILED++))
        fi
        return 1
    fi
}

# Verificar versión de Bash
check_bash_version() {
    local bash_version="${BASH_VERSION%%.*}"
    if [ "$bash_version" -ge 4 ]; then
        show_message "success" "Bash versión $BASH_VERSION"
        ((DEPENDENCIES_OK++))
    else
        show_message "error" "Bash versión $BASH_VERSION (se requiere 4.0+)"
        ((DEPENDENCIES_FAILED++))
    fi
}

# Verificar permisos de escritura
check_write_permissions() {
    local test_dirs=("/tmp" "/var/log")
    
    for dir in "${test_dirs[@]}"; do
        if [ -w "$dir" ]; then
            show_message "success" "Permisos de escritura en $dir"
        else
            show_message "warning" "Sin permisos de escritura en $dir"
        fi
    done
}

# Verificar espacio en disco
check_disk_space() {
    local required_gb=5
    local available_gb
    available_gb=$(df /tmp | awk 'NR==2 {print int($4/1024/1024)}')
    
    if [ "$available_gb" -ge "$required_gb" ]; then
        show_message "success" "Espacio disponible: ${available_gb}GB (mínimo: ${required_gb}GB)"
    else
        show_message "warning" "Espacio limitado: ${available_gb}GB (recomendado: ${required_gb}GB+)"
    fi
}

# Dar sugerencias de instalación
show_installation_tips() {
    if [ $DEPENDENCIES_FAILED -gt 0 ]; then
        echo ""
        show_message "info" "=== SUGERENCIAS DE INSTALACIÓN ==="
        echo ""
        
        # Ubuntu/Debian
        echo -e "${BLUE}Ubuntu/Debian:${NC}"
        echo "sudo apt update"
        echo "sudo apt install -y mysql-client php-cli tar gzip cron"
        echo ""
        
        # CentOS/RHEL
        echo -e "${BLUE}CentOS/RHEL:${NC}"
        echo "sudo yum install -y mysql php-cli tar gzip cronie"
        echo ""
        
        # rclone
        if ! command -v rclone >/dev/null 2>&1; then
            echo -e "${BLUE}rclone (para backup en nube):${NC}"
            echo "curl https://rclone.org/install.sh | sudo bash"
            echo ""
        fi
    fi
}

# Verificar configuración rclone
check_rclone_config() {
    if command -v rclone >/dev/null 2>&1; then
        local remotes
        remotes=$(rclone listremotes 2>/dev/null)
        if [ -n "$remotes" ]; then
            show_message "success" "rclone configurado con remotes: $(echo "$remotes" | tr '\n' ' ')"
        else
            show_message "warning" "rclone instalado pero sin remotes configurados"
            echo "  Ejecuta: rclone config"
        fi
    fi
}

# Función principal
main() {
    echo "================================================================"
    echo "    VERIFICADOR DE DEPENDENCIAS - SISTEMA BACKUP MOODLE"
    echo "================================================================"
    echo ""
    
    show_message "info" "Verificando dependencias del sistema..."
    echo ""
    
    # Verificaciones obligatorias
    echo "--- DEPENDENCIAS REQUERIDAS ---"
    check_bash_version
    check_command "mysql" "Cliente MySQL/MariaDB"
    check_command "php" "PHP CLI"
    check_command "tar" "Herramienta tar"
    check_command "gzip" "Herramienta gzip"
    check_command "zip" "Herramienta zip" "true"
    
    echo ""
    echo "--- DEPENDENCIAS OPCIONALES ---"
    check_command "rclone" "rclone (backup en nube)" "true"
    check_command "crontab" "Cron (automatización)" "true"
    check_command "shellcheck" "shellcheck (desarrollo)" "true"
    
    echo ""
    echo "--- CONFIGURACIONES ADICIONALES ---"
    check_rclone_config
    check_write_permissions
    check_disk_space
    
    echo ""
    echo "================================================================"
    echo "                        RESUMEN"
    echo "================================================================"
    
    # Mostrar resumen
    echo -e "Dependencias requeridas: ${GREEN}$DEPENDENCIES_OK OK${NC} | ${RED}$DEPENDENCIES_FAILED FALTAN${NC}"
    echo -e "Dependencias opcionales: ${GREEN}$OPTIONAL_OK OK${NC} | ${YELLOW}$OPTIONAL_FAILED FALTAN${NC}"
    
    echo ""
    
    if [ $DEPENDENCIES_FAILED -eq 0 ]; then
        show_message "success" "¡Sistema listo para usar!"
        echo ""
        show_message "info" "Próximos pasos:"
        echo "  1. Crear configuración: ./moodlesite create mi-moodle"
        echo "  2. Editar configuración: nano configs/available/mi-moodle.config"
        echo "  3. Habilitar configuración: ./moodlesite enable mi-moodle"
        echo "  4. Probar backup: ./backup.sh mi-moodle"
    else
        show_message "error" "Hay dependencias faltantes que deben instalarse"
        show_installation_tips
    fi
    
    echo ""
    
    # Código de salida
    if [ $DEPENDENCIES_FAILED -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Ejecutar verificación
main "$@"