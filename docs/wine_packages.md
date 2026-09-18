# Wine packages

Receiving wines from producers, and tracking the reviews they need.

A **WinePackage** is the unit of work behind the reviewing workflow: a producer
sends (or announces) one or more wines to Wine Words, a reviewer owns the
package, and every wine that was flagged as needing a review must end up with a
**published** review.

The feature is deliberately **producer-centric and reviewer-owned**. It adds the
workflow without changing how wines, vintages or reviews already work:

* the existing `reviews` table is **untouched** — no column was added to it;
* `Producer` gained no account/billing coupling;
* a review created directly on a vintage (the long-standing path) is completely
  unaffected.

---

## 1. Domain model

```
                    Producer
                        |
                        | 1..n
                        v
                  WinePackage <--------------- User (reviewer, created_by,
                /     |      \                           accepted_by, rejected_by)
      1..n     /      |       \   1..1
              v      v        v
   WinePackageItem  ShipmentTracking    Notification (recipient)
        |            |
        | 0..n       | 0..n
        v            v
      Review   ShipmentTrackingEvent
        ^
        |
   Vintage ---> Wine ---> Producer        (the existing catalogue)
```

Rows below a table are its children (`has_many`), rows above are its parents
(`belongs_to`). `WinePackageItem.vintage_id` is **optional**: a line can be
recorded before its wine exists in the catalogue.

### Tables

| Table | Purpose | Notes |
|---|---|---|
| `wine_packages` | the shipment + workflow state | `producer_id` NOT NULL; `reviewer_id`, `created_by_id`, `accepted_by_id`, `rejected_by_id` → `users` |
| `wine_package_items` | one wine line inside a package | `vintage_id` and `review_id` optional; **no** unique index on `(wine_package_id, vintage_id)` |
| `shipment_trackings` | carrier-independent tracking row | exactly one per package (unique index) |
| `shipment_tracking_events` | the carrier's milestone history | unique `(wine_package_id, external_id)` for idempotent imports |
| `notifications` | reminder events (email + future in-app) | unique `(wine_package_id, notification_type, scheduled_date)` |

### Deliberate modelling decisions

* **One link, one truth.** An item points at its review through
  `wine_package_items.review_id`. There is no `reviews.wine_package_item_id`
  column — that would store the same fact twice, and the two copies can drift.
* **No Project association.** The application has no `Project` model, so adding
  the FK would only create a dangling reference. If a Project model is ever
  introduced, an optional `project_id` can be added additively.
* **`status` / `source` are string-backed enums** (the codebase convention, cf.
  `Review#status`, `Producer#producer_type`) *plus* an explicit transition guard,
  because a Rails enum alone does not enforce a legal workflow.
* **`reviewed` is never stored.** It is derived from the linked review's status
  (`item.review&.status == "published"`), so unpublishing a review immediately
  reopens the work.
* **The same vintage may appear in several packages, and twice in one.** No
  uniqueness is enforced, because that is the real-world case.

---

## 2. Lifecycle

### Statuses

| Status | Meaning |
|---|---|
| `draft` | recorded, not yet part of the workflow |
| `requested` | a producer asked Wine Words to review these wines |
| `accepted` | Wine Words agreed to the request |
| `rejected` | Wine Words declined (a reason is required) |
| `announced` | the producer says wines are on their way |
| `in_transit` | shipped |
| `arrived` | physically received — **starts the review clock** |
| `reviewing` | reviews are being written |
| `completed` | finished (automatically or deliberately) |
| `cancelled` | abandoned |

`TERMINAL_STATUSES = %w[completed cancelled rejected]` drive the `active` scope
and the reminder scheduler. `overdue?` agrees with the `overdue` scope and
returns false for all three, so finished business is never reported as overdue.

### Sources

| Source | Meaning |
|---|---|
| `manual` | entered by hand (the default) |
| `unexpected` | a delivery nobody was expecting |
| `producer_request` | the producer asked for a review |
| `producer_announcement` | the producer announced a shipment |

The frontend's four creation modes map onto these: *Record Received Package* →
`arrived`/`unexpected`, *Add Expected Package* → `announced`/`manual`,
*Add Producer Request* → `requested`/`producer_request`, *New Wine Package* →
`draft`/`manual`.

### Legal transitions

`WinePackage::VALID_TRANSITIONS` is the single source of truth. The model
publishes `can_transition_to?(status)` (which the API's `can` map exposes to the
UI) and `transition_to!(status)`, which raises `WinePackage::InvalidTransition`
for a move the workflow forbids.

| From | May move to |
|---|---|
| `draft` | `requested`, `announced`, `arrived`, `cancelled` |
| `requested` | `accepted`, `rejected`, `announced`, `in_transit`, `arrived`, `cancelled` |
| `accepted` | `announced`, `in_transit`, `arrived`, `cancelled` |
| `rejected` | — (terminal) |
| `announced` | `in_transit`, `arrived`, `cancelled` |
| `in_transit` | `arrived`, `cancelled` |
| `arrived` | `reviewing`, `completed`, `cancelled` |
| `reviewing` | `completed`, `arrived`, `cancelled` |
| `completed` | `reviewing` (undo a mistake) |
| `cancelled` | `draft` |

A package may be **created** in `draft`, `announced`, `requested` or `arrived`
only. Everything else is reached through a workflow action, so a status can
never be written straight into the column from the API.

### Workflow actions

| Method | Effect |
|---|---|
| `request!(at:)` | `draft` → `requested`, stamps `requested_at` (kept if already set) |
| `accept!(by:, at:)` | `requested` → `accepted`, records actor/time, clears any rejection state |
| `reject!(by:, reason:, at:)` | `requested` → `rejected`, records reason + actor (**reason required**) |
| `mark_in_transit!` | → `in_transit` |
| `mark_arrived!(at:)` | → `arrived`, sets `arrived_at`, computes `review_deadline` |
| `start_reviewing!` | `arrived` → `reviewing` |
| `mark_completed!(at:)` | → `completed`, stamps `reviewed_at` |
| `reopen!` | `completed` → `reviewing`, clears `auto_completed` |
| `cancel!` | → `cancelled` |

### The review clock

`WinePackages::MarkArrived.call(package, at:, deadline:)` is the only supported
way to record an arrival:

```ruby
package.arrived_at      ||= at                      # keeps any explicit value
package.review_deadline ||= arrived_at.to_date >> 1 # ONE CALENDAR MONTH
```

* `>>` is a true calendar month, so 2026-12-15 → 2027-01-15 (year rollover) and
  2026-01-31 → 2026-02-28 (shorter month) behave correctly.
* An explicitly supplied deadline always wins — the service never overwrites a
  date a person typed in.
* `review_deadline` and `expected_at` are **dates**, not datetimes: the reminder
  arithmetic and the UI countdown are then timezone-free.
* `WinePackage` validates that a deadline is never *earlier* than the arrival
  date.

### Completion: automatic vs deliberate

`WinePackages::CheckCompletion.call(package)` is the single source of truth for
**automatic** completion, and it is idempotent:

| Rule | Behaviour |
|---|---|
| Only `review_requested` lines are ever considered | a non-review wine never blocks anything |
| A package with **no** requested lines never auto-completes | otherwise a request-free package would close itself the moment a wine was added |
| Only `arrived` / `reviewing` may auto-complete | a draft/announced/in-transit package is never completed for you |
| `cancelled` / `rejected` are ignored | finished business |
| Auto-complete when every requested line has a **published** review | status → `completed`, `reviewed_at` stamped, `auto_completed = true` |
| Reopen when that stops being true | an `auto_completed` package returns to `reviewing` |
| A **deliberate** completion is never undone | `WinePackages::MarkCompleted` leaves `auto_completed = false` |

That last row is why the `auto_completed` flag exists: both completions look
identical in `status`, but only the automatic one may be reversed on the user's
behalf. A reviewer who clicked *Mark completed* with reviews still outstanding
keeps that decision even if they later publish or unpublish a review.

It is invoked from:

| Trigger | Hook |
|---|---|
| a linked review is published / unpublished | `Review` `after_save`, `if: :saved_change_to_status?` |
| an item's review link changes | `WinePackageItem` `after_save` |
| `review_requested` is switched on/off | `WinePackageItem` `after_save` |
| **a review-requested line is added** | `WinePackageItem` `after_save` (it cannot complete anything, but it *must* reopen an auto-completed package) |
| a line is removed | `WinePackageItem` `after_destroy` |
| items are created/updated/deleted through the API | the controllers (covers the paths a hook cannot see) |
| `mark_arrived` | the controller, so a package whose reviews already exist completes immediately |

---

## 3. Review integration

A review is started **from a package line** with
`WinePackages::CreateReviewFromPackage.call(item, user:, attributes:)`:

1. it validates that the line is `review_requested`, has a vintage and no review
   yet, and that a reviewer was supplied — otherwise `WinePackages::Error` is
   raised;
2. it builds the review through the **ordinary** `Review` path, so every existing
   rule applies unchanged: score/title presence, slug generation, drink-window
   consistency, images and categories;
3. it saves the review *first*, then writes the link
   (`item.update!(review: review)`), which is what triggers the item-side
   completion check.

Order matters. If the link were written before the review existed, the `Review`
completion hook would fire against a half-built association; saving first also
means a published review created in one step completes the package immediately.

Afterwards the item exposes `review_id`, `review_status`, `review_slug`,
`reviewed` (published?) and `pending_review`, which is exactly what the detail
screen renders. Unpublishing the review flips `reviewed` back to false and
reopens the package if it had auto-completed.

Files are unaffected: the link lives on the item, so `Review` keeps its existing
save path, and reviews created directly on a vintage simply have no item.

---

## 4. Notifications

`Notification` is one event per reminder, shared by email delivery and the
future in-app list. Types currently in use:

| Type | Meaning |
|---|---|
| `wine_package_deadline` | a review deadline reminder (15 / 5 / 0 days before it is due) |
| `wine_package_arrived` | reserved |
| `wine_package_completed` | reserved |
| `wine_package_rejected` | reserved |

### Scheduling

`WinePackages::Notifications::Schedule.call(package, at: Date.current)` creates
the reminders for `THRESHOLD_DAYS = [15, 5, 0]`:

* each reminder's `scheduled_date` is the day it should go out
  (`review_deadline - 15`, `- 5`, `- 0`), so the three rows are distinct and the
  `(wine_package_id, notification_type, scheduled_date)` unique index makes the
  whole thing idempotent;
* dates already in the past are skipped (nothing is sent for a deadline that has
  effectively passed), and so are finished packages;
* rows start undelivered (`sent_at` nil) — this service never emails anything;
* the recipient is the reviewer, falling back to whoever recorded the package;
* the message names the producer, the number of pending reviews and the lead
  time ("in 15 days" / "is today"), measured **on the day the reminder goes
  out**.

### Delivery

`WinePackages::SendReviewDeadlineNotificationsJob` runs daily
(`config/recurring.yml` → `wine_package_review_deadline_reminders`,
`at 7am every day`, queue `background`) and does exactly two things:

1. top up the reminders for every `WinePackage.active` with a deadline;
2. deliver every `Notification.undelivered.for_date(..today)` whose type is
   `wine_package_deadline`, marking `sent_at`.

Delivery is skipped for packages that are no longer active, so a package
completed or cancelled after its reminders were scheduled never emails the
reviewer. `WinePackagesMailer#review_deadline_notification` renders both a text
and an HTML part, listing the wines still waiting and linking to
`FRONTEND_URL/wine-packages/:id`. A single bad address or hiccup is logged and
skipped — one failure must never stop the batch (the same contract as
`Billing::ReconcileSubscriptionsJob`).

Idempotency notes: `Notification.notify!` looks the row up by its **dedup key**
(not by the full attribute set), because Rails' `find_or_create_by!` retries the
lookup with *all* attributes and would raise `RecordNotFound` for a reminder
that belongs to somebody else. A reminder is therefore never duplicated, and if
two people ask for the same package/day the first recipient wins.

---

## 5. Shipment tracking

Tracking is **carrier-independent and optional**. The package workflow works
with no carrier account at all, and a reviewer can always maintain the status by
hand.

```
ShipmentTracking#provider_impl ──> TrackingProvider.for(provider)
                                     ├── Manual          (always available)
                                     └── AustraliaPost  (API only with a key)
```

Every provider answers the same normalised contract:

```ruby
track(number) => {
  status:,               # carrier status text
  status_updated_at:,    # when the carrier last changed it
  estimated_delivery_at:,
  delivered_at:,         # informational only
  url:,                  # human tracking page
  events: [ { external_id:, status:, event_at:, location:, message:, raw_data: } ]
}
```

* `TrackingProvider.for` accepts a provider key **or** a carrier name, so
  `"Australia Post"`, `"AUSPost"` and `"australia_post"` all resolve to the same
  provider; everything else falls back to `manual`. `ShipmentTracking` infers the
  provider from the carrier name, so callers only have to set the carrier.
* `ShipmentTracking#refresh!` asks the provider and applies the result;
  `ShipmentTracking#apply_result!` writes **only the keys the provider
  returned**, so a provider that yields nothing (manual entry, an unreachable
  carrier API) can never wipe data a reviewer typed in.
* Provider events are stored in `shipment_tracking_events` and upserted by
  `external_id`; Australia Post events without an id are fingerprinted from
  their date/location/description, so re-importing a payload is idempotent.
* After every save the row projects its current values onto the package
  (`tracking_carrier`, `tracking_number`, `tracking_url`, `tracking_status`,
  `tracking_status_updated_at`, `estimated_delivery_at`, `delivered_at`) so the
  package list can show the shipping state without a join.
* **A carrier "Delivered" never marks a package as arrived.** It is surfaced as
  "confirm arrival" in the UI instead — only a person confirms that the wines
  physically turned up.
* With no `AUSTRALIA_POST_API_KEY` the Australia Post provider still builds the
  human tracking URL and reports `provider_configured: false`, so the UI can
  explain why nothing was fetched rather than appearing broken.

---

## 6. API reference

All endpoints live under `/api/v1` and require a Bearer JWT (the
application-wide `authenticate_user!`), exactly like every other namespaced
resource.

### Packages

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/wine_packages` | list (paginated envelope when `page` is given, plain array otherwise) |
| `POST` | `/wine_packages` | create — `status` selects the entry point |
| `GET` | `/wine_packages/:id` | detail (items, tracking snapshot, progress, `can`) |
| `PATCH` | `/wine_packages/:id` | update editable attributes |
| `DELETE` | `/wine_packages/:id` | delete (cascades to items, tracking, events, reminders) |
| `POST` | `/wine_packages/:id/mark_arrived` | arrival (+ review clock, + reminders) |
| `POST` | `/wine_packages/:id/mark_in_transit` | shipped |
| `POST` | `/wine_packages/:id/mark_completed` | deliberate completion |
| `POST` | `/wine_packages/:id/reopen` | undo a completion |
| `POST` | `/wine_packages/:id/cancel` | abandon |
| `POST` | `/wine_packages/:id/accept` | accept a producer request |
| `POST` | `/wine_packages/:id/reject` | reject a producer request (`rejection_reason`) |

`index` filters: `status`, `source`, `producer_id`, `reviewer_id`,
`overdue=true`, `due_within_days=N`, `query` (matches producer name, notes or
tracking number), plus the standard `page` / `per_page`.

`create` body (`wine_package`): `producer_id`, `reviewer_id`, `source`, `notes`,
`expected_at`, `arrived_at`, `review_deadline`, and any tracking snapshot column.
Two rules are enforced:

* **`status` is only honoured as an entry point** — `draft` (default),
  `announced`, `requested` or `arrived`. Anything else is a `422`.
* **`status` and `source` are not writable through `PATCH`**; they belong to the
  workflow actions, so an edit can never rewrite provenance.

### Items

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/wine_packages/:wine_package_id/items` | add a wine line |
| `PATCH` | `/wine_packages/:wine_package_id/items/:id` | update a line |
| `DELETE` | `/wine_packages/:wine_package_id/items/:id` | remove a line |
| `POST` | `/wine_packages/:wine_package_id/items/:id/create_review` | start the review (body: `review`) |

Item body: `vintage_id` (optional), `quantity` (> 0), `review_requested`,
`condition`, `notes`, `received_at`, `review_id`.

### Tracking

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/wine_packages/:wine_package_id/shipment_tracking` | read (404 when none recorded) |
| `PATCH` | `/wine_packages/:wine_package_id/shipment_tracking` | upsert (201 first time, 200 after) |
| `POST` | `/wine_packages/:wine_package_id/shipment_tracking/refresh` | refresh from the resolved provider |

Body (`shipment_tracking`): `carrier`, `number`, `url`, `provider`, `status`,
`estimated_delivery_at`, `delivered_at`.

### Notifications

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/notifications` | the caller's notifications (`unread=true`, `date=`, `type=`) |
| `PATCH` | `/notifications/:id/mark_read` | mark one read |
| `PATCH` | `/notifications/mark_all_read` | mark every unread one read |

Another user's notification is a `404`, never a `403`, so the endpoint never
reveals that it exists.

### Error contract

| Situation | Response |
|---|---|
| illegal workflow move | `422` `{ "error": "cannot transition from …" }` |
| `WinePackages::Error` (e.g. line not requested for review) | `422` `{ "error": "…" }` |
| model validation failure | `422` `{ "errors": [ … ] }` |
| not permitted | `403` `{ "error": "Forbidden" }` |
| package not visible to the caller | `404` `{ "error": "Wine package not found" }` |

### Serializer contract

The detail payload carries everything the UI needs, including a `can` map so a
button is never offered for a move the transition guard would reject:

```json
{
  "id": 7, "status": "arrived", "source": "unexpected",
  "arrived_at": "…", "review_deadline": "2026-10-15", "auto_completed": false,
  "review_progress": { "requested": 3, "reviewed": 1, "pending": 2, "percent": 33 },
  "pending_review_count": 2, "reviews_complete": false,
  "overdue": false, "days_until_deadline": 20,
  "tracking": { "carrier": "Australia Post", "number": "AP1", "status": "In transit",
                "delivered_at": null, "url": "…" },
  "items": [ { "id": 11, "label": "Bin 389 2020", "quantity": 2,
               "review_requested": true, "reviewed": false, "pending_review": true,
               "review_id": null, "review_status": null, "review_slug": null } ],
  "can": { "mark_in_transit": false, "mark_arrived": false, "start_reviewing": false,
           "mark_completed": true, "reopen": false, "cancel": true,
           "accept": false, "reject": false }
}
```

`review_progress.percent` is **100** when nothing was requested: there is nothing
left to block, so a request-free package is not shown as 0% complete.

---

## 7. Authorization

Ownership lives in one place, `WinePackageAuthorizable`, so every controller
agrees:

| Action | Who may do it |
|---|---|
| `GET /wine_packages` | content managers see every package; everyone else sees only the ones they review or recorded |
| `GET /wine_packages/:id` | as above — otherwise **404** (never 403, so existence is not revealed) |
| `POST /wine_packages` | `wine_manager?` (Admin/Editor) **or** the `Reviewer` role |
| `PATCH` / `DELETE` / every workflow action | `wine_manager?` **or** `package.reviewer_id == current_user.id` |
| items, tracking, `create_review` | same as managing the package |

`User#wine_manager?` is `admin? || role?(:editor)`. The `Reviewer` role is
accepted **only** when recording a new package — the person who opens the box is
exactly who needs to log it — and it never grants access to somebody else's
package.

The frontend mirrors this: `canAccessPackages(user)` (Admin/Editor/Reviewer)
gates the navigation and create buttons, while management controls require
`canManageWinesRole(user) || pkg.reviewer_id === user.id`.

---

## 8. Frontend

| Route | Component | Purpose |
|---|---|---|
| `/wine-packages` | `WinePackages.jsx` | list + URL-backed filters (status, source, overdue, search) |
| `/wine-packages/new` | `WinePackageForm.jsx` | create (`?mode=arrived\|announced\|requested\|draft`) |
| `/wine-packages/:id` | `WinePackageDetail.jsx` | detail, workflow actions, wine lines, tracking |
| `/wine-packages/:id/edit` | `WinePackageForm.jsx` | edit |
| `/notifications` | `Notifications.jsx` | the reviewer's reminders |

Supporting components: `WinePackageItemForm.jsx` (add/edit a line, with the wine
picker), `PackageReviewForm.jsx` (start a review), `ShipmentTrackingPanel.jsx`,
`PackageStatusBadge.jsx`, `NotificationBell.jsx` (header unread count). Shared
vocabulary and helpers live in `constants/winePackages.js` (statuses, sources,
labels, badge tones) and `utils/dates.js` (`deadlineLabel`,
`daysUntil`, local-midnight date parsing). API clients: `winePackagesApi`,
`winePackageItemsApi`, `shipmentTrackingsApi`, `notificationsApi` in
`services/api.js`.

The header shows **Wine Packages** for package roles and an unread-reminder
count beside it.

Deliberate UI behaviours: every action button comes from the API's `can` map;
"Mark completed" warns when reviews are outstanding; a carrier "Delivered" is
shown as *confirm arrival* rather than changing the package; the tracking panel
says so when no carrier credentials exist.

Two current limitations worth knowing:

* **Reviewer reassignment is admin-only in the UI**, because `users#search` is
  admin-gated. A proper user picker needs a non-admin-safe lookup endpoint.
* A wine with **no vintages** cannot be linked from a line yet; record it as
  "Not in the catalogue yet" (or as an unmatched line) and match it once the
  vintage exists. Images for a package-created review are added from the review
  page, which already has the image manager.

---

## 9. Environment variables

| Variable | Purpose |
|---|---|
| `FRONTEND_URL` | base URL for the reminder email's link to `/wine-packages/:id` (defaults to `http://localhost:5173`) |
| `AUSTRALIA_POST_API_KEY` | Australia Post API key. **When blank, no carrier call is made** — packages still get a tracking URL |
| `AUSTRALIA_POST_TRACKING_URL` | optional override for the human tracking page prefix |
| `AUSTRALIA_POST_API_URL` | optional override for the tracking API endpoint |

None of them is required: the workflow runs fully without a carrier account.
They live server-side only (Render in production) and are never exposed to
Vite/React.

---

## 10. Audit logging

Every mutating endpoint is audited through the existing `Auditable` concern +
`LogService`, under a dedicated action name:

`wine_package.arrived`, `wine_package.in_transit`, `wine_package.completed`,
`wine_package.reopened`, `wine_package.cancelled`, `wine_package.accepted`,
`wine_package.rejected`, `wine_package_item.review_created`,
`shipment_tracking.created`, `shipment_tracking.updated`,
`shipment_tracking.refreshed`, `notification.read`, `notification.read_all`.

---

## 11. Testing

| Spec | Covers |
|---|---|
| `spec/models/wine_package_spec.rb` | validations, associations, the whole transition matrix, every workflow action, the review clock (calendar month, rollover, clamping), review progress, scopes, `overdue?`, dependent records |
| `spec/models/wine_package_item_spec.rb` | quantity/vintage rules, derived review state, scopes, and the completion/reopen hook scenarios |
| `spec/models/shipment_tracking_spec.rb` | 1:1 uniqueness, provider inference, non-destructive `apply_result!`, `refresh!`, delivery ≠ arrival |
| `spec/models/shipment_tracking_event_spec.rb` | provider events: mapping, `external_id` upsert, fingerprints, ordering |
| `spec/models/notification_spec.rb` | the dedup key, `notify!` idempotency, read/sent stamping, scopes |
| `spec/services/wine_packages/check_completion_spec.rb` | automatic completion, reopening, deliberate completion immunity |
| `spec/services/wine_packages/mark_arrived_spec.rb` | the clock, the reminders, idempotency |
| `spec/services/wine_packages/mark_completed_spec.rb` | deliberate completion semantics |
| `spec/services/wine_packages/create_review_from_package_spec.rb` | review creation, linking, guards, one-step completion |
| `spec/services/wine_packages/notifications/schedule_spec.rb` | threshold dates, wording, skipping rules, idempotency |
| `spec/services/tracking_provider_spec.rb` | provider resolution and offline Australia Post payload mapping |
| `spec/requests/api/v1/wine_packages_spec.rb` | CRUD, entry points, workflow actions, filters, authorization, serializers |
| `spec/requests/api/v1/wine_package_items_spec.rb` | nested item CRUD and `create_review` end to end |
| `spec/requests/api/v1/shipment_trackings_spec.rb` | tracking read/upsert/refresh over HTTP |
| `spec/requests/api/v1/notifications_spec.rb` | index filters, mark read / mark all read, cross-user isolation |
| `spec/jobs/wine_packages/send_review_deadline_notifications_job_spec.rb` | scheduling + delivery, finished-package skipping, idempotency |
| `spec/mailers/wine_packages_mailer_spec.rb` | subject wording, body content, `FRONTEND_URL` link, text + HTML parts |

Frontend (Vitest + Testing Library): `WinePackages.test.jsx`,
`WinePackageDetail.test.jsx`, `WinePackageForm.test.jsx`,
`Notifications.test.jsx`, `NotificationBell.test.jsx`, `utils/dates.test.js`.

```bash
# backend
bin/rails db:prepare
bundle exec rspec spec/models/wine_package_spec.rb      # or the whole suite

# frontend
cd ../wine_prediction && npm test
```

> Do not run two RSpec processes against the same test database at once — the
> resulting failures look like real regressions but vanish on a clean re-run.

---

## 12. Backward compatibility

The feature is additive:

* **No existing table was changed for it.** The `reviews`, `wines`, `vintages`
  and `producers` tables are untouched; the only cross-resource link is the
  nullable `wine_package_items.review_id`.
* A review created directly on a vintage behaves exactly as before — the
  completion hook only fires for reviews that an item references.
* Deleting a package cascades to its own rows and leaves the reviews alone.
  Deleting a **user** detaches (nullifies) the packages they reviewed or
  recorded, and deletes their notifications.
* `Producer` still has no account, and no Producer↔Account coupling was added.

Migrations: `20260918000001`…`20260918000005` and `20260918000007` create the
five tables plus `wine_packages.auto_completed`. (There is deliberately no
`…000006` — an earlier `reviews.wine_package_item_id` migration was dropped in
favour of the single link on the item.)

---

## 13. Future: the producer portal

The model already carries what a future producer-facing workflow needs, without
any redesign:

* `source` distinguishes `producer_request` / `producer_announcement` from
  internal logging, so producer-submitted packages are identifiable today;
* the accept/reject half of the lifecycle exists now — `requested`, `accepted`,
  `rejected`, `requested_at`, `accepted_at`, `accepted_by_id`, `rejected_at`,
  `rejected_by_id`, `rejection_reason` — and is exercised by
  `accept!` / `reject!`;
* the transition guard and services are the single entry point for state
  changes, so a producer-facing controller would call the same code the internal
  API calls;
* `Notification` is a generic recipient + type + polymorphic `notifiable` event,
  so producer notifications need a new type, not a new system.

What is intentionally **not** built yet: a Producer account/auth model, a
producer-facing API surface, and the UI for producer submissions (the reviewer
picker gap noted in §8 is part of the same future work).