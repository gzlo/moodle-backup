#!/usr/bin/env bats

load '../test_helper'

@test "cron_wrapper.sh requires config argument" {
    run bash "${MB_PROJECT_DIR}/scripts/cron_wrapper.sh"
    [ "$status" -eq 1 ]
}

@test "cron_wrapper.sh fails for missing config" {
    run bash "${MB_PROJECT_DIR}/scripts/cron_wrapper.sh" "nonexistent-config"
    [ "$status" -eq 1 ]
}
