#!/usr/bin/env bats

load '../test_helper'

setup() {
    setup_test_env
    load_lib "utils"
    load_lib "logging"
    load_lib "notifications"
    
    MB_LOG_FILE="$MB_TEST_DIR/test.log"
    
    # Set required vars
    export SERVER_NAME="test-server"
    export INSTANCE_NAME="test-moodle"
    export NOTIFICATION_EMAIL="test@example.com"
    export SRC_APP="/tmp/fake"
    export SRC_DATA="/tmp/fake-data"
    export DB_NAME="test_db"
}

teardown() {
    teardown_test_env
}

@test "send_email uses mock mail command" {
    run send_email "Test Subject" "Test Body" "test@example.com"
    [ "$status" -eq 0 ]
    grep -q "MOCK_MAIL" "$MB_TEST_DIR/mock_calls.log"
}

@test "send_email fails without recipient" {
    run send_email "Subject" "Body" ""
    [ "$status" -eq 1 ]
}

@test "send_phase1_error sends email" {
    run send_phase1_error "Test error" "00:01:00"
    [ "$status" -eq 0 ]
}

@test "send_phase1_success sends email" {
    run send_phase1_success "00:05:00" "10M" "50M"
    [ "$status" -eq 0 ]
}

@test "send_phase2_error sends email" {
    run send_phase2_error "Streaming failed" "00:10:00"
    [ "$status" -eq 0 ]
}

@test "send_phase2_success sends email" {
    run send_phase2_success "01:00:00" "50GB" "gdrive:backups/test"
    [ "$status" -eq 0 ]
}
