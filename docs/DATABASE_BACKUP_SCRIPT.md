# Database Backup & Restore Script

A standalone Bash script for backing up and restoring Wine Words databases (local PostgreSQL, Supabase, NeonDB) with full compatibility with the Cloudflare R2 backup format used by GitHub Actions workflows.

## Location

`scripts/db_backup_restore.sh`

## Features

| Command | Description |
|---------|-------------|
| `backup` | Create encrypted backup from local/Supabase/Neon → local filesystem |
| `restore` | Restore `.dump` or `.dump.age` to local/Supabase/Neon |
| `verify` | Verify Cloudflare R2 downloaded files (checksum + decryption test) |
| `list` | List available backups in Cloudflare R2 |
| `download` | Download specific backup (or `latest`) from R2 |

## Prerequisites

- **PostgreSQL 18 client** (`pg_dump`, `pg_restore`, `psql`)
- **age** v1.3.2 (encryption tool)
- **awscli** (for R2 operations)
- **jq**, `sha256sum`, `curl`

```bash
# macOS
brew install postgresql@18 age awscli jq

# Verify versions
pg_dump --version    # Should show 18.x
age --version        # Should show 1.3.2
```
## Environment Setup

### 1. Database URLs (in `.env.development.local`)

```dotenv
# Local PostgreSQL (default)
DATABASE_URL=postgresql:///wine_words_development

# Supabase
SUPABASE_DATABASE_URL=postgresql://postgres:password@db.xxx.supabase.co:5432/postgres

# Neon
NEON_DATABASE_URL=postgresql://user:password@ep-xxx.neon.tech/dbname
```

### 2. Encryption Keys

```bash
# Generate age key pair (run once)
age-keygen -o age-keys.txt
# Contains: AGE-SECRET-KEY-... (private) and age1... (public)

# For BACKUP: export public key
export BACKUP_ENCRYPTION_RECIPIENT=age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# For RESTORE: export private key
export BACKUP_ENCRYPTION_IDENTITY=AGE-SECRET-KEY-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 3. Cloudflare R2 (for list/download)

```bash
export R2_BUCKET=database-backups
export R2_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com
export R2_ACCESS_KEY_ID=xxxxxxxxxxxxxxxxxxxx
export R2_SECRET_ACCESS_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## Usage Examples

### Backup Local Database

```bash
# Basic backup to ./backups/
./scripts/db_backup_restore.sh backup local ./backups

# With custom name
./scripts/db_backup_restore.sh backup local ./backups my-dev-backup
```

Output files created:
- `wine-words_postgresql_local_20240115T020000Z.dump` (plaintext, auto-deleted if encrypted)
- `wine-words_postgresql_local_20240115T020000Z.dump.age` (encrypted)
- `wine-words_postgresql_local_20240115T020000Z.dump.sha256` (checksum)
- `wine-words_postgresql_local_20240115T020000Z.dump.json` (metadata)

### Backup Neon/Supabase Database

```bash
# Requires NEON_DATABASE_URL or SUPABASE_DATABASE_URL in .env.development.local
./scripts/db_backup_restore.sh backup neon ./backups
./scripts/db_backup_restore.sh backup supabase ./backups
```
### Verify Cloudflare Downloads

If you downloaded the three files from Cloudflare R2 (`.dump.age`, `.sha256`, `.json`):

```bash
./scripts/db_backup_restore.sh verify ./cloudflare-downloads
```

Example output:
```
[INFO] Verifying Cloudflare R2 downloaded files in: ./cloudflare-downloads
[INFO] Found files:
  Dump: ./cloudflare-downloads/wine-words_postgresql_neon_20240115T020000Z.dump.age
  Checksum: ./cloudflare-downloads/wine-words_postgresql_neon_20240115T020000Z.dump.age.sha256
  Metadata: ./cloudflare-downloads/wine-words_postgresql_neon_20240115T020000Z.dump.age.json
[INFO] Verifying SHA-256 checksum...
[SUCCESS] Checksum MATCHES
[INFO] Backup metadata:
{
  "system": "wine-words",
  "provider": "neon",
  "timestamp": "20240115T020000Z",
  "database": "wine_words_production",
  ...
}
[INFO] Testing decryption (requires BACKUP_ENCRYPTION_IDENTITY)...
[SUCCESS] Decryption test PASSED
[SUCCESS] All Cloudflare download files verified!
```

### Restore to Local Database

```bash
# From a verified Cloudflare download
./scripts/db_backup_restore.sh restore neon ./cloudflare-downloads/backup.dump.age local
```

Interactive confirmation required:
```
[INFO] Target database: wine_words_development
[WARN] This will OVERWRITE the target database. Continue? (y/N)
```

### Restore to Neon Test Database

```bash
# Direct connection URL (must be a disposable/test database)
./scripts/db_backup_restore.sh restore neon backup.dump.age neon "postgresql://user:pass@ep-xxx.neon.tech/test_db"
```

### List R2 Backups

```bash
./scripts/db_backup_restore.sh list neon
./scripts/db_backup_restore.sh list supabase
```

### Download Latest Backup from R2

```bash
./scripts/db_backup_restore.sh download neon latest ./downloads
```

### Download Specific Backup from R2

```bash
./scripts/db_backup_restore.sh download neon "wine-words/postgresql/neon/DAILY_20240115T020000Z.dump.age" ./downloads
```

## Complete Recovery Workflow (Cloudflare → Local)

```bash
# 1. Set up environment
export BACKUP_ENCRYPTION_IDENTITY=AGE-SECRET-KEY-...
export R2_BUCKET=database-backups
export R2_ENDPOINT=https://<account>.r2.cloudflarestorage.com
export R2_ACCESS_KEY_ID=...
export R2_SECRET_ACCESS_KEY=...

# 2. Download latest backup
./scripts/db_backup_restore.sh download neon latest ./recovery

# 3. Verify files
./scripts/db_backup_restore.sh verify ./recovery

# 4. Restore to local database
./scripts/db_backup_restore.sh restore neon ./recovery/*.dump.age local
```
## Safety Features

- ✅ **Production protection** - Refuses to restore to databases with "prod" or "production" in name
- ✅ **Explicit confirmation** - Requires `y/N` before overwriting target
- ✅ **Checksum verification** - Validates SHA-256 before restore
- ✅ **Secure cleanup** - Shreds plaintext dump after restore
- ✅ **Schema validation** - Checks tables, migrations, and users post-restore

## Compatibility with GitHub Actions

This script uses the same format as the automated workflows:
- **Encryption**: age with key ID `v1`
- **Checksum**: SHA-256
- **Metadata**: JSON sidecar with schema info
- **R2 path**: `wine-words/postgresql/<provider>/DAILY_<timestamp>.dump.age`
- **pg_dump flags**: `--no-owner --no-acl --format=custom`

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `pg_dump: command not found` | Install PostgreSQL 18 client: `brew install postgresql@18` |
| `age: command not found` | Install age: `brew install age` |
| `CHECKSUM MISMATCH` | Re-download files; don't rename browser-added suffixes like `(1)` |
| `Decryption test FAILED` | Wrong private key; ensure `BACKUP_ENCRYPTION_IDENTITY` matches the key used for encryption |
| `SAFETY: Target database appears to be production` | Use a disposable database name without "prod"/"production" |
| `Connection fails / pooler rejected` | Use direct host URL, not pooler; check TLS, firewall, credentials |

## Related Documentation

- [Database Backup & Restore Guide](DATABASE_BACKUP_AND_RESTORE.md) - Full runbook with GitHub Actions workflows
- [Local & Deployment Setup](LOCAL_AND_DEPLOYMENT_SETUP.md) - Environment configuration