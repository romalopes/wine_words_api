# Wine Words --- Configurable Per-Bottle Review Fee & Manual Billing
## Detailed implementation plan and AI coding prompts
**Status:** Proposed implementation plan\
**Product:** Wine Words\
**Pricing decision:** AUD \$50 per billable bottle as the initial
configured price\
**Payment approach:** Manual invoicing by email; no payment gateway\
**Architecture:** Rails API + React/Vite frontend\
**Primary goal:** Introduce transparent per-bottle review pricing and a
lightweight, auditable billing workflow without building an accounting
or payment-processing system.

---
## 1. Executive summary
Wine Words will charge a configurable fee for each bottle accepted by
the Wine Words team for review. The initial configured fee is **AUD
\$50.00 per bottle**.

The fee must be configuration-driven. Do not hardcode `50` in
controllers, models, serializers, React components, email templates, or
tests as the business rule. A clearly defined application setting will
provide the current default price and currency. The price shown to a
submitter must be captured as a historical snapshot when the package is
submitted, so future price changes do not alter existing packages.

The submitter sees the current fee, bottle count, and estimated total
before submitting. Submission does not collect payment. After the team
reviews the submission and confirms which bottles are billable, an
Admin/Editor can record the billable quantity, issue an invoice outside
the application, and record the invoice details in Wine Words. The team
later marks the invoice as paid, waived/cancelled, or otherwise updates
its status.

The application must keep these three workflows independent:

1.  **Submission status** --- what is happening to the wine package
    submission.
2.  **Review status** --- progress of review and catalogue work.
3.  **Payment status** --- whether an invoice has been issued and paid.

Overdue should be a derived display state based on an unpaid invoice's
due date. It should not be a separate manually maintained payment
status.
### Decisions fixed for this plan

---
Topic Decision

---
Initial fee **AUD \$50.00 per billable bottle**

Configurability Fee and currency managed through
application configuration

Price display Show price per bottle and estimated
total before submission

Submission payment No payment collected at submission

Billable quantity Number of bottles accepted for
review; staff can confirm or adjust
it

Invoice Prepared and sent manually by the
Wine Words team outside the app

Payment recording Admin/Editor manually records
invoice and payment details

Gateway No Stripe, PayPal, or other payment
gateway in this implementation

Automated PDF invoice Out of scope for the initial
implementation

Automated invoice email Out of scope unless a later phase
is explicitly approved

Payment status Separate from submission and review
statuses

Historical pricing Store immutable
price/currency/amount snapshots for
each package/invoice

---
### Important business rule to confirm during implementation
The public estimate is calculated using the number of bottles included
in the submitted package. The final invoice is calculated using the
number of bottles the team accepts as billable. The user must be told
clearly that the displayed total is an estimate and that the final
billable quantity is confirmed by Wine Words.

Do not silently change the commercial model to charge for every bottle
submitted if the team has accepted fewer bottles for review.

---
## 2. Goals and non-goals
### Goals
- Make the fee visible before a user submits a Wine Package.
- Display the configured fee in AUD and calculate an estimated total
  dynamically.
- Make it straightforward for staff to change the fee without a code
  deployment, if the existing settings architecture supports secure
  application settings.
- Preserve the fee applicable at the time of submission.
- Allow staff to confirm the number of billable bottles.
- Record invoice reference, dates, amount, and payment status.
- Make billing information visible to the package owner.
- Preserve existing Wine Package submission, producer, wine selection,
  and catalogue workflows.
- Enforce Admin/Editor permissions for billing changes.
- Provide audit-friendly timestamps and, where appropriate, a change
  history.
- Keep the implementation compatible with the existing Rails and React
  architecture.
### Non-goals
Do not implement any of the following in this project:

- Payment gateway or online checkout.
- Card storage or payment credentials.
- Automatic bank reconciliation.
- Automatic payment confirmation.
- Full accounting, tax, or bookkeeping software.
- Automatic PDF invoice generation.
- Automatic invoice delivery from Wine Words.
- Automatic overdue reminders.
- Multiple partial payments or instalment schedules.
- Refund processing.
- Subscription billing.
- Volume discounts or negotiated customer-specific rates.
- A general-purpose billing engine.

These can be considered separately after the manual process is
validated.

---
## 3. Repository and architecture context
Known Wine Words repositories:

- Frontend: `https://github.com/romalopes/wine_words_frontend`
- API: `https://github.com/romalopes/wine_words_api`

Known stack from the project context:

- Rails API backend.
- React/Vite frontend.
- Existing Wine Package submission and administration workflows.
- Existing user roles include Guest, Reader, Reviewer, Editor, and
  Admin.
- Existing email infrastructure and staff notification patterns should
  be inspected and reused where appropriate.

The implementation agent must inspect the actual repositories and
current branch before making changes. Do not assume model names, routes,
serializers, component paths, role policies, settings architecture, or
test framework details from this plan. Discover the real implementation
first.

Suggested documentation location in the API repository:

`wine_words_api/docs/FUTURE/Billing/WINE_PACKAGE_BILLING_IMPLEMENTATION_PLAN.md`

This plan is standalone and should also be saved in the project
documentation location if requested.

---
# 4. Functional design
## 4.1 Configurable pricing
Introduce a centrally managed configuration value for the review fee.

Suggested logical settings:

- `wine_review_fee_amount`: `50.00`
- `wine_review_fee_currency`: `AUD`
- Optional `wine_review_fee_active`: `true`, only if the existing
  settings architecture benefits from an enable/disable switch.

The exact storage mechanism must be selected after reconnaissance.
Prefer the existing application settings/configuration pattern if one
exists and is suitable. If no suitable mechanism exists, propose a
small, validated settings model or equivalent persistent configuration
rather than adding a large settings framework.

Requirements:

- Initial amount must be AUD \$50.00.
- Store money using decimal-safe representation (for example, integer
  minor units or a decimal column with appropriate precision); never
  use floating-point arithmetic for currency.
- Validate amount is non-negative and has at most two decimal places.
- Validate currency against the currencies actually supported by the
  product. Initially, AUD is the only required currency.
- Expose the current public price to the submission UI through an
  appropriate API endpoint or existing public settings response.
- Only authorized Admin users should be able to change the global fee
  unless the existing permissions model explicitly supports another
  role.
- Editors may manage package-level billing details only if that
  permission is explicitly granted by the existing role policy.
- Record who changed the configured fee and when, if the settings
  architecture supports auditing.
- Do not retroactively update package price snapshots when the global
  setting changes.

A setting change from AUD \$50 to AUD \$60 should affect new estimates
and new submissions only. Previously submitted packages retain their
captured fee.
## 4.2 Submission estimate
On the Wine Package submission page:

- Display the configured price per bottle.
- Display the number of bottles currently included.
- Calculate the estimated total as `bottle_count × configured_fee`.
- Recalculate immediately when bottles are added or removed.
- Display the currency clearly as AUD.
- Explain that no payment is taken during submission.
- Explain that Wine Words confirms the final billable quantity and
  sends an invoice separately.
- Require an explicit acknowledgement of the fee terms before final
  submission, if consistent with the current form UX.
- Ensure the estimate is also validated/recalculated by the API. Never
  trust a total supplied by the browser.

Suggested copy:

> **Wine review fee**
>
> Wine Words charges AUD \$50.00 per bottle accepted for review. Based
> on the bottles in this submission, your estimated review fee is AUD
> \$\[estimate\].
>
> No payment is required when you submit this package. The Wine Words
> team will review your submission, confirm the number of billable
> bottles, and send an invoice separately. The final invoice may differ
> from this estimate if the number of bottles accepted for review
> changes.

The displayed amount must come from the API's current configuration, not
a duplicated frontend constant.
## 4.3 Package pricing snapshot
When a package is submitted, persist a snapshot of the applicable
pricing context.

Suggested package-level fields (adapt names to existing conventions):

- `review_fee_unit_amount` --- fee per bottle at submission.
- `review_fee_currency` --- currency at submission.
- `submitted_bottle_count` --- count used for the initial estimate, if
  not already reliably available.
- `estimated_review_fee_total` --- initial estimated total.
- `billable_bottle_count` --- final quantity confirmed by staff; may
  initially be null or unset until reviewed.
- `final_review_fee_total` --- final amount confirmed for invoicing;
  may initially be null.
- `payment_status` --- default `not_invoiced`.

Avoid duplicating fields that can be reliably derived from existing
associations. Use database constraints and model validations where
suitable.

A price snapshot is historical data. Do not recalculate it from the
current global fee when rendering old packages.
## 4.4 Final billable quantity and amount
Admin/Editor workflow:

1.  Review the submitted package and its wines.
2.  Confirm how many bottles are accepted for review.
3.  Enter or confirm the billable bottle count.
4.  Calculate the final total using the package's captured unit fee
    unless a specifically authorized adjustment is supported.
5.  Save the confirmed billable quantity and total.
6.  Prepare and send the invoice outside Wine Words.
7.  Record the invoice details and mark the payment status as
    `invoice_sent`.

The application should show both the original estimate and the final
confirmed amount when they differ.

For the initial version, do not introduce arbitrary per-package
unit-price overrides unless the business explicitly needs them. If an
exception is necessary, require an Admin-only adjustment with a reason
and preserve the original captured price and the final agreed amount
separately.
## 4.5 Payment status
Use a separate payment status, independent from submission and review
status.

Recommended values:

- `not_invoiced` --- no invoice has been issued.
- `invoice_sent` --- invoice has been sent externally; payment is
  outstanding.
- `paid` --- staff have confirmed payment.
- `cancelled` or `waived` --- payment is no longer required.

Choose either a combined `cancelled_waived` value or distinct
`cancelled` and `waived` values based on whether the business needs to
distinguish those cases. Keep the first implementation small.

Overdue is derived:

`payment_status == invoice_sent AND invoice_due_at < current_date`

Display `Overdue` as a visual indicator, but retain the underlying
payment status as `invoice_sent`.

Do not automatically mark an invoice as paid based on a date or email.
Only an authorized team member can confirm payment.
## 4.6 Invoice metadata
Suggested fields:

- `invoice_number` --- reference from the externally prepared invoice.
- `invoice_sent_at` --- date/time staff confirm that the invoice was
  sent.
- `invoice_due_at` --- due date.
- `paid_at` --- date/time payment was confirmed.
- `payment_notes` --- internal notes/reference, with suitable length
  limits.
- `payment_status_updated_at` --- optional if timestamps or audit
  history do not already provide this.
- `payment_status_updated_by_id` --- optional association to the staff
  member, if audit history is not available elsewhere.

Store only the metadata needed to track the manual process. Do not store
card/bank credentials. Do not imply that an invoice PDF is attached or
available inside Wine Words.
## 4.7 Multiple invoices
The simplest first version can store one invoice reference per Wine
Package. However, the business statement that the team may add a newly
accepted bottle and send a new invoice later introduces a potential need
for more than one invoice per package.

**Recommended design decision:** use a separate invoice record
associated with the Wine Package if the team expects to issue a second
invoice after the initial invoice. This avoids overwriting the first
invoice's number, amount, sent date, or paid date.

Suggested `WinePackageInvoice` (or project-conventional equivalent)
fields:

- package association
- invoice number
- currency
- amount
- billable bottle count
- unit fee snapshot
- status (`draft` only if useful, otherwise `sent`, `paid`,
  `cancelled`/`waived`)
- sent timestamp
- due date
- paid timestamp
- internal notes
- created/updated timestamps
- creator/updater association if supported

The package can expose an aggregate billing summary, while each invoice
retains its own status and history.

If reconnaissance reveals that the business truly guarantees only one
invoice per package, a simpler package-level metadata implementation is
acceptable. But because later invoices are explicitly anticipated, the
default recommendation is **one package to many invoices**.

Do not implement partial payments in this phase. If an invoice is paid,
mark that invoice paid. If another invoice is later issued, it is a
separate invoice.
## 4.8 Adding bottles after an invoice
When Wine Words adds a newly accepted bottle after an earlier invoice
has been sent:

- Do not silently modify the old invoice amount.
- Preserve the old invoice and its payment status.
- Create a new invoice record for the additional billable bottle(s).
- Use the applicable agreed unit fee, normally the package's captured
  unit fee.
- Staff manually issue the new invoice outside the app and record its
  reference/date/due date.
- The package billing summary must show all invoices and the
  outstanding balance.
- If the original invoice is unpaid, it remains unpaid; the new
  invoice is separately tracked.

The team must be able to explain the difference between: - original
submission estimate, - total bottles accepted for review to date, -
amounts already invoiced, - amounts paid, - current outstanding balance.

For the first version, calculate outstanding balance from invoice
records that are sent and not paid/cancelled/waived. Do not create a
general ledger.

---
# 5. User experience
## 5.1 Public submission page
Add a pricing panel near the bottle list and before the final submit
action.

Display:

- Fee per bottle, e.g. `AUD $50.00`.
- Current number of bottles in the package.
- Estimated total.
- Clear no-payment-at-submission message.
- Explanation that the final billable quantity is confirmed by Wine
  Words.
- Terms acknowledgement if appropriate.

States to handle:

- Loading current price.
- Price unavailable or configuration error.
- No bottles selected.
- Bottle list changes.
- API validation error.
- Existing draft package.
- User returning to edit a draft after the global fee has changed.

For an already submitted package, show its captured estimate, not the
current global price.
## 5.2 User's Wine Package page
Add a Billing section visible only to the package owner and authorized
staff.

Show:

- Initial estimate.
- Confirmed billable bottle count, once available.
- Final confirmed amount.
- Invoice list with invoice number, amount, sent date, due date, and
  status.
- Paid date for paid invoices.
- Outstanding balance.
- Clear instruction to use the invoice's external payment
  instructions.
- No online payment button.

Do not expose internal staff notes to package owners.
## 5.3 Admin/Editor package management
Add a Billing panel to the existing Wine Package administration page.

Staff should be able to:

- See submitted bottle count and original estimate.
- Confirm/update billable bottle count.
- See the resulting final amount.
- Create an invoice record after the external invoice has been
  prepared/sent, or create a draft record only if that is genuinely
  useful.
- Record invoice number, sent date, due date, amount, and notes.
- Mark an invoice paid.
- Cancel/waive an invoice with a reason.
- See who made billing changes and when, if audit support is
  available.
- See all previous invoices and the package-level billing summary.

The UI must make clear that clicking "Record invoice sent" records an
external action; it does not send an invoice itself.
## 5.4 Global pricing configuration UI
Provide a small Admin-only setting in the existing settings area.

Fields:

- Review fee amount.
- Currency (AUD initially; avoid exposing unsupported currencies).
- Save action.
- Current configured value.
- Optional updated-by/updated-at information.

Add confirmation or clear warning that changing the fee affects future
submissions only and does not change existing package snapshots.

---
# 6. Authorization, validation, and security
- Public/Guest users may read the public current price.
- Package owners may read their own package billing summary and
  invoice information.
- Package owners must not change billable quantity, invoice metadata,
  payment status, or staff notes.
- Admin/Editor permissions must follow the existing authorization
  policy. Confirm whether Editors are allowed to perform billing
  actions; do not infer permission from UI visibility alone.
- Only the appropriate privileged role may change global pricing.
- Never accept a client-supplied total as authoritative.
- Recalculate estimates and invoice totals on the server.
- Validate billable quantity is an integer, non-negative, and does not
  exceed the relevant accepted bottle count unless an explicit
  additional-bottle workflow is being used.
- Validate invoice amount is non-negative and currency is supported.
- Validate invoice status transitions.
- A paid invoice must have a `paid_at` timestamp.
- A sent invoice must have an invoice number and sent timestamp,
  unless the existing manual process has a documented exception.
- A cancelled/waived invoice should require a reason or note.
- Prevent unauthorized access to another producer's/package owner's
  invoice data.
- Protect against mass assignment of privileged billing attributes.
- Add audit logging or use existing audit facilities for fee changes,
  billable quantity changes, invoice creation, and payment status
  changes.
- Do not log sensitive payment instructions or bank account details.

---
# 7. Implementation phases
Each phase should be completed and reviewed before starting the next.
The AI coding agent must inspect the real codebase, follow existing
conventions, run relevant tests, and report files changed and
outstanding risks.
## Phase 0 --- Repository reconnaissance and architecture audit
**Purpose:** Understand the current Wine Words implementation before
proposing code changes.

Tasks:

1.  Inspect both repositories and the current Git branch/status.
2.  Locate Wine Package models, controllers, serializers, routes,
    policies, and frontend pages/components.
3.  Trace the full submission flow from React form to Rails persistence.
4.  Identify how bottle/wine submissions are represented and counted.
5.  Inspect the existing package-to-producer relationship and any
    catalogue selection workflow.
6.  Inspect application settings/configuration patterns.
7.  Inspect roles and authorization policies for Admin, Editor, and
    package owners.
8.  Inspect email infrastructure and existing invoice-like or
    staff-notification patterns.
9.  Inspect test frameworks, factories/fixtures, API request specs, and
    frontend test setup.
10. Identify any existing billing, invoice, payment, or monetary fields.
11. Confirm how monetary values are serialized and formatted.
12. Report any schema or workflow conflicts with this plan.

**Deliverables:**

- Architecture summary.
- Relevant file/path inventory.
- Existing workflow diagram or concise sequence.
- Recommended schema and API design.
- Risks and questions.
- No implementation changes in this phase.
### AI Prompt 0 --- Audit before implementation
> You are working on the Wine Words application. Audit the existing
> `wine_words_api` and `wine_words_frontend` repositories before
> implementing configurable per-bottle review billing.
>
> Business requirements: - Initial review fee is AUD \$50.00 per
> billable bottle. - The fee must be configurable, not hardcoded. - The
> submission page must show the current fee and estimated total before
> submission. - No payment is collected at submission. - Wine Words
> staff confirm the billable bottle quantity. - Staff prepare/send
> invoices manually outside the application and record invoice metadata
> in Wine Words. - No payment gateway, automatic invoice PDF, or
> automatic invoice sending in this implementation. - Submission,
> review, and payment statuses are separate. - Later additional bottles
> may require a new invoice; do not overwrite earlier invoice records.
>
> Inspect the actual repositories, current branch, models, migrations,
> routes, controllers, serializers, frontend submission flow, settings
> architecture, role policies, email infrastructure, and tests. Trace
> the complete current Wine Package workflow. Do not assume names or
> paths.
>
> Do not modify files. Return: 1. Current architecture and submission
> workflow. 2. Exact relevant files and responsibilities in both
> repositories. 3. Existing settings and authorization patterns to
> reuse. 4. Existing bottle count and catalogue acceptance logic. 5.
> Recommended schema, including whether a separate invoice table is
> needed. 6. Proposed API contract and frontend changes. 7. Security,
> migration, and backward-compatibility risks. 8. A phased
> implementation sequence and test strategy.
>
> Identify ambiguities explicitly. Stop after the audit and wait for
> approval.

## Phase 1 --- Finalize billing domain model and business rules
**Purpose:** Confirm whether invoice records are one-to-many and
establish precise lifecycle rules before migrations.

Tasks:

1.  Confirm that a Wine Package can have multiple invoices.
2.  Define the distinction between submitted bottle count and billable
    bottle count.
3.  Define how additional accepted bottles are billed after an earlier
    invoice.
4.  Define the package-level aggregate billing summary.
5.  Define invoice statuses and allowed transitions.
6.  Decide whether cancelled and waived are separate states.
7.  Define fee snapshot semantics.
8.  Define rounding and currency precision.
9.  Define who can change global pricing and who can manage invoices.
10. Document the final domain rules.

**Recommended default:** one Wine Package has many invoices; each
invoice snapshots its own billable quantity, unit fee, currency, and
total. Package billing summary aggregates invoice records.
### AI Prompt 1 --- Domain design and schema proposal
> Based on the completed reconnaissance, design the Wine Words billing
> domain model. Do not write migrations yet.
>
> Preserve these rules: - Initial global fee: AUD \$50.00 per billable
> bottle. - Fee is centrally configurable. - Existing submitted packages
> retain their historical price snapshot. - The submission estimate uses
> the submitted bottle count. - Staff confirm the billable bottle
> count. - Each manually issued invoice is a separate record. - One
> package may have multiple invoices, including a later invoice for
> additional bottles. - No partial payments, gateway transactions,
> refunds, or accounting ledger. - Overdue is derived from an invoice
> due date and unpaid status.
>
> Propose: 1. Settings storage and validation. 2. Wine Package fields
> needed for the submission estimate and aggregate summary. 3. Invoice
> model/table fields and associations. 4. Enumerated statuses and valid
> transitions. 5. Database indexes, constraints, decimal precision, and
> nullability. 6. Authorization responsibilities. 7. Handling for
> existing packages and draft submissions. 8. How to calculate total
> invoiced, paid, and outstanding amounts without double-counting. 9.
> How additional bottles are invoiced without altering previous
> invoices.
>
> Compare the proposal with existing project conventions. List exact
> files that would change and migration risks. Stop for approval before
> implementation.

## Phase 2 --- Configurable global pricing
**Purpose:** Add a single source of truth for the review fee.

Tasks:

1.  Implement or reuse persistent application settings.
2.  Set initial configured fee to AUD \$50.00.
3.  Add safe amount/currency validation.
4.  Add authorized Admin update capability.
5.  Add a public read endpoint or include the fee in an existing public
    settings response.
6.  Add frontend Admin settings UI.
7.  Ensure existing package snapshots are not changed when the global
    setting changes.
8.  Add tests for defaults, validation, permissions, persistence, and
    public read access.

**Acceptance criteria:**

- A new installation/configuration starts at AUD \$50.00.
- Admin can change the fee without deployment.
- Unauthorized users cannot change the fee.
- Public users can retrieve the current fee.
- Unsupported currencies and invalid amounts are rejected.
- Old package snapshots are unaffected.
### AI Prompt 2 --- Implement configurable review fee
> Implement the approved global Wine Words review-fee configuration in
> the API and frontend.
>
> Requirements: - Initial amount AUD \$50.00 per bottle. - Do not
> hardcode the fee in business logic or UI. - Reuse the existing
> settings architecture if suitable. - Use decimal-safe currency
> handling; never use floating-point calculations. - Expose a safe
> public read endpoint/response for the current fee. - Allow only the
> authorized Admin role to update the setting. - Provide a small Admin
> settings UI consistent with the existing Wine Words design. - Explain
> in the UI that changes affect future submissions only. - Do not alter
> existing Wine Package records.
>
> Follow the exact paths and conventions discovered in Phase 0. Add
> migrations only as approved in Phase 1. Add model, request/API,
> authorization, and frontend tests. Run relevant test suites and report
> results. Do not implement package invoicing yet. Stop and summarize
> the changes.

## Phase 3 --- Submission page pricing and estimate
**Purpose:** Make the fee transparent before the user submits a package.

Tasks:

1.  Fetch the current configured price from the API.
2.  Display price per bottle and currency.
3.  Calculate estimated total using current bottle count.
4.  Update estimate immediately when bottles are added or removed.
5.  Add clear no-payment-at-submission explanation.
6.  Add final-fee/billable-quantity explanation.
7.  Add terms acknowledgement if appropriate.
8.  Persist the estimate and fee snapshot server-side during submission.
9.  Ensure API recalculates rather than trusting browser totals.
10. Handle loading, error, empty, and draft states.
11. Ensure editing an existing submitted package does not silently
    replace its historical fee.

**Acceptance criteria:**

- User sees the fee and estimate before submitting.
- Changing bottle count updates the estimate.
- User understands payment is not taken at submission.
- API stores the authoritative snapshot.
- Browser cannot manipulate the persisted total.
- Existing packages retain historical values.
### AI Prompt 3 --- Submission pricing UX and API snapshot
> Implement the Wine Package submission pricing experience.
>
> Use the configured fee from the API; do not duplicate AUD \$50 in
> React. Show: - Current fee per bottle. - Current submitted bottle
> count. - Estimated total. - AUD currency. - No-payment-at-submission
> explanation. - Notice that Wine Words confirms the final billable
> bottle count and sends an invoice separately.
>
> Recalculate the estimate whenever the package bottle list changes.
> Ensure the API calculates and persists the authoritative price
> snapshot during submission. Do not trust a total sent by the browser.
>
> Preserve existing draft/edit/submission behavior. For an already
> submitted package, show its stored historical estimate rather than the
> current global fee. Handle loading and pricing API errors gracefully.
>
> Add frontend tests for bottle count changes, estimate formatting,
> loading/error states, and terms acknowledgement if implemented. Add
> API tests proving the server calculates the snapshot and
> ignores/manages client-supplied totals safely. Run tests and report
> changed files. Do not implement staff invoice management in this
> phase.

## Phase 4 --- Database migrations and invoice model
**Purpose:** Implement the approved billing persistence model.

Tasks:

1.  Add package snapshot fields.
2.  Add invoice table and associations.
3.  Add appropriate monetary precision and currency fields.
4.  Add invoice status and timestamps.
5.  Add database constraints and indexes.
6.  Add model validations and scopes.
7.  Add aggregate methods for invoiced, paid, and outstanding totals.
8.  Add migration/backfill behavior for existing packages.
9.  Ensure existing records remain valid.
10. Add model and migration tests.

**Migration principles:**

- Existing Wine Packages must continue to work.
- Do not invent historical fees for old packages.
- Legacy packages may have no fee snapshot and should display an
  appropriate "not priced under current billing workflow" or
  equivalent state.
- Do not backfill old records at AUD \$50 unless there is reliable
  evidence that they were actually priced that way.
- Keep migrations reversible where practical.
### AI Prompt 4 --- Implement billing persistence
> Implement the approved billing database and model changes in
> `wine_words_api`.
>
> Add the package-level historical estimate snapshot and the one-to-many
> invoice model agreed in Phase 1. Each invoice must snapshot its
> billable bottle count, unit fee, currency, and total. Include invoice
> number, status, sent date, due date, paid date, notes, and staff
> attribution/audit fields where consistent with the application.
>
> Use decimal-safe monetary storage and database constraints. Add model
> validations, associations, status transitions, and aggregate methods.
> Avoid storing redundant values unless a snapshot is required for
> historical correctness.
>
> Existing Wine Packages must remain valid. Do not fabricate historical
> pricing for old records. Provide safe null/legacy behavior and
> reversible migrations where practical.
>
> Add model, validation, association, aggregate, and migration tests.
> Run the API test suite relevant to these models. Do not yet expose
> staff invoice APIs or build frontend billing controls. Report schema
> changes and any unresolved design decisions.

## Phase 5 --- Staff billing workflow and API
**Purpose:** Let authorized staff confirm quantities and record manually
issued invoices.

Tasks:

1.  Add API endpoints for billing summary and invoice listing.
2.  Add endpoint/action to confirm billable quantity.
3.  Calculate final amount on the server.
4.  Add endpoint/action to record an externally sent invoice.
5.  Add endpoint/action to mark an invoice paid.
6.  Add endpoint/action to cancel/waive an invoice.
7.  Add validation for required invoice details and status transitions.
8.  Add authorization policies for Admin/Editor.
9.  Record staff attribution and timestamps.
10. Ensure old invoice records cannot be overwritten by later invoices.
11. Support a later invoice for additional bottles.
12. Add request/policy tests.

**Important UX/API distinction:** "Record invoice sent" records that
staff sent an invoice outside the application. It must not claim to send
email.
### AI Prompt 5 --- Staff billing API and authorization
> Implement the Wine Package billing API and staff authorization.
>
> Authorized staff must be able to: - Read package billing summary and
> invoice history. - Confirm/update the billable bottle quantity. - See
> the server-calculated final amount. - Record an invoice that has been
> sent externally. - Mark an invoice as paid. - Cancel or waive an
> invoice with a reason. - Create a separate later invoice for newly
> accepted additional bottles.
>
> Do not implement payment gateway calls or email sending. An API action
> named or presented as "record invoice sent" must only record the
> external action.
>
> Enforce role and package access through existing policies, not just
> frontend checks. Confirm whether Admin and Editor have the required
> permissions based on the existing authorization design. Prevent
> package owners from changing billing fields.
>
> Validate all money and quantities on the server. Preserve prior
> invoices. Add request specs for success, validation failures,
> unauthorized roles, cross-user access, invalid transitions, and
> additional invoices. Run relevant tests and report the exact API
> contract for the frontend phase.

## Phase 6 --- Admin/Editor billing interface
**Purpose:** Provide an understandable staff interface for managing
billing manually.

Tasks:

1.  Add Billing panel to Wine Package administration detail.
2.  Show submitted count, initial estimate, billable count, final
    amount, and invoice history.
3.  Allow staff to confirm billable quantity.
4.  Show the calculated invoice amount.
5.  Allow staff to record invoice number, sent date, due date, and
    notes.
6.  Allow staff to mark an invoice paid.
7.  Allow staff to cancel/waive with a reason.
8.  Show overdue indicator derived from due date.
9.  Show who updated billing and when if available.
10. Make external invoice handling explicit.
11. Add UI loading, success, validation, and error states.
12. Add frontend tests.
### AI Prompt 6 --- Admin/Editor billing UI
> Build the Wine Package Billing section in the existing Wine Words
> administration interface using the API contract from Phase 5.
>
> Display: - Submitted bottle count. - Original estimated fee and
> total. - Confirmed billable bottle count. - Final amount. - Invoice
> history, with invoice number, amount, sent date, due date, and payment
> status. - Paid date where applicable. - Outstanding balance.
>
> Provide staff controls to confirm billable quantity, record an
> externally sent invoice, mark an invoice paid, and cancel/waive an
> invoice with a reason. Do not create a payment button or imply that
> Wine Words sends the invoice.
>
> Display overdue as a derived visual indicator when an invoice is
> unpaid and past its due date. Do not persist overdue as a manually
> editable status.
>
> Follow existing UI components, responsive behavior, role visibility,
> form patterns, and API error handling. Add tests for each action,
> invalid values, loading states, and role-based visibility. Do not
> expose internal notes to package owners. Run relevant frontend tests
> and summarize the result.

## Phase 7 --- User-facing billing information
**Purpose:** Give package owners visibility of the estimated and
invoiced amounts.

Tasks:

1.  Add billing summary to the user's Wine Package page.
2.  Show original estimate.
3.  Show confirmed billable count and final amount.
4.  Show invoice list and status.
5.  Show invoice number and due date.
6.  Show paid date after staff confirms payment.
7.  Show outstanding balance.
8.  Explain that payment instructions are in the external invoice.
9.  Hide internal staff notes and staff-only attribution.
10. Ensure package owner access is scoped correctly.
11. Add frontend/API tests.
### AI Prompt 7 --- Package owner billing view
> Add a read-only Billing section to the package owner's Wine Package
> page.
>
> Show the original submission estimate, confirmed billable bottle
> count, final confirmed amount, invoice history, invoice numbers,
> invoice dates/due dates, payment status, paid dates, and outstanding
> balance.
>
> Explain that invoices are sent separately by the Wine Words team and
> that payment instructions are included in the external invoice. There
> must be no online payment or checkout action.
>
> Do not expose internal staff notes, private audit details, or another
> user's package information. Use the package billing API and
> server-calculated amounts. Handle packages that predate billing and
> have no historical fee snapshot.
>
> Add tests for owner access, no access to another user's package,
> display of multiple invoices, paid/unpaid/overdue states, and legacy
> packages. Run relevant tests and report the changes.

## Phase 8 --- Invoice history, additional bottles, and billing summaries
**Purpose:** Make later invoices safe and understandable.

Tasks:

1.  Implement package-level billing aggregate.
2.  Display all invoices in chronological order.
3.  Support additional accepted bottles after an earlier invoice.
4.  Create a separate invoice for additional billable bottles.
5.  Prevent changing old invoice amounts when new bottles are accepted.
6.  Calculate outstanding balance from invoice records.
7.  Ensure cancelled/waived invoices are excluded from outstanding
    balance.
8.  Ensure paid invoices are excluded from outstanding balance.
9.  Add tests for multiple invoices and aggregate calculations.
### AI Prompt 8 --- Multiple invoices and additional bottle workflow
> Review and complete the one-package-to-many-invoices workflow.
>
> A package may receive a first invoice and later another invoice for
> additional bottles accepted by Wine Words. Creating the later invoice
> must not mutate the original invoice's quantity, amount, number, sent
> date, due date, or payment status.
>
> Ensure each invoice stores its own unit-fee and currency snapshots.
> The package summary must show: - Total bottles submitted. - Total
> bottles accepted/billable to date, where this can be reliably
> calculated. - Total invoiced. - Total paid. - Outstanding balance. -
> Invoice history.
>
> Define aggregate behavior carefully. Exclude cancelled/waived invoices
> from outstanding balance; exclude paid invoices from outstanding
> balance; include only relevant sent invoices. Avoid double-counting.
>
> Add comprehensive model and request tests for multiple invoices,
> additional bottles, old invoice immutability, status changes, and
> aggregate calculations. Do not add partial payments or a ledger.
> Report any business-rule ambiguity instead of guessing.

## Phase 9 --- Email and staff communication alignment
**Purpose:** Make the manual email process clear without adding
automated invoice sending.

Tasks:

1.  Confirm the invoice email is sent externally by staff.
2.  Provide approved email copy as documentation/template if useful.
3.  Ensure Wine Words does not claim that an invoice was emailed
    automatically.
4.  Reuse existing contact details and branding in suggested copy.
5.  Do not attach or generate invoice PDFs.
6.  Decide whether an optional internal staff notification is useful
    when billing is ready; do not add it unless approved and consistent
    with existing notification architecture.
7.  Test any changed email copy or notification behavior.
### AI Prompt 9 --- Manual invoice communication review
> Review Wine Words email and staff communication patterns for the
> manual invoice workflow.
>
> The invoice is prepared and emailed by a Wine Words team member
> outside the application. Wine Words only records the invoice number,
> amount, sent date, due date, and later payment confirmation.
>
> Do not implement automatic invoice sending, PDF generation, payment
> gateway integration, or automated overdue reminders.
>
> Provide a concise branded invoice email template that includes bottle
> count, fee per bottle, total, invoice number, due date, and payment
> instructions placeholder. Ensure UI wording says "record invoice sent"
> rather than implying the app sent it.
>
> Check that existing email jobs and staff notification flows are not
> unintentionally changed. Only implement approved copy/documentation
> changes. Report findings and tests.

## Phase 10 --- Configuration, auditability, and operational safeguards
**Purpose:** Make billing changes traceable and safe for production.

Tasks:

1.  Ensure price changes are auditable.
2.  Ensure billable quantity changes are auditable.
3.  Ensure invoice create/status changes are auditable.
4.  Ensure staff identity and timestamps are available.
5.  Add server-side safeguards against invalid state transitions.
6.  Confirm all totals are decimal-safe.
7.  Confirm historical snapshots are immutable except through an
    explicit correction path.
8.  Confirm API responses do not expose staff-only fields.
9.  Confirm logs do not contain sensitive payment instructions.
10. Add operational documentation for staff.
### AI Prompt 10 --- Audit and security review
> Perform a focused security, auditability, and data-integrity review of
> the completed Wine Words billing implementation.
>
> Verify: - Only authorized staff can change global pricing and package
> billing data. - Package owners can read only their own billing data. -
> Client-supplied monetary totals are never trusted. - All currency
> calculations are decimal-safe. - Historical package and invoice
> snapshots are preserved. - Additional invoices do not mutate earlier
> invoices. - Status transitions are validated. - Paid invoices have
> paid timestamps. - Sent invoices have required invoice metadata. -
> Waived/cancelled invoices have an explanatory reason where required. -
> Overdue is derived, not manually stored. - Private notes and audit
> fields are not exposed to users. - No payment credentials or sensitive
> bank details are stored.
>
> Review migrations and legacy package behavior. Add missing tests and
> correct defects within the approved scope. Do not add a payment
> gateway or new billing features. Return a security checklist with
> pass/fail and evidence from code/tests.

## Phase 11 --- End-to-end testing, deployment, and documentation
**Purpose:** Verify the complete workflow before production rollout.

Tasks:

1.  Run backend test suite.
2.  Run frontend test suite.
3.  Run lint, type checking, and production builds.
4.  Test public fee retrieval.
5.  Test Admin fee update.
6.  Test package submission estimate.
7.  Test package fee snapshot.
8.  Test staff billable quantity confirmation.
9.  Test manual invoice recording.
10. Test paid and waived transitions.
11. Test overdue display.
12. Test a second invoice for additional bottles.
13. Test owner visibility and access control.
14. Test legacy package rendering.
15. Review migrations and rollback plan.
16. Document staff procedure.
17. Document production configuration and initial AUD \$50 setting.
18. Deploy API and frontend in the project's established sequence.
19. Verify production behavior and logs.
### AI Prompt 11 --- Full integration and release readiness
> Perform end-to-end release verification for Wine Words configurable
> per-bottle review billing.
>
> Verify the full workflow: 1. Public user retrieves the configured AUD
> \$50.00 fee. 2. Admin changes the fee and the public value updates. 3.
> User adds/removes bottles and sees the correct estimate. 4. User
> submits without paying. 5. API stores the historical fee and estimate
> snapshot. 6. Staff confirms the billable quantity. 7. Staff records an
> invoice sent externally. 8. User sees invoice details and payment
> status. 9. Staff marks invoice paid and user sees the updated state. 10. Overdue indicator appears only when an invoice is unpaid and past
> due. 11. Staff adds newly accepted bottles and records a separate
> invoice. 12. Previous invoice remains unchanged. 13. Package owner
> cannot access another user's billing data or modify billing fields. 14. Legacy packages render safely.
>
> Run API and frontend tests, lint, type checking, and production
> builds. Review migration order and rollback implications. Provide a
> release checklist, exact commands/results, changed files, known
> limitations, deployment sequence, and post-deployment smoke tests.
>
> Do not deploy or modify production services unless explicitly
> authorized. Do not introduce payment gateway or automated invoice
> functionality.

---
# 8. Suggested API contract (to be adapted after reconnaissance)
The following is conceptual, not a mandate to create these exact routes.
Follow existing API versioning, naming, and serializer conventions.
## Public configuration
- Read current review fee and currency.
- No public write access.

Conceptual response:

```json
{
  "wine_review_fee": {
    "amount": "50.00",
    "currency": "AUD",
    "unit": "bottle"
  }
}
```
## Package submission
The client submits package content, not an authoritative total. The
server retrieves the current fee, counts submitted bottles, calculates
the estimate, and persists the snapshot.
## Staff billing
Conceptual operations:

- Read billing summary.
- Confirm billable bottle quantity.
- Record an invoice sent externally.
- Mark invoice paid.
- Cancel/waive an invoice.
- List invoice history.
## Package owner
Read-only billing summary scoped to the package owner.

---
# 9. Suggested data model (conceptual)
Actual field names must follow the existing Rails conventions and
approved Phase 1 design.
## Application setting
A persistent setting for the current review fee:

- key/name
- amount
- currency
- updated_by
- timestamps

If the project already has a robust settings model, reuse it rather than
introducing a second configuration system.
## Wine Package
Potential snapshot/summary fields:

- submitted bottle count or reliable association-derived count
- review fee unit amount at submission
- review fee currency at submission
- estimated total at submission
- optional staff-confirmed billable bottle count if needed for
  workflow

Do not store redundant totals without a reason. A final total may be
derived from invoice records when all billing is invoice-based.
## Wine Package Invoice
Potential fields:

- wine_package_id
- invoice_number
- billable_bottle_count
- unit_fee_amount
- currency
- total_amount
- status
- sent_at
- due_at
- paid_at
- cancellation/waiver reason
- internal notes
- created_by_id / updated_by_id where supported
- timestamps

Use integer minor units or decimal columns with fixed precision. Ensure
API serialization returns money in a stable decimal format.

---
# 10. Core business rules and edge cases
1.  **Fee changes:** A new fee affects new submissions only. Existing
    package and invoice snapshots remain unchanged.
2.  **Draft packages:** Decide whether a draft uses the current fee only
    for display and snapshots the fee at final submission. Recommended:
    snapshot at submission, not when a draft is first created.
3.  **Submitted package edits:** Do not silently change historical
    estimate snapshots. If adding bottles after submission, treat them
    as an explicit additional-bottle review/invoice workflow.
4.  **Billable count:** Staff confirm accepted/billable bottles. The
    server validates the quantity against accepted items.
5.  **Additional invoices:** New accepted bottles after an earlier
    invoice require a new invoice record; never rewrite the old invoice.
6.  **No payment at submission:** Submission remains possible without
    payment.
7.  **Manual payment confirmation:** Only authorized staff mark an
    invoice paid.
8.  **Overdue:** Derived from due date and invoice status using a
    consistent timezone/date rule.
9.  **Waived/cancelled:** Preserve reason and staff attribution.
10. **Legacy packages:** No fabricated fee or invoice history.
11. **Currency:** AUD is the only required currency initially. Do not
    expose multi-currency selection unless the business approves it.
12. **Rounding:** Use decimal-safe arithmetic and two decimal places for
    AUD.
13. **Invoice numbers:** Staff enter the externally generated invoice
    number. Do not assume Wine Words should generate a legal/accounting
    invoice number.
14. **Invoice email:** Sent externally; app records the fact and
    metadata only.
15. **Multiple invoices:** Outstanding balance is calculated from
    invoice records, not from a manually editable package total.

---
# 11. Test matrix
Area Required test

---
Settings Default fee is AUD \$50.00
Settings Admin can update fee
Settings Unauthorized user cannot update fee
Settings Invalid/negative amount rejected
Public API Current fee readable without exposing private settings
Submission UI Fee and total shown before submit
Submission UI Estimate changes when bottle count changes
Submission API Server calculates total
Snapshot Existing packages retain old snapshot after fee change
Snapshot Draft snapshots at the intended lifecycle point
Quantity Staff can confirm valid billable count
Quantity Invalid count rejected
Invoice Staff can record invoice sent
Invoice Required invoice metadata validated
Invoice Staff can mark paid
Invoice Invalid transitions rejected
Invoice Waived/cancelled reason recorded
Multiple invoices Second invoice does not change first
Aggregates Paid/outstanding totals correct
Overdue Derived only for unpaid sent invoices past due
Authorization Owner sees own billing only
Authorization Owner cannot edit billing
Privacy Staff notes hidden from owner
Legacy Old packages render without fabricated prices
Frontend Loading/error/empty states work
Integration Full submission-to-paid workflow succeeds

---
# 12. Staff operating procedure (initial release)
1.  Admin maintains the current per-bottle fee in Wine Words settings.
    Initial value: AUD \$50.00.
2.  Submitter sees the configured fee and estimated total before
    submission.
3.  Submitter sends the Wine Package without payment.
4.  Wine Words team reviews the submission and decides which bottles are
    accepted for review.
5.  Staff confirms the billable bottle quantity in the Billing panel.
6.  Staff prepares and sends an invoice using the team's existing
    external invoicing/email process.
7.  Staff records the invoice number, amount, sent date, and due date in
    Wine Words.
8.  User can see invoice status and due date on their package page.
9.  When payment is received, staff marks the invoice as paid and
    records the paid date.
10. If additional bottles are accepted later, staff creates and sends a
    separate invoice and records it as a new invoice.
11. If payment is waived or an invoice cancelled, staff records the
    reason.

---
# 13. Release checklist
## Before implementation
- [ ] Phase 0 repository audit completed.
- [ ] Existing settings architecture confirmed.
- [ ] Existing Wine Package submission flow documented.
- [ ] One-to-many invoice decision confirmed.
- [ ] Admin/Editor billing permissions confirmed.
- [ ] Final business rules approved.
## Before production
- [ ] Initial configured fee is AUD \$50.00.
- [ ] Fee can be changed by authorized Admin.
- [ ] Public submission page displays configured fee.
- [ ] Estimate is recalculated server-side.
- [ ] Historical snapshots are preserved.
- [ ] Staff can confirm billable quantity.
- [ ] Staff can record external invoices.
- [ ] Staff can mark invoices paid or waived/cancelled.
- [ ] Additional invoices are supported without overwriting old
      invoices.
- [ ] User billing view is read-only and scoped correctly.
- [ ] Overdue is derived.
- [ ] No gateway or online checkout exists.
- [ ] No automatic invoice PDF/email is implied.
- [ ] Backend/frontend tests and production builds pass.
- [ ] Legacy packages render correctly.
- [ ] Staff procedure is documented.

---
# 14. Master AI prompt --- coordinate the complete implementation
Use this prompt after Phase 0 has been completed and the phase-specific
design has been approved. It is a coordination prompt, not permission to
skip the phase gates.

> You are the senior engineer implementing configurable per-bottle
> review billing for Wine Words across: - `romalopes/wine_words_api` -
> `romalopes/wine_words_frontend`
>
> Follow the approved implementation plan and execute one phase at a
> time. Start by reading the plan and the Phase 0 audit. Do not assume
> paths or architecture; verify them in the repositories.
>
> ## Commercial rules
>
> - Initial configured review fee: **AUD \$50.00 per billable
>   bottle**.
> - Fee must be configurable by an authorized Admin.
> - The submission page displays the current fee and estimated total
>   before submission.
> - No payment is collected at submission.
> - The Wine Words team confirms the billable quantity after review.
> - The team manually prepares and emails invoices outside the app.
> - Wine Words records invoice metadata and payment status only.
> - One Wine Package may have multiple invoices. A later invoice for
>   additional accepted bottles must not alter an earlier invoice.
> - Submission status, review status, and payment status remain
>   independent.
> - Overdue is derived from due date and unpaid status.
>
> ## Strict exclusions
>
> - No payment gateway.
> - No checkout.
> - No card or bank credential storage.
> - No automatic invoice PDF generation.
> - No automatic invoice email sending.
> - No automatic payment reconciliation.
> - No partial payments, refunds, subscriptions, or accounting ledger.
> - Do not expand scope without explicit approval.
>
> ## Engineering requirements
>
> - Use the existing Rails and React/Vite conventions.
> - Inspect before editing.
> - Keep money calculations decimal-safe.
> - Never trust client-supplied totals.
> - Snapshot the fee and currency for historical correctness.
> - Do not fabricate historical prices for legacy packages.
> - Enforce authorization on the API, not only in the UI.
> - Preserve existing Wine Package, Producer, wine catalogue, and
>   submission workflows.
> - Add tests with each phase.
> - Keep migrations safe and explain rollback implications.
> - Do not change production configuration or deploy unless explicitly
>   authorized.
>
> ## Execution protocol
>
> 1.  Confirm the current branch and clean/dirty working tree.
> 2.  Read the approved audit and relevant phase prompt.
> 3.  State the phase objective and files expected to change.
> 4.  Implement only that phase.
> 5.  Run focused tests, then broader relevant tests where practical.
> 6.  Review the diff for unrelated changes, security problems, and
>     accidental scope expansion.
> 7.  Report files changed, migrations, tests and results, unresolved
>     questions, and manual verification steps.
> 8.  Stop and wait for approval before proceeding to the next phase.
>
> Do not claim tests passed unless they were actually run. If a
> requirement conflicts with existing architecture, explain the conflict
> and recommend the smallest safe adjustment before coding.

---
## Final recommendation
Implement this as a small billing capability attached to the existing
Wine Package workflow, not as a standalone finance subsystem.

The key design choices are:

- **AUD \$50.00 per bottle initially**, stored in configurable
  application settings.
- Historical price snapshots for each submission and invoice.
- Separate invoice records so additional accepted bottles can be
  invoiced later.
- Independent submission, review, and payment statuses.
- Manual invoice sending and manual payment confirmation by the Wine
  Words team.
- Clear public pricing before submission and read-only billing
  visibility for package owners.

The most important first step is Phase 0: inspect both repositories and
verify how Wine Packages, bottle submissions, settings, permissions, and
catalogue acceptance currently work. The remaining phases should follow
the discovered architecture rather than forcing a new structure onto the
application.
