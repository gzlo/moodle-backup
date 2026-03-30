#!/bin/bash
# =============================================================================
# NOTIFICACIONES POR EMAIL - Moodle Backup CLI
# =============================================================================
# Multi-transporte: smtp, msmtp, ssmtp, mailx, sendmail, api
# Modo "auto" detecta el mejor disponible en el sistema
# =============================================================================

# ─── TRANSPORTES DE EMAIL ────────────────────────────────────────────────────

# Enviar via curl SMTP directo (no necesita MTA local)
_send_via_smtp() {
    local subject="$1" body="$2" to="$3" from="$4"
    local host="${SMTP_HOST:-}" port="${SMTP_PORT:-587}"
    local user="${SMTP_USER:-}" pass="${SMTP_PASSWORD:-}"
    local tls="${SMTP_TLS:-yes}"
    
    if [ -z "$host" ] || [ -z "$user" ] || [ -z "$pass" ]; then
        return 1
    fi
    
    local url="smtp://${host}:${port}"
    [ "$tls" = "yes" ] && url="smtps://${host}:${port}"
    [ "$port" = "587" ] && url="smtp://${host}:${port}" # STARTTLS
    
    local mail_txt
    mail_txt=$(mktemp)
    cat > "$mail_txt" << MAILEOF
From: ${from}
To: ${to}
Subject: ${subject}
Date: $(date -R)
Content-Type: text/plain; charset=UTF-8

${body}
MAILEOF
    
    local curl_args=(
        --url "$url"
        --mail-from "$from"
        --mail-rcpt "$to"
        --upload-file "$mail_txt"
        --user "${user}:${pass}"
        --silent --show-error
        --max-time 30
    )
    
    # STARTTLS para puerto 587
    [ "$port" = "587" ] && curl_args+=(--ssl-reqd)
    
    local result=0
    curl "${curl_args[@]}" 2>/dev/null || result=$?
    rm -f "$mail_txt"
    return $result
}

# Enviar via msmtp (cliente SMTP ligero)
_send_via_msmtp() {
    local subject="$1" body="$2" to="$3" from="$4"
    
    local msmtp_args=(-t)
    
    # Si hay SMTP config, usar directamente sin archivo de config
    if [ -n "${SMTP_HOST:-}" ]; then
        msmtp_args=(
            --host="${SMTP_HOST}"
            --port="${SMTP_PORT:-587}"
            --auth=on
            --user="${SMTP_USER}"
            --password="${SMTP_PASSWORD}"
            --from="$from"
            --tls=on
            -t
        )
    fi
    
    printf "From: %s\nTo: %s\nSubject: %s\nContent-Type: text/plain; charset=UTF-8\n\n%s" \
        "$from" "$to" "$subject" "$body" | msmtp "${msmtp_args[@]}" "$to" 2>/dev/null
}

# Enviar via ssmtp
_send_via_ssmtp() {
    local subject="$1" body="$2" to="$3" from="$4"
    
    printf "From: %s\nTo: %s\nSubject: %s\nContent-Type: text/plain; charset=UTF-8\n\n%s" \
        "$from" "$to" "$subject" "$body" | ssmtp "$to" 2>/dev/null
}

# Enviar via mail/mailx (el método original)
_send_via_mailx() {
    local subject="$1" body="$2" to="$3" from="$4"
    
    echo "$body" | mail -s "$subject" -r "$from" "$to" 2>/dev/null
}

# Enviar via sendmail directo
_send_via_sendmail() {
    local subject="$1" body="$2" to="$3" from="$4"
    
    local sendmail_bin=""
    for bin in /usr/sbin/sendmail /usr/lib/sendmail sendmail; do
        if command -v "$bin" >/dev/null 2>&1; then
            sendmail_bin="$bin"
            break
        fi
    done
    [ -z "$sendmail_bin" ] && return 1
    
    printf "From: %s\nTo: %s\nSubject: %s\nContent-Type: text/plain; charset=UTF-8\n\n%s" \
        "$from" "$to" "$subject" "$body" | "$sendmail_bin" -f "$from" "$to" 2>/dev/null
}

# Enviar via HTTP API (SendGrid / Mailgun)
_send_via_api() {
    local subject="$1" body="$2" to="$3" from="$4"
    local api_url="${EMAIL_API_URL:-}"
    local api_key="${EMAIL_API_KEY:-}"
    
    if [ -z "$api_url" ] || [ -z "$api_key" ]; then
        return 1
    fi
    
    # Detectar proveedor por URL
    if [[ "$api_url" == *"sendgrid"* ]]; then
        # SendGrid v3 API
        local json
        json=$(cat << JSONEOF
{
  "personalizations": [{"to": [{"email": "${to}"}]}],
  "from": {"email": "${from}"},
  "subject": "${subject}",
  "content": [{"type": "text/plain", "value": $(printf '%s' "$body" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || echo "\"${body}\"")}]
}
JSONEOF
)
        curl -s --max-time 30 \
            -X POST "$api_url" \
            -H "Authorization: Bearer ${api_key}" \
            -H "Content-Type: application/json" \
            -d "$json" 2>/dev/null
    elif [[ "$api_url" == *"mailgun"* ]]; then
        # Mailgun API
        curl -s --max-time 30 \
            -X POST "$api_url" \
            -u "api:${api_key}" \
            -F from="$from" \
            -F to="$to" \
            -F subject="$subject" \
            -F text="$body" 2>/dev/null
    else
        # Genérico: POST con JSON
        curl -s --max-time 30 \
            -X POST "$api_url" \
            -H "Authorization: Bearer ${api_key}" \
            -H "Content-Type: application/json" \
            -d "{\"from\":\"${from}\",\"to\":\"${to}\",\"subject\":\"${subject}\",\"text\":\"${body}\"}" 2>/dev/null
    fi
}

# ─── AUTO-DETECCIÓN ──────────────────────────────────────────────────────────

# Detectar el mejor transporte disponible
_detect_email_transport() {
    # Si tiene SMTP configurado, preferir curl SMTP
    if [ -n "${SMTP_HOST:-}" ] && [ -n "${SMTP_USER:-}" ] && command -v curl >/dev/null 2>&1; then
        echo "smtp"
        return
    fi
    
    # Si tiene API configurada
    if [ -n "${EMAIL_API_URL:-}" ] && [ -n "${EMAIL_API_KEY:-}" ] && command -v curl >/dev/null 2>&1; then
        echo "api"
        return
    fi
    
    # msmtp (con o sin config SMTP)
    if command -v msmtp >/dev/null 2>&1; then
        echo "msmtp"
        return
    fi
    
    # ssmtp
    if command -v ssmtp >/dev/null 2>&1; then
        echo "ssmtp"
        return
    fi
    
    # mail/mailx
    if command -v mail >/dev/null 2>&1; then
        echo "mailx"
        return
    fi
    
    # sendmail
    if command -v sendmail >/dev/null 2>&1 || [ -x /usr/sbin/sendmail ]; then
        echo "sendmail"
        return
    fi
    
    echo "none"
}

# Mostrar info del transporte detectado
show_email_transport_info() {
    local transport="${EMAIL_TRANSPORT:-auto}"
    
    if [ "$transport" = "auto" ]; then
        transport=$(_detect_email_transport)
        echo "Transporte email: auto → $transport"
    else
        echo "Transporte email: $transport (forzado)"
    fi
    
    case "$transport" in
        smtp)    echo "  ✉️  SMTP directo via curl → ${SMTP_HOST:-?}:${SMTP_PORT:-587}" ;;
        msmtp)   echo "  ✉️  msmtp $(msmtp --version 2>/dev/null | head -1)" ;;
        ssmtp)   echo "  ✉️  ssmtp" ;;
        mailx)   echo "  ✉️  mail/mailx del sistema" ;;
        sendmail)echo "  ✉️  sendmail directo" ;;
        api)     echo "  ✉️  HTTP API → ${EMAIL_API_URL:-?}" ;;
        none)    echo "  ⚠️  No hay transporte de email disponible" ;;
    esac
}

# ─── FUNCIÓN PRINCIPAL ───────────────────────────────────────────────────────

# Enviar email con auto-detección de transporte
# Args: subject, body, email_to, [email_from]
send_email() {
    local subject="$1" body="$2" email_to="$3"
    local email_from="${4:-${NOTIFICATION_FROM:-backup-noreply@$(hostname -d 2>/dev/null || hostname -f 2>/dev/null || echo localhost)}}"
    
    if [ -z "$email_to" ]; then
        log_message "WARNING" "No hay email de destino configurado"
        return 1
    fi
    
    # Determinar transporte
    local transport="${EMAIL_TRANSPORT:-auto}"
    [ "$transport" = "auto" ] && transport=$(_detect_email_transport)
    
    if [ "$transport" = "none" ]; then
        log_message "WARNING" "No hay transporte de email disponible. Instala: mailutils, msmtp, o configura SMTP"
        return 1
    fi
    
    # Enviar con el transporte seleccionado
    local result=1
    case "$transport" in
        smtp)     _send_via_smtp     "$subject" "$body" "$email_to" "$email_from" && result=0 ;;
        msmtp)    _send_via_msmtp    "$subject" "$body" "$email_to" "$email_from" && result=0 ;;
        ssmtp)    _send_via_ssmtp    "$subject" "$body" "$email_to" "$email_from" && result=0 ;;
        mailx)    _send_via_mailx    "$subject" "$body" "$email_to" "$email_from" && result=0 ;;
        sendmail) _send_via_sendmail "$subject" "$body" "$email_to" "$email_from" && result=0 ;;
        api)      _send_via_api      "$subject" "$body" "$email_to" "$email_from" && result=0 ;;
        *)
            log_message "ERROR" "Transporte de email desconocido: $transport"
            return 1
            ;;
    esac
    
    if [ $result -ne 0 ]; then
        log_message "WARNING" "Falló envío por '$transport', intentando fallback..."
        # Fallback: intentar otros transportes
        for fallback in smtp msmtp mailx sendmail; do
            [ "$fallback" = "$transport" ] && continue
            case "$fallback" in
                smtp)
                    [ -z "${SMTP_HOST:-}" ] && continue
                    command -v curl >/dev/null 2>&1 || continue
                    ;;
                msmtp)    command -v msmtp >/dev/null 2>&1    || continue ;;
                mailx)    command -v mail  >/dev/null 2>&1    || continue ;;
                sendmail) command -v sendmail >/dev/null 2>&1 || [ -x /usr/sbin/sendmail ] || continue ;;
            esac
            
            log_message "INFO" "Intentando fallback: $fallback"
            if "_send_via_${fallback}" "$subject" "$body" "$email_to" "$email_from" 2>/dev/null; then
                log_message "SUCCESS" "Email enviado via fallback: $fallback"
                return 0
            fi
        done
        
        log_message "ERROR" "No se pudo enviar email por ningún transporte"
        return 1
    fi
    
    return 0
}

# Enviar email de prueba
send_test_email() {
    local config_name="${1:-test}"
    local transport="${EMAIL_TRANSPORT:-auto}"
    [ "$transport" = "auto" ] && transport=$(_detect_email_transport)
    
    local subject="[TEST] Moodle Backup - Email de prueba - ${SERVER_NAME:-$(hostname)}"
    local body="Este es un email de prueba del sistema Moodle Backup CLI.

Configuración: ${config_name}
Servidor: ${SERVER_NAME:-$(hostname)}
Transporte: ${transport}
Fecha: $(date)
Hora: $(date +%H:%M:%S)

Si recibes este email, las notificaciones están configuradas correctamente. ✅

---
Moodle Backup CLI v${MB_VERSION:-4.x}"
    
    echo "Enviando email de prueba..."
    echo "  Destino: ${NOTIFICATION_EMAIL:-?}"
    echo "  Transporte: $transport"
    echo ""
    
    if send_email "$subject" "$body" "${NOTIFICATION_EMAIL:-}"; then
        echo "✅ Email enviado correctamente via $transport"
        echo "   Revisa tu bandeja de entrada (y spam) en: ${NOTIFICATION_EMAIL:-?}"
        return 0
    else
        echo "❌ No se pudo enviar el email"
        echo ""
        echo "Soluciones:"
        echo "  1. Configura SMTP: edita el .config y agrega SMTP_HOST, SMTP_USER, SMTP_PASSWORD"
        echo "  2. Instala msmtp: apt install msmtp / dnf install msmtp"
        echo "  3. Instala mailutils: apt install mailutils"
        echo "  4. Usa SendGrid/Mailgun API: configura EMAIL_API_URL y EMAIL_API_KEY"
        return 1
    fi
}

# ─── NOTIFICACIONES POR FASE ─────────────────────────────────────────────────

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
