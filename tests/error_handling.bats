#!/usr/bin/env bats

setup_file() {
    load helpers/common
    build_image
}

setup() {
    load helpers/common
}

@test "exits with error when build command fails" {
    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=false" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Pipeline failed"* ]]
}

@test "exits with error when BEFORE_INSTALL hook fails" {
    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        -e "BEFORE_INSTALL=false" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=echo 'build ok'" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    [ "$status" -ne 0 ]
}

@test "exits with error when AFTER_INSTALL hook fails" {
    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        -e "AFTER_INSTALL=false" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=echo 'build ok'" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Pipeline failed"* ]]
}

@test "exits with error when BEFORE_BUILD hook fails" {
    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        -e "BEFORE_BUILD=false" \
        -e "BUILD=echo 'build ok'" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Pipeline failed"* ]]
}

@test "exits with error when AFTER_BUILD hook fails" {
    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=echo 'build ok'" \
        -e "AFTER_BUILD=false" \
        "$IMAGE_NAME"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Pipeline failed"* ]]
}

@test "exits with error when BUNDLE_URL download fails" {
    run run_container \
        -e "BUNDLE_URL=http://host.docker.internal:9999/nonexistent.tar.gz" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=echo 'build ok'" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    [ "$status" -ne 0 ]
}

@test "exits with error when npm install fails" {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo '{"name": "bad", "version": "1.0.0", "dependencies": {"this-package-does-not-exist-xyz": "1.0.0"}}' > "$tmpdir/package.json"

    run run_container \
        -v "$tmpdir:/build" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=echo 'build ok'" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    [ "$status" -ne 0 ]
    rm -rf "$tmpdir"
}

@test "pipeline does not continue after failure" {
    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=false" \
        -e "AFTER_BUILD=echo 'SHOULD_NOT_SEE_THIS'" \
        "$IMAGE_NAME"

    [ "$status" -ne 0 ]
    [[ "$output" != *"SHOULD_NOT_SEE_THIS"* ]]
}
