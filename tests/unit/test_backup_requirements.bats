#!/usr/bin/env bats

load '../test_helper'

setup() {
    setup_test_env
    load_lib "utils"
    load_lib "logging"
    load_lib "backup_maintenance"
    init_logging "$MB_TEST_DIR/test.log"

    export DB_ENGINE="mysql"
    export DB_NAME="test_db"
    export DB_USER="test_user"
    export DB_PASSWORD="test_pass"
    export DB_HOST="localhost"

    mkdir -p "$MB_TEST_DIR/moodle/admin/cli"
    touch "$MB_TEST_DIR/moodle/admin/cli/maintenance.php"
    export SRC_APP="$MB_TEST_DIR/moodle"
}

teardown() {
    teardown_test_env
}

@test "validate_phase1_requirements fails with missing SRC_APP dir" {
    export SRC_APP="$MB_TEST_DIR/nonexistent"
    run validate_phase1_requirements
    [ "$status" -eq 1 ]
}

@test "validate_phase1_requirements fails with missing maintenance.php" {
    mkdir -p "$MB_TEST_DIR/nomaint/admin/cli"
    export SRC_APP="$MB_TEST_DIR/nomaint"
    run validate_phase1_requirements
    [ "$status" -eq 1 ]
}

@test "validate_phase1_requirements fails when required command missing" {
    local stripped="$MB_TEST_DIR/cmd-stripped"
    mkdir -p "$stripped"
    for cmd in mysql mysqldump php rclone; do
        cp "$MB_PROJECT_DIR/tests/mocks/$cmd" "$stripped/"
    done
    export PATH="$stripped"
    run validate_phase1_requirements
    [ "$status" -eq 1 ]
}

@test "validate_phase1_requirements fails when MySQL unreachable" {
    local faildir="$MB_TEST_DIR/fail-mysql"
    mkdir -p "$faildir"
    cat > "$faildir/mysql" << 'HEREDOC'
#!/bin/bash
exit 1
HEREDOC
    chmod +x "$faildir/mysql"
    export PATH="$faildir:$MB_PROJECT_DIR/tests/mocks:$PATH"
    run validate_phase1_requirements
    [ "$status" -eq 1 ]
}

@test "validate_phase1_requirements passes with all requirements met" {
    run validate_phase1_requirements
    [ "$status" -eq 0 ]
}

@test "validate_phase1_requirements passes with PostgreSQL and pg_dump" {
    export DB_ENGINE="pgsql"
    run validate_phase1_requirements
    [ "$status" -eq 0 ]
}

@test "validate_phase1_requirements fails with PostgreSQL and no pg_dump" {
    local no_pg="$MB_TEST_DIR/no-pg"
    mkdir -p "$no_pg"
    for cmd in mysql mysqldump php rclone zip; do
        cp "$MB_PROJECT_DIR/tests/mocks/$cmd" "$no_pg/"
    done
    export PATH="$no_pg"
    export DB_ENGINE="pgsql"
    run validate_phase1_requirements
    [ "$status" -eq 1 ]
}
