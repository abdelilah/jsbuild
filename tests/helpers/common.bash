#!/usr/bin/env bash

HOST_PROJECT_DIR="${HOST_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJECT_ROOT="$HOST_PROJECT_DIR/tests"
FIXTURES_DIR="$PROJECT_ROOT/fixtures"
IMAGE_NAME="jsbuild-test"

if [[ -n "${HOST_PROJECT_DIR:-}" && -d "$HOST_PROJECT_DIR" ]]; then
    export TMPDIR="$HOST_PROJECT_DIR/.tmp"
    mkdir -p "$TMPDIR"
fi

build_image() {
    if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        echo "# Building Docker image..." >&3
        docker build -t "$IMAGE_NAME" "$HOST_PROJECT_DIR" >&3 2>&3
    fi
}

run_container() {
    timeout 60 docker run --rm --user 0:0 --add-host=host.docker.internal:host-gateway "$@"
}

create_archive() {
    local source_dir="$1"
    local output_file="$2"
    local format="$3"

    local tmpdir
    tmpdir=$(mktemp -d)
    cp -r "$source_dir"/* "$tmpdir"/

    case "$format" in
        tar.gz|tgz)
            tar -czf "$output_file" -C "$tmpdir" .
            ;;
        zip)
            (cd "$tmpdir" && zip -qr "$output_file" .)
            ;;
        gz)
            local single_file
            single_file=$(find "$tmpdir" -type f | head -1)
            gzip -c "$single_file" > "$output_file"
            ;;
    esac

    rm -rf "$tmpdir"
}

serve_file() {
    local file="$1"
    local port="${2:-8888}"

    python3 -m http.server "$port" --directory "$(dirname "$file")" >/dev/null 2>&1 &
    local pid=$!
    sleep 0.5
    echo "$pid"
}

stop_server() {
    kill "$1" 2>/dev/null || true
}
