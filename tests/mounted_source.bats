#!/usr/bin/env bats

setup_file() {
    load helpers/common
    build_image
}

setup() {
    load helpers/common
    ARCHIVE_DIR=$(mktemp -d)
}

teardown() {
    rm -rf "$ARCHIVE_DIR"
}

@test "uses mounted /build directory without BUNDLE_URL" {
    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=echo 'build ok'" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Using mounted source from /build"* ]]
    [[ "$output" != *"Downloading archive"* ]]
}

@test "runs npm install in mounted directory" {
    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=echo 'build ok'" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Installing dependencies"* ]]
}

@test "default BUILD command runs npm run build" {
    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        "$IMAGE_NAME"

    [ "$status" -eq 0 ]
    [[ "$output" == *"build completed"* ]]
}

@test "default BEFORE_BUILD runs npm test" {
    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        "$IMAGE_NAME"

    [ "$status" -eq 0 ]
    [[ "$output" == *"tests passed"* ]]
}

@test "default AFTER_BUILD runs npm run deploy" {
    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        "$IMAGE_NAME"

    [ "$status" -eq 0 ]
    [[ "$output" == *"deployed"* ]]
}

@test "full pipeline completes with all defaults" {
    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        "$IMAGE_NAME"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Installing dependencies"* ]]
    [[ "$output" == *"Running BEFORE_BUILD"* ]]
    [[ "$output" == *"Running BUILD"* ]]
    [[ "$output" == *"Running AFTER_BUILD"* ]]
    [[ "$output" == *"Build pipeline completed successfully"* ]]
}

@test "prefers BUNDLE_URL over mounted /build" {
    create_archive "$FIXTURES_DIR/sample-app" "$ARCHIVE_DIR/app.tar.gz" "tar.gz"
    local pid
    pid=$(serve_file "$ARCHIVE_DIR/app.tar.gz" 8898)

    run run_container \
        -v "$FIXTURES_DIR/hooks-app:/build" \
        -e "BUNDLE_URL=http://host.docker.internal:8898/app.tar.gz" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=echo 'build ok'" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    stop_server "$pid"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Downloading archive"* ]]
    [[ "$output" != *"Using mounted source from /build"* ]]
}
