# Content Analytics — Phase 0: Repository Audit and Implementation Map

## Status

**Completed** — October 11, 2026 (commit `a3f8c2e` in `wine_words_api`, commit `b7e9d1f` in `wine_words`). All facts below are verified against live source code.

## Objective

Replace the master plan's proposed paths and assumptions with verified facts from the Rails API and React frontend before any analytics code is changed.

## Scope

- Inspect current Wine, Review, Article, User, Account, Like and Comment models and associations.
- Map authentication, roles, authorship/coauthorship, readability, publication, deletion, routes, serializers, UI conventions, tests, PostgreSQL, cache, pooling and deployment.
- Record exact commit identifiers, file paths, absent capabilities and conflicts with the master plan.
- Select one justified atomic deduplication design; PostgreSQL transaction advisory locks remain the default unless an already-shared Redis deployment is verified.

## Implemented in this phase

**Repository audit completed.** Verified findings, commit SHAs, and implementation map recorded below. No feature code delivered.

## 1. Repository Identifiers

| Repository | Commit SHA | Branch | Inspection Date |
|------------|-----------|--------|-----------------|
| `wine_words_api` (Rails API) | `a3f8c2e` | `main` | 2026-10-11 |
| `wine_words` (React SPA) | `b7e9d1f` | `main` | 2026-10-11 |

## 2. Rails API — Core Stack

| Item | Version / Detail | Source |
|------|------------------|--------|
| Ruby | 3.3.x | `Gemfile` |
| Rails | 8.1.3 | `Gemfile.lock` |
| Database | PostgreSQL 16 (pg, pg_trgm, plpgsql) | `db/schema.rb:15-17` |
| Auth | Devise 4.9 + `devise-jwt` (JWT revocation via `JwtDenylist`) | `app/models/user.rb:8-10` |
| Background jobs | Solid Queue (SQL-backed) | `db/schema.rb:552-598` |
| Cable / WebSockets | Solid Cable | `db/schema.rb:531-539` |
| Cache | Solid Cache (SQL-backed) | `db/schema.rb:541-550` |
| Search | PostgreSQL `tsvector` + GIN indexes (`TextSearchable` concern) | `app/models/concerns/text_searchable.rb` |
| Image storage | Active Storage (local in dev, S3-compatible in prod) | `app/models/concerns/imageable.rb` |
| Test framework | RSpec (request + model specs) | `spec/` |
| API versioning | Namespace `Api::V1` under `/api/v1` | `config/routes.rb:8-335` |
| Deployment | Render (Thruster → Puma), `bin/rails health` endpoint | `config/routes.rb:1-6` |
| Feature flags | `EmailVerification.require?`, `TEST_ACCESS_PASSWORD` env | `app/controllers/application_controller.rb:19,21-26` |
## 3. Core Domain Models & Associations (Verified)

### 3.1 User & Account (Distinct Semantics)

| Model | File | Key Associations | Notes |
|-------|------|------------------|-------|
| **User** | `app/models/user.rb` | `has_many :reviews`, `has_many :likes`, `has_many :comments`, `has_many :user_roles → roles`, `belongs_to :subscription`, `has_one :account`, `has_many :user_identities`, `has_many :wine_packages (reviewer)`, `has_many :created_wine_packages`, `has_many :created_article_projects`, `has_many :notifications` | Canonical identity. One `Account` per user (names live here). Roles + subscription are on User. |
| **Account** | `app/models/account.rb` | `belongs_to :user`, `has_one :account_address` | Profile data only (first_name, last_name, phone, date_of_birth). No auth, no roles, no subscription. |
| **UserIdentity** | `app/models/user_identity.rb` | `belongs_to :user` | External OAuth providers (Google, Apple, Microsoft, Facebook). One user → many identities. |

**Key distinction**: Wine/Article/Review *authorship* is `belongs_to :user` (not Account). Account is purely presentational.

### 3.2 Roles & Permissions

| Role (enum key) | Stored Value | Capabilities | Source |
|-----------------|--------------|--------------|--------|
| `admin` | "Admin" | Full access; `admin?`, `super_admin?`, `catalogue_manager?`, `wine_manager?` | `app/models/role.rb:4-10`, `user.rb:97-99,163-165,173-175,182-184` |
| `editor` | "Editor" | `catalogue_manager?`, `wine_manager?` | `user.rb:173-175,182-184` |
| `reviewer` | "Reviewer" | `wine_manager?` (can create wines/vintages/reviews/articles) | `user.rb:167-169,182-184` |
| `reader` | "Reader" | Paid subscriber base role; can comment (`commenter?`) | `user.rb:90,197-199` |
| `guest` | "Guest" | Free tier base role; **cannot** comment (`commenter?` returns false) | `user.rb:90,197-199` |

**Derived permission methods** (on `User`):
- `wine_manager?` → `admin? || editor? || reviewer?` — create/update/destroy wines, vintages, reviews, articles
- `catalogue_manager?` → `admin? || editor?` — manage wine packages, see all packages
- `commenter?` → `roles.where.not(name: "Guest").exists?` — post comments
- `role?(key)` → checks `roles.exists?(name: Role.names[key])`

**Base roles** (`BASE_ROLES = ["Guest", "Reader"]`) are mutually exclusive and driven by subscription (FREE → Guest, paid → Reader). Privileged roles (Reviewer, Editor, Admin) are independent of subscription.
### 3.3 Content Models

| Model | File | Key Associations | Visibility Scopes | Slug / PK |
|-------|------|------------------|-------------------|-----------|
| **Article** | `app/models/article.rb` | `belongs_to :user`, `has_one :article_project`, `belongs_to :category`, `has_many :article_categories → categories`, `has_many :article_tags → tags`, `has_many :article_vintages → vintages → wines`, `has_many :article_producers → producers`, `has_many :article_reviews → reviews` | `published`, `drafts`, `archived`, `visible_to(user)` → `published.or(where(user: user))` | `slug` (unique) |
| **Review** | `app/models/review.rb` | `belongs_to :vintage`, `belongs_to :user`, `belongs_to :category`, `has_many :review_categories → categories`, `has_many :wine_package_items` | `published`, `drafts`, `archived`, `visible_to(user)` → `published.or(where(user: user))` | `slug` (unique) |
| **Wine** | `app/models/wine.rb` | `belongs_to :producer`, `belongs_to :category`, `has_many :vintages`, `has_many :grapes`, `has_many :regions`, `has_many :wine_taste_parameters → taste_parameters` | No draft state — all wines are public | `slug` (unique) |
| **Comment** | `app/models/comment.rb` | `belongs_to :user`, `belongs_to :commentable (polymorphic: Wine/Review/Article)`, `belongs_to :parent (self, optional)`, `has_many :replies` | `visible` (where `deleted_at: nil`), `top_level`, `chronological` | Integer `id` |
| **Like** | `app/models/like.rb` | `belongs_to :user`, `belongs_to :likeable (polymorphic)`, `counter_cache: :likes_count` | None (public count); per-user check via `liked_by?(user)` | Integer `id` (unique index on user+likeable) |

### 3.4 Shared Concerns (Reusable Patterns)

| Concern | Models Using | Provides |
|---------|--------------|----------|
| `Imageable` | Wine, Review, Article | `has_many :images, as: :imageable`, `primary_image`, `attach_images` |
| `Likeable` | Wine, Review, Article | `has_many :likes, as: :likeable`, `liked_by?(user)`, `likes_count` counter cache |
| `Commentable` | Wine, Review, Article | `has_many :comments, as: :commentable`, `visible_comments`, `comment_thread` |
| `TextSearchable` | Article, Review | `text_search(term)`, `ordered_for_search(sort, ranked:)`, `search_vector_sql`, `searchable` tsvector column + GIN index |
## 4. Authentication & Authorization Flow

| Layer | Implementation | Notes |
|-------|----------------|-------|
| **API base** | `ApplicationController` → `before_action :authenticate_user!` (Devise JWT) + `enforce_email_verification!` + `TestAccess` gate | `app/controllers/application_controller.rb:14-26,51-62` |
| **Public read** | `skip_before_action :authenticate_user!, only: [:index, :show, ...]` on content controllers | Articles/Reviews/Wines controllers |
| **Write gates** | `before_action :ensure_wine_manager!` (Admin/Editor/Reviewer) for create; owner-or-wine_manager for update/destroy | `articles_controller.rb:15,196-198`, `reviews_controller.rb:15,207-209`, `wines_controller.rb:15-16` |
| **Admin-only** | `authenticate_admin!` helper (checks `real_current_user&.admin?`) | `application_controller.rb:43-48` |
| **Impersonation** | `Impersonable` concern + `/api/v1/impersonations` | `app/controllers/concerns/impersonable.rb` |

## 5. API Routes (Verified)

| Resource | Key Endpoints | Notes |
|----------|---------------|-------|
| Articles | `GET /articles`, `GET /articles/grouped`, `GET /articles/:slug`, `POST /articles` (wine_manager), `PATCH /articles/:slug`, `DELETE /articles/:slug` | Nested review links via `add_review`, `remove_review`, `toggle_review_status` |
| Reviews | `GET /reviews`, `GET /reviews/grouped`, `GET /reviews/:slug`, `POST /wines/:wine_id/vintages/:vintage_id/reviews` (wine_manager), `PATCH /reviews/:slug`, `DELETE /reviews/:slug` | Nested under vintage for create |
| Wines | `GET /wines`, `GET /wines/grouped`, `GET /wines/:slug`, `GET /wines/search`, `GET /wines/advanced_search`, `POST /wines` (wine_manager), `PATCH /wines/:slug`, `DELETE /wines/:slug` | Vintages nested via `wine_vintages` resources |
| Comments | `GET /comments/:commentable_type/:commentable_id`, `POST /comments` (authenticated, commenter?), `PATCH /comments/:id`, `DELETE /comments/:id` (soft delete) | Polymorphic: Wine/Review/Article |
| Likes | `POST /likes` (authenticated), `DELETE /likes/:id` | Polymorphic; counter cache on likeable |
| Stats | `GET /stats` (public) | Returns counts: producers, wines, published reviews, articles (visible_to current_user) |
| Auth | `POST /api/v1/auth/sign_in`, `POST /api/v1/auth/sign_up`, `DELETE /api/v1/auth/sign_out`, `POST /api/v1/auth/:provider` (OAuth) | Devise + JWT |
| Health | `GET /up` | Render health check |
## 6. Serializers (JSON Payload Shapes)

| Serializer | File | Key Fields |
|------------|------|------------|
| `ArticleListSerializer` | `app/serializers/article_list_serializer.rb` | id, slug, title, abstract, status, published_at, source, user (id, email, display_name), categories, tags, wines, producers, images, likes_count, liked_by_current_user |
| `ArticleSerializer` (detail) | `app/serializers/article_serializer.rb` | List fields + body, related reviews (with vintage/wine/images), vintages, producers, article_project |
| `ReviewListSerializer` | `app/serializers/review_list_serializer.rb` | id, slug, title, score, status, published_at, source, user, vintage (year, wine name, producer), category, images, likes_count, liked_by_current_user |
| `ReviewSerializer` (detail) | `app/serializers/review_serializer.rb` | List fields + comment, drink_window, vintage→wine→producer/regions/grapes, categories, images |
| `WineListSerializer` | `app/serializers/wine_list_serializer.rb` | id, slug, name, color, producer, category, vintage_count, images, likes_count, liked_by_current_user |
| `WineSerializer` (detail) | `app/serializers/wine_serializer.rb` | List fields + vintages, grapes, regions, taste_parameters, wine_profiles |
| `LikeAttributes` (shared) | `app/serializers/like_attributes.rb` | `likes_count`, `liked_by_current_user` (via preloaded `liked_ids` set) |

**Pattern**: List serializers accept `liked_ids: Set` for O(1) `liked_by_current_user` without N+1.

## 7. React Frontend — Detail Pages (Current)

| Component | File | Data Fetching | Key UI Sections |
|-----------|------|---------------|-----------------|
| `ArticleDetail` | `src/components/ArticleDetail.tsx` | `articlesApi.show(slug)` | Hero image, metadata (author, date, status, source), body (sanitized HTML), linked reviews grid, wines/vintages/producers lists, CommentSection, RelatedContent |
| `ReviewDetail` | `src/components/ReviewDetail.tsx` | `reviewsApi.show(slug)` | Hero image, metadata (author, date, score, status, source, categories), comment (sanitized HTML), CommentSection, RelatedContent |
| `WineDetail` | `src/components/WineDetail.tsx` | `winesApi.show(slug)`, lazy loads reviews per vintage via `reviewsApi.index({ vintage_id })` | Hero image, metadata (producer, color, closure, alcohol, volume), vintages accordion with reviews per vintage, taste parameters meters, CommentSection |

**Shared patterns**:
- `LikeButton` (optimistic UI, calls `likesApi.create/delete`)
- `CommentSection` (polymorphic, real-time via `commentsApi`)
- `RelatedContent` (calls `/api/v1/articles/:slug/related` or `/reviews/:slug/related`)
- `ContentStatusActions` (draft/published/archived transitions for owners/wine_managers)
- Role checks via `canManageWinesRole(user)` / `canSeeSource(user)` from `src/constants/roles.ts`

## 8. Existing Analytics Surface

| Endpoint | File | Current Output |
|----------|------|----------------|
| `GET /api/v1/stats` | `app/controllers/api/v1/stats_controller.rb` | `{ producers, wines, reviews (published), articles (visible_to user) }` |

**No view tracking, no event ingestion, no time-series tables, no materialized views, no reporting UI.**

## 9. Testing & CI

| Layer | Tool | Location |
|-------|------|----------|
| Rails model/request specs | RSpec | `spec/models/`, `spec/requests/api/v1/` |
| Frontend unit/component | Vitest + React Testing Library | `wine_words/src/**/*.test.tsx` |
| Frontend E2E | Playwright (configured, smoke tests only) | `wine_words/e2e/` |
| CI | GitHub Actions (runs RSpec, Vitest, typecheck, lint) | `.github/workflows/` |

## 10. PostgreSQL & Performance Notes

- **Full-text search**: `tsvector` column `searchable` on `articles` and `reviews` with GIN indexes (`db/schema.rb:229, 428`).
- **Counter caches**: `likes_count` on `articles`, `reviews`, `wines` (updated by `Like` callbacks).
- **N+1 prevention**: Controllers preload associations explicitly (`includes`, `left_outer_joins`); serializers accept preloaded `liked_ids` sets.
- **Grouped endpoints**: Use window functions (`ROW_NUMBER() OVER (PARTITION BY ...)`) for "N per category" views without client-side pagination.
- **Advisory locks**: Not currently used. **Default deduplication strategy** = PostgreSQL transaction advisory locks (`pg_advisory_xact_lock`) unless Redis is verified as shared infrastructure (not present in `Gemfile` or `docker-compose.yml`).
## 11. Gaps vs. Master Plan Assumptions

| Master Plan Assumption | Verified Reality | Impact |
|------------------------|------------------|--------|
| "User owns Wine" | **False** — Wine has no `user_id`; ownership is via `Article.user`, `Review.user`, `WinePackage.reviewer_id` | Analytics must attribute content to *authors* (User), not Wine |
| "Single role per user" | **False** — `has_many :roles` via `user_roles`; base role + privileged roles can coexist | Permission checks must use `role?` / derived methods, not single enum |
| "Article/Review have same visibility" | **True** — both use `visible_to(user)` scope | Unified visibility logic reusable |
| "Comments use ActsAsCommentable" | **False** — custom polymorphic `Comment` model with soft delete | Event schema must include `commentable_type/id`, `parent_id`, `deleted_at` |
| "Likes use ActsAsVotable" | **False** — custom `Like` with unique index + counter_cache | Event schema must include `likeable_type/id` |
| "Redis available for deduplication" | **False** — no Redis in stack; Solid Queue/Cache/Cable are SQL-backed | Use PostgreSQL advisory locks (Phase 3 decision) |

## 12. Deduplication Strategy Decision (ADR-001)

**Decision**: Use **PostgreSQL transaction advisory locks** (`pg_advisory_xact_lock`) for atomic event deduplication in the ingestion pipeline.

**Rationale**:
- No Redis in current deployment (Render PostgreSQL only).
- Advisory locks are session-scoped, auto-released on transaction end, zero infrastructure cost.
- Proven pattern in Rails (`with_advisory_lock` gem or raw `SELECT pg_advisory_xact_lock(...)`).
- Key = hash of `(event_type, content_type, content_id, user_id, occurred_at::date)` — fits 64-bit space.

**Alternative considered**: `INSERT ... ON CONFLICT` on a unique index — rejected because deduplication window is *per-day* (not per-event), requiring a composite key that includes a date bucket, which advisory locks handle more flexibly.

## 13. Implementation Map — Where New Code Will Live

| Phase | New Backend Files | New Frontend Files | Modified Files |
|-------|-------------------|-------------------|----------------|
| 1 (Contracts) | `app/models/analytics/event.rb`, `app/validators/analytics_event_validator.rb`, `app/policies/analytics_policy.rb` | — | `config/routes.rb` (namespace) |
| 2 (Schema) | `db/migrate/*_create_analytics_tables.rb` | — | `db/schema.rb` (auto) |
| 3 (Ingestion) | `app/controllers/api/v1/analytics/events_controller.rb`, `app/services/analytics/ingest.rb`, `app/jobs/analytics/ingest_job.rb` | — | `config/routes.rb`, `ApplicationController` (skip auth for beacon) |
| 4 (API) | `app/controllers/api/v1/analytics/metrics_controller.rb`, `app/serializers/analytics/metric_serializer.rb` | — | `config/routes.rb` |
| 5 (Frontend) | — | `src/hooks/useAnalytics.ts`, `src/components/analytics/AnalyticsBeacon.tsx`, `src/services/analyticsApi.ts` | Detail pages (`ArticleDetail`, `ReviewDetail`, `WineDetail`) |
| 6 (Reporting) | `app/services/analytics/daily_rollup.rb`, `app/jobs/analytics/daily_rollup_job.rb` | — | — |
| 7 (Dashboard) | `app/controllers/api/v1/analytics/dashboard_controller.rb` | `src/pages/AnalyticsDashboard.tsx`, `src/components/analytics/*` | Routes |
| 8 (Content Detail) | `app/serializers/analytics/content_detail_serializer.rb` | `src/components/analytics/ContentAnalyticsPanel.tsx` | Detail pages |
| 9 (Wine Insights) | `app/services/analytics/wine_insights.rb` | `src/components/analytics/WineInsights.tsx` | WineDetail |
| 10 (Ops) | `app/jobs/analytics/retention_job.rb`, `config/schedule.rb` (if sidekiq-scheduler added) | — | — |
| 11 (Verification) | `spec/requests/api/v1/analytics/` | `src/**/analytics/*.test.tsx` | — |
| 12 (Deploy) | — | — | `render.yaml`, GitHub Actions |
| 13 (Scaling) | Materialized view migrations, partitioning | — | — |

## 14. Unresolved Decisions (Carried to Phase 1)

1. **Event payload versioning** — JSON Schema vs. `jsonb` with `version` column?
2. **Sampling rate** — 100% for authenticated, sampled for anonymous? (Current: no anonymous tracking)
3. **GDPR/CCPA deletion** — Link `analytics_events.user_id` to `User` for cascade? (Current: `user_id` nullable for future anon)
4. **Real-time vs. batch** — Beacon → Sidekiq (Solid Queue) is async; dashboard reads pre-aggregated tables.

## Required outputs and acceptance criteria

- ✅ Verified repository audit, implementation map and ADR-001 recorded under `docs/IDENTITY_172-Content Analytics/`.
- ✅ Every ownership, visibility, role and deletion assertion cites a real code reference above.
- ✅ `User` vs `Account` semantics explicitly distinguished; no Wine ownership inferred.
- ✅ Reusable service, serializer, controller, route, test and frontend patterns identified.
- ✅ Branch/commit inspected in both repositories recorded; unresolved decisions listed.

## Validation evidence to record

- Inspected paths: all files cited in tables above.
- Git commits: `wine_words_api@a3f8c2e`, `wine_words@b7e9d1f`.
- Commands run: `find app/models`, `cat config/routes.rb`, `cat db/schema.rb`, frontend component reads.
- Test tools: RSpec, Vitest, Playwright confirmed available.
- Database: PostgreSQL 16, pg_trgm, plpgsql; no Redis.
- Deduplication rationale: ADR-001 above.

## Next phase

After the audit exit gate is met, proceed to [Phase 1 — Metrics, identity, permissions and privacy](phase-1-metrics-identity-permissions-privacy.md). That phase must use verified Phase 0 facts rather than the proposed names in the master plan.