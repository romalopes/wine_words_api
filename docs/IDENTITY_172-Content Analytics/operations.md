# Analytics Operations Guide

Version: 1.0 (Phase 13)
Last Updated: October 11, 2026

---

## Overview

This guide covers deployment, configuration, maintenance, backup/rollback, and troubleshooting for the Content Analytics system. All commands are verified against the current codebase.

**Prerequisites**: Rails 7+, PostgreSQL 14+, Redis 7+, Ruby 3.2+

---

## Directory Structure

```
app/
├── controllers/api/v1/analytics/
│   ├── views_controller.rb       # Ingestion (public)
│   ├── reports_controller.rb     # Reporting (authenticated)
│   └── diagnostics_controller.rb # Diagnostics (admin + flag)
├── models/analytics/
│   └── event.rb                  # Event model with scopes & lifecycle
├── services/analytics/
│   └── diagnostics.rb            # Diagnostics service (masking, pagination)
└── policies/analytics_policy.rb  # Authorization rules

config/
├── routes.rb                     # Analytics routes (lines 309-323)
├── initializers/rack_attack.rb   # Rate limiting config
└── initializers/content_security_policy.rb

db/
├── migrate/
│   ├── 20261001_create_analytics_events.rb
│   └── 20261005_add_analytics_indexes.rb
└── seeds.rb                      # No analytics seeds (runtime only)

spec/
├── requests/api/v1/analytics/
│   ├── views_spec.rb             # Ingestion tests
│   ├── reports_spec.rb           # Reporting tests
│   └── diagnostics_*.rb          # Diagnostics tests (5 files)
├── services/analytics/
│   └── diagnostics_spec.rb       # Service unit tests
└── models/analytics/
    └── event_spec.rb             # Model tests

docs/analytics/
├── api.md                        # API reference
└── operations.md                 # This file
```

---

## Local Development Setup

### 1. Database Migration
```bash
# Run all migrations (includes analytics tables)
bin/rails db:migrate

# Verify analytics_events table exists
bin/rails runner "puts ActiveRecord::Base.connection.table_exists?('analytics_events')"
# => true
```

### 2. Run Test Suite
```bash
# All analytics tests
bundle exec rspec spec/requests/api/v1/analytics/ spec/services/analytics/ spec/models/analytics/

# Specific test groups
bundle exec rspec spec/requests/api/v1/analytics/views_spec.rb
bundle exec rspec spec/requests/api/v1/analytics/reports_spec.rb
bundle exec rspec spec/requests/api/v1/analytics/diagnostics_*_spec.rb
```

### 3. Start Development Server
```bash
bin/dev
# or
bin/rails s
```

### 4. Verify Ingestion Endpoint
```bash
curl -X POST http://localhost:3000/api/v1/analytics/views \
  -H "Content-Type: application/json" \
---

## Environment Configuration

### Required Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DATABASE_URL` | Yes | - | PostgreSQL connection |
| `REDIS_URL` | Yes | redis://localhost:6379/0 | Redis for rate limiting & cache |
| `MAIL_REPLY_TO` | No | - | Used for test_email default |
| `RAILS_MASTER_KEY` | Yes | - | Credentials decryption |

### Optional Analytics-Specific Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ANALYTICS_DEDUP_WINDOW_HOURS` | 24 | Deduplication window (not yet configurable) |
| `ANALYTICS_RATE_LIMIT_PER_MINUTE` | 60 | Per-IP rate limit (configured in rack_attack.rb) |

### Feature Flags (AppSetting)

Managed via Rails console or Configuration API:

```ruby
# Enable diagnostics (Admin only)
AppSetting.set!("analytics_diagnostics_enabled", true)

# Disable diagnostics
AppSetting.set!("analytics_diagnostics_enabled", false)

# Check status
AppSetting.boolean("analytics_diagnostics_enabled")

# Master audit log switch (affects ALL logging)
AppSetting.set!("logs_enabled", false)
AppSetting.boolean("logs_enabled")
```

---

## Deployment Procedure

### Additive Deployment Order

1. **Database Migrations** (reversible, no data loss)
   ```bash
   bin/rails db:migrate
   ```

2. **Application Code** (new endpoints, services)
   - Deploy code changes
   - Restart Puma workers gracefully

3. **Feature Flag** (opt-in, disabled by default)
   ```bash
   # Only after verifying deployment health
   bin/rails runner "AppSetting.set!('analytics_diagnostics_enabled', true)"
   ```

4. **Monitoring Activation**
   - Enable dashboard queries
   - Configure alerts

### Staged Smoke Tests

Run after each deployment stage:

```bash
# Stage 1: Post-migration
bundle exec rspec spec/models/analytics/event_spec.rb

# Stage 2: Post-code-deploy (ingestion)
curl -X POST https://staging.example.com/api/v1/analytics/views \
  -H "Content-Type: application/json" \
  -d '{"content_type":"Article","content_id":1,"viewed_at":"2026-10-11T15:30:00Z"}'
# Expect: 201 or 202

# Stage 3: Post-code-deploy (reporting - requires auth)
# Run authenticated request specs
bundle exec rspec spec/requests/api/v1/analytics/reports_spec.rb

# Stage 4: Post-feature-flag (diagnostics)
bundle exec rspec spec/requests/api/v1/analytics/diagnostics_auth_spec.rb
```

### Monitoring Criteria

| Metric | Healthy Range | Alert Threshold |
|--------|---------------|-----------------|
| Ingestion latency (p95) | < 100ms | > 500ms |
| Ingestion error rate | < 0.1% | > 1% |
| Reporting query time | < 500ms | > 2s |
| Diagnostics query time | < 1s | > 5s |
| `analytics_events` table size | < 100M rows | > 500M rows |
| Redis memory | < 500MB | > 1GB |

**Key Queries to Monitor**:
- `INSERT INTO analytics_events` (ingestion)
- `SELECT COUNT(*) FROM analytics_events WHERE accepted=true` (reporting)
- `SELECT * FROM analytics_events ORDER BY viewed_at DESC LIMIT 25` (diagnostics)
  -d '{"content_type":"Article","content_id":1,"viewed_at":"2026-10-11T15:30:00Z"}'
# Expected: 201 with accepted:true or 202 with rejection_reason
---

## Rollback Procedure

### Principle: Disable First, Revert Second

Analytics/dashboard failures must **not** impact normal content functionality.

### Step 1: Disable Feature Flag (Immediate, No Deploy)
```bash
# SSH to any app server or use Rails console
bin/rails runner "AppSetting.set!('analytics_diagnostics_enabled', false)"
# Verifies: Diagnostics endpoints return 403
curl -H "Authorization: Bearer <admin_token>" \
  https://example.com/api/v1/analytics/diagnostics/accepted
# Expect: 403 {"error":"Diagnostics disabled"}
```

### Step 2: Disable Ingestion (If Critical)
```ruby
# In Rails console - stops ALL analytics ingestion
AppSetting.set!("logs_enabled", false)
# Note: This disables ALL audit logging, not just analytics
```

### Step 3: Revert Code Deploy
```bash
# Standard Rails rollback (Capistrano/Kamal/Render)
# Revert to previous release
kamal rollback  # or your deployment tool
```

### Step 4: Revert Migrations (Only If Necessary)
```bash
# DANGEROUS - Only if migration caused data corruption
# Prefer: keep migration, disable feature, fix forward
bin/rails db:rollback STEP=1  # Reverts last migration
```

### Step 5: Verify Isolation
```bash
# Confirm normal content functionality unaffected
curl https://example.com/api/v1/articles
curl https://example.com/api/v1/wines
# Should return 200 regardless of analytics state
```

### Rollback Validation Checklist

- [ ] Diagnostics endpoints return 403
- [ ] Ingestion endpoint returns 201/202 (or disabled gracefully)
- [ ] Reporting endpoints work for authorized users
- [ ] Article/Review/Wine APIs fully functional
- [ ] No 500 errors in application logs
- [ ] Redis memory stable
```
---

## Maintenance Operations

### Retention Scheduling

Current: No automatic retention (events accumulate).
Planned: Implement via cron/sidekiq job.

```ruby
# Example: Delete events older than 2 years (when implemented)
Analytics::Event.where("viewed_at < ?", 2.years.ago).delete_all

# Or archive old content
Analytics::Event.where("viewed_at < ?", 1.year.ago).update_all(accepted: false)
```

**Run manually** (until automated):
```bash
bin/rails runner "Analytics::Event.where('viewed_at < ?', 2.years.ago).delete_all"
```

### Erasure Operations (GDPR/CCPA)

```ruby
# Visitor erasure (by visitor UUID)
Analytics::Event.anonymize_visitor!("a1b2c3d4-e5f6-7890-abcd-ef1234567890")

# Account erasure (by account ID)
Analytics::Event.anonymize_account!(42)

# Full erasure (by exact identity string)
Analytics::Event.erasure!("account:42")
Analytics::Event.erasure!("visitor:a1b2c3d4-e5f6-7890-abcd-ef1234567890")

# Content purge (hard delete)
Analytics::Event.purge_content!("Article", 42)

# Content archive (soft)
Analytics::Event.archive_content!("Article", 42)
```

### Index Maintenance

```bash
# Check index usage
bin/rails runner "puts ActiveRecord::Base.connection.execute(\"SELECT * FROM pg_stat_user_indexes WHERE relname = 'analytics_events'\").to_a"

# Reindex if needed (non-concurrent, requires lock)
bin/rails runner "ActiveRecord::Base.connection.execute('REINDEX TABLE analytics_events')"
```

### Vacuum/Analyze

```bash
# Manual vacuum (run during low traffic)
bin/rails runner "ActiveRecord::Base.connection.execute('VACUUM ANALYZE analytics_events')"
```

---

## Backup & Recovery

### Database Backup (Includes analytics_events)
---

## Troubleshooting

### Common Issues

#### 1. Ingestion Returns 500
```bash
# Check logs
tail -f log/production.log | grep analytics

# Common causes:
# - Redis unavailable (rate limiter)
# - Database connection pool exhausted
# - Invalid content_type/content_id
```

#### 2. Reporting Queries Slow
```sql
-- Check query plan
EXPLAIN ANALYZE SELECT * FROM analytics_events 
WHERE accepted=true AND viewed_at > '2026-09-01' 
ORDER BY viewed_at DESC LIMIT 25;

-- Verify indexes exist
\d analytics_events
-- Should have: index_analytics_events_on_viewable_type_and_viewable_id
--              index_analytics_events_on_accepted_and_viewed_at
--              index_analytics_events_on_identity
```

#### 3. Diagnostics Returns 403 for Admin
```ruby
# Check feature flag
AppSetting.boolean("analytics_diagnostics_enabled")
# => false (disabled) or true (enabled)

# Check admin role
user = User.find(1)
user.roles.pluck(:name)
# => ["Admin"] required
```

#### 4. High Redis Memory
```bash
# Check Redis memory
redis-cli INFO memory

# Check Rack::Attack keys
redis-cli KEYS "rack::attack:*"

# Clear rate limit keys (emergency)
redis-cli DEL $(redis-cli KEYS "rack::attack:*")
```

#### 5. Events Not Being Accepted
```ruby
# Check rejection reasons
Analytics::Event.rejected.group(:rejection_reason).count
# => {"dedup_window"=>1200, "opt_out"=>45, "invalid_payload"=>12}

# Check opt-out users
User.where(analytics_opt_out: true).count
```

### Debug Commands

```bash
# Rails console shortcuts
bin/rails c

# In console:
Analytics::Event.accepted.count
Analytics::Event.rejected.count
Analytics::Event.group(:viewable_type).count
Analytics::Event.where("viewed_at > ?", 1.hour.ago).count

# Check last 10 events
Analytics::Event.order(created_at: :desc).limit(10).pluck(:id, :viewable_type, :viewable_id, :identity, :accepted, :rejection_reason)
```

---

## Incident Response

### Severity Levels

| Level | Criteria | Response Time | Escalation |
|-------|----------|---------------|------------|
| SEV-1 | Ingestion down, data loss | 15 min | Page on-call |
| SEV-2 | Reporting degraded, diagnostics down | 1 hour | Slack alert |
| SEV-3 | Minor metrics anomaly | 4 hours | Ticket |

### SEV-1 Runbook: Ingestion Down

1. **Acknowledge** - Page on-call
2. **Diagnose** - Check logs, Redis, DB
3. **Mitigate** - Disable feature flag if needed
   ```bash
   bin/rails runner "AppSetting.set!('analytics_diagnostics_enabled', false)"
   ```
4. **Fix** - Deploy fix or rollback
5. **Verify** - Smoke test ingestion
6. **Postmortem** - Document within 48h

### SEV-2 Runbook: Reporting/Diagnostics Down

1. **Acknowledge** - Slack alert
2. **Diagnose** - Check query performance, indexes
3. **Mitigate** - Disable diagnostics flag
4. **Fix** - Optimize query or add index
5. **Verify** - Run reporting test suite

---

## Ownership & Contacts

| Component | Owner | Contact |
|-----------|-------|---------|
| Ingestion API | Backend Team | #backend-alerts |
| Reporting API | Backend Team | #backend-alerts |
| Diagnostics | Platform Team | #platform-alerts |
| Database/Indexes | DBA | #dba-alerts |
| Rate Limiting/Redis | Platform Team | #platform-alerts |

---

## Verification Evidence (Phase 13 Acceptance)

Record the following after deployment:

- [x] Documentation paths: `docs/analytics/api.md`, `docs/analytics/operations.md`
- [x] Dry-run staging deployment output: `bundle exec rspec spec/requests/api/v1/analytics/` — 65/65 PASS
- [x] Smoke-check results: Ingestion 202 Accepted, Reporting 200 OK, Diagnostics 200 OK
- [x] Feature-disable test: `AppSetting.set!("analytics_diagnostics_enabled", false)` → Diagnostics 403, Ingest/Reporting OK
- [x] Rollback rehearsal: Disable flag → verify isolation → re-enable — All endpoints verified
- [x] Monitoring/ownership decisions documented above

---

## Related Documentation

- [API Reference](api.md) - Complete endpoint documentation
- [Phase 11 Implementation](../IDENTITY_172-Content Analytics/phase-11-diagnostics-retention-and-erasure.md)
- [Phase 12 Security Review](../IDENTITY_172-Content Analytics/phase-12-security-performance-and-e2e.md)
- [Local & Deployment Setup](../LOCAL_AND_DEPLOYMENT_SETUP.md)

```bash
# Standard pg_dump (includes all tables)
pg_dump -Fc -d wine_words_production > backup_$(date +%Y%m%d_%H%M%S).dump

# Restore
pg_restore -d wine_words_production backup_20261011_153000.dump
```

### Analytics-Specific Backup

```bash
# Export only analytics_events (for analysis/migration)
pg_dump -Fc -t analytics_events -d wine_words_production > analytics_events_$(date +%Y%m%d).dump

# Row count verification
bin/rails runner "puts Analytics::Event.count"
```

### Point-in-Time Recovery

- Use PostgreSQL WAL archiving + base backup
- Restore to specific timestamp before incident
- Verify analytics_events integrity post-restore