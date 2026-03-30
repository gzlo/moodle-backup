#!/bin/bash
# =============================================================================
# NOTIFICACIONES POR EMAIL - Moodle Backup CLI
# =============================================================================

# Enviar email de notificación
# Args: subject, body, email_to, [email_from]
send_email() {
    local subject="$1" body="$2" email_to="$3"
    local email_from="${4:-${NOTIFICATION_FROM:-backup-noreply@localhost}}"
    
    if [ -z "$email_to" ]; then
        log_message "WARNING" "No hay email de destino configurado"
        return 1
    fi
    
    echo "$body" | mail -s "$subject" -r "$email_from" "$email_to" 2>/dev/null || {
        log_message "WARNING" "No se pudo enviar email a $email_to"
        return 1
    }
    return 0
}

# Notificación de error para Fase 1 (BD + App)
send_phase1_error() {
    local error_msg="$1" elapsed="$2"
    local subject="[CRITICO] Backup Moodle - Fase 1 - Backup BD+App - ${SERVER_NAME}"
    
    local body="BACKUP MOODLE FALLIDO - $(date)

Detalles del Error:
$error_msg

Información del Sistema:
- Servidor: ${SERVER_NAME}
- Instancia: ${INSTANCE_NAME}
- Directorio App: ${SRC_APP}
- Base de datos: ${DB_NAME}
- Tiempo transcurrido: $elapsed
- Fecha/Hora: $(date)

Log disponible en: ${MB_LOG_FILE:-N/A}

---
Sistema de Backup Automatizado ${SERVER_NAME}"

    send_email "$subject" "$body" "$NOTIFICATION_EMAIL"
}

# Notificación de éxito para Fase 1 (BD + App)
send_phase1_success() {
    local elapsed="$1" db_size="$2" app_size="$3"
    local subject="[EXITO] Backup Moodle - Fase 1 - Backup BD+App - ${SERVER_NAME}"
    
    local body="BACKUP ${INSTANCE_NAME} COMPLETADO - $(date)

Detalles:
- Servidor: ${SERVER_NAME}
- Instancia: ${INSTANCE_NAME}
- Fecha: $(date +%d-%m-%Y)
- Tiempo total: $elapsed

Archivos:
- Base de datos: $db_size
- Aplicación: $app_size

---
Sistema de Backup Automatizado ${SERVER_NAME}"

    send_email "$subject" "$body" "$NOTIFICATION_EMAIL"
}

# Notificación de error para Fase 2 (Streaming)
send_phase2_error() {
    local error_msg="$1" elapsed="$2"
    local subject="[CRITICO] Backup Moodle - Fase 2 - Backup Moodledata Streaming - ${SERVER_NAME}"
    
    local body="BACKUP ${INSTANCE_NAME} MOODLEDATA FALLIDO - $(date)

Detalles del Error:
$error_msg

Información:
- Servidor: ${SERVER_NAME}
- Instancia: ${INSTANCE_NAME}
- Directorio: ${SRC_DATA}
- Tiempo transcurrido: $elapsed

Log disponible en: ${MB_LOG_FILE:-N/A}

---
Sistema de Backup Automatizado ${SERVER_NAME}"

    send_email "$subject" "$body" "$NOTIFICATION_EMAIL"
}

# Notificación de éxito para Fase 2 (Streaming)
send_phase2_success() {
    local elapsed="$1" final_size="$2" gdrive_path="$3"
    local subject="[OK] Backup Moodle - Fase 2 - Backup Moodledata Streaming - ${SERVER_NAME}"
    
    local body="BACKUP ${INSTANCE_NAME} MOODLEDATA COMPLETADO - $(date)

Detalles:
- Servidor: ${SERVER_NAME}
- Instancia: ${INSTANCE_NAME}
- Ubicación: $gdrive_path
- Tamaño: $final_size
- Tiempo total: $elapsed

---
Sistema de Backup Automatizado ${SERVER_NAME}"

    send_email "$subject" "$body" "$NOTIFICATION_EMAIL"
}

# Notificación de progreso del orquestador
send_progress_notification() {
    local stage="$1" status="$2" elapsed="$3"
    local subject="[INFO] Backup Moodle - $stage - ${SERVER_NAME}"
    
    local body="BACKUP ${INSTANCE_NAME} - PROGRESO - $(date)

Configuración: ${INSTANCE_NAME}
Etapa: $stage
Estado: $status
Tiempo transcurrido: $elapsed
Servidor: ${SERVER_NAME}

---
Sistema de Backup Automatizado ${SERVER_NAME}"

    send_email "$subject" "$body" "$NOTIFICATION_EMAIL"
}

# Notificación final del orquestador
send_final_notification() {
    local success="$1" phase1_result="$2" phase2_result="$3" elapsed="$4"
    
    local subject status
    if [ "$success" = "true" ]; then
        subject="[EXITO] Backup Completo TERMINADO - ${SERVER_NAME}"
        status="COMPLETADO EXITOSAMENTE"
    else
        subject="[ERROR] Backup Completo FALLO - ${SERVER_NAME}"
        status="COMPLETADO CON ERRORES"
    fi
    
    local body="BACKUP MOODLE COMPLETO - $status - $(date)

Resumen:
- Fase 1 (BD + App): $phase1_result
- Fase 2 (moodledata): $phase2_result
- Tiempo total: $elapsed

Servidor: ${SERVER_NAME}
Instancia: ${INSTANCE_NAME}

---
Sistema de Backup Automatizado ${SERVER_NAME}"

    send_email "$subject" "$body" "$NOTIFICATION_EMAIL"
}
