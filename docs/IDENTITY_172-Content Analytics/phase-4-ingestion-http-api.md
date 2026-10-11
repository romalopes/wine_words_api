# Content Analytics — Phase 4: Ingestion HTTP API

## Status

**Completed** — October 11, 2026. HTTP endpoint contract, OpenAPI spec, validation, and integration with Phase 3 ingestion service designed.

## Objective

Expose the validated ingestion flow through a small, safe API endpoint that does not reveal private exclusion decisions.

## Scope

- Add the audited route/controller for `POST /api/v1/analytics/views`.
- Validate allowlisted content types, IDs, UUIDs and limited source/navigation metadata.
- Authenticate supplied credentials; expired or malformed credentials must use existing authentication errors rather than anonymous fallback.
- Return one neutral valid-event response such as `{"accepted":true}` for counted and intentionally ignored requests.

## Implemented in this phase

**Endpoint contract, OpenAPI spec, validation rules, and integration with Phase 3 service designed and recorded below.** Controller exists from Phase 3; this phase finalizes the public contract.
---

## 1. Route

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    namespace :analytics do
      post "views", to: "views#create"   # alias for Phase 3's events#create
    end
  end
end
```

**Note**: Phase 3 created `POST /api/v1/analytics/events`. This phase adds a semantic alias `POST /api/v1/analytics/views` that routes to the same controller action. Both paths accepted; `views` is the public contract.

---

## 2. OpenAPI 3.1 Specification

```yaml
# doc/openapi/analytics.yaml
openapi: 3.1.0
info:
  title: Wine Words Analytics Ingestion API
  version: "1.0"
  description: |
    Client-side beacon endpoint for content view tracking.
    Returns 202 Accepted for all valid requests (counted or intentionally ignored).
    Never reveals exclusion reasons (admin, author, opt-out, draft).
servers:
  - url: https://api.winewords.example/api/v1
    description: Production
  - url: http://localhost:3000/api/v1
    description: Development

paths:
  /analytics/views:
    post:
      summary: Record a content view
      operationId: recordView
      security:
        - bearerAuth: []      # Optional — authenticated users get account: identity
        - visitorId: []       # Optional — anonymous users send X-Visitor-ID header
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ViewEventRequest'
      responses:
        '202':
          description: Event accepted (counted or intentionally ignored)
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ViewEventResponse'
              example:
                accepted: true
        '400':
          description: Invalid payload
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
              example:
                error: "Invalid content_type"
        '422':
          description: Unprocessable entity (valid JSON, invalid values)
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
              example:
                error: "Content not found"
        '415':
          description: Unsupported Media Type
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
              example:
                error: "Content-Type must be application/json"
        '429':
          description: Rate limited
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
              example:
                error: "Rate limit exceeded"
        '503':
          description: Analytics service temporarily unavailable
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
              example:
                error: "Service unavailable"

components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
    visitorId:
      type: apiKey
      in: header
      name: X-Visitor-ID
      description: Anonymous visitor UUID (client-generated, stored in localStorage)

  schemas:
    ViewEventRequest:
      type: object
      required: [event_type, content_type, content_id]
      properties:
        event_type:
          type: string
          enum: [view]
          description: "Only 'view' supported in V1"
        content_type:
          type: string
          enum: [Article, Review, Wine]
          description: "Allowlisted content types"
        content_id:
          type: integer
          minimum: 1
          description: "Database ID of the content"
        occurred_at:
          type: string
          format: date-time
          description: "Client timestamp (logged only; server uses receipt time)"
        source:
          type: string
          enum: [direct, search, internal, external]
          description: "Navigation source (untrusted; discarded if invalid)"
        referrer:
          type: string
          maxLength: 500
          description: "HTTP Referer header (untrusted; truncated)"
        viewport:
          type: string
          maxLength: 32
          pattern: '^\d+x\d+$'
          description: "Screen viewport (untrusted; discarded if invalid)"

    ViewEventResponse:
      type: object
      properties:
        accepted:
          type: boolean
          const: true
          description: "Always true for valid requests; never reveals exclusion"

    ErrorResponse:
      type: object
      properties:
        error:
          type: string
          description: "Generic error message; no internal details"
```
---

## 3. Request Validation Rules

| Field | Rule | Invalid → Response |
|-------|------|-------------------|
| `event_type` | Must equal `"view"` | 422 `{"error":"Invalid event_type"}` |
| `content_type` | Must be `Article`, `Review`, or `Wine` | 422 `{"error":"Invalid content_type"}` |
| `content_id` | Integer > 0; record must exist | 422 `{"error":"Content not found"}` |
| `occurred_at` | ISO 8601 datetime (optional) | Ignored if invalid; logged only |
| `source` | Enum: `direct`, `search`, `internal`, `external` | Discarded if invalid |
| `referrer` | String ≤ 500 chars (optional) | Truncated to 500 |
| `viewport` | Pattern `^\d+x\d+$` (optional) | Discarded if invalid |

**Authentication**:
- Valid JWT (Bearer token) → `current_user` available for identity resolution
- Invalid/expired JWT → **401 Unauthorized** (standard Devise error), NOT anonymous fallback
- No auth header + `X-Visitor-ID` header → anonymous `visitor:` identity
- No auth header + no `X-Visitor-ID` → server generates `visitor:` UUID

---

## 4. Controller: `app/controllers/api/v1/analytics/views_controller.rb`

```ruby
module Api
  module V1
    module Analytics
      class ViewsController < ApplicationController
        # Public endpoint — no authentication required
        skip_before_action :authenticate_user!, only: [:create]
        skip_before_action :enforce_email_verification!, only: [:create]
        skip_before_action :verify_authenticity_token, only: [:create]

        before_action :ensure_json_request

        # POST /api/v1/analytics/views
        def create
          # Delegate to shared ingestion service (Phase 3)
          result = Analytics::Ingest.call(
            event_type: params[:event_type],
            content_type: params[:content_type],
            content_id: params[:content_id]&.to_i,
            identity: build_identity,
            occurred_at: parse_occurred_at,
            source: params[:source],
            referrer: params[:referrer],
            viewport: params[:viewport],
            current_user: current_user
          )

          # Neutral response — never reveals exclusion
          if result.success?
            head :accepted, content_type: "application/json", json: { accepted: true }
          else
            # Invalid payload → 422; valid but excluded → 202 (neutral)
            case result.error_code
            when :invalid_event_type, :invalid_content_type, :invalid_identity
              render json: { error: "Invalid #{result.error_code.to_s.split('_').last}" }, status: :unprocessable_entity
            when :content_not_found
              render json: { error: "Content not found" }, status: :unprocessable_entity
            else
              # excluded_admin, excluded_author, opt_out, inaccessible, database_error
              head :accepted, content_type: "application/json", json: { accepted: true }
            end
          end
        end

        private

        def ensure_json_request
          unless request.content_type&.include?("application/json")
            render json: { error: "Content-Type must be application/json" }, status: :unsupported_media_type
          end
        end

        def build_identity
          if current_user&.persisted? && !current_user.analytics_opt_out?
            "account:#{current_user.id}"
          else
            visitor_uuid = request.headers["X-Visitor-ID"] || SecureRandom.uuid
            "visitor:#{visitor_uuid}"
          end
        end

        def parse_occurred_at
          Time.zone.parse(params[:occurred_at]) if params[:occurred_at].present?
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
```

---

## 5. Rate Limiting

**Strategy**: Reuse existing `Rack::Attack` configuration (if present) or add analytics-specific throttle.

```ruby
# config/initializers/rack_attack.rb (addition)
Rack::Attack.throttle("analytics/views/ip", limit: 300, period: 1.minute) do |req|
  req.ip if req.path == "/api/v1/analytics/views" && req.post?
end

Rack::Attack.throttle("analytics/views/visitor", limit: 60, period: 1.minute) do |req|
  req.headers["X-Visitor-ID"] if req.path == "/api/v1/analytics/views" && req.post?
end
```

**Response**: 429 with `Retry-After` header; body `{"error":"Rate limit exceeded"}`.

---

## 6. CORS Configuration

```ruby
# config/initializers/cors.rb (addition)
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch("FRONTEND_ORIGIN", "http://localhost:5173")
    resource "/api/v1/analytics/views",
             headers: :any,
             methods: [:post, :options],
             credentials: false,
             expose: ["Retry-After"]
  end
end
```
---

## 7. Request Specs

```ruby
# spec/requests/api/v1/analytics/views_spec.rb
require "rails_helper"

RSpec.describe "POST /api/v1/analytics/views", type: :request do
  let(:article) { create(:article, :published) }
  let(:valid_payload) do
    {
      event_type: "view",
      content_type: "Article",
      content_id: article.id,
      source: "direct"
    }
  end

  context "authenticated user" do
    let(:user) { create(:user) }
    let(:headers) { { "Authorization" => "Bearer #{user.jwt_token}" } }

    it "returns 202 with accepted: true" do
      post "/api/v1/analytics/views", params: valid_payload, headers: headers
      expect(response).to have_http_status(:accepted)
      expect(json_response["accepted"]).to be true
    end

    it "uses account: identity" do
      expect(Analytics::Ingest).to receive(:call).with(hash_including(identity: "account:#{user.id}"))
      post "/api/v1/analytics/views", params: valid_payload, headers: headers
    end
  end

  context "anonymous with X-Visitor-ID" do
    let(:visitor_id) { "550e8400-e29b-41d4-a716-446655440000" }
    let(:headers) { { "X-Visitor-ID" => visitor_id } }

    it "returns 202" do
      post "/api/v1/analytics/views", params: valid_payload, headers: headers
      expect(response).to have_http_status(:accepted)
    end

    it "uses visitor: identity" do
      expect(Analytics::Ingest).to receive(:call).with(hash_including(identity: "visitor:#{visitor_id}"))
      post "/api/v1/analytics/views", params: valid_payload, headers: headers
    end
  end

  context "anonymous without X-Visitor-ID" do
    it "generates visitor UUID" do
      expect(Analytics::Ingest).to receive(:call).with(hash_including(identity: /\Avisitor:[0-9a-f-]{36}\z/))
      post "/api/v1/analytics/views", params: valid_payload
    end
  end

  context "invalid JWT" do
    let(:headers) { { "Authorization" => "Bearer invalid.token.here" } }

    it "returns 401 (not anonymous fallback)" do
      post "/api/v1/analytics/views", params: valid_payload, headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end
context "invalid payload" do
    it "rejects unknown content_type" do
      post "/api/v1/analytics/views", params: valid_payload.merge(content_type: "User")
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["error"]).to eq("Invalid content_type")
    end

    it "rejects missing content_id" do
      post "/api/v1/analytics/views", params: valid_payload.except(:content_id)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects non-integer content_id" do
      post "/api/v1/analytics/views", params: valid_payload.merge(content_id: "abc")
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects invalid event_type" do
      post "/api/v1/analytics/views", params: valid_payload.merge(event_type: "click")
      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["error"]).to eq("Invalid event_type")
    end
  end

  context "exclusions (neutral 202)" do
    let(:user) { create(:user, :admin) }
    let(:headers) { { "Authorization" => "Bearer #{user.jwt_token}" } }

    it "returns 202 for admin viewing own content" do
      post "/api/v1/analytics/views", params: valid_payload, headers: headers
      expect(response).to have_http_status(:accepted)
      expect(json_response["accepted"]).to be true
    end

    it "returns 202 for opted-out user" do
      user.update!(analytics_opt_out: true)
      post "/api/v1/analytics/views", params: valid_payload, headers: headers
      expect(response).to have_http_status(:accepted)
    end

    it "returns 202 for inaccessible content" do
      draft = create(:article, :draft)
      post "/api/v1/analytics/views", params: valid_payload.merge(content_id: draft.id), headers: headers
      expect(response).to have_http_status(:accepted)
    end
  end

  context "rate limiting" do
    it "returns 429 when threshold exceeded" do
      301.times { post "/api/v1/analytics/views", params: valid_payload }
      expect(response).to have_http_status(:too_many_requests)
    end
  end

  context "CORS" do
    it "allows configured origin" do
      post "/api/v1/analytics/views", params: valid_payload, headers: { "Origin" => "http://localhost:5173" }
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("http://localhost:5173")
    end
  end
end
```

---

## 8. Integration with Phase 3

- Controller calls `Analytics::Ingest.call` (same as `EventsController`)
- `Analytics::IngestJob` enqueued asynchronously
- Advisory lock deduplication runs in job
- Neutral 202 response returned immediately

---

## 9. ADRs Extended in This Phase

### ADR-013: Neutral 202 Response for All Valid Requests
**Decision**: Return `202 Accepted` + `{"accepted":true}` for counted events AND intentionally ignored events (admin, author, opt-out, inaccessible).
**Rationale**: Prevents client-side inference of user roles, content visibility, or opt-out status. Privacy-preserving by design.

### ADR-014: Invalid JWT → 401, Not Anonymous Fallback
**Decision**: Expired/malformed Bearer token returns standard 401; does NOT fall back to anonymous tracking.
**Rationale**: Matches existing API convention (Devise JWT behavior). Prevents token stuffing to bypass exclusions.

### ADR-015: Semantic Alias `/views` for Public Contract
**Decision**: Keep Phase 3's `/events` endpoint; add `/views` as public contract alias.
**Rationale**: `/events` is generic; `/views` is semantically clear for beacon. Both route to same logic.

---

## Required outputs and acceptance criteria

- ✅ OpenAPI 3.1 spec for `POST /api/v1/analytics/views`.
- ✅ Request validation rules matching spec.
- ✅ Controller with neutral 202 response, proper error codes.
- ✅ Rate limiting (IP + visitor) with 429 response.
- ✅ CORS configuration for frontend origin.
- ✅ Request specs covering auth, anonymous, invalid payload, exclusions, rate limit, CORS.
- ✅ ADRs 013–015 recorded.

## Validation evidence to record

- OpenAPI spec validates against `openapi` CLI.
- Request specs pass: 202 for valid, 422 for invalid payload, 401 for bad JWT, 429 for rate limit.
- Neutral response verified: admin/author/opt-out/inaccessible all return `{"accepted":true}`.
- CORS headers present for configured origin.
- No exclusion reason leaked in response body or headers.

## Next phase

Proceed to [Phase 5 — Frontend tracking](phase-5-frontend-tracking.md) to integrate the beacon into React detail pages.
```