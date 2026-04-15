#!/usr/bin/env bats

setup_file() {
    load helpers/common
    build_image
}

setup() {
    load helpers/common
}

@test "BEFORE_INSTALL hook runs before npm install" {
    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        -e "BEFORE_INSTALL=echo 'BEFORE_INSTALL_RAN'" \
        -e "BUILD=echo 'build ok'" \
        -e "BEFORE_BUILD=true" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    [ "$status" -eq 0 ]
    [[ "$output" == *"BEFORE_INSTALL_RAN"* ]]

    local before_idx install_idx
    before_idx=$(echo "$output" | grep -n "BEFORE_INSTALL_RAN" | head -1 | cut -d: -f1)
    install_idx=$(echo "$output" | grep -n "Installing dependencies" | head -1 | cut -d: -f1)
    [ "$before_idx" -lt "$install_idx" ]
}

@test "AFTER_INSTALL hook runs after npm install" {
    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        -e "AFTER_INSTALL=echo 'AFTER_INSTALL_RAN'" \
        -e "BUILD=echo 'build ok'" \
        -e "BEFORE_BUILD=true" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    [ "$status" -eq 0 ]
    [[ "$output" == *"AFTER_INSTALL_RAN"* ]]

    local after_idx before_build_idx
    after_idx=$(echo "$output" | grep -n "AFTER_INSTALL_RAN" | head -1 | cut -d: -f1)
    before_build_idx=$(echo "$output" | grep -n "Running BEFORE_BUILD" | head -1 | cut -d: -f1)
    [ "$after_idx" -lt "$before_build_idx" ]
}

@test "BEFORE_BUILD hook runs with default value" {
    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        -e "BUILD=echo 'build ok'" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Running BEFORE_BUILD"* ]]
}

@test "BEFORE_BUILD hook runs custom command" {
    run run_container \
        -v "$FIXTURES_DIR/hooks-app:/build" \
        -e "BEFORE_INSTALL=touch /build/before-install-marker" \
        -e "AFTER_INSTALL=touch /build/after-install-marker" \
        -e "BEFORE_BUILD=echo 'CUSTOM_BEFORE_BUILD'" \
        -e "BUILD=echo 'build ok'" \
        -e "AFTER_BUILD=echo 'CUSTOM_AFTER_BUILD'" \
        "$IMAGE_NAME"

    [ "$status" -eq 0 ]
    [[ "$output" == *"CUSTOM_BEFORE_BUILD"* ]]
}

@test "BUILD command runs custom build script" {
    run run_container \
        -v "$FIXTURES_DIR/hooks-app:/build" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=echo 'CUSTOM_BUILD_RAN'" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    [ "$status" -eq 0 ]
    [[ "$output" == *"CUSTOM_BUILD_RAN"* ]]
}

@test "AFTER_BUILD hook runs after build" {
    run run_container \
        -v "$FIXTURES_DIR/hooks-app:/build" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=echo 'build ok'" \
        -e "AFTER_BUILD=echo 'CUSTOM_AFTER_BUILD'" \
        "$IMAGE_NAME"

    [ "$status" -eq 0 ]
    [[ "$output" == *"CUSTOM_AFTER_BUILD"* ]]
}

@test "lifecycle hooks run in correct order" {
    run run_container \
        -v "$FIXTURES_DIR/hooks-app:/build" \
        -e "BEFORE_INSTALL=echo 'STEP_1'" \
        -e "AFTER_INSTALL=echo 'STEP_3'" \
        -e "BEFORE_BUILD=echo 'STEP_4'" \
        -e "BUILD=echo 'STEP_5'" \
        -e "AFTER_BUILD=echo 'STEP_6'" \
        "$IMAGE_NAME"

    [ "$status" -eq 0 ]

    local s1 s3 s4 s5 s6
    s1=$(echo "$output" | grep -n "STEP_1" | head -1 | cut -d: -f1)
    s3=$(echo "$output" | grep -n "STEP_3" | head -1 | cut -d: -f1)
    s4=$(echo "$output" | grep -n "STEP_4" | head -1 | cut -d: -f1)
    s5=$(echo "$output" | grep -n "STEP_5" | head -1 | cut -d: -f1)
    s6=$(echo "$output" | grep -n "STEP_6" | head -1 | cut -d: -f1)

    [ "$s1" -lt "$s3" ]
    [ "$s3" -lt "$s4" ]
    [ "$s4" -lt "$s5" ]
    [ "$s5" -lt "$s6" ]
}

@test "hooks can create files in /build" {
    local tmpdir
    tmpdir=$(mktemp -d)
    cp "$FIXTURES_DIR/sample-app/package.json" "$tmpdir/"
    cp "$FIXTURES_DIR/sample-app/index.js" "$tmpdir/"

    run run_container \
        -v "$tmpdir:/build" \
        -e "BEFORE_INSTALL=touch /build/before-install.txt" \
        -e "AFTER_INSTALL=touch /build/after-install.txt" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=touch /build/build-done.txt" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    [ "$status" -eq 0 ]
    [ -f "$tmpdir/before-install.txt" ]
    [ -f "$tmpdir/after-install.txt" ]
    [ -f "$tmpdir/build-done.txt" ]

    rm -rf "$tmpdir"
}

@test "unset hooks are skipped" {
    run run_container \
        -v "$FIXTURES_DIR/hooks-app:/build" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=echo 'build ok'" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    [ "$status" -eq 0 ]
    [[ "$output" != *"Running BEFORE_INSTALL"* ]]
    [[ "$output" != *"Running AFTER_INSTALL"* ]]
}
