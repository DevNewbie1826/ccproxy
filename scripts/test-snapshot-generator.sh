#!/bin/bash
# test-snapshot-generator.sh — Deterministic tests for the snapshot generator script.
# Uses environment variable overrides to run without live network access.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo -e "${RED}FAIL${NC}: $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

# Create fixture files for sources that succeed
cat > "$TMPDIR/models.json" << 'EOF'
{
    "claude": [
        {"id": "claude-sonnet-4", "object": "model", "created": 1700000000, "owned_by": "anthropic"}
    ],
    "codex-free": [
        {"id": "gpt-4o", "object": "model", "created": 1700000002, "owned_by": "openai"}
    ],
    "kimi": [
        {"id": "kimi-k2", "object": "model", "created": 1700000003, "owned_by": "moonshotai"}
    ],
    "xai": [
        {"id": "grok-4.5", "object": "model", "created": 1700000004, "owned_by": "xai"}
    ],
    "gemini": [
        {"id": "gemini-ignored", "object": "model", "created": 1700000005, "owned_by": "google"}
    ],
    "antigravity": [
        {"id": "antigravity-ignored", "object": "model", "created": 1700000006, "owned_by": "google"}
    ],
    "aistudio": [
        {"id": "aistudio-ignored", "object": "model", "created": 1700000007, "owned_by": "google"}
    ]
}
EOF

cat > "$TMPDIR/codex_client_models.json" << 'EOF'
{
    "models": [
        {"slug": "gpt-4o", "display_name": "GPT-4o Free"}
    ]
}
EOF

cat > "$TMPDIR/models_dev.json" << 'EOF'
{
    "anthropic": {
        "models": {
            "claude-sonnet-4": {"owned_by": "anthropic-dev"}
        }
    },
    "zai-coding-plan": {
        "models": {
            "glm-5": {"owned_by": "zhipu"}
        }
    },
    "opencode-go": {
        "models": {
            "test-model": {"owned_by": "opencode-go"}
        }
    },
    "moonshotai": {
        "models": {
            "kimi-k2-0905-preview": {"owned_by": "moonshotai"}
        }
    }
}
EOF

INVALID_URL="file:///nonexistent/path/to/fail.json"
MODELS_URL="file://$TMPDIR/models.json"
CODEX_URL="file://$TMPDIR/codex_client_models.json"
DEV_URL="file://$TMPDIR/models_dev.json"

extract_field() {
    local file="$1"
    local field="$2"
    if command -v python3 &>/dev/null; then
        python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2],''))" "$file" "$field"
    else
        swift -e "import Foundation; let d=try Data(contentsOf:URL(fileURLWithPath:\"$file\")); let j=try JSONSerialization.jsonObject(with:d) as![String:Any]; print(j[\"$field\"]??\"\")" 2>/dev/null
    fi
}

run_generator() {
    local output_path="$1"
    local models_url="$2"
    local codex_url="$3"
    local dev_url="$4"

    set +e
    MODEL_CATALOG_OUTPUT_PATH="$output_path" \
    MODEL_CATALOG_MODELS_JSON_URL="$models_url" \
    MODEL_CATALOG_CODEX_CLIENT_URL="$codex_url" \
    MODEL_CATALOG_MODELS_DEV_URL="$dev_url" \
    swift "$PROJECT_DIR/scripts/generate-model-catalog-snapshot.swift" > /dev/null 2>&1
    LAST_EXIT_CODE=$?
    set -e
}

# ---- Test 1: All sources fail + valid existing snapshot => exit 0, file unchanged ----

echo ""
echo "=== Test 1: All sources fail + valid existing snapshot => exit 0, preserved ==="

OUTPUT1="$TMPDIR/test1-snapshot.json"
cat > "$OUTPUT1" << 'SNAPSHOTEOT'
{"generatedAt":"2026-01-01T00:00:00Z","providerModels":{"claude":[{"created":1,"displayName":null,"id":"claude-sonnet-4","object":"model","ownedBy":"anthropic","supplementalMetadata":{},"tier":null}]},"schemaVersion":"2","sources":["models.json","models.dev"]}
SNAPSHOTEOT

EXISTING_HASH=$(shasum "$OUTPUT1" | awk '{print $1}')

run_generator "$OUTPUT1" "$INVALID_URL" "$INVALID_URL" "$INVALID_URL"
EXIT_CODE=$LAST_EXIT_CODE

NEW_HASH=$(shasum "$OUTPUT1" | awk '{print $1}')

if [ $EXIT_CODE -ne 0 ]; then
    fail "Test 1: exit $EXIT_CODE (expected 0) when all sources fail with valid existing snapshot"
elif [ "$EXISTING_HASH" != "$NEW_HASH" ]; then
    fail "Test 1: snapshot was modified when it should be preserved"
else
    pass "Test 1: exit 0 and file preserved when all sources fail with valid existing snapshot"
fi

# ---- Test 2: All sources fail + malformed existing snapshot => exit non-zero ----

echo ""
echo "=== Test 2: All sources fail + malformed existing snapshot => exit non-zero ==="

OUTPUT2="$TMPDIR/test2-snapshot.json"
echo "{not valid json" > "$OUTPUT2"

run_generator "$OUTPUT2" "$INVALID_URL" "$INVALID_URL" "$INVALID_URL"
EXIT_CODE=$LAST_EXIT_CODE

if [ $EXIT_CODE -ne 0 ]; then
    pass "Test 2: script exited non-zero ($EXIT_CODE) with malformed existing snapshot"
else
    fail "Test 2: script exited 0 with malformed existing snapshot (expected non-zero)"
fi

# ---- Test 3: All sources fail + empty-providerModels existing snapshot => exit non-zero ----

echo ""
echo "=== Test 3: All sources fail + empty-providerModels snapshot => exit non-zero ==="

OUTPUT3="$TMPDIR/test3-snapshot.json"
cat > "$OUTPUT3" << 'SNAPSHOTEOT'
{"generatedAt":"2026-01-01T00:00:00Z","providerModels":{},"schemaVersion":"2","sources":["models.json","models.dev"]}
SNAPSHOTEOT

run_generator "$OUTPUT3" "$INVALID_URL" "$INVALID_URL" "$INVALID_URL"
EXIT_CODE=$LAST_EXIT_CODE

if [ $EXIT_CODE -ne 0 ]; then
    pass "Test 3: script exited non-zero ($EXIT_CODE) with empty-providerModels snapshot"
else
    fail "Test 3: script exited 0 with empty-providerModels snapshot (expected non-zero)"
fi

# ---- Test 4: All sources fail + valid-schema but unknown-sources snapshot => exit non-zero ----

echo ""
echo "=== Test 4: All sources fail + unknown-sources snapshot => exit non-zero ==="

OUTPUT4="$TMPDIR/test4-snapshot.json"
cat > "$OUTPUT4" << 'SNAPSHOTEOT'
{"generatedAt":"2026-01-01T00:00:00Z","providerModels":{"claude":[{"created":1,"displayName":null,"id":"claude-sonnet-4","object":"model","ownedBy":"anthropic","supplementalMetadata":{},"tier":null}]},"schemaVersion":"2","sources":["unknown-source"]}
SNAPSHOTEOT

run_generator "$OUTPUT4" "$INVALID_URL" "$INVALID_URL" "$INVALID_URL"
EXIT_CODE=$LAST_EXIT_CODE

if [ $EXIT_CODE -ne 0 ]; then
    pass "Test 4: script exited non-zero ($EXIT_CODE) with unknown-sources snapshot"
else
    fail "Test 4: script exited 0 with unknown-sources snapshot (expected non-zero)"
fi

# ---- Test 5: Repeated run with same inputs => byte-for-byte identical output ----

echo ""
echo "=== Test 5: Repeated run with same inputs => byte-for-byte identical ==="

OUTPUT5="$TMPDIR/test5-snapshot.json"

run_generator "$OUTPUT5" "$MODELS_URL" "$CODEX_URL" "$DEV_URL"
EXIT_CODE=$LAST_EXIT_CODE

if [ $EXIT_CODE -ne 0 ]; then
    fail "Test 5: first run failed with exit code $EXIT_CODE"
else
    FIRST_HASH=$(shasum "$OUTPUT5" | awk '{print $1}')

    run_generator "$OUTPUT5" "$MODELS_URL" "$CODEX_URL" "$DEV_URL"
    EXIT_CODE=$LAST_EXIT_CODE

    if [ $EXIT_CODE -ne 0 ]; then
        fail "Test 5: second run failed with exit code $EXIT_CODE"
    else
        SECOND_HASH=$(shasum "$OUTPUT5" | awk '{print $1}')
        if [ "$FIRST_HASH" = "$SECOND_HASH" ]; then
            pass "Test 5: repeated run produces byte-for-byte identical output"
        else
            fail "Test 5: repeated run produced different output (hash changed)"
        fi
    fi
fi

# ---- Test 6: generatedAt preserved when semantic content unchanged ----

echo ""
echo "=== Test 6: generatedAt preserved when content unchanged ==="

OUTPUT6="$TMPDIR/test6-snapshot.json"

run_generator "$OUTPUT6" "$MODELS_URL" "$CODEX_URL" "$DEV_URL"
EXIT_CODE_FIRST=$LAST_EXIT_CODE

if [ $EXIT_CODE_FIRST -ne 0 ]; then
    fail "Test 6: first run failed with exit code $EXIT_CODE_FIRST"
else
    FIRST_GENERATED_AT=$(extract_field "$OUTPUT6" "generatedAt")

    # Ensure time has passed so wall-clock would differ without preservation
    sleep 2

    run_generator "$OUTPUT6" "$MODELS_URL" "$CODEX_URL" "$DEV_URL"
    EXIT_CODE_SECOND=$LAST_EXIT_CODE

    if [ $EXIT_CODE_SECOND -ne 0 ]; then
        fail "Test 6: second run failed with exit code $EXIT_CODE_SECOND"
    else
        SECOND_GENERATED_AT=$(extract_field "$OUTPUT6" "generatedAt")

        if [ "$FIRST_GENERATED_AT" = "$SECOND_GENERATED_AT" ]; then
            pass "Test 6: generatedAt preserved across runs with identical content (exit codes: $EXIT_CODE_FIRST, $EXIT_CODE_SECOND)"
        else
            fail "Test 6: generatedAt changed: first=$FIRST_GENERATED_AT second=$SECOND_GENERATED_AT"
        fi
    fi
fi

# ---- Test 7: Sources succeed produces valid snapshot with non-empty providerModels ----

echo ""
echo "=== Test 7: Sources succeed => valid snapshot with non-empty providerModels ==="

OUTPUT7="$TMPDIR/test7-snapshot.json"

run_generator "$OUTPUT7" "$MODELS_URL" "$CODEX_URL" "$DEV_URL"
EXIT_CODE=$LAST_EXIT_CODE

if [ $EXIT_CODE -ne 0 ]; then
    fail "Test 7: script failed with exit code $EXIT_CODE"
elif [ ! -f "$OUTPUT7" ]; then
    fail "Test 7: output file missing"
else
    if command -v python3 &>/dev/null; then
        if python3 -m json.tool "$OUTPUT7" > /dev/null 2>&1; then
            PM_COUNT=$(python3 -c "import json; d=json.load(open('$OUTPUT7')); print(len(d.get('providerModels',{})))" 2>/dev/null || echo "0")
            if [ "$PM_COUNT" -gt 0 ]; then
                HAS_KNOWN=$(python3 -c "
import json
d=json.load(open('$OUTPUT7'))
sources=d.get('sources',[])
known={'models.json','codex_client_models.json','models.dev'}
print('yes' if any(s in known for s in sources) else 'no')
" 2>/dev/null || echo "no")
                if [ "$HAS_KNOWN" = "yes" ]; then
                    pass "Test 7: sources succeed produced valid snapshot with $PM_COUNT providers and known source metadata"
                else
                    fail "Test 7: snapshot missing known source identifiers"
                fi
            else
                fail "Test 7: snapshot has empty providerModels"
            fi
        else
            fail "Test 7: output is not valid JSON"
        fi
    else
        VALID=$(swift -e "
import Foundation
let d=try Data(contentsOf:URL(fileURLWithPath:\"$OUTPUT7\"))
let j=try JSONSerialization.jsonObject(with:d) as![String:Any]
let pm=j[\"providerModels\"] as?[String:Any] ?? [:]
let sources=j[\"sources\"] as?[String] ?? []
let known:Set<String>=[\"models.json\",\"codex_client_models.json\",\"models.dev\"]
print(pm.isEmpty ? \"empty\" : \"\\(pm.count)\")
" 2>/dev/null || echo "error")
        if [ "$VALID" != "empty" ] && [ "$VALID" != "error" ]; then
            pass "Test 7: sources succeed produced valid snapshot with $VALID providers"
        else
            fail "Test 7: snapshot validation failed: $VALID"
        fi
    fi
fi

# ---- Test 8: All sources fail + no existing snapshot => exit non-zero ----

echo ""
echo "=== Test 8: All sources fail + no existing snapshot => exit non-zero ==="

OUTPUT8="$TMPDIR/test8-snapshot.json"
# Do NOT create the file

run_generator "$OUTPUT8" "$INVALID_URL" "$INVALID_URL" "$INVALID_URL"
EXIT_CODE=$LAST_EXIT_CODE

if [ $EXIT_CODE -ne 0 ]; then
    pass "Test 8: script exited non-zero ($EXIT_CODE) with no existing snapshot and all sources failed"
else
    fail "Test 8: script exited 0 with no existing snapshot (expected non-zero)"
fi

# ---- Test 9: Existing snapshot with model entries missing required fields => exit non-zero ----

echo ""
echo "=== Test 9: Existing snapshot with model entries missing required fields => exit non-zero ==="

OUTPUT9="$TMPDIR/test9-snapshot.json"
cat > "$OUTPUT9" << 'SNAPSHOTEOT'
{
    "generatedAt": "2026-01-01T00:00:00Z",
    "providerModels": {
        "claude": [
            {"object": "model", "ownedBy": "anthropic", "supplementalMetadata": {}}
        ]
    },
    "schemaVersion": "2",
    "sources": ["models.json", "models.dev"]
}
SNAPSHOTEOT

run_generator "$OUTPUT9" "$INVALID_URL" "$INVALID_URL" "$INVALID_URL"
EXIT_CODE=$LAST_EXIT_CODE

if [ $EXIT_CODE -ne 0 ]; then
    pass "Test 9: script exited non-zero ($EXIT_CODE) with model entries missing 'id' field (Codable decode fails)"
else
    fail "Test 9: script exited 0 with missing model 'id' field (expected non-zero)"
fi

# ---- Test 10: Existing snapshot with valid structure but all providers have empty model arrays => exit non-zero ----

echo ""
echo "=== Test 10: Existing snapshot, all providers have empty model arrays => exit non-zero ==="

OUTPUT10="$TMPDIR/test10-snapshot.json"
cat > "$OUTPUT10" << 'SNAPSHOTEOT'
{
    "generatedAt": "2026-01-01T00:00:00Z",
    "providerModels": {
        "claude": []
    },
    "schemaVersion": "2",
    "sources": ["models.json", "models.dev"]
}
SNAPSHOTEOT

run_generator "$OUTPUT10" "$INVALID_URL" "$INVALID_URL" "$INVALID_URL"
EXIT_CODE=$LAST_EXIT_CODE

if [ $EXIT_CODE -ne 0 ]; then
    pass "Test 10: script exited non-zero ($EXIT_CODE) with all providers having empty model arrays"
else
    fail "Test 10: script exited 0 with empty model arrays (expected non-zero)"
fi

# ---- Test 11: Generated output is fully Codable-decodable as CatalogSnapshot ----

echo ""
echo "=== Test 11: Generated output is fully Codable-decodable ==="

OUTPUT11="$TMPDIR/test11-snapshot.json"

run_generator "$OUTPUT11" "$MODELS_URL" "$CODEX_URL" "$DEV_URL"
EXIT_CODE=$LAST_EXIT_CODE

if [ $EXIT_CODE -ne 0 ]; then
    fail "Test 11: first run failed with exit code $EXIT_CODE"
else
    DECODE_CHECK=$(swift -e "
import Foundation
struct CE: Decodable { let id: String; let object: String; let created: Int; let ownedBy: String; let displayName: String?; let tier: String?; let supplementalMetadata: [String: String] }
struct CS: Decodable { let schemaVersion: String; let generatedAt: String; let sources: [String]; let providerModels: [String: [CE]] }
let d = try Data(contentsOf: URL(fileURLWithPath: \"$OUTPUT11\"))
let s = try JSONDecoder().decode(CS.self, from: d)
let totalModels = s.providerModels.values.reduce(0) { \$0 + \$1.count }
let allIdsValid = s.providerModels.values.flatMap { \$0 }.allSatisfy { !\$0.id.isEmpty }
print(s.providerModels.isEmpty ? \"empty\" : \"\\(s.providerModels.count)-\\(totalModels)-\\(allIdsValid)\")
" 2>/dev/null || echo "decode-error")

    if [[ "$DECODE_CHECK" == *"decode-error"* ]] || [[ "$DECODE_CHECK" == *"empty"* ]]; then
        fail "Test 11: generated snapshot failed Codable decode: $DECODE_CHECK"
    elif [[ "$DECODE_CHECK" == *"-true" ]]; then
        PASS_COUNT_DETAILS="$DECODE_CHECK"
        pass "Test 11: generated snapshot fully Codable-decodable ($PASS_COUNT_DETAILS, all model IDs non-empty)"
    else
        if [[ "$DECODE_CHECK" == *"-false" ]]; then
            fail "Test 11: generated snapshot decoded but contains empty model IDs"
        else
            pass "Test 11: generated snapshot Codable-decodable with providers ($DECODE_CHECK)"
        fi
    fi
fi

# ---- Test 12: Existing snapshot with wrong type for 'created' field => exit non-zero ----

echo ""
echo "=== Test 12: Existing snapshot with wrong type for 'created' field => exit non-zero ==="

OUTPUT12="$TMPDIR/test12-snapshot.json"
cat > "$OUTPUT12" << 'SNAPSHOTEOT'
{
    "generatedAt": "2026-01-01T00:00:00Z",
    "providerModels": {
        "claude": [
            {"id": "claude-sonnet-4", "object": "model", "created": "not-an-int", "ownedBy": "anthropic", "supplementalMetadata": {}}
        ]
    },
    "schemaVersion": "2",
    "sources": ["models.json", "models.dev"]
}
SNAPSHOTEOT

run_generator "$OUTPUT12" "$INVALID_URL" "$INVALID_URL" "$INVALID_URL"
EXIT_CODE=$LAST_EXIT_CODE

if [ $EXIT_CODE -ne 0 ]; then
    pass "Test 12: script exited non-zero ($EXIT_CODE) with wrong type for 'created' field (Codable decode fails)"
else
    fail "Test 12: script exited 0 with wrong 'created' type (expected non-zero)"
fi

# ---- Test 13: Existing snapshot with one valid provider and one empty provider => exit non-zero ----

echo ""
echo "=== Test 13: Existing snapshot with mixed valid/empty providers => exit non-zero ==="

OUTPUT13="$TMPDIR/test13-snapshot.json"
cat > "$OUTPUT13" << 'SNAPSHOTEOT'
{
    "generatedAt": "2026-01-01T00:00:00Z",
    "providerModels": {
        "claude": [
            {"id": "claude-sonnet-4", "object": "model", "created": 1, "ownedBy": "anthropic", "supplementalMetadata": {}, "tier": null}
        ],
        "codex": []
    },
    "schemaVersion": "2",
    "sources": ["models.json", "models.dev"]
}
SNAPSHOTEOT

run_generator "$OUTPUT13" "$INVALID_URL" "$INVALID_URL" "$INVALID_URL"
EXIT_CODE=$LAST_EXIT_CODE

if [ $EXIT_CODE -ne 0 ]; then
    pass "Test 13: script exited non-zero ($EXIT_CODE) with one valid provider and one empty provider"
else
    fail "Test 13: script exited 0 with mixed valid/empty providers (expected non-zero)"
fi

# ---- Test 14: Existing snapshot with one valid provider and one provider with empty model ID => exit non-zero ----

echo ""
echo "=== Test 14: Existing snapshot with mixed valid/empty-ID providers => exit non-zero ==="

OUTPUT14="$TMPDIR/test14-snapshot.json"
cat > "$OUTPUT14" << 'SNAPSHOTEOT'
{
    "generatedAt": "2026-01-01T00:00:00Z",
    "providerModels": {
        "claude": [
            {"id": "claude-sonnet-4", "object": "model", "created": 1, "ownedBy": "anthropic", "supplementalMetadata": {}, "tier": null}
        ],
        "codex": [
            {"id": "", "object": "model", "created": 1, "ownedBy": "openai", "supplementalMetadata": {}, "tier": null}
        ]
    },
    "schemaVersion": "2",
    "sources": ["models.json", "models.dev"]
}
SNAPSHOTEOT

run_generator "$OUTPUT14" "$INVALID_URL" "$INVALID_URL" "$INVALID_URL"
EXIT_CODE=$LAST_EXIT_CODE

if [ $EXIT_CODE -ne 0 ]; then
    pass "Test 14: script exited non-zero ($EXIT_CODE) with one valid provider and one provider with empty model ID"
else
    fail "Test 14: script exited 0 with mixed valid/empty-ID providers (expected non-zero)"
fi

# ---- Test 15: All sources fail + old-schema "1" existing snapshot => exit non-zero ----

echo ""
echo "=== Test 15: All sources fail + old-schema \"1\" snapshot => exit non-zero ==="

OUTPUT15="$TMPDIR/test15-snapshot.json"
cat > "$OUTPUT15" << 'SNAPSHOTEOT'
{
    "generatedAt": "2026-01-01T00:00:00Z",
    "providerModels": {
        "claude": [
            {"id": "claude-sonnet-4", "object": "model", "created": 1, "ownedBy": "anthropic", "supplementalMetadata": {}, "tier": null}
        ],
        "codex": [
            {"id": "gpt-4o", "object": "model", "created": 2, "ownedBy": "openai", "supplementalMetadata": {}, "tier": null}
        ]
    },
    "schemaVersion": "1",
    "sources": ["models.json", "codex_client_models.json", "models.dev"]
}
SNAPSHOTEOT

run_generator "$OUTPUT15" "$INVALID_URL" "$INVALID_URL" "$INVALID_URL"
EXIT_CODE=$LAST_EXIT_CODE

if [ $EXIT_CODE -ne 0 ]; then
    pass "Test 15: script exited non-zero ($EXIT_CODE) with old-schema '1' snapshot (schema mismatch rejected)"
else
    fail "Test 15: script exited 0 with old-schema '1' snapshot (expected non-zero — old schema must be rejected)"
fi

# ---- Test 16: Primary provider policy includes kimi/xai and excludes unmapped/removed secondary providers ----

echo ""
echo "=== Test 16: Primary policy includes kimi/xai and excludes unmapped/removed secondary providers ==="

OUTPUT16="$TMPDIR/test16-snapshot.json"

run_generator "$OUTPUT16" "$MODELS_URL" "$CODEX_URL" "$DEV_URL"
EXIT_CODE=$LAST_EXIT_CODE

if [ $EXIT_CODE -ne 0 ]; then
    fail "Test 16: script failed with exit code $EXIT_CODE"
elif [ ! -f "$OUTPUT16" ]; then
    fail "Test 16: output file missing"
elif command -v python3 &>/dev/null; then
    POLICY_CHECK=$(python3 - "$OUTPUT16" << 'PY' 2>/dev/null || echo "python-error"
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    snapshot = json.load(handle)

provider_models = snapshot.get("providerModels", {})
all_ids = {
    entry.get("id")
    for entries in provider_models.values()
    for entry in entries
}

checks = {
    "schema-v2": snapshot.get("schemaVersion") == "2",
    "kimi-provider": "kimi" in provider_models,
    "kimi-bare-id": any(entry.get("id") == "kimi-k2" for entry in provider_models.get("kimi", [])),
    "xai-provider": "xai" in provider_models,
    "xai-bare-id": any(entry.get("id") == "grok-4.5" for entry in provider_models.get("xai", [])),
    "moonshot-secondary-ignored": "kimi-k2-0905-preview" not in all_ids,
    "gemini-excluded": "gemini" not in provider_models and "gemini-ignored" not in all_ids,
    "antigravity-excluded": "antigravity" not in provider_models and "antigravity-ignored" not in all_ids,
    "aistudio-excluded": "aistudio" not in provider_models and "aistudio-ignored" not in all_ids,
}

failed = [name for name, ok in checks.items() if not ok]
if failed:
    print("failed:" + ",".join(failed))
    sys.exit(1)

print("ok:kimi,xai primary providers included; moonshotai/gemini/antigravity/aistudio excluded")
PY
)
    if [[ "$POLICY_CHECK" == ok:* ]]; then
        pass "Test 16: $POLICY_CHECK"
    else
        fail "Test 16: policy assertions failed ($POLICY_CHECK)"
    fi
else
    POLICY_CHECK=$(swift -e "
import Foundation
let data = try Data(contentsOf: URL(fileURLWithPath: \"$OUTPUT16\"))
let snapshot = try JSONSerialization.jsonObject(with: data) as! [String: Any]
let providerModels = snapshot[\"providerModels\"] as? [String: [[String: Any]]] ?? [:]
let allIds = Set(providerModels.values.flatMap { $0 }.compactMap { $0[\"id\"] as? String })
let checks = [
    snapshot[\"schemaVersion\"] as? String == \"2\",
    providerModels[\"kimi\"]?.contains { $0[\"id\"] as? String == \"kimi-k2\" } == true,
    providerModels[\"xai\"]?.contains { $0[\"id\"] as? String == \"grok-4.5\" } == true,
    !allIds.contains(\"kimi-k2-0905-preview\"),
    providerModels[\"gemini\"] == nil && !allIds.contains(\"gemini-ignored\"),
    providerModels[\"antigravity\"] == nil && !allIds.contains(\"antigravity-ignored\"),
    providerModels[\"aistudio\"] == nil && !allIds.contains(\"aistudio-ignored\")
]
print(checks.allSatisfy { $0 } ? \"ok\" : \"failed\")
" 2>/dev/null || echo "swift-error")
    if [ "$POLICY_CHECK" = "ok" ]; then
        pass "Test 16: kimi/xai primary providers included; moonshotai/gemini/antigravity/aistudio excluded"
    else
        fail "Test 16: policy assertions failed ($POLICY_CHECK)"
    fi
fi

# ---- Summary ----

echo ""
echo "========================================="
echo -e "Results: ${GREEN}$PASS_COUNT passed${NC}, ${RED}$FAIL_COUNT failed${NC}"
echo "========================================="

if [ $FAIL_COUNT -gt 0 ]; then
    exit 1
fi
