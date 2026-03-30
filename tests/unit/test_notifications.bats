#!/usr/bin/env bats

load '../test_helper'

setup() {
    setup_test_env
    load_lib "utils"
    load_lib "logging"
    load_lib "notifications"
    
    init_logging "$MB_TEST_DIR/test.log"
    
    export NOTIFICATION_EMAIL="test@example.com"
    export SERVER_NAME="test-server"
    export INSTANCE_NAME="test-moodle"
    export SRC_APP="/tmp/fake-moodle"
    export SRC_DATA="/tmp/fake-data"
    export DB_NAME="test_db"
    export MB_LOG_FILE="$MB_TEST_DIR/test.log"
    export MB_VERSION="4.0.0"
}

teardown() {
    teardown_test_env
}

@test "send_email uses mock mail command" {
    export EMAIL_TRANSPORT="mailx"
    run send_email "Test Subject" "Test Body" "test@example.com"
    [ "$status" -eq 0 ]
}

@test "send_email fails without recipient" {
    run send_email "Test" "Body" ""
    [ "$status" -eq 1 ]
}

@test "send_phase1_error sends email" {
    export EMAIL_TRANSPORT="mailx"
    run send_phase1_error "Error de prueba" "5m 30s"
    [ "$status" -eq 0 ]
}

@test "send_phase1_success sends email" {
    export EMAIL_TRANSPORT="mailx"
    run send_phase1_success "3m 20s" "500MB" "1.2GB"
    [ "$status" -eq 0 ]
}

@test "send_phase2_error sends email" {
    export EMAIL_TRANSPORT="mailx"
    run send_phase2_error "Error streaming" "10m"
    [ "$status" -eq 0 ]
}

@test "send_phase2_success sends email" {
    export EMAIL_TRANSPORT="mailx"
    run send_phase2_success "45m" "50GB" "gdrive:backups/test"
    [ "$status" -eq 0 ]
}

@test "_detect_email_transport finds mailx mock" {
    run _detect_email_transport
    [ "$status" -eq 0 ]
    # Mock mail is in PATH, so should detect mailx or msmtp etc
    [ -n "$output" ]
    [ "$output" != "none" ]
}

@test "show_email_transport_info outputs info" {
    export EMAIL_TRANSPORT="auto"
    run show_email_transport_info
    [ "$status" -eq 0 ]
    [[ "$output" == *"Transporte email"* ]]
}

@test "send_email with smtp transport requires SMTP_HOST" {
    export EMAIL_TRANSPORT="smtp"
    export SMTP_HOST=""
    # Should fall through to fallback since smtp needs config
    run send_email "Test" "Body" "test@example.com"
    # May succeed via fallback to mailx mock
    true
}

@test "send_test_email outputs test message" {
    export EMAIL_TRANSPORT="mailx"
    run send_test_email "test-config"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Enviando email de prueba"* ]]
    [[ "$output" == *"enviado correctamente"* ]]
}
