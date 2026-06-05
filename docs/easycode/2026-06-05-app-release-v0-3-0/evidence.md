# App Release v0.3.0 Evidence

## Internal Evidence

- Explorer checked the current repository release process and version state.
- Current latest published release evidence:
  - `appcast.xml` currently contains `Version 0.2.0`, short version `0.2.0`, Sparkle build `12`, and release asset URL for `v0.2.0`.
  - Local tag evidence showed `v0.2.0` at commit `efb683c...` and `v0.1.10` at commit `458eb30...`.
- Current main evidence:
  - Local `main` is at merge commit `70e3b9b...`, which includes the OpenCode Go + external catalog feature work.
  - The prior feature final review recorded PASS and verification with 243 tests / 1 skipped / 0 failures plus build/release checks.
- Release tooling evidence:
  - `Makefile` defines `release`, `sparkle-archive`, `test`, `build`, and `backend-version` targets.
  - `create-app-bundle.sh` builds the app, injects `APP_VERSION` and `APP_BUILD_NUMBER` into the bundle Info.plist, copies resources, and signs with Developer ID or ad-hoc fallback.
  - `scripts/generate-sparkle-appcast.sh` signs the archive with Sparkle `sign_update` using `SPARKLE_ED_KEY_FILE` and writes `appcast.xml` with release metadata.
  - `scripts/update-cli-proxy-api.sh` is the repository-owned backend update workflow.
  - `src/Info.plist` contains Sparkle configuration and placeholder version values overwritten by release tooling.
- Prior release workflow evidence:
  - `docs/easycode/2026-06-04-app-release-v0-2-0/spec.md`, `plan.md`, `evidence.md`, and `final-review.md` document the successful `v0.2.0` / build `12` release pattern.
  - The prior release excluded x86_64 artifacts and used arm64-only publication.
- Git hygiene evidence:
  - The root checkout has a pre-existing unrelated `.gitignore` dirty change that must remain untouched.

## External Evidence

- No external web evidence was needed for the spec.
- GitHub/Sparkle publication behavior is based on repository scripts and prior release artifacts.

## Checked Scope

- `Makefile`
- `create-app-bundle.sh`
- `appcast.xml`
- `src/Info.plist`
- `src/Package.swift`
- `scripts/generate-sparkle-appcast.sh`
- `scripts/update-cli-proxy-api.sh` as referenced release workflow
- `.gitignore`
- local git refs for `main`, `v0.2.0`, and `v0.1.10`
- prior release workflow artifacts for `v0.2.0` and `v0.1.10`
- prior OpenCode Go/catalog workflow artifacts and final review
- `README.md` release/update references

## Unchecked Scope

- Live `gh release` and remote tag absence for `v0.3.0`; this must be checked during plan/execute close to publication.
- Current `SPARKLE_ED_KEY_FILE` availability/readability; this must be checked during execute without exposing the key.
- Whether a newer CLIProxyAPI release exists and validates; this must be checked during execute using repository tooling.
- Actual post-spec baseline command outputs for `make backend-version`, `make test`, and `make build`; these must be captured in the isolated worktree.

## Unresolved Uncertainty

- Whether the CLIProxyAPI backend will be updated in this release depends on live repository update tooling results.
- Whether release signing uses Developer ID or ad-hoc signing depends on local signing identity availability; Sparkle archive signing still requires the EdDSA key path.
- Publication is blocked if `SPARKLE_ED_KEY_FILE` is unavailable or unsafe.
