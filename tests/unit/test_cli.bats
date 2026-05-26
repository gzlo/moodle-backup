#!/usr/bin/env bats

load '../test_helper'

@test "mb --version shows version" {
    run "${MB_PROJECT_DIR}/bin/mb" --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"MB v"* ]]
}

@test "mb --help shows help text" {
    run "${MB_PROJECT_DIR}/bin/mb" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"COMANDOS PRINCIPALES"* || "$output" == *"MAIN COMMANDS"* ]]
}

@test "mb without args shows help" {
    run "${MB_PROJECT_DIR}/bin/mb"
    [ "$status" -eq 0 ]
    [[ "$output" == *"COMANDOS PRINCIPALES"* || "$output" == *"MAIN COMMANDS"* ]]
}

@test "mb unknown command fails" {
    run "${MB_PROJECT_DIR}/bin/mb" foobar
    [ "$status" -eq 1 ]
    [[ "$output" == *"Comando desconocido"* || "$output" == *"Unknown command"* ]]
}

@test "mb list runs without error" {
    run "${MB_PROJECT_DIR}/bin/mb" list
    [ "$status" -eq 0 ]
}

@test "mb backup without config fails" {
    run "${MB_PROJECT_DIR}/bin/mb" backup
    [ "$status" -eq 1 ]
}

@test "mb test without config fails" {
    run "${MB_PROJECT_DIR}/bin/mb" test
    [ "$status" -eq 1 ]
}

@test "mb --dry-run parses correctly" {
    run "${MB_PROJECT_DIR}/bin/mb" --dry-run
    [ "$status" -eq 0 ]
}

@test "mb backup --dry-run with valid config validates" {
    setup_test_env
    load_lib "config"
    setup_test_configs
    export CONFIG_BASE_DIR="$MB_TEST_CONFIGS"
    export CONFIG_AVAILABLE_DIR="$MB_TEST_CONFIGS/available"
    export CONFIG_ENABLED_DIR="$MB_TEST_CONFIGS/enabled"
    cp "${MB_PROJECT_DIR}/tests/fixtures/valid.config" "${CONFIG_AVAILABLE_DIR}/drytest.config"
    
    # Dry-run validate_phase1_requirements needs maintenance.php to exist
    mkdir -p /tmp/fake-moodle/admin/cli
    touch /tmp/fake-moodle/admin/cli/maintenance.php

    run "${MB_PROJECT_DIR}/bin/mb" --dry-run backup drytest
    [ "$status" -eq 0 ]
}

@test "mb backup --dry-run usage appears in help" {
    run "${MB_PROJECT_DIR}/bin/mb" --help
    [[ "$output" == *"--dry-run"* ]]
}

@test "mb status runs" {
    run "${MB_PROJECT_DIR}/bin/mb" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Estado del Sistema"* || "$output" == *"Status"* || "$output" == *"Backup"* ]]
}

@test "mb moodlesite list runs" {
    run "${MB_PROJECT_DIR}/bin/mb" moodlesite list
    [ "$status" -eq 0 ]
}

@test "mb --no-color flag is processed" {
    run "${MB_PROJECT_DIR}/bin/mb" --no-color --help
    [ "$status" -eq 0 ]
    # Should not contain ANSI escape codes
    [[ "$output" != *$'\033'* ]]
}
