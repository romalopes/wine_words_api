#!/usr/bin/env bash
# Repository and PostgreSQL security checks. This script never prints a
# database URL or password. Supply DATABASE_URL (or AUDIT_DATABASE_URL) to run
# the live database checks against a deployed environment.
# AUDIT_DATABASE_URL="$DATABASE_URL" ./scripts/security_audit.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0
warnings=0

pass() { printf 'PASS: %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*"; warnings=$((warnings + 1)); }
fail() { printf 'FAIL: %s\n' "$*"; failures=$((failures + 1)); }

cd "$ROOT" || exit 1

tracked_env=$(git ls-files | grep -E '(^|/)\.env($|\.)' | grep -vE '(^|/)\.env\.example$' || true)
if [[ -z "$tracked_env" ]]; then
  pass "no runtime .env files are tracked"
else
  fail "runtime environment files are tracked: $(printf '%s' "$tracked_env" | tr '\n' ' ')"
fi

tracked_secret_files=$(git grep -InE 'postgres(ql)?://[^[:space:]/:$<{]+:[^[:space:]@/$<{]+@[^[:space:]/]*(neon\.tech|render\.com|supabase\.co|amazonaws\.com)' -- . \
  ':(exclude).env.example' ':(exclude)docs/**' ':(exclude)scripts/tests/**' 2>/dev/null \
  | grep -vE 'postgres(ql)?://(user:password|fake:fake)@|ep-xxx\.|db\.xxx\.' \
  | cut -d: -f1 | sort -u || true)
if [[ -z "$tracked_secret_files" ]]; then
  pass "no credential-bearing PostgreSQL URL was found in tracked application files"
else
  fail "possible PostgreSQL credentials found in tracked files: $(printf '%s' "$tracked_secret_files" | tr '\n' ' ')"
fi

if git check-ignore -q .env.production 2>/dev/null; then
  pass ".env.production is ignored"
else
  warn ".env.production is not present or is not ignored"
fi

if git check-ignore -q .env.development 2>/dev/null; then
  pass ".env.development is ignored"
else
  warn ".env.development is not present or is not ignored"
fi


if grep -q 'fromDatabase:' render.yaml 2>/dev/null; then
  pass "Render injects DATABASE_URL from a server-side database resource"
else
  warn "Render DATABASE_URL injection was not found"
fi

db_url="${AUDIT_DATABASE_URL:-${DATABASE_URL:-}}"
if [[ -z "$db_url" ]]; then
  warn "live database checks skipped; set AUDIT_DATABASE_URL or DATABASE_URL"
else
  if [[ "$db_url" == *"sslmode=require"* || "$db_url" == *"sslmode=verify-ca"* || "$db_url" == *"sslmode=verify-full"* ]]; then
    pass "database URL requires TLS"
  elif [[ "$db_url" == *"localhost"* || "$db_url" == postgresql:///* || "$db_url" == postgres:///* ]]; then
    warn "local database URL does not require TLS"
  else
    fail "remote database URL does not explicitly require or verify TLS"
  fi

  if ! command -v psql >/dev/null 2>&1; then
    fail "psql is required for live database checks"
  else
    role_row=$(psql "$db_url" -XAtqc \
      "SELECT current_user, rolsuper, rolcreaterole, rolcreatedb, rolreplication, rolbypassrls FROM pg_roles WHERE rolname = current_user" \
      2>/dev/null || true)
    if [[ -z "$role_row" ]]; then
      fail "could not connect to the target database"
    else
      IFS='|' read -r db_user superuser createrole createdb replication bypassrls <<< "$role_row"
      pass "connected as database role ${db_user}"
      [[ "$superuser" == "f" ]] && pass "application role is not SUPERUSER" || fail "application role is SUPERUSER"
      [[ "$createrole" == "f" ]] && pass "application role cannot create roles" || fail "application role can create roles"
      [[ "$replication" == "f" ]] && pass "application role has no replication privilege" || fail "application role has replication privilege"
      [[ "$bypassrls" == "f" ]] && pass "application role cannot bypass row-level security" || warn "application role can bypass row-level security"
      [[ "$createdb" == "f" ]] && pass "application role cannot create databases" || warn "application role can create databases"
    fi
  fi
fi

if [[ -n "${BACKUP_R2_BUCKET:-}" && -n "${BACKUP_R2_ENDPOINT:-}" ]]; then
  pass "backup object-storage configuration is present"
else
  warn "backup existence is not verified; configure R2 variables and run scripts/db_backup_restore.sh list neon"
fi
warn "restore success is an operational drill; record a dated restore test separately"

printf '\nSummary: %d failure(s), %d warning(s)\n' "$failures" "$warnings"
[[ "$failures" -eq 0 ]]