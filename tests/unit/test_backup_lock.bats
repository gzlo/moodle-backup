#!/usr/bin/env bats

load '../test_helper'

setup() {
    setup_test_env
    load_lib "utils"
    load_lib "logging"
    load_lib "backup_lock"

    export INSTANCE_NAME="test-lock"
    init_logging "$MB_TEST_DIR/test.log"
}

teardown() {
    rm -f "/tmp/backup_${INSTANCE_NAME}.lock" 2>/dev/null || true
    teardown_test_env
}

@test "is_backup_running returns false when no lock exists" {
    run is_backup_running "$INSTANCE_NAME"
    [ "$status" -eq 1 ]
}

@test "acquire_lock creates lock file" {
    run acquire_lock "$INSTANCE_NAME"
    [ "$status" -eq 0 ]
    [ -f "/tmp/backup_${INSTANCE_NAME}.lock" ]
}

@test "acquire_lock stores PID in lock file" {
    acquire_lock "$INSTANCE_NAME"
    local stored_pid
    stored_pid=$(head -1 "/tmp/backup_${INSTANCE_NAME}.lock")
    [ "$stored_pid" = "$$" ]
}

@test "acquire_lock stores timestamp in lock file" {
    acquire_lock "$INSTANCE_NAME"
    local stored_time
    stored_time=$(sed -n '2p' "/tmp/backup_${INSTANCE_NAME}.lock")
    [[ "$stored_time" =~ ^[0-9]+$ ]]
}

@test "is_backup_running returns true after acquire_lock" {
    acquire_lock "$INSTANCE_NAME"
    run is_backup_running "$INSTANCE_NAME"
    [ "$status" -eq 0 ]
}

@test "release_lock removes lock file" {
    acquire_lock "$INSTANCE_NAME"
    release_lock "$INSTANCE_NAME"
    [ ! -f "/tmp/backup_${INSTANCE_NAME}.lock" ]
}

@test "release_lock only removes own lock (not foreign PID)" {
    echo "99999" > "/tmp/backup_${INSTANCE_NAME}.lock"
    run release_lock "$INSTANCE_NAME"
    [ -f "/tmp/backup_${INSTANCE_NAME}.lock" ]
}

@test "acquire_lock detects stale lock (>timeout)" {
    export BACKUP_LOCK_TIMEOUT="0"
    local old_time=$(( $(date +%s) - 120 ))
    printf "99999\n%s\n" "$old_time" > "/tmp/backup_${INSTANCE_NAME}.lock"
    run acquire_lock "$INSTANCE_NAME"
    [ "$status" -eq 0 ]
}

@test "acquire_lock rejects active lock" {
    acquire_lock "$INSTANCE_NAME"
    run acquire_lock "$INSTANCE_NAME"
    [ "$status" -eq 1 ]
}
