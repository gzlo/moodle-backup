#!/bin/bash
# =============================================================================
# CIFRADO GPG - Moodle Backup CLI
# =============================================================================
# Cifrado de backups con GPG simetrico o asimetrico.
# =============================================================================

# Cifrar archivo con GPG
encrypt_file() {
    local input="$1"
    local output="${2:-${input}.gpg}"

    if [ ! -f "$input" ]; then
        log_message "ERROR" "Archivo a cifrar no existe: $input"
        return 1
    fi

    validate_encryption || return 1

    case "${ENCRYPTION_METHOD:-passphrase}" in
        passphrase)
            if [ -z "${GPG_PASSPHRASE:-}" ]; then
                log_message "ERROR" "GPG_PASSPHRASE no configurada"
                return 1
            fi
            if echo -n "$GPG_PASSPHRASE" | gpg --batch --passphrase-fd 0 --symmetric --cipher-algo AES256 \
                --output "$output" "$input" 2>/dev/null; then
                log_message "SUCCESS" "Archivo cifrado: $(basename "$output")"
                rm -f "$input"
                return 0
            fi
            ;;
        recipient)
            if [ -z "${GPG_RECIPIENT:-}" ]; then
                log_message "ERROR" "GPG_RECIPIENT no configurado"
                return 1
            fi
            if gpg --batch --trust-model always --recipient "$GPG_RECIPIENT" --encrypt \
                --output "$output" "$input" 2>/dev/null; then
                log_message "SUCCESS" "Archivo cifrado para $GPG_RECIPIENT: $(basename "$output")"
                rm -f "$input"
                return 0
            fi
            ;;
        *)
            log_message "ERROR" "ENCRYPTION_METHOD desconocido: ${ENCRYPTION_METHOD}"
            return 1
            ;;
    esac

    log_message "ERROR" "Fallo el cifrado GPG"
    return 1
}

# Descifrar archivo GPG (para restauracion)
decrypt_file() {
    local input="$1"
    local output="$2"

    if [ ! -f "$input" ]; then
        log_message "ERROR" "Archivo cifrado no existe: $input"
        return 1
    fi

    case "${ENCRYPTION_METHOD:-passphrase}" in
        passphrase)
            if [ -z "${GPG_PASSPHRASE:-}" ]; then
                log_message "ERROR" "GPG_PASSPHRASE no configurada"
                return 1
            fi
            echo -n "$GPG_PASSPHRASE" | gpg --batch --passphrase-fd 0 --decrypt \
                --output "$output" "$input" 2>/dev/null
            ;;
        recipient)
            gpg --batch --decrypt --output "$output" "$input" 2>/dev/null
            ;;
    esac
}

# Validar que el entorno de cifrado esta listo
validate_encryption() {
    if ! command -v gpg >/dev/null 2>&1; then
        log_message "ERROR" "GPG no instalado. Instala: apt install gnupg / dnf install gnupg"
        return 1
    fi

    case "${ENCRYPTION_METHOD:-passphrase}" in
        passphrase)
            if [ -z "${GPG_PASSPHRASE:-}" ]; then
                log_message "ERROR" "GPG_PASSPHRASE requerida para cifrado simetrico"
                return 1
            fi
            ;;
        recipient)
            if [ -z "${GPG_RECIPIENT:-}" ]; then
                log_message "ERROR" "GPG_RECIPIENT requerido para cifrado asimetrico"
                return 1
            fi
            if ! gpg --list-keys "$GPG_RECIPIENT" >/dev/null 2>&1; then
                log_message "ERROR" "Clave publica no encontrada para: $GPG_RECIPIENT. Importala con: gpg --import"
                return 1
            fi
            ;;
        *)
            log_message "ERROR" "ENCRYPTION_METHOD desconocido: ${ENCRYPTION_METHOD}. Usar 'passphrase' o 'recipient'"
            return 1
            ;;
    esac
    return 0
}
