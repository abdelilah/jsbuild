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

@test "extracts .tar.gz archive from URL" {
    create_archive "$FIXTURES_DIR/sample-app" "$ARCHIVE_DIR/app.tar.gz" "tar.gz"
    local pid
    pid=$(serve_file "$ARCHIVE_DIR/app.tar.gz" 8891)

    run run_container \
        -e "BUNDLE_URL=http://host.docker.internal:8891/app.tar.gz" \
        -e "BUILD=echo 'build ok'" \
        -e "BEFORE_BUILD=true" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    stop_server "$pid"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Extracting archive"* ]]
    [[ "$output" == *"Build pipeline completed successfully"* ]]
}

@test "extracts .tgz archive from URL" {
    create_archive "$FIXTURES_DIR/sample-app" "$ARCHIVE_DIR/app.tgz" "tgz"
    local pid
    pid=$(serve_file "$ARCHIVE_DIR/app.tgz" 8892)

    run run_container \
        -e "BUNDLE_URL=http://host.docker.internal:8892/app.tgz" \
        -e "BUILD=echo 'build ok'" \
        -e "BEFORE_BUILD=true" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    stop_server "$pid"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Extracting archive"* ]]
}

@test "extracts .zip archive from URL" {
    create_archive "$FIXTURES_DIR/sample-app" "$ARCHIVE_DIR/app.zip" "zip"
    local pid
    pid=$(serve_file "$ARCHIVE_DIR/app.zip" 8893)

    run run_container \
        -e "BUNDLE_URL=http://host.docker.internal:8893/app.zip" \
        -e "BUILD=echo 'build ok'" \
        -e "BEFORE_BUILD=true" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    stop_server "$pid"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Extracting archive"* ]]
}

@test "extracts .gz archive from URL" {
    local tmpdir
    tmpdir=$(mktemp -d)
    cp "$FIXTURES_DIR/sample-app/package.json" "$tmpdir/"
    gzip "$tmpdir/package.json"
    cp "$tmpdir/package.json.gz" "$ARCHIVE_DIR/package.json.gz"
    rm -rf "$tmpdir"

    local pid
    pid=$(serve_file "$ARCHIVE_DIR/package.json.gz" 8894)

    run run_container \
        -e "BUNDLE_URL=http://host.docker.internal:8894/package.json.gz" \
        -e "BUILD=echo 'build ok'" \
        -e "BEFORE_BUILD=true" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    stop_server "$pid"
    [[ "$output" == *"Extracting archive"* ]]
}

@test "hoists single top-level directory from archive" {
    local tmpdir
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/myproject"
    cp "$FIXTURES_DIR/sample-app/package.json" "$tmpdir/myproject/"
    cp "$FIXTURES_DIR/sample-app/index.js" "$tmpdir/myproject/"
    tar -czf "$ARCHIVE_DIR/nested.tar.gz" -C "$tmpdir" myproject
    rm -rf "$tmpdir"

    local pid
    pid=$(serve_file "$ARCHIVE_DIR/nested.tar.gz" 8895)

    run run_container \
        -e "BUNDLE_URL=http://host.docker.internal:8895/nested.tar.gz" \
        -e "BUILD=echo 'build ok'" \
        -e "BEFORE_BUILD=true" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    stop_server "$pid"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Hoisting single top-level directory"* ]]
}

@test "does not hoist when archive has multiple top-level items" {
    local tmpdir
    tmpdir=$(mktemp -d)
    mkdir -p "$tmpdir/dir1" "$tmpdir/dir2"
    cp "$FIXTURES_DIR/sample-app/package.json" "$tmpdir/"
    cp "$FIXTURES_DIR/sample-app/index.js" "$tmpdir/"
    cp "$FIXTURES_DIR/sample-app/package.json" "$tmpdir/dir1/"
    echo "file2" > "$tmpdir/dir2/file.txt"
    tar -czf "$ARCHIVE_DIR/multi.tar.gz" -C "$tmpdir" package.json index.js dir1 dir2
    rm -rf "$tmpdir"

    local pid
    pid=$(serve_file "$ARCHIVE_DIR/multi.tar.gz" 8896)

    run run_container \
        -e "BUNDLE_URL=http://host.docker.internal:8896/multi.tar.gz" \
        -e "BUILD=echo 'build ok'" \
        -e "BEFORE_BUILD=true" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    stop_server "$pid"
    [ "$status" -eq 0 ]
    [[ "$output" != *"Hoisting single top-level directory"* ]]
}

@test "falls back to tar.gz for unknown archive extension" {
    create_archive "$FIXTURES_DIR/sample-app" "$ARCHIVE_DIR/app.tar.gz" "tar.gz"
    mv "$ARCHIVE_DIR/app.tar.gz" "$ARCHIVE_DIR/app.unknown"
    local pid
    pid=$(serve_file "$ARCHIVE_DIR/app.unknown" 8897)

    run run_container \
        -e "BUNDLE_URL=http://host.docker.internal:8897/app.unknown" \
        -e "BUILD=echo 'build ok'" \
        -e "BEFORE_BUILD=true" \
        -e "AFTER_BUILD=true" \
        "$IMAGE_NAME"

    stop_server "$pid"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Could not detect archive format"* ]]
}
