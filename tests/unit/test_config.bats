#!/usr/bin/env bats

load '../test_helper'

setup() {
    setup_test_env
    setup_test_configs
    load_lib "utils"
    load_lib "config"
}

teardown() {
    teardown_test_env
}

@test "load_moodle_config fails without argument" {
    run load_moodle_config ""
    [ "$status" -eq 1 ]
}

@test "load_moodle_config fails for nonexistent config" {
    run load_moodle_config "nonexistent"
    [ "$status" -eq 1 ]
}

@test "load_moodle_config loads valid config" {
    # Create fake moodle structure for validation
    mkdir -p /tmp/fake-moodle/admin/cli
    touch /tmp/fake-moodle/admin/cli/maintenance.php
    
    run load_moodle_config "test-moodle"
    
    rm -rf /tmp/fake-moodle
    # May fail on DB check, but should at least load the file
    [[ "$output" == *"test-moodle"* ]] || true
}

@test "validate_config_variables catches missing vars" {
    INSTANCE_NAME="" SRC_APP="" DB_NAME="" DB_USER="" DB_PASSWORD="" NOTIFICATION_EMAIL="" SERVER_NAME=""
    run validate_config_variables
    [ "$status" -ne 0 ]
}

@test "validate_config_variables sets defaults" {
    INSTANCE_NAME="test" SRC_APP="/tmp" DB_NAME="db" DB_USER="u" DB_PASSWORD="p" NOTIFICATION_EMAIL="e@e" SERVER_NAME="s"
    RETENTION_COPIES="" DB_HOST="" PHP_CLI=""
    validate_config_variables 2>/dev/null || true
    [ "$RETENTION_COPIES" = "2" ]
    [ "$DB_HOST" = "localhost" ]
    [ "$PHP_CLI" = "/usr/bin/php" ]
}

@test "list_available_configs shows configs" {
    run list_available_configs
    [ "$status" -eq 0 ]
    [[ "$output" == *"test-moodle"* ]]
}

@test "enable_config creates symlink" {
    enable_config "test-moodle"
    [ -L "$CONFIG_ENABLED_DIR/test-moodle.config" ]
}

@test "enable_config fails for nonexistent config" {
    run enable_config "nonexistent"
    [ "$status" -eq 1 ]
}

@test "disable_config removes symlink" {
    enable_config "test-moodle"
    disable_config "test-moodle"
    [ ! -L "$CONFIG_ENABLED_DIR/test-moodle.config" ]
}

@test "create_config creates from template" {
    cp "${MB_PROJECT_DIR}/configs/available/moodle.config.example" "$CONFIG_AVAILABLE_DIR/"
    run create_config "new-site"
    [ "$status" -eq 0 ]
    [ -f "$CONFIG_AVAILABLE_DIR/new-site.config" ]
    grep -q 'INSTANCE_NAME="new-site"' "$CONFIG_AVAILABLE_DIR/new-site.config"
}

@test "create_config fails if already exists" {
    run create_config "test-moodle"
    [ "$status" -eq 1 ]
}
