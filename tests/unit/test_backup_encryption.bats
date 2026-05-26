#!/usr/bin/env bats

load '../test_helper'

setup() {
    setup_test_env
    load_lib "utils"
    load_lib "logging"
    load_lib "backup_encryption"

    init_logging "$MB_TEST_DIR/test.log"
    export ENCRYPTION_METHOD="passphrase"
    export GPG_PASSPHRASE="test-passphrase-123"
}

teardown() {
    teardown_test_env
}

@test "validate_encryption fails without gpg passphrase" {
    unset GPG_PASSPHRASE
    run validate_encryption
    [ "$status" -eq 1 ]
}

@test "validate_encryption succeeds with passphrase set" {
    run validate_encryption
    [ "$status" -eq 0 ]
}

@test "validate_encryption fails with unknown method" {
    export ENCRYPTION_METHOD="unknown"
    run validate_encryption
    [ "$status" -eq 1 ]
}

@test "encrypt_file creates .gpg output" {
    local test_file="$MB_TEST_DIR/test.txt"
    echo "secret data" > "$test_file"

    run encrypt_file "$test_file" "${test_file}.gpg"
    [ "$status" -eq 0 ]
    [ -f "${test_file}.gpg" ]
}

@test "encrypt_file removes original after encryption" {
    local test_file="$MB_TEST_DIR/test2.txt"
    echo "secret data" > "$test_file"

    encrypt_file "$test_file" "${test_file}.gpg"
    [ ! -f "$test_file" ]
    [ -f "${test_file}.gpg" ]
}

@test "encrypt_file fails for non-existent file" {
    run encrypt_file "/nonexistent/file.zip" "/tmp/out.gpg"
    [ "$status" -eq 1 ]
}
