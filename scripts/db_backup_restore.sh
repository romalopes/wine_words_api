#!/usr/bin/env bash
# Database Backup & Restore Script for Wine Words
# Supports: Local PostgreSQL, Supabase, NeonDB
# Compatible with Cloudflare R2 backup format (age-encrypted + SHA-256)

set -euo pipefail

# ============================================================================
# CONFIGURATION & DEFAULTS
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
API_DIR="$PROJECT_ROOT"

# Default versions (match GitHub Actions workflows)
PG_CLIENT_MAJOR="${PG_CLIENT_MAJOR:-18}"
AGE_VERSION="1.3.2"
SYSTEM_PREFIX="wine-words"
ENCRYPTION_KEY_ID="v1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

die() { log_error "$*"; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command '$1' not found. Please install it."
}

# ============================================================================
# DEPENDENCY CHECKS
# ============================================================================

postgres_clients_match() {
  local client version
  for client in pg_dump pg_restore psql; do
    version=$("$client" --version 2>/dev/null) || return 1
    [[ "$version" =~ PostgreSQL\)\ ([0-9]+) ]] || return 1
    [[ "${BASH_REMATCH[1]}" == "$PG_CLIENT_MAJOR" ]] || return 1
  done
}

select_postgres_clients() {
  [[ "$PG_CLIENT_MAJOR" =~ ^[0-9]+$ ]] || die "PG_CLIENT_MAJOR must be a major version number"
  if ! postgres_clients_match; then
    local prefix
    if command -v brew >/dev/null 2>&1; then
      prefix=$(brew --prefix "postgresql@$PG_CLIENT_MAJOR" 2>/dev/null) || prefix=""
      if [ -n "$prefix" ] && [ -x "$prefix/bin/pg_dump" ]; then
        export PATH="$prefix/bin:$PATH"
        hash -r
      fi
    fi
  fi
  postgres_clients_match || die "PostgreSQL $PG_CLIENT_MAJOR clients required. Install with: brew install postgresql@$PG_CLIENT_MAJOR; or prepend the matching PostgreSQL bin directory to PATH."
  log_info "Using $(pg_dump --version) from $(command -v pg_dump)"
}

check_dependencies() {
  log_info "Checking dependencies..."
  select_postgres_clients
  require_cmd pg_dump
  require_cmd pg_restore
  require_cmd psql
  require_cmd age
  require_cmd sha256sum
  require_cmd jq
  require_cmd curl
  require_cmd aws
  log_success "All dependencies available"
}

# ============================================================================
# DATABASE URL HELPERS
# ============================================================================

get_database_url() {
  local provider="$1"
  local env_file="$API_DIR/.env.development.local"
  local variable

  case "$provider" in
    local) variable="LOCAL_DATABASE_URL" ;;
    supabase) variable="SUPABASE_DATABASE_URL" ;;
    neon) variable="NEON_DATABASE_URL" ;;
    *) die "Unknown provider: $provider. Use: local, supabase, or neon" ;;
  esac

  local value
  value=$(get_config_value "$variable")
  [ -n "$value" ] || die "$variable not set in the environment or $env_file"
  printf '%s\n' "$value"
}

get_config_value() {
  local variable="$1"
  local env_file="$API_DIR/.env.development.local"
  # Exported variables take precedence. Read dotenv values as data, never shell code.
  local value="${!variable:-}"
  if [ -z "$value" ] && [ -f "$env_file" ]; then
    value=$(sed -En "s/^[[:space:]]*(export[[:space:]]+)?${variable}[[:space:]]*=[[:space:]]*//p" "$env_file" | tail -n 1)
    value="${value%$'\r'}"
    if [[ "$value" == \"*\" || "$value" == \'*\' ]]; then
      value="${value:1:${#value}-2}"
    fi
  fi
  printf '%s\n' "$value"
}

validate_database_url() {
  local url="$1"
  [[ "$url" =~ ^postgres(ql)?:// ]] || die "Invalid database URL: expected postgres:// or postgresql://"
}

get_database_name() {
  local url="$1"
  echo "$url" | sed -E 's#.*/([^/?]+)(\?.*)?$#\1#'
}

is_production_database() {
  local db_name="$1"
  [[ "$db_name" =~ prod|production ]]
}

# ============================================================================
# BACKUP FUNCTIONS
# ============================================================================

backup_database() {
  local provider="$1"
  local output_dir="$2"
  local custom_name="${3:-}"
  
  log_info "Starting backup for provider: $provider"
  
  local db_url
  db_url=$(get_database_url "$provider")
  validate_database_url "$db_url"
  
  local db_name
  db_name=$(get_database_name "$db_url")
  log_info "Source database: $db_name"
  
  mkdir -p "$output_dir"
  
  local timestamp
  timestamp=$(date -u +"%Y%m%dT%H%M%SZ")
  local suffix="${SYSTEM_PREFIX}_postgresql_${provider}_${timestamp}.dump"
  [ -n "$custom_name" ] && suffix="${custom_name}.dump"
  
  local dump_file="$output_dir/$suffix"
  local encrypted_file="${dump_file}.age"
  local checksum_file="${dump_file}.sha256"
  local metadata_file="${dump_file}.json"
  
  log_info "Creating PostgreSQL dump..."
  pg_dump --no-owner --no-acl --format=custom --dbname="$db_url" --file="$dump_file"
  log_success "Dump created: $dump_file"
  
  log_info "Calculating SHA-256 checksum..."
  sha256sum "$dump_file" | awk '{print $1}' > "$checksum_file"
  log_success "Checksum saved: $checksum_file"
  
  log_info "Creating metadata sidecar..."
  local server_version
  server_version=$(psql "$db_url" -Atc "SELECT version();" | head -1)
  local client_version
  client_version=$(pg_dump --version)
  local dump_size
  dump_size=$(stat -c%s "$dump_file" 2>/dev/null || stat -f%z "$dump_file")
  
  cat > "$metadata_file" <<META_EOF
{
  "system": "$SYSTEM_PREFIX",
  "provider": "$provider",
  "timestamp": "$timestamp",
  "database": "$db_name",
  "server_version": "$server_version",
  "client_version": "$client_version",
  "dump_size_bytes": $dump_size,
  "encryption_key_id": "$ENCRYPTION_KEY_ID",
  "pg_dump_flags": ["--no-owner", "--no-acl", "--format=custom"]
}
META_EOF
  log_success "Metadata saved: $metadata_file"
  
  log_info "Encrypting with age (key id: $ENCRYPTION_KEY_ID)..."
  local recipient="$(get_config_value BACKUP_ENCRYPTION_RECIPIENT)"
  if [ -z "$recipient" ]; then
    log_warn "BACKUP_ENCRYPTION_RECIPIENT not set. Skipping encryption."
    log_success "Backup completed (unencrypted): $dump_file"
    BACKUP_RESULT_FILE="$dump_file"
    echo "$dump_file"
    return 0
  fi
  
  age -r "$recipient" -e -o "$encrypted_file" "$dump_file"
  log_success "Encrypted backup: $encrypted_file"
  
  if [ -f "$encrypted_file" ]; then
    local enc_size
    enc_size=$(stat -c%s "$encrypted_file" 2>/dev/null || stat -f%z "$encrypted_file")
    log_info "Encrypted size: $enc_size bytes"
    
    shred -u "$dump_file" 2>/dev/null || rm -f "$dump_file"
    log_info "Plaintext dump securely deleted"
  fi
  
  sha256sum "$encrypted_file" | awk '{print $1}' > "${encrypted_file}.sha256"
  
  log_success "Backup completed successfully!"
  BACKUP_RESULT_FILE="$encrypted_file"
  echo "$encrypted_file"
}

# ============================================================================
# RESTORE FUNCTIONS
# ============================================================================

copy_database() {
  local command="$1" output_dir="${2:-./backups}"
  local source_provider target_provider target_variable
  case "$command" in
    restore_local_to_neondb) source_provider=local; target_provider=neon; target_variable=NEON_DATABASE_URL ;;
    restore_local_to_supabase) source_provider=local; target_provider=supabase; target_variable=SUPA_DATABASE_URL ;;
    restore_neondb_to_neondb) source_provider=neon; target_provider=neon; target_variable=NEON_SECOND_DATABASE_URL ;;
    restore_neondb_to_local) source_provider=neon; target_provider=local; target_variable=LOCAL_DATABASE_URL ;;
    *) die "Unknown copy command: $command" ;;
  esac
  local source_url target_url recipient identity
  source_url=$(get_database_url "$source_provider")
  target_url=$(get_config_value "$target_variable")
  [ -n "$target_url" ] || die "$target_variable not set in .env.development.local or environment"
  validate_database_url "$source_url"
  validate_database_url "$target_url"
  [ "$source_url" != "$target_url" ] || die "Source and destination URLs are identical"
  is_production_database "$(get_database_name "$target_url")" && die "SAFETY: Target database appears to be production. Aborting."
  check_restore_server_version "$target_url"
  recipient=$(get_config_value BACKUP_ENCRYPTION_RECIPIENT)
  identity=$(get_config_value BACKUP_ENCRYPTION_IDENTITY)
  if [ -n "$recipient" ] && [ -z "$identity" ]; then
    die "BACKUP_ENCRYPTION_IDENTITY is required to restore the encrypted source backup"
  fi
  local backup_dir
  mkdir -p "$output_dir"
  backup_dir=$(mktemp -d "$output_dir/${command}.XXXXXX")
  log_info "Copying $source_provider to $target_variable; source backup retained in $backup_dir"
  BACKUP_RESULT_FILE=""
  backup_database "$source_provider" "$backup_dir"
  [ -n "$BACKUP_RESULT_FILE" ] && [ -s "$BACKUP_RESULT_FILE" ] || die "Source backup was not created"
  verify_backup_file "$BACKUP_RESULT_FILE"
  restore_database "$source_provider" "$BACKUP_RESULT_FILE" "$target_provider" "$target_url"
}

validate_restored_table_count() {
  local dump_file="$1" target_url="$2" archive_list expected actual
  archive_list=$(pg_restore --list "$dump_file") || die "Cannot inspect backup table list"
  # TABLE DATA and TABLE ATTACH entries are not table definitions.
  expected=$(printf '%s\n' "$archive_list" | awk '$1 ~ /^[0-9]+;$/ && $4 == "TABLE" && $2 != 0 {n++} END {print n+0}')
  actual=$(psql -X "$target_url" -Atc "SELECT count(*) FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind IN ('r','p','f') AND n.nspname NOT IN ('pg_catalog','information_schema') AND n.nspname !~ '^pg_toast';") || die "Cannot count restored tables"
  [[ "$actual" =~ ^[0-9]+$ ]] || die "Invalid restored table count"
  log_info "Table definitions in backup: $expected; user tables in target: $actual"
  [ "$actual" -ge "$expected" ] || die "Restore committed, but target has fewer tables ($actual) than the backup ($expected)"
  if [ "$actual" -gt "$expected" ]; then
    log_warn "Target has additional tables; pg_restore --clean only replaces objects included in the backup."
  fi
}

check_restore_server_version() {
  local target_url="$1" server_number server_major
  server_number=$(psql -X "$target_url" -Atc 'SHOW server_version_num;') || die "Cannot determine target PostgreSQL server version"
  [[ "$server_number" =~ ^[0-9]+$ ]] || die "Invalid target PostgreSQL server version"
  server_major=$((server_number / 10000))
  [ "$server_major" -ge "$PG_CLIENT_MAJOR" ] || die "Target server is PostgreSQL $server_major, but restore uses PostgreSQL $PG_CLIENT_MAJOR. Restore into a PostgreSQL $PG_CLIENT_MAJOR or newer server; selecting newer client binaries does not upgrade the server. No restore changes made."
}

restore_database() {
  local provider="$1"
  local backup_file="$2"
  local target_provider="${3:-local}"
  local target_db_url="${4:-}"
  
  log_info "Starting restore from: $backup_file"
  log_info "Source provider: $provider, Target provider: $target_provider"
  
  [ -f "$backup_file" ] || die "Backup file not found: $backup_file"
  
  local target_url
  if [ -n "$target_db_url" ]; then
    target_url="$target_db_url"
  else
    target_url=$(get_database_url "$target_provider")
  fi
  validate_database_url "$target_url"
  
  local target_db_name
  target_db_name=$(get_database_name "$target_url")
  
  if is_production_database "$target_db_name"; then
    die "SAFETY: Target database '$target_db_name' appears to be production. Aborting."
  fi
  
  check_restore_server_version "$target_url"
  log_info "Target database: $target_db_name"
  log_warn "This will OVERWRITE the target database. Continue? (y/N)"
  read -r confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || die "Restore cancelled by user"
  
  local work_dir
  work_dir=$(mktemp -d -t winewords-restore-XXXXXX)
  trap "rm -rf '$work_dir'" EXIT
  
  local decrypted_dump="$work_dir/backup.dump"
  
  if [[ "$backup_file" == *.age ]]; then
    log_info "Decrypting age-encrypted backup..."
    local identity="$(get_config_value BACKUP_ENCRYPTION_IDENTITY)"
    [ -n "$identity" ] || die "BACKUP_ENCRYPTION_IDENTITY (private key) required for decryption. Set it in .env.development.local or your environment."
    
    decrypt_backup -o "$decrypted_dump" "$backup_file"
    log_success "Decrypted to: $decrypted_dump"
  elif [[ "$backup_file" == *.dump ]]; then
    log_info "Using plaintext dump directly..."
    cp "$backup_file" "$decrypted_dump"
  else
    die "Unknown backup file format. Expected .dump or .dump.age"
  fi
  
  local checksum_file
  if [[ "$backup_file" == *.age ]]; then
    checksum_file="${backup_file}.sha256"
  else
    checksum_file="${backup_file}.sha256"
  fi
  
  if [ -f "$checksum_file" ]; then
    log_info "Verifying SHA-256 checksum..."
    local expected_checksum
    expected_checksum=$(awk 'NR == 1 {print $1}' "$checksum_file")
    local actual_checksum
    actual_checksum=$(sha256sum "$backup_file" | awk '{print $1}')
    [ "$expected_checksum" = "$actual_checksum" ] || die "CHECKSUM MISMATCH! Expected: $expected_checksum, Got: $actual_checksum"
    log_success "Checksum verified"
  else
    log_warn "No checksum file found. Skipping verification."
  fi
  
  log_info "Restoring database (this may take a while)..."
  pg_restore --single-transaction --exit-on-error --clean --if-exists --no-owner --no-acl --dbname="$target_url" "$decrypted_dump"
  log_success "Database restored successfully!"
  
  validate_restored_table_count "$decrypted_dump" "$target_url"

  local relation row_count
  for relation in schema_migrations users; do
    if row_count=$(psql -X "$target_url" -Atc "SELECT count(*) FROM public.$relation;" 2>/dev/null); then
      log_info "$relation rows: $row_count"
    else
      log_warn "$relation row count unavailable; this backup may not contain that Rails table."
    fi
  done

  shred -u "$decrypted_dump" 2>/dev/null || rm -f "$decrypted_dump"
  log_success "Restore validation passed! Plaintext dump shredded."
}

# ============================================================================
# CLOUDFLARE R2 FUNCTIONS
# ============================================================================

decrypt_backup() {
  local identity="$(get_config_value BACKUP_ENCRYPTION_IDENTITY)"
  [ -n "$identity" ] || die "BACKUP_ENCRYPTION_IDENTITY is required for decryption"
  if [[ "$identity" == AGE-SECRET-KEY-* || "$identity" == *$'\n'* ]]; then
    # Feed raw keys (or an age-keygen identity document) over stdin, not argv.
    printf '%s\n' "$identity" | age -d -i - "$@"
  else
    [ -f "$identity" ] && [ -r "$identity" ] || die "BACKUP_ENCRYPTION_IDENTITY must contain an age private key or a readable identity-file path"
    age -d -i "$identity" "$@"
  fi
}

verify_backup_file() {
  local dump_file="$1"
  local checksum_file="${dump_file}.sha256"
  local metadata_file="${dump_file}.json"
  if [[ "$dump_file" == *.age ]] && [ ! -f "$metadata_file" ]; then
    metadata_file="${dump_file%.age}.json"
  fi
  [ -s "$dump_file" ] || die "Empty or missing dump: $dump_file"
  [ -f "$checksum_file" ] || die "Missing checksum: $checksum_file"
  [ -f "$metadata_file" ] || die "Missing metadata: $metadata_file"
  log_info "Verifying backup: $dump_file"
  local expected actual
  expected=$(awk 'NR == 1 {print $1}' "$checksum_file")
  [[ "$expected" =~ ^[[:xdigit:]]{64}$ ]] || die "Invalid SHA-256 checksum: $checksum_file"
  actual=$(sha256sum "$dump_file" | awk '{print $1}')
  [ "$expected" = "$actual" ] || die "CHECKSUM MISMATCH for $dump_file"
  log_success "Checksum MATCHES"
  jq -e 'type == "object"' "$metadata_file" >/dev/null || die "Invalid metadata: $metadata_file"

  if [[ "$dump_file" == *.age ]]; then
    if [ -n "$(get_config_value BACKUP_ENCRYPTION_IDENTITY)" ]; then
      # Stream to /dev/null to avoid leaving decrypted database contents on disk.
      decrypt_backup "$dump_file" > /dev/null || die "Decryption test FAILED: $dump_file"
      log_success "Decryption test PASSED"
    else
      log_warn "BACKUP_ENCRYPTION_IDENTITY not set. Decryption not tested."
    fi
  fi
  log_success "Checksum and metadata verified: $dump_file"
}

verify_cloudflare_downloads() {
  local input="$1"
  if [ -f "$input" ]; then
    verify_backup_file "$input"
    return
  fi
  [ -d "$input" ] || die "Backup file or directory not found: $input"
  local dump_file metadata_file count=0 skipped=0 failed=0
  while IFS= read -r -d '' dump_file; do
    metadata_file="${dump_file}.json"
    if [[ "$dump_file" == *.age ]] && [ ! -f "$metadata_file" ]; then
      metadata_file="${dump_file%.age}.json"
    fi
    if [ ! -s "$dump_file" ] || [ ! -f "${dump_file}.sha256" ] || [ ! -f "$metadata_file" ]; then
      log_warn "Skipping empty or incomplete backup: $dump_file"
      skipped=$((skipped + 1))
      continue
    fi
    if (verify_backup_file "$dump_file"); then
      count=$((count + 1))
    else
      failed=$((failed + 1))
    fi
  done < <(find "$input" -type f \( -name '*.dump.age' -o -name '*.dump' \) -print0)
  log_info "Verified: $count; skipped empty/incomplete: $skipped; failed: $failed"
  [ "$failed" -eq 0 ] || die "Backup verification failed"
  [ "$count" -gt 0 ] || die "No complete backups found in $input"
}

list_r2_backups() {
  local provider="${1:-neon}"
  
  log_info "Listing backups in Cloudflare R2 for provider: $provider"
  
  require_cmd aws
  
  local bucket="$(get_config_value R2_BUCKET)"
  local endpoint="$(get_config_value R2_ENDPOINT)"
  local access_key="$(get_config_value R2_ACCESS_KEY_ID)"
  local secret_key="$(get_config_value R2_SECRET_ACCESS_KEY)"
  
  [ -n "$bucket" ] || die "R2_BUCKET not set in .env.development.local or environment"
  [ -n "$endpoint" ] || die "R2_ENDPOINT not set in .env.development.local or environment"
  [ -n "$access_key" ] || die "R2_ACCESS_KEY_ID not set in .env.development.local or environment"
  [ -n "$secret_key" ] || die "R2_SECRET_ACCESS_KEY not set in .env.development.local or environment"
  
  export AWS_ACCESS_KEY_ID="$access_key"
  export AWS_SECRET_ACCESS_KEY="$secret_key"
  
  aws s3 ls "s3://${bucket}/${SYSTEM_PREFIX}/postgresql/${provider}/" --endpoint-url "$endpoint" --human-readable --summarize
}

download_from_r2() {
  local provider="$1"
  local backup_key="$2"
  local output_dir="$3"
  
  log_info "Downloading backup from R2: $backup_key"
  
  require_cmd aws
  
  local bucket="$(get_config_value R2_BUCKET)"
  local endpoint="$(get_config_value R2_ENDPOINT)"
  local access_key="$(get_config_value R2_ACCESS_KEY_ID)"
  local secret_key="$(get_config_value R2_SECRET_ACCESS_KEY)"
  
  [ -n "$bucket" ] || die "R2_BUCKET not set in .env.development.local or environment"
  [ -n "$endpoint" ] || die "R2_ENDPOINT not set in .env.development.local or environment"
  [ -n "$access_key" ] || die "R2_ACCESS_KEY_ID not set in .env.development.local or environment"
  [ -n "$secret_key" ] || die "R2_SECRET_ACCESS_KEY not set in .env.development.local or environment"
  
  export AWS_ACCESS_KEY_ID="$access_key"
  export AWS_SECRET_ACCESS_KEY="$secret_key"
  
  mkdir -p "$output_dir"
  
  local prefix="${SYSTEM_PREFIX}/postgresql/${provider}/"
  
  if [ "$backup_key" = "latest" ]; then
    log_info "Finding latest backup..."
    backup_key=$(aws s3api list-objects-v2 \
      --bucket "$bucket" \
      --prefix "$prefix" \
      --endpoint-url "$endpoint" \
      --query 'Contents[?ends_with(Key, `.dump.age`)].Key | sort_by(@, &LastModified)[-1]' \
      --output text)
    [ -n "$backup_key" ] && [ "$backup_key" != "None" ] || die "No backups found for provider $provider"
    log_info "Latest backup: $backup_key"
  fi
  
  local base_key="${backup_key%.age}"
  local files=("${base_key}.age" "${base_key}.sha256" "${base_key}.json")
  
  for file in "${files[@]}"; do
    local local_file="$output_dir/$(basename "$file")"
    log_info "Downloading: $file"
    aws s3 cp "s3://${bucket}/$file" "$local_file" --endpoint-url "$endpoint" || log_warn "File not found: $file (may not exist for older backups)"
  done
  
  log_success "Download complete to: $output_dir"
}

# ============================================================================
# USAGE / HELP
# ============================================================================

usage() {
  cat <<USAGE_EOF
Database Backup & Restore Script for Wine Words

USAGE:
  $0 <command> [options]

COMMANDS:
  restore_local_to_neondb [output_dir]
    Copy LOCAL_DATABASE_URL to NEON_DATABASE_URL
  restore_local_to_supabase [output_dir]
    Copy LOCAL_DATABASE_URL to SUPA_DATABASE_URL
  restore_neondb_to_neondb [output_dir]
    Copy NEON_DATABASE_URL to NEON_SECOND_DATABASE_URL
  restore_neondb_to_local [output_dir]
    Copy NEON_DATABASE_URL to LOCAL_DATABASE_URL
    These commands back up, verify, then prompt before restoring the target.
    Source backups are retained under output_dir (default: ./backups).

  backup <provider> [output_dir] [custom_name]
    Create a backup from the specified provider
    Providers: local, supabase, neon
    Example: $0 backup neon ./backups
    Example: $0 backup local ./backups my-custom-backup

  restore <provider> <backup_file> [target_provider] [target_db_url]
    Restore a backup to the specified target
    Providers: local, supabase, neon
    Example: $0 restore neon backup.dump.age local
    Example: $0 restore neon backup.dump.age neon postgresql://user:pass@host/db

  verify <backup_file_or_directory>
    Verify matching dump, checksum, and metadata sets (local or R2)
    Example: $0 verify ./downloads

  list <provider>
    List available backups in Cloudflare R2
    Example: $0 list neon

  download <provider> <backup_key> <output_dir>
    Download a specific backup (or 'latest') from Cloudflare R2
    Example: $0 download neon latest ./downloads
    Example: $0 download neon wine-words/postgresql/neon/DAILY_20240115T020000Z.dump.age ./downloads

CONFIGURATION (.env.development.local; exported values take precedence):
  BACKUP_ENCRYPTION_RECIPIENT    Age public key for encryption (age1...)
  BACKUP_ENCRYPTION_IDENTITY     Age private key (AGE-SECRET-KEY-...) or identity-file path
  R2_BUCKET                      Cloudflare R2 bucket name
  R2_ENDPOINT                    Cloudflare R2 S3 endpoint URL
  R2_ACCESS_KEY_ID               Cloudflare R2 access key ID
  R2_SECRET_ACCESS_KEY           Cloudflare R2 secret access key
  LOCAL_DATABASE_URL             Local database URL (exported or in .env.development.local)
  NEON_DATABASE_URL              Neon database URL (exported or in .env.development.local)
  SUPA_DATABASE_URL              Destination for restore_local_to_supabase
  NEON_SECOND_DATABASE_URL       Destination for restore_neondb_to_neondb
  SUPABASE_DATABASE_URL          Supabase database URL (exported or in .env.development.local)
  PG_CLIENT_MAJOR                PostgreSQL client major version (default: 18)

FILES:
  .env.development.local         Local environment file (in wine_words_api/)

EXAMPLES:
  # Backup local database to ./backups
  $0 backup local ./backups

  # Backup Neon database (requires NEON_DATABASE_URL in .env.development.local)
  $0 backup neon ./backups

  # Restore from Cloudflare download to local database
  $0 verify ./cloudflare-downloads
  $0 restore neon ./cloudflare-downloads/backup.dump.age local

  # Restore to a specific Neon test database
  $0 restore neon backup.dump.age neon "postgresql://user:pass@ep-xxx.neon.tech/db"

  # List and download latest backup from R2
  # Set R2_BUCKET, R2_ENDPOINT, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY in .env.development.local
  $0 list neon
  $0 download neon latest ./downloads
  $0 verify ./downloads
  $0 restore neon ./downloads/backup.dump.age local

REQUIREMENTS:
  - PostgreSQL client (pg_dump, pg_restore, psql) version 18
  - age (encryption tool) version 1.3.2
  - awscli (for R2 operations)
  - jq (JSON parsing)
  - sha256sum, curl
USAGE_EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
  local command="${1:-}"
  shift || true
  
  case "$command" in
    help|--help|-h)
      usage
      ;;
    restore_local_to_neondb|restore_local_to_supabase|restore_neondb_to_neondb|restore_neondb_to_local)
      [ "$#" -le 1 ] || die "Usage: $0 $command [output_dir]"
      check_dependencies
      copy_database "$command" "${1:-./backups}"
      ;;
    backup)
      check_dependencies
      local provider="${1:-}"
      local output_dir="${2:-./backups}"
      local custom_name="${3:-}"
      [ -n "$provider" ] || die "Provider required. Usage: $0 backup <provider> [output_dir] [custom_name]"
      backup_database "$provider" "$output_dir" "$custom_name"
      ;;
    restore)
      check_dependencies
      local provider="${1:-}"
      local backup_file="${2:-}"
      local target_provider="${3:-local}"
      local target_db_url="${4:-}"
      [ -n "$provider" ] && [ -n "$backup_file" ] || die "Usage: $0 restore <provider> <backup_file> [target_provider] [target_db_url]"
      restore_database "$provider" "$backup_file" "$target_provider" "$target_db_url"
      ;;
    verify)
      check_dependencies
      local download_dir="${1:-}"
      [ -n "$download_dir" ] || die "Usage: $0 verify <backup_file_or_directory>"
      verify_cloudflare_downloads "$download_dir"
      ;;
    list)
      local provider="${1:-neon}"
      list_r2_backups "$provider"
      ;;
    download)
      local provider="${1:-}"
      local backup_key="${2:-}"
      local output_dir="${3:-}"
      [ -n "$provider" ] && [ -n "$backup_key" ] && [ -n "$output_dir" ] || die "Usage: $0 download <provider> <backup_key> <output_dir>"
      download_from_r2 "$provider" "$backup_key" "$output_dir"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
