#!/usr/bin/env bash
set -euo pipefail

HOST_DIR=$(pwd)
DOCKER_API_VERSION=$(docker version -f '{{.Client.APIVersion}}')

docker build -t jsbuild-test-runner -f Dockerfile.test . >&2

cleanup() {
    rm -rf "$HOST_DIR/.tmp"
}
trap cleanup EXIT

exec docker run --rm \
    --network=host \
    -e "DOCKER_API_VERSION=$DOCKER_API_VERSION" \
    -e "HOST_PROJECT_DIR=$HOST_DIR" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "$HOST_DIR:$HOST_DIR" \
    -w "$HOST_DIR" \
    jsbuild-test-runner tests/
