# Local Proxy README Setup Design

## Summary

Add practical Claude Code local proxy setup guidance to both README files so users can discover models from the local proxy and map them into `settings.json` correctly.

The current README content explains the local proxy base URL and shared-secret authentication, but it does not yet show how to inspect the available model IDs or how to translate those IDs into Claude Code environment settings. This design fills that documentation gap without changing application behavior.

## Goals

- Document the local proxy model discovery endpoint: `http://localhost:8317/v1/models`
- Show a practical `settings.json` example for Claude Code using the local proxy
- Explain the meaning of `ANTHROPIC_MODEL`, `ANTHROPIC_DEFAULT_HAIKU_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`, and `ANTHROPIC_DEFAULT_OPUS_MODEL`
- Make it explicit that model names must exactly match values returned by `/v1/models`
- Mirror the guidance in both `README.md` and `README.ko.md`

## Non-goals

- Changing application runtime behavior
- Adding new config files to the repository
- Documenting provider-specific tuning beyond the example values
- Expanding into full troubleshooting or advanced routing strategy docs

## Current State

### Confirmed repository facts

- `README.md` already documents the local proxy base URL `http://localhost:8317` and a minimal JSON snippet with `ANTHROPIC_AUTH_TOKEN` and `ANTHROPIC_BASE_URL`.
- `README.ko.md` mirrors the same minimal local proxy authentication guidance in Korean.
- Neither README currently documents `http://localhost:8317/v1/models`.
- Neither README currently shows a Claude Code `settings.json` example with model mapping fields.
- The installation section was recently expanded, so the cleanest place for this new content is the existing local proxy section rather than the installation section.

## Recommended Approach

Extend the existing local proxy section in each README instead of creating a new top-level section.

Why this approach:
- The new content is conceptually part of local proxy usage, not installation.
- Users already looking at the authentication section are the same users who need the `settings.json` example.
- It keeps the README structure compact and avoids creating a separate section that would duplicate context.

## File-by-file Design

### 1. `README.md`

Expand the existing `## Local proxy authentication` section into a short setup guide for Claude Code.

Planned content order:
1. Keep the explanation that CCProxy can enforce a shared secret.
2. Keep the base URL example using `http://localhost:8317`.
3. Add a short model discovery subsection showing:
   - endpoint `http://localhost:8317/v1/models`
   - a `curl` example to inspect available model IDs
4. Add a `settings.json` example using real sample values:

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

5. Add short bullet explanations for each env variable.
6. Add a note that the model names must exactly match the IDs returned by `/v1/models`.
7. Keep the shared-secret note explaining that `ANTHROPIC_AUTH_TOKEN` must match the secret configured in the app when local auth is enabled.

### 2. `README.ko.md`

Mirror the English content in Korean with the same order and structure.

Planned Korean content:
- local proxy endpoint explanation
- `/v1/models` model discovery example
- same `settings.json` example values
- Korean explanations for each env field
- explicit note that model names must exactly match `/v1/models` output
- Korean shared-secret note aligned with the app behavior

## Content Rules

To keep the README practical and scoped:

- Use one concrete `settings.json` example with real sample model names.
- Immediately follow the example with a note that these are only examples and the user must use exact IDs returned by `http://localhost:8317/v1/models`.
- Do not promise that the example model names will exist in every setup.
- Do not add speculative provider-routing theory or extended troubleshooting.
- Do not document unsupported endpoints beyond `/v1/models`.

## Proposed README Structure Change

### English

Keep the heading `## Local proxy authentication`, but reshape the section into:
- short intro
- base URL snippet
- model discovery snippet
- `settings.json` example
- env field explanation bullets
- auth token / shared secret note

### Korean

Keep the heading `## 로컬 프록시 인증`, but mirror the same structure.

## Example Guidance Details

### Model discovery example

Planned command:

```bash
curl http://localhost:8317/v1/models
```

Purpose:
- lets the user inspect the exact model IDs exposed by the local proxy
- gives the source of truth for the values used in `ANTHROPIC_MODEL` and `ANTHROPIC_DEFAULT_*`

### Env field explanations

The README should briefly explain:
- `ANTHROPIC_AUTH_TOKEN`: local shared secret if enabled in the app
- `ANTHROPIC_BASE_URL`: local proxy base URL
- `ANTHROPIC_MODEL`: default primary model
- `ANTHROPIC_DEFAULT_HAIKU_MODEL`: model used for Haiku-like route
- `ANTHROPIC_DEFAULT_SONNET_MODEL`: model used for Sonnet-like route
- `ANTHROPIC_DEFAULT_OPUS_MODEL`: model used for Opus-like route

### Accuracy note

Add an explicit warning such as:
- Use the exact model names returned by `http://localhost:8317/v1/models`.
- If local authentication is enabled in CCProxy, the token in `settings.json` must match the secret configured in the app.

## Testing and Verification

After implementation, verify:

1. `README.md` contains:
   - `http://localhost:8317/v1/models`
   - `settings.json`
   - `ANTHROPIC_MODEL`
   - `ANTHROPIC_DEFAULT_HAIKU_MODEL`
   - `ANTHROPIC_DEFAULT_SONNET_MODEL`
   - `ANTHROPIC_DEFAULT_OPUS_MODEL`
2. `README.ko.md` contains the same endpoint and env variable names
3. Both README files explicitly say model names must match `/v1/models` output
4. Both README files retain the local auth/shared-secret guidance

## Scope Boundaries

This work is limited to README documentation only.

It should not expand into:
- app code changes
- CLI integration changes
- release metadata changes
- full Claude Code onboarding documentation outside the local proxy setup flow

## Final Decision

Proceed by extending the existing local proxy sections in `README.md` and `README.ko.md` with a concise Claude Code setup guide that includes `/v1/models` discovery, a `settings.json` example, env variable explanations, and an explicit exact-model-name note.