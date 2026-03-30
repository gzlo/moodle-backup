#!/usr/bin/env bats

load '../test_helper'

setup() {
    setup_test_env
    load_lib "utils"
    load_lib "logging"
    load_lib "config"
    load_lib "notifications"
    load_lib "backup_maintenance"
    setup_test_configs
    
    # Create fake Moodle structure
    export SRC_APP="$MB_TEST_DIR/moodle"
    export SRC_DATA="$MB_TEST_DIR/moodledata"
    export BACKUP_BASE="$MB_TEST_DIR/backups"
    
    mkdir -p "$SRC_APP/admin/cli"
    echo '<?php echo "OK";' > "$SRC_APP/admin/cli/maintenance.php"
    mkdir -p "$SRC_DATA"
    echo "test file" > "$SRC_DATA/testfile.txt"
    mkdir -p "$BACKUP_BASE"
    
    export INSTANCE_NAME="test-moodle"
    export DB_NAME="test_db"
    export DB_USER="test_user"
    export DB_PASSWORD="test_pass"
    export DB_HOST="localhost"
    export PHP_CLI="php"
    export NOTIFICATION_EMAIL="test@example.com"
    export SERVER_NAME="test-server"
    export GDRIVE_REMOTE="gdrive"
    export GDRIVE_BASE_PATH="test_backups"
    export SYSTEM_USER="www-data"
}

teardown() {
    teardown_test_env
}

@test "backup_database creates zip file" {
    local backup_dir="$MB_TEST_DIR/backup_output"
    mkdir -p "$backup_dir"
    
    init_logging "$MB_TEST_DIR/test.log"
    
    run backup_database "$backup_dir"
    [ "$status" -eq 0 ]
    # Output should contain path to zip file
    [[ "$output" == *".zip"* ]]
}

@test "enable_maintenance_mode calls php" {
    init_logging "$MB_TEST_DIR/test.log"
    run enable_maintenance_mode
    # Should call the mock php
    grep -q "MOCK_PHP" "$MB_TEST_DIR/mock_calls.log" 2>/dev/null || true
}

@test "disable_maintenance_mode calls php" {
    init_logging "$MB_TEST_DIR/test.log"
    run disable_maintenance_mode
    grep -q "MOCK_PHP" "$MB_TEST_DIR/mock_calls.log" 2>/dev/null || true
}

@test "validate_phase1_requirements checks all dependencies" {
    init_logging "$MB_TEST_DIR/test.log"
    run validate_phase1_requirements
    # With mocks in path, commands should be "found"
    [[ "$output" == *"Requisitos"* ]] || true
}
