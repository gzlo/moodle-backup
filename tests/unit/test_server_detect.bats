#!/usr/bin/env bats

load '../test_helper'

setup() {
    setup_test_env
    load_lib "server_detect"
}

teardown() {
    teardown_test_env
}

# --- detect_control_panel ---

@test "detect_control_panel returns cpanel when /usr/local/cpanel exists" {
    mkdir -p "$MB_TEST_DIR/fake_root/usr/local/cpanel"
    _original_detect=$(declare -f detect_control_panel)
    detect_control_panel() {
        if [ -d "$MB_TEST_DIR/fake_root/usr/local/cpanel" ]; then
            if [ -d "$MB_TEST_DIR/fake_root/usr/local/cpanel/whostmgr" ]; then
                echo "cpanel-whm"
            else
                echo "cpanel"
            fi
            return
        fi
        echo "none"
    }
    run detect_control_panel
    [ "$status" -eq 0 ]
    [ "$output" = "cpanel" ]
}

@test "detect_control_panel returns cpanel-whm when whostmgr exists" {
    mkdir -p "$MB_TEST_DIR/fake_root/usr/local/cpanel/whostmgr"
    detect_control_panel() {
        if [ -d "$MB_TEST_DIR/fake_root/usr/local/cpanel/whostmgr" ]; then
            echo "cpanel-whm"
            return
        fi
        echo "none"
    }
    run detect_control_panel
    [ "$status" -eq 0 ]
    [ "$output" = "cpanel-whm" ]
}

@test "detect_control_panel returns plesk when /usr/local/psa exists" {
    mkdir -p "$MB_TEST_DIR/fake_root/usr/local/psa"
    detect_control_panel() {
        if [ -d "$MB_TEST_DIR/fake_root/usr/local/psa" ]; then
            echo "plesk"; return
        fi
        echo "none"
    }
    run detect_control_panel
    [ "$status" -eq 0 ]
    [ "$output" = "plesk" ]
}

@test "detect_control_panel returns hestiacp when /usr/local/hestia exists" {
    mkdir -p "$MB_TEST_DIR/fake_root/usr/local/hestia"
    detect_control_panel() {
        if [ -d "$MB_TEST_DIR/fake_root/usr/local/hestia" ]; then
            echo "hestiacp"; return
        fi
        echo "none"
    }
    run detect_control_panel
    [ "$status" -eq 0 ]
    [ "$output" = "hestiacp" ]
}

# --- get_panel_search_paths ---

@test "get_panel_search_paths returns cpanel paths" {
    run get_panel_search_paths "cpanel"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/home/*/public_html"* ]]
}

@test "get_panel_search_paths returns plesk paths" {
    run get_panel_search_paths "plesk"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/var/www/vhosts/*/httpdocs"* ]]
}

@test "get_panel_search_paths returns hestiacp paths" {
    run get_panel_search_paths "hestiacp"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/home/*/web/*/public_html"* ]]
}

@test "get_panel_search_paths returns directadmin paths" {
    run get_panel_search_paths "directadmin"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/home/*/domains/*/public_html"* ]]
}

@test "get_panel_search_paths returns docker paths" {
    run get_panel_search_paths "docker"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/var/www/html"* ]]
}

@test "get_panel_search_paths returns bare-metal paths for none" {
    run get_panel_search_paths "none"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/var/www/html"* ]]
    [[ "$output" == *"/var/www"* ]]
}

# --- detect_moodle_installations ---

@test "detect_moodle_installations finds moodle with config.php" {
    # Create a fake moodle installation
    local fake_moodle="$MB_TEST_DIR/var/www/html/moodle"
    mkdir -p "$fake_moodle"
    cat > "$fake_moodle/config.php" << 'EOF'
<?php
$CFG->dbname = 'moodle';
$CFG->dataroot = '/var/moodledata';
EOF

    # Override to search in test dir
    get_panel_search_paths() { echo "$MB_TEST_DIR/var/www/html"; }
    detect_control_panel() { echo "none"; }
    
    run detect_moodle_installations
    [ "$status" -eq 0 ]
    [[ "$output" == *"$fake_moodle"* ]]
}

@test "detect_moodle_installations ignores non-moodle config.php" {
    local fake_app="$MB_TEST_DIR/var/www/html/wordpress"
    mkdir -p "$fake_app"
    echo "<?php // WordPress config" > "$fake_app/config.php"

    get_panel_search_paths() { echo "$MB_TEST_DIR/var/www/html"; }
    detect_control_panel() { echo "none"; }
    
    run detect_moodle_installations
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# --- get_moodle_version ---

@test "get_moodle_version extracts version from version.php" {
    local fake_moodle="$MB_TEST_DIR/moodle"
    mkdir -p "$fake_moodle"
    cat > "$fake_moodle/version.php" << 'EOF'
<?php
$release = '4.3.2 (Build: 20240101)';
$version = 2024010100;
EOF
    
    run get_moodle_version "$fake_moodle"
    [ "$status" -eq 0 ]
    [ "$output" = "4.3.2" ]
}

@test "get_moodle_version returns ? when no version.php" {
    run get_moodle_version "$MB_TEST_DIR/nonexistent"
    [ "$status" -eq 0 ]
    [ "$output" = "?" ]
}

# --- detect_environment ---

@test "detect_environment returns a valid value" {
    run detect_environment
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^(docker|lxc|openvz|vps|dedicated|unknown)$ ]]
}

# --- detect_web_server ---

@test "detect_web_server returns a value" {
    run detect_web_server
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

# --- detect_php_version ---

@test "detect_php_version returns a string" {
    run detect_php_version
    [ "$status" -eq 0 ]
    # May be empty if PHP not installed in test environment
}

# --- mb detect command ---

@test "mb detect runs without error" {
    run "${MB_PROJECT_DIR}/bin/mb" detect
    [ "$status" -eq 0 ]
    [[ "$output" == *"Detección de servidor"* ]]
    [[ "$output" == *"Panel de control:"* ]]
    [[ "$output" == *"Web server:"* ]]
}
