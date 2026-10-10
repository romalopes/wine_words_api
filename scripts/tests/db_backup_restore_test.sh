#!/usr/bin/env bash
# Isolated regression tests: no real credentials, database, or network access.
set -euo pipefail
SCRIPT_PATH="$(cd "$(dirname "$0")/.." && pwd)/db_backup_restore.sh"
source "$SCRIPT_PATH"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
API_DIR="$TEST_DIR"
unset NEON_DATABASE_URL SUPABASE_DATABASE_URL LOCAL_DATABASE_URL

assert_equal() {
  [[ "$1" == "$2" ]] || { echo "FAIL: $3" >&2; exit 1; }
}

# Simulate an older PATH and an installed Homebrew client suite.
(
  mkdir -p "$TEST_DIR/old-bin" "$TEST_DIR/pg18/bin"
  for client in pg_dump pg_restore psql; do
    printf '#!/bin/sh\necho "%s (PostgreSQL) 14.19"\n' "$client" > "$TEST_DIR/old-bin/$client"
    printf '#!/bin/sh\necho "%s (PostgreSQL) 18.6"\n' "$client" > "$TEST_DIR/pg18/bin/$client"
    chmod +x "$TEST_DIR/old-bin/$client" "$TEST_DIR/pg18/bin/$client"
  done
  export PATH="$TEST_DIR/old-bin:$PATH"
  brew() { printf '%s\n' "$TEST_DIR/pg18"; }
  PG_CLIENT_MAJOR=18
  if postgres_clients_match; then echo 'FAIL: accepted old clients'; exit 1; fi
  select_postgres_clients > /dev/null
  assert_equal "$(command -v pg_dump)" "$TEST_DIR/pg18/bin/pg_dump" client_selection
  postgres_clients_match
  # Reject a mixed toolchain as well as an entirely outdated one.
  printf '#!/bin/sh\necho "pg_restore (PostgreSQL) 14.19"\n' > "$TEST_DIR/pg18/bin/pg_restore"
  if (select_postgres_clients) > /dev/null 2>&1; then
    echo 'FAIL: accepted mismatched pg_restore'; exit 1
  fi
)

# Fail before restoring into an older server; newer clients alone are insufficient.
(
  PG_CLIENT_MAJOR=18
  psql() { echo 140019; }
  if (check_restore_server_version postgresql:///fake) > /dev/null 2>&1; then
    echo 'FAIL: accepted PostgreSQL 14 restore target'; exit 1
  fi
  psql() { echo 180006; }
  check_restore_server_version postgresql:///fake
  psql() { echo 190000; }
  check_restore_server_version postgresql:///fake
  psql() { return 1; }
  if (check_restore_server_version postgresql:///fake) > /dev/null 2>&1; then
    echo 'FAIL: accepted unreachable restore target'; exit 1
  fi
)

# All commands must expand arguments, including spaces and optional defaults.
(
  check_dependencies() { :; }
  backup_database() { printf '%s|%s|%s' "$@"; }
  restore_database() { printf '%s|%s|%s|%s' "$@"; }
  verify_cloudflare_downloads() { printf '%s' "$1"; }
  list_r2_backups() { printf '%s' "$1"; }
  download_from_r2() { printf '%s|%s|%s' "$@"; }
  assert_equal "$(main backup neon './backup files' custom)" 'neon|./backup files|custom' backup
  assert_equal "$(main backup local)" 'local|./backups|' defaults
  assert_equal "$(main restore neon sample.dump)" 'neon|sample.dump|local|' restore
  assert_equal "$(main verify './download files')" './download files' verify
  assert_equal "$(main list)" neon list
  assert_equal "$(main download neon latest ./downloads)" 'neon|latest|./downloads' download
  if (main backup) >/dev/null 2>&1; then exit 1; fi
)

if (get_database_url local) > /dev/null 2>&1; then
  echo 'FAIL: accepted missing LOCAL_DATABASE_URL'; exit 1
fi
printf '%s\n' 'LOCAL_DATABASE_URL="postgresql:///custom_local"' > "$API_DIR/.env.development.local"
assert_equal "$(get_database_url local)" 'postgresql:///custom_local' local_file_url
export LOCAL_DATABASE_URL=postgresql:///exported_local
assert_equal "$(get_database_url local)" "$LOCAL_DATABASE_URL" local_environment_precedence
unset LOCAL_DATABASE_URL

printf '%s\n' 'NEON_DATABASE_URL="postgresql://fake:fake@invalid/test_db?sslmode=require"' > "$API_DIR/.env.development.local"
assert_equal "$(get_database_url neon)" 'postgresql://fake:fake@invalid/test_db?sslmode=require' quoted_url
export NEON_DATABASE_URL=postgres://fake:fake@invalid/override
assert_equal "$(get_database_url neon)" "$NEON_DATABASE_URL" environment_precedence
validate_database_url "$NEON_DATABASE_URL"
unset NEON_DATABASE_URL
printf "%s\n" "SUPABASE_DATABASE_URL='postgresql://fake:fake@invalid/test_db'" >> "$API_DIR/.env.development.local"
assert_equal "$(get_database_url supabase)" 'postgresql://fake:fake@invalid/test_db' single_quoted_url
if (validate_database_url 'invalid://secret') > "$TEST_DIR/error" 2>&1; then exit 1; fi
if grep -q secret "$TEST_DIR/error"; then exit 1; fi

# Exercise the real backup path with fake PostgreSQL commands and a fake dump.
(
  check_dependencies() { :; }
  pg_dump() {
    if [[ "${1:-}" == --version ]]; then echo 'pg_dump (PostgreSQL) 18'; return; fi
    local arg
    for arg in "$@"; do
      case "$arg" in --file=*) printf 'fake database dump\n' > "${arg#--file=}" ;; esac
    done
  }
  psql() { echo 'PostgreSQL 18'; }
  export BACKUP_ENCRYPTION_RECIPIENT=''
  main backup neon "$TEST_DIR/backups" regression > "$TEST_DIR/backup.log"
  test -s "$TEST_DIR/backups/regression.dump"
  test -s "$TEST_DIR/backups/regression.dump.sha256"
  test -s "$TEST_DIR/backups/regression.dump.json"
)
# Multiple backup sets, failed leftovers, and both checksum formats.
(
  unset BACKUP_ENCRYPTION_IDENTITY
  fixture_dir="$TEST_DIR/verify sets"
  mkdir -p "$fixture_dir"
  : > "$fixture_dir/old-failed.dump"
  printf 'first dump' > "$fixture_dir/first.dump"
  sha256sum "$fixture_dir/first.dump" | awk '{print $1}' > "$fixture_dir/first.dump.sha256"
  printf '{}' > "$fixture_dir/first.dump.json"
  printf 'fake encrypted bytes' > "$fixture_dir/second.dump.age"
  sha256sum "$fixture_dir/second.dump.age" > "$fixture_dir/second.dump.age.sha256"
  printf '{}' > "$fixture_dir/second.dump.age.json"
  verify_cloudflare_downloads "$fixture_dir" > "$TEST_DIR/verify.log"
  grep -q 'Verified: 2; skipped empty/incomplete: 1; failed: 0' "$TEST_DIR/verify.log"
  mv "$fixture_dir/second.dump.age.json" "$fixture_dir/second.dump.json"
  verify_cloudflare_downloads "$fixture_dir/second.dump.age" > /dev/null
  printf 'corruption' >> "$fixture_dir/second.dump.age"
  if (verify_cloudflare_downloads "$fixture_dir") > /dev/null 2>&1; then
    echo 'FAIL: accepted corrupted backup'; exit 1
  fi
  if (verify_cloudflare_downloads "$fixture_dir/old-failed.dump") > /dev/null 2>&1; then
    echo 'FAIL: accepted empty backup'; exit 1
  fi
  rm "$fixture_dir/first.dump.sha256"
  if (verify_cloudflare_downloads "$fixture_dir/first.dump") > /dev/null 2>&1; then
    echo 'FAIL: accepted missing checksum'; exit 1
  fi
)
# Real age round-trip using disposable keys, never the user's identity.
(
  age-keygen -o "$TEST_DIR/test-identity.txt" 2> /dev/null
  recipient=$(age-keygen -y "$TEST_DIR/test-identity.txt")
  printf 'disposable test data' > "$TEST_DIR/age-input"
  age -r "$recipient" -o "$TEST_DIR/age-input.age" "$TEST_DIR/age-input"
  export BACKUP_ENCRYPTION_IDENTITY="$TEST_DIR/test-identity.txt"
  decrypt_backup "$TEST_DIR/age-input.age" > "$TEST_DIR/age-output"
  cmp "$TEST_DIR/age-input" "$TEST_DIR/age-output"
  BACKUP_ENCRYPTION_IDENTITY=$(sed -n '/^AGE-SECRET-KEY-/p' "$TEST_DIR/test-identity.txt")
  decrypt_backup -o "$TEST_DIR/age-output-raw" "$TEST_DIR/age-input.age"
  cmp "$TEST_DIR/age-input" "$TEST_DIR/age-output-raw"
  BACKUP_ENCRYPTION_IDENTITY=$(cat "$TEST_DIR/test-identity.txt")
  decrypt_backup "$TEST_DIR/age-input.age" > "$TEST_DIR/age-output-document"
  cmp "$TEST_DIR/age-input" "$TEST_DIR/age-output-document"
  BACKUP_ENCRYPTION_IDENTITY="$TEST_DIR/nonexistent-identity"
  if (decrypt_backup "$TEST_DIR/age-input.age") > /dev/null 2>&1; then
    echo 'FAIL: accepted missing identity'; exit 1
  fi
)
# R2 and encryption settings work from dotenv without exports.
(
  unset R2_BUCKET R2_ENDPOINT R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY
  unset BACKUP_ENCRYPTION_RECIPIENT BACKUP_ENCRYPTION_IDENTITY
  mkdir -p "$TEST_DIR/config-only"
  API_DIR="$TEST_DIR/config-only"
  recipient=$(age-keygen -y "$TEST_DIR/test-identity.txt")
  cat > "$API_DIR/.env.development.local" <<ENV
export R2_BUCKET="test-backups"
  export R2_ENDPOINT = https://example.invalid
export R2_ACCESS_KEY_ID='fake-access'
export R2_SECRET_ACCESS_KEY="fake-secret"
BACKUP_ENCRYPTION_RECIPIENT=$recipient
BACKUP_ENCRYPTION_IDENTITY="$TEST_DIR/test-identity.txt"
ENV
  aws() {
    assert_equal "$AWS_ACCESS_KEY_ID" fake-access r2_access_from_file
    assert_equal "$AWS_SECRET_ACCESS_KEY" fake-secret r2_secret_from_file
    assert_equal "$3" 's3://test-backups/wine-words/postgresql/neon/' r2_bucket_from_file
    assert_equal "$5" https://example.invalid r2_endpoint_from_file
  }
  list_r2_backups neon > /dev/null
  assert_equal "$(get_config_value BACKUP_ENCRYPTION_RECIPIENT)" "$recipient" recipient_from_file
  decrypt_backup "$TEST_DIR/age-input.age" > "$TEST_DIR/from-dotenv"
  cmp "$TEST_DIR/age-input" "$TEST_DIR/from-dotenv"
  export R2_BUCKET=override
  assert_equal "$(get_config_value R2_BUCKET)" override r2_export_precedence
)
bash "$SCRIPT_PATH" --help > "$TEST_DIR/help"
if grep -Fq '$0' "$TEST_DIR/help"; then exit 1; fi
if bash "$SCRIPT_PATH" unknown > /dev/null 2>&1; then exit 1; fi
echo 'All backup script regression tests passed.'
