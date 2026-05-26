#!/bin/bash
# =============================================================================
# NOTIFICACIONES POR WEBHOOK - Moodle Backup CLI
# =============================================================================
# Discord, Slack, Telegram webhooks para notificaciones de backup.
# =============================================================================

_send_via_discord() {
    local title="$1" content="$2" color="$3"
    local url="${DISCORD_WEBHOOK_URL:-}"

    [ -z "$url" ] && return 1

    local escaped="${content//$'\n'/ }"
    escaped="${escaped//\"/\\\"}"

    curl -s --max-time 10 -X POST "$url" \
        -H "Content-Type: application/json" \
        -d "$(cat << JSONEOF
{
  "embeds": [{
    "title": "$title",
    "description": "$escaped",
    "color": $color,
    "timestamp": "$(date -Iseconds)"
  }]
}
JSONEOF
)" 2>/dev/null >/dev/null
}

_send_via_slack() {
    local title="$1" content="$2" color="$3"
    local url="${SLACK_WEBHOOK_URL:-}"

    [ -z "$url" ] && return 1

    local escaped="${content//\"/\\\"}"

    curl -s --max-time 10 -X POST "$url" \
        -H "Content-Type: application/json" \
        -d "$(cat << JSONEOF
{
  "blocks": [
    {"type": "header", "text": {"type": "plain_text", "text": "$title"}},
    {"type": "section", "text": {"type": "mrkdwn", "text": "$escaped"}}
  ]
}
JSONEOF
)" 2>/dev/null >/dev/null
}

_send_via_telegram() {
    local content="$1"
    local token="${TELEGRAM_BOT_TOKEN:-}"
    local chat_id="${TELEGRAM_CHAT_ID:-}"

    [ -z "$token" ] || [ -z "$chat_id" ] && return 1

    curl -s --max-time 10 -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        -d "chat_id=${chat_id}" \
        -d "text=$(echo "$content" | head -20)" \
        -d "parse_mode=HTML" 2>/dev/null >/dev/null
}

_notify_webhooks() {
    local status="$1" phase="$2" details="$3" elapsed="$4"

    local title content color

    case "$status" in
        success)
            [ "${WEBHOOK_NOTIFY_SUCCESS:-false}" != "true" ] && return 0
            title="Backup Exitoso - ${SERVER_NAME}"
            content="Instancia: ${INSTANCE_NAME}
Fase: ${phase}
Detalles: ${details}
Tiempo: ${elapsed}
Fecha: $(date)"
            color=65280
            ;;
        error)
            title="Backup FALLIDO - ${SERVER_NAME}"
            content="Instancia: ${INSTANCE_NAME}
Fase: ${phase}
Error: ${details}
Tiempo: ${elapsed}
Fecha: $(date)"
            color=16711680
            ;;
        progress)
            title="Backup en Progreso - ${SERVER_NAME}"
            content="Instancia: ${INSTANCE_NAME}
Fase: ${phase}
Estado: ${details}
Tiempo: ${elapsed}"
            color=16776960
            ;;
        final_success)
            [ "${WEBHOOK_NOTIFY_SUCCESS:-false}" != "true" ] && return 0
            title="Backup Completo - ${SERVER_NAME}"
            content="Instancia: ${INSTANCE_NAME}
${details}
Tiempo total: ${elapsed}
Fecha: $(date)"
            color=65280
            ;;
        final_error)
            title="Backup con Errores - ${SERVER_NAME}"
            content="Instancia: ${INSTANCE_NAME}
${details}
Tiempo total: ${elapsed}
Fecha: $(date)"
            color=16711680
            ;;
        *)
            return 0
            ;;
    esac

    if _send_via_discord "$title" "$content" "$color"; then
        log_message "INFO" "Notificacion Discord enviada"
    fi
    if _send_via_slack "$title" "$content" "$color"; then
        log_message "INFO" "Notificacion Slack enviada"
    fi
    if _send_via_telegram "${title}\n${content}"; then
        log_message "INFO" "Notificacion Telegram enviada"
    fi
}
