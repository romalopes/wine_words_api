#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
output=$(cd "$ROOT" && env -u DATABASE_URL -u AUDIT_DATABASE_URL ./scripts/security_audit.sh)

grep -q 'PASS: no runtime .env files are tracked' <<< "$output"
grep -q 'PASS: .env.production is ignored' <<< "$output"
grep -q 'WARN: live database checks skipped' <<< "$output"
grep -q 'Summary: 0 failure(s)' <<< "$output"

echo 'Security audit script regression test passed.'