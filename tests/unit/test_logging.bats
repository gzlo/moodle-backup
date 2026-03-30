#!/usr/bin/env bats

load '../test_helper'

setup() {
    setup_test_env
    load_lib "logging"
}

teardown() {
    teardown_test_env
}

@test "init_logging creates log directory" {
    init_logging "$MB_TEST_DIR/logs/test.log"
    [ -d "$MB_TEST_DIR/logs" ]
}

@test "log_message writes to stdout" {
    MB_LOG_FILE=""
    run log_message "INFO" "test message"
    [ "$status" -eq 0 ]
    [[ "$output" == *"INFO"* ]]
    [[ "$output" == *"test message"* ]]
}

@test "log_message writes to log file" {
    init_logging "$MB_TEST_DIR/test.log"
    log_message "INFO" "logged message" >/dev/null
    grep -q "logged message" "$MB_TEST_DIR/test.log"
}

@test "log_message includes timestamp" {
    MB_LOG_FILE=""
    run log_message "WARNING" "timestamp test"
    [[ "$output" =~ \[[0-9]{4}-[0-9]{2}-[0-9]{2} ]]
}

@test "rotate_logs removes old files" {
    local log_dir="$MB_TEST_DIR/old_logs"
    mkdir -p "$log_dir"
    
    # Create a "40 days old" file
    touch -d "40 days ago" "$log_dir/old.log"
    touch "$log_dir/new.log"
    
    rotate_logs "$log_dir" 30
    
    [ ! -f "$log_dir/old.log" ]
    [ -f "$log_dir/new.log" ]
}

@test "rotate_logs handles missing directory" {
    run rotate_logs "/nonexistent/path" 30
    [ "$status" -eq 0 ]
}
