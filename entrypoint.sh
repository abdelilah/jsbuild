#!/bin/bash
set -euo pipefail

LOG_FILE=$(mktemp /tmp/build-logs.XXXXXX)
exec > >(tee -a "$LOG_FILE") 2>&1

send_webhook() {
    local status="$1"
    if [[ -z "${WEBHOOK_URL:-}" && -z "${WEBHOOK_COMMAND:-}" ]]; then
        return 0
    fi

    local logs
    logs=$(cat "$LOG_FILE")

    if [[ -n "${WEBHOOK_COMMAND:-}" ]]; then
        eval "$WEBHOOK_COMMAND" || true
    else
        local escaped_logs
        escaped_logs=$(printf '%s' "$logs" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\n/\\n/g')
        curl -sf -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"status\":\"$status\",\"logs\":\"$escaped_logs\"}" || true
    fi
}

on_error() {
    local exit_code=$?
    echo "[jsbuild] Pipeline failed with exit code $exit_code"
    send_webhook "error"
    exit 1
}
trap on_error ERR

if [[ -n "${BUNDLE_URL:-}" ]]; then
    echo "[jsbuild] Downloading archive..."
    ARCHIVE=/tmp/source-archive
    curl -sfL -o "$ARCHIVE" "$BUNDLE_URL"

    echo "[jsbuild] Extracting archive..."

    extracted=false

    if echo "$BUNDLE_URL" | grep -qE '\.tar\.gz$|\.tgz$'; then
        tar -xzf "$ARCHIVE" -C /build
        extracted=true
    elif echo "$BUNDLE_URL" | grep -qE '\.zip$'; then
        unzip -q "$ARCHIVE" -d /build
        extracted=true
    elif echo "$BUNDLE_URL" | grep -qE '\.gz$'; then
        cp "$ARCHIVE" "${ARCHIVE}.gz"
        gunzip "${ARCHIVE}.gz"
        mv "$ARCHIVE" /build/
        extracted=true
    fi

    if [[ "$extracted" != "true" ]]; then
        echo "[jsbuild] Warning: Could not detect archive format from URL. Attempting tar.gz..."
        tar -xzf "$ARCHIVE" -C /build
    fi

    top_level_dirs=()
    while IFS= read -r -d '' dir; do
        top_level_dirs+=("$dir")
    done < <(find /build -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

    top_level_files=()
    while IFS= read -r -d '' f; do
        top_level_files+=("$f")
    done < <(find /build -mindepth 1 -maxdepth 1 -type f -print0 2>/dev/null)

    if [[ ${#top_level_dirs[@]} -eq 1 && ${#top_level_files[@]} -eq 0 ]]; then
        echo "[jsbuild] Hoisting single top-level directory: ${top_level_dirs[0]}"
        tmp_hoist=$(mktemp -d)
        mv "${top_level_dirs[0]}"/* "$tmp_hoist"/ 2>/dev/null || true
        mv "${top_level_dirs[0]}"/.* "$tmp_hoist"/ 2>/dev/null || true
        rmdir "${top_level_dirs[0]}"
        mv "$tmp_hoist"/* /build/ 2>/dev/null || true
        mv "$tmp_hoist"/.* /build/ 2>/dev/null || true
        rm -rf "$tmp_hoist"
    fi
else
    echo "[jsbuild] Using mounted source from /build"
fi

if [[ -n "${BEFORE_INSTALL:-}" ]]; then
    echo "[jsbuild] Running BEFORE_INSTALL..."
    eval "$BEFORE_INSTALL"
fi

echo "[jsbuild] Installing dependencies..."
npm install

if [[ -n "${AFTER_INSTALL:-}" ]]; then
    echo "[jsbuild] Running AFTER_INSTALL..."
    eval "$AFTER_INSTALL"
fi

echo "[jsbuild] Running BEFORE_BUILD..."
eval "${BEFORE_BUILD:-npm run test || echo \"No test script found\"}"

echo "[jsbuild] Running BUILD..."
eval "${BUILD:-npm run build}"

echo "[jsbuild] Running AFTER_BUILD..."
eval "${AFTER_BUILD:-npm run deploy || echo \"No deployment script found\"}"

echo "[jsbuild] Build pipeline completed successfully."
send_webhook "success"
