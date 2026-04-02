# Local Proxy README Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add practical Claude Code local proxy setup guidance to both README files, including model discovery via `/v1/models`, a `settings.json` example, and exact model-name matching guidance.

**Architecture:** Keep this work documentation-only and extend the existing local proxy sections in `README.md` and `README.ko.md`. Reuse the current local auth/shared-secret explanation, then add a short setup flow for model discovery and `settings.json` mapping without changing app code or creating new config files.

**Tech Stack:** Markdown, Python 3 string assertions

---

## File Structure

- Modify: `README.md` — extend `## Local proxy authentication` with Claude Code local proxy setup guidance.
- Modify: `README.ko.md` — mirror the same setup guidance in Korean under `## 로컬 프록시 인증`.

### Task 1: Add Claude Code local proxy setup guidance to README.md

**Files:**
- Modify: `README.md`
- Test: `README.md`

- [ ] **Step 1: Write the failing test**

```bash
python3 - <<'PY'
from pathlib import Path
text = Path('/Users/mirage/go/src/ccproxy/README.md').read_text()
assert 'http://localhost:8317/v1/models' in text
assert 'curl http://localhost:8317/v1/models' in text
assert 'settings.json' in text
assert 'ANTHROPIC_MODEL' in text
assert 'ANTHROPIC_DEFAULT_HAIKU_MODEL' in text
assert 'ANTHROPIC_DEFAULT_SONNET_MODEL' in text
assert 'ANTHROPIC_DEFAULT_OPUS_MODEL' in text
assert 'Use the exact model names returned by `http://localhost:8317/v1/models`.' in text
PY
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 - <<'PY'
from pathlib import Path
text = Path('/Users/mirage/go/src/ccproxy/README.md').read_text()
assert 'http://localhost:8317/v1/models' in text
assert 'curl http://localhost:8317/v1/models' in text
assert 'settings.json' in text
assert 'ANTHROPIC_MODEL' in text
assert 'ANTHROPIC_DEFAULT_HAIKU_MODEL' in text
assert 'ANTHROPIC_DEFAULT_SONNET_MODEL' in text
assert 'ANTHROPIC_DEFAULT_OPUS_MODEL' in text
assert 'Use the exact model names returned by `http://localhost:8317/v1/models`.' in text
PY`
Expected: FAIL because the current README only documents `ANTHROPIC_AUTH_TOKEN` and `ANTHROPIC_BASE_URL` in the local proxy section.

- [ ] **Step 3: Write minimal implementation**

Replace the current `## Local proxy authentication` section in `README.md` with this content:

```md
## Local proxy authentication

CCProxy can enforce a shared secret for local proxy requests.

The local proxy base URL is:

```text
http://localhost:8317
```

To see which model IDs are currently exposed by the local proxy, query:

```bash
curl http://localhost:8317/v1/models
```

Use the returned model IDs when configuring Claude Code.

Example `settings.json`:

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "local-test",
    "ANTHROPIC_BASE_URL": "http://localhost:8317",
    "ANTHROPIC_MODEL": "gpt-5.4",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "MiniMax-M2.7",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5.1",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "gpt-5.4"
  }
}
```

- `ANTHROPIC_AUTH_TOKEN`: local shared secret if you enabled authentication in the app
- `ANTHROPIC_BASE_URL`: local proxy base URL
- `ANTHROPIC_MODEL`: default primary model
- `ANTHROPIC_DEFAULT_HAIKU_MODEL`: model to use for Haiku-like routing
- `ANTHROPIC_DEFAULT_SONNET_MODEL`: model to use for Sonnet-like routing
- `ANTHROPIC_DEFAULT_OPUS_MODEL`: model to use for Opus-like routing

Use the exact model names returned by `http://localhost:8317/v1/models`.
The example values above are only examples and may differ from your local setup.

When a secret key is configured in the app, `ANTHROPIC_AUTH_TOKEN` must match that same secret.
Local proxy requests are expected to provide:

```http
Authorization: Bearer <secret-key>
```
```

Keep the rest of `README.md` unchanged.

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 - <<'PY'
from pathlib import Path
text = Path('/Users/mirage/go/src/ccproxy/README.md').read_text()
assert 'http://localhost:8317/v1/models' in text
assert 'curl http://localhost:8317/v1/models' in text
assert 'settings.json' in text
assert 'ANTHROPIC_MODEL' in text
assert 'ANTHROPIC_DEFAULT_HAIKU_MODEL' in text
assert 'ANTHROPIC_DEFAULT_SONNET_MODEL' in text
assert 'ANTHROPIC_DEFAULT_OPUS_MODEL' in text
assert 'Use the exact model names returned by `http://localhost:8317/v1/models`.' in text
PY`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add /Users/mirage/go/src/ccproxy/README.md
git commit -m "docs: add local proxy setup to README"
```

### Task 2: Add mirrored local proxy setup guidance to README.ko.md

**Files:**
- Modify: `README.ko.md`
- Test: `README.ko.md`

- [ ] **Step 1: Write the failing test**

```bash
python3 - <<'PY'
from pathlib import Path
text = Path('/Users/mirage/go/src/ccproxy/README.ko.md').read_text()
assert 'http://localhost:8317/v1/models' in text
assert 'curl http://localhost:8317/v1/models' in text
assert 'settings.json' in text
assert 'ANTHROPIC_MODEL' in text
assert 'ANTHROPIC_DEFAULT_HAIKU_MODEL' in text
assert 'ANTHROPIC_DEFAULT_SONNET_MODEL' in text
assert 'ANTHROPIC_DEFAULT_OPUS_MODEL' in text
assert '`/v1/models` 응답에 나온 정확한 모델 이름을 사용하세요.' in text
PY
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 - <<'PY'
from pathlib import Path
text = Path('/Users/mirage/go/src/ccproxy/README.ko.md').read_text()
assert 'http://localhost:8317/v1/models' in text
assert 'curl http://localhost:8317/v1/models' in text
assert 'settings.json' in text
assert 'ANTHROPIC_MODEL' in text
assert 'ANTHROPIC_DEFAULT_HAIKU_MODEL' in text
assert 'ANTHROPIC_DEFAULT_SONNET_MODEL' in text
assert 'ANTHROPIC_DEFAULT_OPUS_MODEL' in text
assert '`/v1/models` 응답에 나온 정확한 모델 이름을 사용하세요.' in text
PY`
Expected: FAIL because the current Korean README only documents `ANTHROPIC_AUTH_TOKEN` and `ANTHROPIC_BASE_URL` in the local proxy section.

- [ ] **Step 3: Write minimal implementation**

Replace the current `## 로컬 프록시 인증` section in `README.ko.md` with this content:

```md
## 로컬 프록시 인증

CCProxy는 로컬 프록시 요청에 대해 shared secret 검증을 적용할 수 있습니다.

로컬 프록시 base URL은 다음과 같습니다.

```text
http://localhost:8317
```

현재 로컬 프록시가 노출하는 모델 ID를 확인하려면 다음을 실행하세요.

```bash
curl http://localhost:8317/v1/models
```

여기서 반환된 모델 ID를 Claude Code 설정에 사용하면 됩니다.

예시 `settings.json`:

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "local-test",
    "ANTHROPIC_BASE_URL": "http://localhost:8317",
    "ANTHROPIC_MODEL": "gpt-5.4",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "MiniMax-M2.7",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5.1",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "gpt-5.4"
  }
}
```

- `ANTHROPIC_AUTH_TOKEN`: 앱에서 로컬 인증을 켰다면 그 shared secret
- `ANTHROPIC_BASE_URL`: 로컬 프록시 base URL
- `ANTHROPIC_MODEL`: 기본 주 모델
- `ANTHROPIC_DEFAULT_HAIKU_MODEL`: Haiku 계열 라우팅에 사용할 모델
- `ANTHROPIC_DEFAULT_SONNET_MODEL`: Sonnet 계열 라우팅에 사용할 모델
- `ANTHROPIC_DEFAULT_OPUS_MODEL`: Opus 계열 라우팅에 사용할 모델

`/v1/models` 응답에 나온 정확한 모델 이름을 사용하세요.
위 예시 값은 설명용 예시이며 로컬 환경에 따라 다를 수 있습니다.

앱에서 secret key를 설정한 경우 `ANTHROPIC_AUTH_TOKEN` 값도 그 secret과 같아야 합니다.
로컬 프록시 요청은 아래 헤더를 포함해야 합니다.

```http
Authorization: Bearer <secret-key>
```
```

Keep the rest of `README.ko.md` unchanged.

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 - <<'PY'
from pathlib import Path
text = Path('/Users/mirage/go/src/ccproxy/README.ko.md').read_text()
assert 'http://localhost:8317/v1/models' in text
assert 'curl http://localhost:8317/v1/models' in text
assert 'settings.json' in text
assert 'ANTHROPIC_MODEL' in text
assert 'ANTHROPIC_DEFAULT_HAIKU_MODEL' in text
assert 'ANTHROPIC_DEFAULT_SONNET_MODEL' in text
assert 'ANTHROPIC_DEFAULT_OPUS_MODEL' in text
assert '`/v1/models` 응답에 나온 정확한 모델 이름을 사용하세요.' in text
PY`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add /Users/mirage/go/src/ccproxy/README.ko.md
git commit -m "docs: add local proxy setup to Korean README"
```

### Task 3: Verify both README files together

**Files:**
- Verify: `README.md`
- Verify: `README.ko.md`

- [ ] **Step 1: Run combined README verification**

Run: `python3 - <<'PY'
from pathlib import Path
readme = Path('/Users/mirage/go/src/ccproxy/README.md').read_text()
readme_ko = Path('/Users/mirage/go/src/ccproxy/README.ko.md').read_text()
assert 'http://localhost:8317/v1/models' in readme
assert 'curl http://localhost:8317/v1/models' in readme
assert 'settings.json' in readme
assert 'ANTHROPIC_MODEL' in readme
assert 'ANTHROPIC_DEFAULT_HAIKU_MODEL' in readme
assert 'ANTHROPIC_DEFAULT_SONNET_MODEL' in readme
assert 'ANTHROPIC_DEFAULT_OPUS_MODEL' in readme
assert 'Use the exact model names returned by `http://localhost:8317/v1/models`.' in readme
assert 'shared secret' in readme
assert 'http://localhost:8317/v1/models' in readme_ko
assert 'curl http://localhost:8317/v1/models' in readme_ko
assert 'settings.json' in readme_ko
assert 'ANTHROPIC_MODEL' in readme_ko
assert 'ANTHROPIC_DEFAULT_HAIKU_MODEL' in readme_ko
assert 'ANTHROPIC_DEFAULT_SONNET_MODEL' in readme_ko
assert 'ANTHROPIC_DEFAULT_OPUS_MODEL' in readme_ko
assert '`/v1/models` 응답에 나온 정확한 모델 이름을 사용하세요.' in readme_ko
assert 'shared secret' in readme_ko
PY`
Expected: PASS

- [ ] **Step 2: Commit**

```bash
git add /Users/mirage/go/src/ccproxy/README.md /Users/mirage/go/src/ccproxy/README.ko.md
git commit -m "docs: document local proxy setup for Claude Code"
```

## Self-Review

- Spec coverage: Task 1 adds `/v1/models`, `settings.json`, env variable explanations, exact-model-name guidance, and auth-token note to `README.md`. Task 2 mirrors the same scope in `README.ko.md`. Task 3 verifies both files together.
- Placeholder scan: no TBD/TODO/fill-in-later text remains; each code-edit step contains exact replacement content and every verification step contains an exact command.
- Type consistency: endpoint paths, env variable names, and settings example values are identical across both tasks and match the approved design.
