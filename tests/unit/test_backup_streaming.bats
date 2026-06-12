#!/usr/bin/env bats

load '../test_helper'

setup() {
    setup_test_env
    load_lib "utils"
    load_lib "logging"
    load_lib "backup_streaming"
    init_logging "$MB_TEST_DIR/test.log"

    export CLOUD_REMOTE="gdrive"
    export CLOUD_BASE_PATH="/backups"
    export INSTANCE_NAME="test-moodle"
    export SRC_DATA="$MB_TEST_DIR/moodledata"
    mkdir -p "$SRC_DATA"

    PHASE2_CLOUD_PATH="gdrive:/backups/test-moodle/11-06-2026/test-moodle_moodledata.tar.gz"
    PHASE2_PID_FILE="$MB_TEST_DIR/phase2.pid"
    PHASE2_CHECKSUM_FILE="$MB_TEST_DIR/phase2.sha256"
    PHASE2_SUCCESS=false
}

teardown() {
    rm -f "$MB_TEST_DIR/mock_calls.log" 2>/dev/null || true
    teardown_test_env
}

@test "_run_phase2_cleanup preserves file when it exists in cloud (size > 0)" {
    _run_phase2_cleanup

    local delete_calls
    delete_calls=$(grep -Fx "MOCK_RCLONE: delete $PHASE2_CLOUD_PATH" "$MB_TEST_DIR/mock_calls.log" 2>/dev/null | wc -l)
    [ "$delete_calls" -eq 0 ]
}

@test "_run_phase2_cleanup deletes file when cloud file has zero size" {
    export MOCK_RCLONE_SIZE_ZERO=true
    _run_phase2_cleanup

    grep -Fx "MOCK_RCLONE: delete $PHASE2_CLOUD_PATH" "$MB_TEST_DIR/mock_calls.log"
}

@test "_run_phase2_cleanup preserves file when PHASE2_SUCCESS is true" {
    PHASE2_SUCCESS=true
    _run_phase2_cleanup

    local delete_calls
    delete_calls=$(grep -c "MOCK_RCLONE: delete" "$MB_TEST_DIR/mock_calls.log" 2>/dev/null || echo "0")
    [ "$delete_calls" -eq 0 ]
}

@test "_run_phase2_cleanup deletes checksum file regardless" {
    _run_phase2_cleanup

    grep -q "MOCK_RCLONE: delete ${PHASE2_CLOUD_PATH}.sha256" "$MB_TEST_DIR/mock_calls.log"
}

@test "_run_phase2_cleanup removes PID and checksum local files" {
    touch "$PHASE2_PID_FILE" "$PHASE2_CHECKSUM_FILE"
    _run_phase2_cleanup

    [ ! -f "$PHASE2_PID_FILE" ]
    [ ! -f "$PHASE2_CHECKSUM_FILE" ]
}

@test "_run_phase2_cleanup noops when PHASE2_CLOUD_PATH is empty" {
    PHASE2_CLOUD_PATH=""
    _run_phase2_cleanup

    local rclone_calls
    rclone_calls=$(wc -l < "$MB_TEST_DIR/mock_calls.log" 2>/dev/null || echo "0")
    [ "$rclone_calls" -eq 0 ]
}
