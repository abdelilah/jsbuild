# jsbuild — Generic JavaScript Build & Deploy Container

A reusable Docker image for downloading, building, and deploying JavaScript projects from archives. Platform-agnostic — works with any JS framework and deployment target.

## Quick Start

### From URL

```bash
docker run --rm \
  -e BUNDLE_URL="https://example.com/my-app.tar.gz" \
  abdelilah/jsbuild
```

### From local directory

```bash
docker run --rm \
  -v /path/to/your/project:/build \
  abdelilah/jsbuild
```

## Environment Variables

### Source

| Variable | Description |
|---|---|
| `BUNDLE_URL` | URL to download the source archive (`.tar.gz`, `.tgz`, `.zip`, or `.gz`). If not set, source is expected to be mounted at `/build`. |

### Optional — Lifecycle Hooks

| Variable | Default | Description |
|---|---|---|
| `BEFORE_INSTALL` | *(empty)* | Shell command(s) to run before `npm install` |
| `AFTER_INSTALL` | *(empty)* | Shell command(s) to run after `npm install` |
| `BEFORE_BUILD` | `npm run test \|\| echo "No test script found"` | Shell command(s) to run before the build step |
| `BUILD` | `npm run build` | Main build command |
| `AFTER_BUILD` | `npm run deploy \|\| echo "No deployment script found"` | Shell command(s) to run after the build step |

### Optional — General

| Variable | Default | Description |
|---|---|---|
| `WEBHOOK_URL` | *(empty)* | If set, sends a JSON POST on success/failure with status and logs |
| `WEBHOOK_COMMAND` | `curl -sf -X POST ...` | Custom shell command to send the webhook. `$status` and `$logs` are available |

## Pipeline

```
1. Download & extract archive from BUNDLE_URL (if set), otherwise use mounted /build
2. Run BEFORE_INSTALL hook
3. Run npm install
4. Run AFTER_INSTALL hook
5. Run BEFORE_BUILD hook
6. Run BUILD command
7. Run AFTER_BUILD hook
8. Send success webhook (if WEBHOOK_URL is set)
   └── On failure at any step: send error webhook and exit 1
```

## Examples

### Basic build

```bash
docker run --rm \
  -e BUNDLE_URL="https://storage.example.com/app-1.0.0.tar.gz" \
  abdelilah/jsbuild
```

### With lifecycle hooks

```bash
docker run --rm \
  -e BUNDLE_URL="https://storage.example.com/app.zip" \
  -e BEFORE_INSTALL="echo 'Setting up...' && cp .env.example .env" \
  -e BUILD="npm run build:production" \
  -e AFTER_BUILD="npm run deploy:staging" \
  abdelilah/jsbuild
```

### With mounted source

```bash
docker run --rm \
  -v $(pwd):/build \
  -e BUILD="npm run build:production" \
  abdelilah/jsbuild
```

### With webhook notifications

```bash
docker run --rm \
  -e BUNDLE_URL="https://storage.example.com/app.tar.gz" \
  -e WEBHOOK_URL="https://hooks.slack.com/services/XXX/YYY/ZZZ" \
  abdelilah/jsbuild
```

### In a CI/CD pipeline

```yaml
- name: Build & Deploy
  run: |
    docker run --rm \
      -e BUNDLE_URL="${{ secrets.ARTIFACT_URL }}" \
      -e BUILD="npm run build && npm run deploy" \
      -e WEBHOOK_URL="${{ secrets.WEBHOOK_URL }}" \
      abdelilah/jsbuild
```

## Supported Archive Formats

| Extension | Command |
|---|---|
| `.tar.gz`, `.tgz` | `tar -xzf <archive> -C /build` |
| `.zip` | `unzip -q <archive> -d /build` |
| `.gz` (non-tar) | `gunzip -k <archive>`, move file into `/build` |

If the archive extracts into a single top-level directory, its contents are automatically hoisted into `/build`.

## Webhook Payload

When `WEBHOOK_URL` is set (or `WEBHOOK_COMMAND` is provided), a webhook is sent on completion. The default payload is:

```json
{
  "status": "success",
  "logs": "full build log output..."
}
```

`status` is either `"success"` or `"error"`.

To fully customize how the webhook is sent, set `WEBHOOK_COMMAND`. The variables `$status` and `$logs` are available:

```bash
docker run --rm \
  -e BUNDLE_URL="https://example.com/app.tar.gz" \
  -e WEBHOOK_COMMAND='curl -sf -X POST https://example.com/hook -H "Authorization: Bearer $TOKEN" -d "{\"status\":\"$status\",\"logs\":\"$logs\"}"' \
  abdelilah/jsbuild
```

## License

MIT
