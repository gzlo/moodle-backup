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
    [[ "$output" == *"COMANDOS PRINCIPALES"* ]]
}

@test "mb without args shows help" {
    run "${MB_PROJECT_DIR}/bin/mb"
    [ "$status" -eq 0 ]
    [[ "$output" == *"COMANDOS PRINCIPALES"* ]]
}

@test "mb unknown command fails" {
    run "${MB_PROJECT_DIR}/bin/mb" foobar
    [ "$status" -eq 1 ]
    [[ "$output" == *"Comando desconocido"* ]]
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

@test "mb status runs" {
    run "${MB_PROJECT_DIR}/bin/mb" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Estado del Sistema"* ]]
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
