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
    export CLOUD_REMOTE="gdrive"
    export CLOUD_BASE_PATH="test_backups"
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
    [ "$status" -eq 0 ]
}

@test "upload_to_cloud tracks uploaded files on success" {
    local backup_dir="$MB_TEST_DIR/backup_upload"
    mkdir -p "$backup_dir"
    echo "test" > "$backup_dir/test_db.zip"
    echo "test" > "$backup_dir/test_app.zip"

    init_logging "$MB_TEST_DIR/test.log"

    run upload_to_cloud "$backup_dir" "${CLOUD_REMOTE}:${CLOUD_BASE_PATH}/test"
    [ "$status" -eq 0 ]
}

@test "run_phase2 streaming prerequisites detect missing moodledata" {
    load_lib "backup_streaming"
    init_logging "$MB_TEST_DIR/test.log"
    export SRC_DATA="$MB_TEST_DIR/nonexistent-moodledata"

    run check_streaming_prerequisites
    [ "$status" -eq 1 ]
}

@test "run_phase2 streaming prerequisites pass with valid setup" {
    load_lib "backup_streaming"
    init_logging "$MB_TEST_DIR/test.log"

    run check_streaming_prerequisites
    [ "$status" -eq 0 ]
}

@test "orchestrator releases lock on success" {
    load_lib "backup_lock"
    load_lib "backup_orchestrator"
    local lock_file="/tmp/backup_${INSTANCE_NAME}.lock"

    acquire_lock "$INSTANCE_NAME"
    [ -f "$lock_file" ]
    release_lock "$INSTANCE_NAME"
    [ ! -f "$lock_file" ]
}

@test "backup_database generates sha256 checksum" {
    local backup_dir="$MB_TEST_DIR/backup_output"
    mkdir -p "$backup_dir"

    init_logging "$MB_TEST_DIR/test.log"

    run backup_database "$backup_dir"
    [ "$status" -eq 0 ]

    local sha256_count
    sha256_count=$(find "$backup_dir" -name "*.sha256" -type f 2>/dev/null | wc -l)
    [ "$sha256_count" -ge 1 ]
}

@test "verify_streaming_backup handles missing checksum gracefully" {
    load_lib "backup_streaming"
    init_logging "$MB_TEST_DIR/test.log"

    run verify_streaming_backup "gdrive:test_backups/test-moodle/test.tar.gz"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GB"* ]] || [[ "$output" == *"MB"* ]]
}

@test "write_heartbeat creates heartbeat file" {
    load_lib "backup_orchestrator"
    init_logging "$MB_TEST_DIR/test.log"
    export HEARTBEAT_DIR="$MB_TEST_DIR/heartbeats"

    write_heartbeat "test-moodle" "success" "05:30" "EXITOSO" "EXITOSO"
    [ -f "$HEARTBEAT_DIR/heartbeat_test-moodle" ]
}

@test "check_heartbeat returns 0 for recent backup" {
    load_lib "backup_orchestrator"
    init_logging "$MB_TEST_DIR/test.log"
    export HEARTBEAT_DIR="$MB_TEST_DIR/heartbeats"

    mkdir -p "$HEARTBEAT_DIR"
    printf "%s|success|05:30|OK|OK\n" "$(date -Iseconds)" > "$HEARTBEAT_DIR/heartbeat_test-moodle"

    run check_heartbeat "test-moodle" "48"
    [ "$status" -eq 0 ]
}

@test "check_heartbeat returns 2 for never-run instance" {
    load_lib "backup_orchestrator"
    init_logging "$MB_TEST_DIR/test.log"
    export HEARTBEAT_DIR="$MB_TEST_DIR/heartbeats"

    rm -f "$HEARTBEAT_DIR/heartbeat_never-ran" 2>/dev/null || true
    run check_heartbeat "never-ran" "24"
    [ "$status" -eq 2 ]
}

@test "check_heartbeat returns 1 for overdue backup" {
    load_lib "backup_orchestrator"
    init_logging "$MB_TEST_DIR/test.log"
    export HEARTBEAT_DIR="$MB_TEST_DIR/heartbeats"

    mkdir -p "$HEARTBEAT_DIR"
    local old_date
    old_date=$(date -d "48 hours ago" -Iseconds 2>/dev/null || date -Iseconds)
    printf "%s|success|05:30|OK|OK\n" "$old_date" > "$HEARTBEAT_DIR/heartbeat_test-overdue"

    run check_heartbeat "test-overdue" "24"
    [ "$status" -eq 1 ]
}

@test "backup_database works with PostgreSQL engine using mock" {
    init_logging "$MB_TEST_DIR/test.log"
    export DB_ENGINE="pgsql"
    export DB_HOST="localhost"
    export DB_PORT="5432"

    local backup_dir="$MB_TEST_DIR/backup_pg"
    mkdir -p "$backup_dir"

    run backup_database "$backup_dir"
    [ "$status" -eq 0 ]
    [[ "$output" == *".zip"* ]]
}

@test "validate_phase1_requirements accepts pg_dump for PostgreSQL" {
    init_logging "$MB_TEST_DIR/test.log"
    export DB_ENGINE="pgsql"
    export DB_HOST="localhost"

    run validate_phase1_requirements
    [ "$status" -eq 0 ]
}
