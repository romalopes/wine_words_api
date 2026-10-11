# Phase 12 Execution Plan: Security, Performance & End-to-End Verification

**Status**: In Progress (started October 11, 2026)
**Prerequisite**: Phase 11 Complete ✅

## Overview

Phase 12 validates that all delivered analytics features are safe, performant at expected traffic, and correct across the consolidated verification matrix before release planning.

## Workstreams (Parallel Execution)

### 1. Security Review
- [ ] Authorization boundary tests for every endpoint
- [ ] Parameter allowlisting validation
- [ ] Log privacy audit (no raw IPs, tokens, names, full UAs, rejected events in logs)
- [ ] Feature control boundary verification (`analytics_diagnostics_enabled`, etc.)
- [ ] Retention/erasure authorization checks

### 2. Performance Measurement
- [ ] Ingestion SQL plans (EXPLAIN ANALYZE) with realistic data volumes
- [ ] Reporting/query SQL plans for metrics, dashboard, wine insights
- [ ] Index usage verification
- [ ] Connection pool behavior under load
- [ ] Memory profiling for Ruby processes
- [ ] Response time percentiles (p50, p95, p99)

### 3. Concurrent Deduplication Testing
- [ ] Real DB connection pool contention tests
- [ ] Same-tuple deduplication under concurrent ingestion
- [ ] Race condition validation for `dedup_lock_key`
- [ ] Verify idempotency at database level

### 4. Verification Matrix Execution
| Scenario | Test Areas |
|----------|------------|
| **Role** | Admin, Author, Member, Anonymous, Opted-out |
| **Visibility** | Public, Private, Draft, Archived content |
| **Boundary** | Cross-content, cross-user, cross-period |
| **Consent** | Opt-in, Opt-out, GDPR erasure requests |
| **Lifecycle** | Create, Update, Delete, Restore, Purge |
| **Degraded Service** | DB slow/unavailable, Redis down, Queue backed up |

### 5. Failure Isolation
- [ ] Analytics DB failure → content pages still load
- [ ] Analytics queue backup → no memory leaks
- [ ] Diagnostics disabled → no performance impact
- [ ] Retention job failure → alerting works
- [ ] Erasure job failure → idempotent retry safe

## Implementation Order

### Sprint 1: Security Review + Test Infrastructure
1. Add security-focused request specs for all analytics endpoints
2. Create test helpers for concurrent connection testing
3. Document log output for privacy audit

### Sprint 2: Performance Measurement
1. Add benchmark/load test scripts
2. Run EXPLAIN ANALYZE on all critical queries
3. Profile memory and connection usage

### Sprint 3: Concurrent Testing + Verification Matrix
1. Execute concurrent deduplication tests
2. Run full verification matrix scenarios
3. Document gaps and deferred items

### Sprint 4: Failure Isolation + Documentation
1. Test failure scenarios
2. Record all evidence
3. Update Phase 12 doc with results

## Evidence to Record

For each workstream:
- Exact commands run
- Environment (local/staging/CI)
- Test output / SQL plans / timings
- Memory/connection observations
- Defects found and resolutions
- Gaps and deferred controls

## Success Criteria

- ✅ All endpoints have tested authorization boundaries
- ✅ Concurrent same-tuple ingestion verified against real DB
- ✅ Query plans and resource usage measured (not assumed)
- ✅ Analytics failures don't break normal content usage
- ✅ All gaps explicitly recorded for release decision