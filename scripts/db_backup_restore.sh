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
API_DIR="$PROJECT_ROOT/wine_prediction_api"

# Default versions (match GitHub Actions workflows)
PG_CLIENT_MAJOR="18"
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
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

die() { log_error "$*"; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command '$1' not found. Please install it."
}

# ============================================================================
# DEPENDENCY CHECKS
# ============================================================================

check_dependencies() {
  log_info "Checking dependencies..."
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
  
  case "$provider" in
    local)
      echo "postgresql:///wine_words_development"
      ;;
    supabase)
      grep -E '^SUPABASE_DATABASE_URL=' "$env_file" 2>/dev/null | cut -d'=' -f2- || die "SUPABASE_DATABASE_URL not found in $env_file"
      ;;
    neon)
      grep -E '^NEON_DATABASE_URL=' "$env_file" 2>/dev/null | cut -d'=' -f2- || die "NEON_DATABASE_URL not found in $env_file"
      ;;
    *)
      die "Unknown provider: $provider. Use: local, supabase, or neon"
      ;;
  esac
}

validate_database_url() {
  local url="$1"
  [[ "$url" =~ ^postgresql:// ]] || die "Invalid DATABASE_URL format: $url"
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
  local recipient="${BACKUP_ENCRYPTION_RECIPIENT:-}"
  if [ -z "$recipient" ]; then
    log_warn "BACKUP_ENCRYPTION_RECIPIENT not set. Skipping encryption."
    log_success "Backup completed (unencrypted): $dump_file"
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
  echo "$encrypted_file"
}

# ============================================================================
# RESTORE FUNCTIONS
# ============================================================================

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
    local identity="${BACKUP_ENCRYPTION_IDENTITY:-}"
    [ -n "$identity" ] || die "BACKUP_ENCRYPTION_IDENTITY (private key) required for decryption. Set it in your environment."
    
    age -d -i "$identity" -o "$decrypted_dump" "$backup_file"
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
    expected_checksum=$(cat "$checksum_file")
    local actual_checksum
    actual_checksum=$(sha256sum "$decrypted_dump" | awk '{print $1}')
    [ "$expected_checksum" = "$actual_checksum" ] || die "CHECKSUM MISMATCH! Expected: $expected_checksum, Got: $actual_checksum"
    log_success "Checksum verified"
  else
    log_warn "No checksum file found. Skipping verification."
  fi
  
  log_info "Restoring database (this may take a while)..."
  pg_restore --clean --if-exists --no-owner --no-acl --dbname="$target_url" "$decrypted_dump"
  log_success "Database restored successfully!"
  
  log_info "Validating restore..."
  local table_count
  table_count=$(psql "$target_url" -Atc "SELECT count(*) FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog','information_schema');")
  log_info "User tables restored: $table_count"
  [ "$table_count" -ge 5 ] || die "Too few tables restored ($table_count). Expected full application schema."
  
  local migrations_count
  migrations_count=$(psql "$target_url" -Atc "SELECT count(*) FROM schema_migrations;" 2>/dev/null || echo "0")
  log_info "Schema migrations: $migrations_count"
  
  local users_count
  users_count=$(psql "$target_url" -Atc "SELECT count(*) FROM users;" 2>/dev/null || echo "0")
  log_info "Users: $users_count"
  
  shred -u "$decrypted_dump" 2>/dev/null || rm -f "$decrypted_dump"
  log_success "Restore validation passed! Plaintext dump shredded."
}

# ============================================================================
# CLOUDFLARE R2 FUNCTIONS
# ============================================================================

verify_cloudflare_downloads() {
  local download_dir="$1"
  
  log_info "Verifying Cloudflare R2 downloaded files in: $download_dir"
  
  [ -d "$download_dir" ] || die "Directory not found: $download_dir"
  
  local dump_file
  dump_file=$(find "$download_dir" -name "*.dump.age" -o -name "*.dump" | head -1)
  [ -n "$dump_file" ] || die "No .dump.age or .dump file found in $download_dir"
  
  local checksum_file
  checksum_file=$(find "$download_dir" -name "*.sha256" | head -1)
  
  local metadata_file
  metadata_file=$(find "$download_dir" -name "*.json" | head -1)
  
  log_info "Found files:"
  echo "  Dump: $dump_file"
  [ -n "$checksum_file" ] && echo "  Checksum: $checksum_file" || echo "  Checksum: NOT FOUND"
  [ -n "$metadata_file" ] && echo "  Metadata: $metadata_file" || echo "  Metadata: NOT FOUND"
  
  if [ -n "$checksum_file" ] && [ -f "$checksum_file" ]; then
    log_info "Verifying SHA-256 checksum..."
    local expected
    expected=$(cat "$checksum_file")
    local actual
    actual=$(sha256sum "$dump_file" | awk '{print $1}')
    if [ "$expected" = "$actual" ]; then
      log_success "Checksum MATCHES"
    else
      die "CHECKSUM MISMATCH! Expected: $expected, Got: $actual"
    fi
  fi
  
  if [ -n "$metadata_file" ] && [ -f "$metadata_file" ]; then
    log_info "Backup metadata:"
    cat "$metadata_file" | jq .
  fi
  
  if [[ "$dump_file" == *.age ]]; then
    log_info "Testing decryption (requires BACKUP_ENCRYPTION_IDENTITY)..."
    local identity="${BACKUP_ENCRYPTION_IDENTITY:-}"
    if [ -n "$identity" ]; then
      local test_output
      test_output=$(mktemp)
      if age -d -i "$identity" -o "$test_output" "$dump_file" 2>/dev/null; then
        log_success "Decryption test PASSED"
        shred -u "$test_output" 2>/dev/null || rm -f "$test_output"
      else
        die "Decryption test FAILED - wrong private key?"
      fi
    else
      log_warn "BACKUP_ENCRYPTION_IDENTITY not set. Skipping decryption test."
    fi
  fi
  
  log_success "All Cloudflare download files verified!"
  echo "$dump_file"
}

list_r2_backups() {
  local provider="${1:-neon}"
  
  log_info "Listing backups in Cloudflare R2 for provider: $provider"
  
  require_cmd aws
  
  local bucket="${R2_BUCKET:-}"
  local endpoint="${R2_ENDPOINT:-}"
  local access_key="${R2_ACCESS_KEY_ID:-}"
  local secret_key="${R2_SECRET_ACCESS_KEY:-}"
  
  [ -n "$bucket" ] || die "R2_BUCKET environment variable not set"
  [ -n "$endpoint" ] || die "R2_ENDPOINT environment variable not set"
  [ -n "$access_key" ] || die "R2_ACCESS_KEY_ID environment variable not set"
  [ -n "$secret_key" ] || die "R2_SECRET_ACCESS_KEY environment variable not set"
  
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
  
  local bucket="${R2_BUCKET:-}"
  local endpoint="${R2_ENDPOINT:-}"
  local access_key="${R2_ACCESS_KEY_ID:-}"
  local secret_key="${R2_SECRET_ACCESS_KEY:-}"
  
  [ -n "$bucket" ] || die "R2_BUCKET environment variable not set"
  [ -n "$endpoint" ] || die "R2_ENDPOINT environment variable not set"
  [ -n "$access_key" ] || die "R2_ACCESS_KEY_ID environment variable not set"
  [ -n "$secret_key" ] || die "R2_SECRET_ACCESS_KEY environment variable not set"
  
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
  \$0 <command> [options]

COMMANDS:
  backup <provider> [output_dir] [custom_name]
    Create a backup from the specified provider
    Providers: local, supabase, neon
    Example: \$0 backup neon ./backups
    Example: \$0 backup local ./backups my-custom-backup

  restore <provider> <backup_file> [target_provider] [target_db_url]
    Restore a backup to the specified target
    Providers: local, supabase, neon
    Example: \$0 restore neon backup.dump.age local
    Example: \$0 restore neon backup.dump.age neon postgresql://user:pass@host/db

  verify <download_dir>
    Verify the three Cloudflare R2 downloaded files (dump, checksum, metadata)
    Example: \$0 verify ./downloads

  list <provider>
    List available backups in Cloudflare R2
    Example: \$0 list neon

  download <provider> <backup_key> <output_dir>
    Download a specific backup (or 'latest') from Cloudflare R2
    Example: \$0 download neon latest ./downloads
    Example: \$0 download neon wine-words/postgresql/neon/DAILY_20240115T020000Z.dump.age ./downloads

ENVIRONMENT VARIABLES:
  BACKUP_ENCRYPTION_RECIPIENT    Age public key for encryption (age1...)
  BACKUP_ENCRYPTION_IDENTITY     Age private key for decryption (AGE-SECRET-KEY-...)
  R2_BUCKET                      Cloudflare R2 bucket name
  R2_ENDPOINT                    Cloudflare R2 S3 endpoint URL
  R2_ACCESS_KEY_ID               Cloudflare R2 access key ID
  R2_SECRET_ACCESS_KEY           Cloudflare R2 secret access key
  NEON_DATABASE_URL              Neon database URL (in .env.development.local)
  SUPABASE_DATABASE_URL          Supabase database URL (in .env.development.local)
  PG_CLIENT_MAJOR                PostgreSQL client major version (default: 18)

FILES:
  .env.development.local         Local environment file (in wine_prediction_api/)

EXAMPLES:
  # Backup local database to ./backups
  \$0 backup local ./backups

  # Backup Neon database (requires NEON_DATABASE_URL in .env.development.local)
  \$0 backup neon ./backups

  # Restore from Cloudflare download to local database
  \$0 verify ./cloudflare-downloads
  \$0 restore neon ./cloudflare-downloads/backup.dump.age local

  # Restore to a specific Neon test database
  \$0 restore neon backup.dump.age neon "postgresql://user:pass@ep-xxx.neon.tech/db"

  # List and download latest backup from R2
  export R2_BUCKET=... R2_ENDPOINT=... R2_ACCESS_KEY_ID=... R2_SECRET_ACCESS_KEY=...
  \$0 list neon
  \$0 download neon latest ./downloads
  \$0 verify ./downloads
  \$0 restore neon ./downloads/backup.dump.age local

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
  local command="\${1:-}"
  shift || true
  
  case "\$command" in
    backup)
      check_dependencies
      local provider="\${1:-}"
      local output_dir="\${2:-./backups}"
      local custom_name="\${3:-}"
      [ -n "\$provider" ] || die "Provider required. Usage: \$0 backup <provider> [output_dir] [custom_name]"
      backup_database "\$provider" "\$output_dir" "\$custom_name"
      ;;
    restore)
      check_dependencies
      local provider="\${1:-}"
      local backup_file="\${2:-}"
      local target_provider="\${3:-local}"
      local target_db_url="\${4:-}"
      [ -n "\$provider" ] && [ -n "\$backup_file" ] || die "Usage: \$0 restore <provider> <backup_file> [target_provider] [target_db_url]"
      restore_database "\$provider" "\$backup_file" "\$target_provider" "\$target_db_url"
      ;;
    verify)
      check_dependencies
      local download_dir="\${1:-}"
      [ -n "\$download_dir" ] || die "Usage: \$0 verify <download_dir>"
      verify_cloudflare_downloads "\$download_dir"
      ;;
    list)
      local provider="\${1:-neon}"
      list_r2_backups "\$provider"
      ;;
    download)
      local provider="\${1:-}"
      local backup_key="\${2:-}"
      local output_dir="\${3:-}"
      [ -n "\$provider" ] && [ -n "\$backup_key" ] && [ -n "\$output_dir" ] || die "Usage: \$0 download <provider> <backup_key> <output_dir>"
      download_from_r2 "\$provider" "\$backup_key" "\$output_dir"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"