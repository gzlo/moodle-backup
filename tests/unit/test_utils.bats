#!/usr/bin/env bats

load '../test_helper'

setup() {
    load_lib "utils"
}

@test "MB_VERSION is defined" {
    [ -n "$MB_VERSION" ]
}

@test "show_message error writes to stderr" {
    run show_message "error" "test error"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ERROR"* ]] || [[ "$output" == *"test error"* ]]
}

@test "show_message success writes to stdout" {
    run show_message "success" "test success"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test success"* ]]
}

@test "get_elapsed_time returns formatted time" {
    local start=$(date +%s)
    sleep 1
    local result=$(get_elapsed_time $start)
    [[ "$result" =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]
}

@test "get_file_size returns N/A for non-existent file" {
    local result=$(get_file_size "/nonexistent/file")
    [ "$result" = "N/A" ]
}

@test "get_file_size returns size for existing file" {
    local tmpfile=$(mktemp)
    echo "test content" > "$tmpfile"
    local result=$(get_file_size "$tmpfile")
    [ "$result" != "N/A" ]
    rm -f "$tmpfile"
}

@test "month_spanish returns correct month" {
    local result=$(month_spanish "01")
    [ "$result" = "Enero" ]
    
    result=$(month_spanish "12")
    [ "$result" = "Diciembre" ]
}

@test "month_spanish handles single digit" {
    local result=$(month_spanish "3")
    [ "$result" = "Marzo" ]
}

@test "detect_color_support respects NO_COLOR" {
    NO_COLOR=1 run detect_color_support
    [ "$status" -eq 1 ]
}

@test "detect_color_support respects --no-color flag" {
    run detect_color_support "--no-color"
    [ "$status" -eq 1 ]
}
