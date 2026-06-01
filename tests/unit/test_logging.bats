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

@test "push_log adds to stack and sets MB_LOG_FILE" {
    push_log "$MB_TEST_DIR/push1.log"
    [ -d "$MB_TEST_DIR" ]
    [ "$MB_LOG_FILE" = "$MB_TEST_DIR/push1.log" ]
    [ ${#MB_LOG_STACK[@]} -eq 1 ]
}

@test "push_log multiple adds to stack" {
    push_log "$MB_TEST_DIR/stack1.log"
    push_log "$MB_TEST_DIR/stack2.log"
    [ ${#MB_LOG_STACK[@]} -eq 2 ]
    [ "$MB_LOG_FILE" = "$MB_TEST_DIR/stack2.log" ]
}

@test "pop_log restores previous log" {
    push_log "$MB_TEST_DIR/pop1.log"
    push_log "$MB_TEST_DIR/pop2.log"
    pop_log
    [ "$MB_LOG_FILE" = "$MB_TEST_DIR/pop1.log" ]
    [ ${#MB_LOG_STACK[@]} -eq 1 ]
}

@test "pop_log empty stack clears MB_LOG_FILE" {
    push_log "$MB_TEST_DIR/empty1.log"
    pop_log
    [ -z "$MB_LOG_FILE" ]
    [ ${#MB_LOG_STACK[@]} -eq 0 ]
}

@test "log_message writes to all files in stack" {
    push_log "$MB_TEST_DIR/all1.log"
    push_log "$MB_TEST_DIR/all2.log"
    log_message "INFO" "multi-stack test" >/dev/null
    grep -q "multi-stack test" "$MB_TEST_DIR/all1.log"
    grep -q "multi-stack test" "$MB_TEST_DIR/all2.log"
}

@test "init_logging delegates to push_log" {
    init_logging "$MB_TEST_DIR/init.log"
    [ ${#MB_LOG_STACK[@]} -eq 1 ]
    [ "$MB_LOG_FILE" = "$MB_TEST_DIR/init.log" ]
    grep -q "init.log" <<< "${MB_LOG_STACK[0]}"
}

@test "push_log and pop_log preserve parent log context" {
    push_log "$MB_TEST_DIR/parent.log"
    log_message "INFO" "parent message" >/dev/null
    
    push_log "$MB_TEST_DIR/child.log"
    log_message "INFO" "child message" >/dev/null
    pop_log
    
    log_message "INFO" "back to parent" >/dev/null
    
    grep -q "parent message" "$MB_TEST_DIR/parent.log"
    grep -q "child message" "$MB_TEST_DIR/child.log"
    grep -q "back to parent" "$MB_TEST_DIR/parent.log"
    
    # child log should NOT have the "back to parent" message
    ! grep -q "back to parent" "$MB_TEST_DIR/child.log"
}
