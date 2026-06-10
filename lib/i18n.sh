#!/bin/bash
# =============================================================================
# INTERNACIONALIZACION (i18n) - Moodle Backup CLI
# =============================================================================
# Soporte es/en. Detecta locale del sistema o usa MB_LANG forzado.
# =============================================================================

declare -A I18N

load_locale() {
    local lang="${MB_LANG:-auto}"

    if [ "$lang" = "auto" ]; then
        case "${LANG:-}" in
            es_*|es) lang="es" ;;
            *) lang="en" ;;
        esac
    fi

    case "$lang" in
        en) _load_en ;;
        *)  _load_es ; lang="es" ;;
    esac

    export MB_CURRENT_LANG="$lang"
}

_() {
    local key="$1"; shift
    local val="${I18N[$key]:-$key}"
    if [ $# -gt 0 ]; then
        # shellcheck disable=SC2059
        printf "$val" "$@"
    else
        printf "%s" "$val"
    fi
}

_load_es() {
    I18N=(
        ["mb_tagline"]="Sistema de Backup para Moodle"
        ["mb_features"]="Cloud Storage · Streaming · Multi-config · Notificaciones"
        ["title_main"]="COMANDOS PRINCIPALES"
        ["title_config"]="GESTIÓN DE CONFIGURACIONES"
        ["title_options"]="OPCIONES"
        ["title_examples"]="EJEMPLOS"
        ["cmd_backup"]="Ejecutar backup completo (Fase 1 + Fase 2)"
        ["cmd_run"]="Ejecutar backup en background"
        ["cmd_list"]="Listar configuraciones"
        ["cmd_status"]="Estado del sistema"
        ["cmd_detect"]="Detectar servidor, panel y Moodle"
        ["cmd_logs"]="Ver logs recientes"
        ["cmd_test"]="Probar configuración"
        ["cmd_test_email"]="Enviar email de prueba"
        ["cmd_cron"]="Monitor del cron"
        ["cmd_health"]="Verificar estado del último backup (Nagios/Zabbix)"
        ["cmd_ms_list"]="Listar configuraciones"
        ["cmd_ms_enable"]="Habilitar configuración"
        ["cmd_ms_disable"]="Deshabilitar configuración"
        ["cmd_ms_create"]="Crear nueva configuración"
        ["cmd_ms_show"]="Mostrar configuración"
        ["cmd_ms_test"]="Probar configuración"
        ["opt_no_color"]="Deshabilitar colores"
        ["opt_dry_run"]="Validar configuración sin ejecutar backup"
        ["opt_version"]="Mostrar versión"
        ["opt_help"]="Mostrar esta ayuda"
        ["status_title"]="Estado del Sistema Moodle Backup"
        ["status_install"]="Instalación"
        ["status_scripts"]="Scripts"
        ["status_configs"]="Configuraciones"
        ["status_deps"]="Dependencias"
        ["status_rclone"]="rclone remotes"
        ["err_usage_backup"]="Uso: mb backup <config>"
        ["err_usage_test"]="Uso: mb test <config>"
        ["err_usage_test_email"]="Uso: mb test-email <config>"
        ["err_usage_health"]="Uso: mb health <config>"
        ["err_usage_logs"]="Uso: mb logs <config>"
        ["err_usage_run"]="Uso: mb run <config>"
        ["err_config_not_found"]="Configuración no encontrada"
        ["err_unknown_cmd"]="Comando desconocido"
        ["err_cron_not_found"]="cron_monitor.sh no encontrado"
        ["err_backup_running"]="Backup ya en ejecucion para '%s'. Espera o usa --force."
        ["info_running_backup"]="Ejecutando backup completo"
        ["info_running_bg"]="Iniciando backup en background..."
        ["info_test_email"]="Enviando email de prueba..."
        ["info_log_not_found"]="Log de hoy no encontrado"
        ["info_searching_logs"]="Buscando logs recientes..."
        ["subject_phase1_error"]="[CRITICO] Backup Moodle - Fase 1 - Backup BD+App - %s"
        ["subject_phase1_ok"]="[EXITO] Backup Moodle - Fase 1 - Backup BD+App - %s"
        ["subject_phase2_error"]="[CRITICO] Backup Moodle - Fase 2 - Moodledata Streaming - %s"
        ["subject_phase2_ok"]="[OK] Backup Moodle - Fase 2 - Moodledata Streaming - %s"
        ["subject_progress"]="[INFO] Backup Moodle - %s - %s"
        ["subject_final_ok"]="[EXITO] Backup Completo TERMINADO - %s"
        ["subject_final_error"]="[ERROR] Backup Completo FALLO - %s"
        ["subject_update"]="[UPDATE] Nueva version disponible - Moodle Backup CLI - %s"
        ["cmd_update"]="Gestionar actualizaciones desde GitHub"
        ["cmd_update_check"]="Verificar si hay nueva version disponible"
        ["cmd_update_install"]="Instalar la ultima version desde GitHub"
    )
}

_load_en() {
    I18N=(
        ["mb_tagline"]="Moodle Backup System"
        ["mb_features"]="Cloud Storage · Streaming · Multi-config · Notifications"
        ["title_main"]="MAIN COMMANDS"
        ["title_config"]="CONFIGURATION MANAGEMENT"
        ["title_options"]="OPTIONS"
        ["title_examples"]="EXAMPLES"
        ["cmd_backup"]="Run full backup (Phase 1 + Phase 2)"
        ["cmd_run"]="Run backup in background"
        ["cmd_list"]="List configurations"
        ["cmd_status"]="System status"
        ["cmd_detect"]="Detect server, panel and Moodle"
        ["cmd_logs"]="View recent logs"
        ["cmd_test"]="Test configuration"
        ["cmd_test_email"]="Send test email"
        ["cmd_cron"]="Cron monitor"
        ["cmd_health"]="Check last backup status (Nagios/Zabbix)"
        ["cmd_ms_list"]="List configurations"
        ["cmd_ms_enable"]="Enable configuration"
        ["cmd_ms_disable"]="Disable configuration"
        ["cmd_ms_create"]="Create new configuration"
        ["cmd_ms_show"]="Show configuration"
        ["cmd_ms_test"]="Test configuration"
        ["opt_no_color"]="Disable colors"
        ["opt_dry_run"]="Validate config without running backup"
        ["opt_version"]="Show version"
        ["opt_help"]="Show this help"
        ["status_title"]="Moodle Backup System Status"
        ["status_install"]="Installation"
        ["status_scripts"]="Scripts"
        ["status_configs"]="Configurations"
        ["status_deps"]="Dependencies"
        ["status_rclone"]="rclone remotes"
        ["err_usage_backup"]="Usage: mb backup <config>"
        ["err_usage_test"]="Usage: mb test <config>"
        ["err_usage_test_email"]="Usage: mb test-email <config>"
        ["err_usage_health"]="Usage: mb health <config>"
        ["err_usage_logs"]="Usage: mb logs <config>"
        ["err_usage_run"]="Usage: mb run <config>"
        ["err_config_not_found"]="Configuration not found"
        ["err_unknown_cmd"]="Unknown command"
        ["err_cron_not_found"]="cron_monitor.sh not found"
        ["err_backup_running"]="Backup already running for '%s'. Wait or use --force."
        ["info_running_backup"]="Running full backup"
        ["info_running_bg"]="Starting backup in background..."
        ["info_test_email"]="Sending test email..."
        ["info_log_not_found"]="Today's log not found"
        ["info_searching_logs"]="Searching recent logs..."
        ["subject_phase1_error"]="[CRITICAL] Moodle Backup - Phase 1 - DB+App - %s"
        ["subject_phase1_ok"]="[SUCCESS] Moodle Backup - Phase 1 - DB+App - %s"
        ["subject_phase2_error"]="[CRITICAL] Moodle Backup - Phase 2 - Moodledata Streaming - %s"
        ["subject_phase2_ok"]="[OK] Moodle Backup - Phase 2 - Moodledata Streaming - %s"
        ["subject_progress"]="[INFO] Moodle Backup - %s - %s"
        ["subject_final_ok"]="[SUCCESS] Full Backup COMPLETED - %s"
        ["subject_final_error"]="[ERROR] Full Backup FAILED - %s"
        ["subject_update"]="[UPDATE] New version available - Moodle Backup CLI - %s"
        ["cmd_update"]="Manage GitHub updates"
        ["cmd_update_check"]="Check if a new version is available"
        ["cmd_update_install"]="Install the latest version from GitHub"
    )
}
