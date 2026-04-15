#!/usr/bin/env bats

setup_file() {
    load helpers/common
    build_image
}

setup() {
    load helpers/common
}

start_webhook_listener() {
    local port="$1"
    printf 'HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n' | timeout 30 nc -l "$port" 2>/dev/null &
    echo $!
}

@test "sends success webhook when WEBHOOK_URL is set" {
    local nc_pid
    nc_pid=$(start_webhook_listener 9991)

    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        -e "WEBHOOK_URL=http://host.docker.internal:9991/webhook" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=echo 'build ok'" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    stop_server "$nc_pid"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Build pipeline completed successfully"* ]]
}

@test "sends error webhook when build fails" {
    local nc_pid
    nc_pid=$(start_webhook_listener 9992)

    run run_container \
        -v "$FIXTURES_DIR/failing-app:/build" \
        -e "WEBHOOK_URL=http://host.docker.internal:9992/webhook" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=false" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    stop_server "$nc_pid"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Pipeline failed"* ]]
}

@test "uses custom WEBHOOK_COMMAND when set" {
    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        -e "WEBHOOK_COMMAND=true" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=echo 'build ok'" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Build pipeline completed successfully"* ]]
}

@test "custom WEBHOOK_COMMAND failure does not fail pipeline" {
    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        -e "WEBHOOK_COMMAND=false" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=echo 'build ok'" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    [ "$status" -eq 0 ]
}

@test "does not send webhook when WEBHOOK_URL is not set" {
    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=echo 'build ok'" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    [ "$status" -eq 0 ]
}

@test "sends webhook on BEFORE_INSTALL failure" {
    local nc_pid
    nc_pid=$(start_webhook_listener 9993)

    run run_container \
        -v "$FIXTURES_DIR/sample-app:/build" \
        -e "WEBHOOK_URL=http://host.docker.internal:9993/webhook" \
        -e "BEFORE_INSTALL=false" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=echo 'build ok'" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    stop_server "$nc_pid"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Pipeline failed"* ]]
}

@test "sends webhook on npm install failure" {
    local tmpdir
    tmpdir=$(mktemp -d)
    echo '{"name": "bad", "version": "1.0.0", "dependencies": {"nonexistent-pkg-xyz": "99.99.99"}}' > "$tmpdir/package.json"

    local nc_pid
    nc_pid=$(start_webhook_listener 9994)

    run run_container \
        -v "$tmpdir:/build" \
        -e "WEBHOOK_URL=http://host.docker.internal:9994/webhook" \
        -e "BEFORE_BUILD=true" \
        -e "BUILD=echo 'build ok'" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    stop_server "$nc_pid"

    [ "$status" -ne 0 ]
    rm -rf "$tmpdir"
}
