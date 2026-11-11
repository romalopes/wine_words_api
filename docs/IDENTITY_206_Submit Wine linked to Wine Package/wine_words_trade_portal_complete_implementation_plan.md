# Wine Words Trade Portal & Wine Package Submission

## Complete implementation, configuration, security, testing and documentation plan

**Status:** Proposed implementation plan\
**Product:** Wine Words\
**Repositories:** - Frontend:
https://github.com/romalopes/wine_words_frontend - API:
https://github.com/romalopes/wine_words_api

**Primary outcome:** Introduce a public-facing **Trade** area where any
person can submit one or more wines without first creating an account or
Producer record. Every accepted submission is managed through the
existing `WinePackage` domain. Submitters can later access their
packages through **My Wine Packages**, communicate with Wine Words
Editors, receive approval decisions and invoices, pay, arrange shipping
and follow review progress.

------------------------------------------------------------------------

# 1. Product vision and guiding decisions

## 1.1 Trade navigation

Add a **Trade** menu to the main website header. Initial menu items:

1.  **Submit a Wine** --- public, no login required.
2.  **My Wine Packages** --- authenticated access, with a secure
    claim/access route for verified anonymous submitters.
3.  **Submission Guidelines** --- public information about eligibility,
    required details, sample requirements, fees and shipping.
4.  **Trade Membership** --- may link to the existing membership/pricing
    functionality or be marked as future scope.
5.  **Promotional Opportunities** --- future scope; do not block the
    submission launch.

The Trade menu must work responsively on desktop and mobile.

## 1.2 Non-negotiable product decisions

-   Anyone can start and submit a wine package, including anonymous
    visitors.
-   An existing Producer record is not required.
-   A registered User is not required to submit.
-   The central operational entity remains `WinePackage`.
-   Do not create a separate `WineSubmission` aggregate or duplicate
    package workflow.
-   A package can contain multiple submitted wines.
-   Wine submissions must not automatically create or publish
    Wine/Vintage catalogue records.
-   Submissions start in an editorial pending state.
-   Editors/Admins assess the submission and can approve or reject
    individual wines, request more information, or partially approve a
    package.
-   Do not require payment before editorial approval.
-   After approval, an Editor defines the service and price and issues a
    quotation/invoice.
-   Shipping instructions are sent after payment is confirmed, unless an
    authorised Admin records an explicit override.
-   Shipping information is collected after package acceptance/payment,
    not in the initial public form.
-   A submitter may be a winery, producer, importer, distributor, agent
    or other representative. The submitter/contact and the represented
    Producer are separate concepts.
-   A submitter may create an account after submission. For a new email,
    the system can provision a pending/unclaimed account and send a
    secure password setup/verification flow. For an existing email, do
    not change credentials, reveal account existence or authenticate the
    visitor.
-   **My Wine Submissions is not a separate feature:** use the name **My
    Wine Packages** and the existing `WinePackage` model.
-   Each package has a conversation between the submitter and Wine
    Words. Messages are persisted in the application; email is a
    notification channel, not the canonical conversation.
-   Editors/Admins can create private internal notes that are never
    visible or emailed to submitters.
-   Reuse the existing Wine Words authentication, notification, email,
    ActiveStorage, role/permission and package functionality wherever
    possible.

## 1.3 Reference product patterns

Use the following websites as product-design references, not as sources
to copy verbatim:

-   Halliday Wine Companion --- structured submission process,
    eligibility and shipping guidance:
    https://winecompanion.com.au/wine-submission-process
-   Campbell Mattinson --- paid fast-track review service and checkout
    concept: https://www.campbellmattinson.com/contact#fast-track
-   Campbell Mattinson checkout example:
    https://www.campbellmattinson.com/checkout?cartToken=yc47q8JY2Ujlyk56gaQ1smbKl6hDB3CA0tu2Bggv
-   The Real Review --- public wine submission and wine-by-wine
    information: https://www.therealreview.com/submit-wines/

Product direction: combine a low-friction public submission, structured
wine registration, editorial assessment and a transparent paid service
workflow. Do not assume that a positive review or score is guaranteed by
payment. Make editorial independence explicit in guidelines and terms.

------------------------------------------------------------------------

# 2. Target user journeys

## 2.1 Anonymous submitter --- new email

1.  Visitor opens Trade → Submit a Wine.
2.  Visitor completes contact/company information and one or more wine
    entries.
3.  Visitor accepts the submission terms and privacy notice and
    completes Cloudflare Turnstile.
4.  API validates and creates a `WinePackage` and its `WinePackageItem`
    records transactionally.
5.  Package status becomes pending editorial assessment.
6.  System sends a submission-received email with a reference number and
    email-verification link.
7.  After verification, the system provisions or activates a User
    account using the existing authentication implementation and sends a
    secure password setup link.
8.  Submitter sets a password and can access My Wine Packages.
9.  Editor assesses the package and communicates through its message
    thread.
10. Approved items receive a quotation/invoice. Rejected items do not
    incur a fee unless the published commercial terms explicitly say
    otherwise.
11. After payment, shipping instructions are sent.
12. Submitter can update shipping/tracking details and follow receipt
    and review progress.

**Security rule:** email ownership must be verified before the person
can claim or view the package. Do not treat the act of entering an email
address as proof of ownership.

## 2.2 Anonymous submitter --- email already belongs to a User

1.  Allow the public submission.
2.  Do not log the visitor in.
3.  Do not reset/change the existing password.
4.  Do not disclose whether the email already has an account.
5.  Send a generic confirmation response and a verification/claim email.
6.  After email verification, provide a safe route to claim the package:
    -   If the user signs in to the existing account, associate the
        package with that authenticated User.
    -   If they cannot sign in, use the normal password recovery
        process.
7.  Do not permit the claim token alone to change the existing account
    password or create an authenticated session unless the existing
    authentication design explicitly and securely supports that flow.

The public response and email wording must avoid account enumeration.

## 2.3 Authenticated submitter

1.  User opens Submit a Wine.
2.  Prepopulate known contact details where appropriate.
3.  Allow the user to select a Producer only from records they are
    authorised to represent; also allow a new/unlisted business name.
4.  Create the package associated with the authenticated User.
5.  Show the package immediately in My Wine Packages.
6.  Preserve the contact snapshot supplied for this particular
    submission.

An authenticated user must not be able to submit on behalf of an
unrelated Producer merely by changing a frontend ID.

## 2.4 Existing Producer without a User account

The submitter can enter the Producer/company name. During editorial
assessment an Editor can:

-   Match the submission to an existing Producer.
-   Create a new Producer if appropriate.
-   Record the represented Producer separately from the submitter.
-   Invite the submitter to create an account or claim the package.
-   Grant ProducerMembership only after an authorised
    verification/approval process.

Never grant Producer ownership or membership automatically based only on
a submitted company name or email domain.

## 2.5 Editor workflow

1.  Editor opens Trade Management → Submissions.
2.  Editor assesses company/contact and submitted wines.
3.  Editor may ask questions in the package conversation.
4.  Editor can approve/reject each wine, or request information.
5.  Editor can match submitted wine details to existing Wine/Vintage
    records or request catalogue creation through the existing editorial
    process.
6.  Editor selects services and sets a price for accepted wines.
7.  Editor approves the commercial quotation and issues an invoice.
8.  On confirmed payment, shipping instructions become available.
9.  Editor records physical receipt and discrepancies.
10. Editor assigns reviewers and manages the existing review process.
11. Submitter receives notifications at relevant milestones.

------------------------------------------------------------------------

# 3. Domain model and architecture

## 3.1 First task: inspect before designing migrations

The actual repositories must be inspected before any schema changes. The
plan below describes target responsibilities, not an instruction to
create duplicate models or columns.

Inspect the existing:

-   `WinePackage`, `WinePackageItem` and their status enums/state
    transitions.
-   Wine, Vintage and Review associations.
-   Producer and ProducerMembership.
-   User authentication modules and email uniqueness rules.
-   Roles, permissions and admin/editor policies.
-   Existing notifications and email delivery.
-   ActiveStorage configuration and Cloudflare R2 integration.
-   Existing billing/subscription code and any payment provider
    integration.
-   API serializers, controllers, service objects and frontend API
    client conventions.

Produce a reuse/gap report. Keep existing package workflows working.

## 3.2 Core entities

### WinePackage

Keep this as the central operational aggregate.

Potential fields to add only if not already represented:

  -----------------------------------------------------------------------
  Field                               Purpose
  ----------------------------------- -----------------------------------
  `user_id`                           Authenticated submitter; nullable
                                      for unclaimed anonymous submissions

  `producer_id`                       Matched/represented Producer;
                                      nullable initially

  `source`                            For example `public_submission`,
                                      `authenticated_submission`,
                                      `internal`

  `submitted_at`                      Submission timestamp

  `editorial_status`                  Editorial assessment state, if not
                                      already supported

  `commercial_status`                 Quotation/invoice/payment state, if
                                      not already supported

  `fulfilment_status`                 Shipping/receipt state, if not
                                      already supported

  `review_status`                     Review progress, preferably reuse
                                      existing package workflow

  `last_message_at`                   Optional denormalised conversation
                                      sorting field

  `last_message_by_id`                Optional denormalised sender
                                      reference
  -----------------------------------------------------------------------

Do not add four new status columns if the existing model already has a
suitable, maintainable state design. First map existing statuses and
identify whether separate dimensions are genuinely needed.

`user_id` and `producer_id` must be nullable for the public intake path.
Preserve current non-public creation behaviour.

### WineSubmissionContact

Create a contact snapshot only if the existing package/contact structure
cannot already represent this information safely.

Suggested attributes:

-   `wine_package_id`
-   `user_id` nullable
-   `name`
-   `email`
-   `phone`
-   `company_name`
-   `business_type`
-   `country`
-   `website`
-   `email_verified_at`
-   timestamps

Store the original submitted contact details even if the User or
Producer profile changes later. Restrict access to personal/contact
information.

Avoid storing the same information in multiple models without a clear
reason. Consider a JSON snapshot only if it matches existing project
conventions and query/reporting needs.

### WinePackageItem

Reuse the existing item model.

It must support a submission that does not yet map to the Wine Words
catalogue. Keep `vintage_id` and any catalogue foreign keys optional
where required by the existing domain.

Preserve submitted values, potentially including:

-   Submitted wine name.
-   Submitted vintage label (including NV).
-   Region/appellation.
-   Country.
-   Grape variety/blend.
-   Alcohol percentage.
-   Retail price and currency.
-   Wholesale price and currency, if collected.
-   Production volume and unit.
-   Release date/status.
-   Wine description and technical notes.
-   Product URL.
-   Optional structured attributes.

Use explicit columns for fields that need validation, filtering or
reporting. Use a structured JSONB field only for genuinely flexible
supplemental details. Do not put the entire domain into an unvalidated
JSON blob.

A submitted wine is not automatically a published catalogue
Wine/Vintage. Preserve the original values even after matching to
catalogue records.

### WinePackageMessage

Create a package-specific conversation model.

Suggested fields:

-   `wine_package_id`
-   `sender_id` nullable only where a verified guest sender is supported
-   `sender_type` or equivalent actor classification
-   `visibility` (`public` / `internal`)
-   `body`
-   `read_at` or a separate read-receipt design
-   timestamps

Prefer a real User sender for authenticated messages. For guest
messages, link to the verified submission contact and/or a secure guest
identity rather than trusting a client-supplied sender type.

Internal notes must be distinguishable and protected at the API
query/policy layer. Never rely on frontend hiding.

Use ActiveStorage for attachments, with strict content type, size and
access controls.

### WinePackageEvent

Use an audit/history model if no existing event/history mechanism is
adequate.

Record significant transitions and actions:

-   Submission received.
-   Email verified.
-   Account claimed.
-   Producer matched/created.
-   Assessment started.
-   Information requested.
-   Wine approved/rejected.
-   Package approved/rejected.
-   Quotation issued/accepted.
-   Invoice issued.
-   Payment confirmed/failed/refunded.
-   Shipping instructions sent.
-   Tracking updated.
-   Partial/full receipt.
-   Review assigned/started/completed.

Include actor, event type, timestamp and safe structured metadata. Avoid
duplicating sensitive message content or payment secrets.

### Billing entities

Keep financial records separate from WinePackage state.

Use existing billing models if suitable. Otherwise consider:

-   `WinePackageQuote` or equivalent quotation record.
-   `WinePackageInvoice`.
-   `Payment` or the existing payment transaction model.

A quote is an offer; an invoice is a financial document; a payment is a
transaction. Do not treat them as one status field.

Snapshot service descriptions, quantities, unit prices, discounts, tax
treatment, currency and totals on the issued commercial document. Never
recompute a historical invoice from current pricing configuration.

### Producer matching

The package may initially have no `producer_id`. During assessment an
Editor can match or create a Producer. Keep submitter identity separate
from Producer identity.

Do not automatically create ProducerMembership or owner permissions.
Membership is a separate authorisation workflow.

## 3.3 Suggested conceptual relationships

``` mermaid
erDiagram
  USER o|--o{ WINE_PACKAGE : submits
  PRODUCER o|--o{ WINE_PACKAGE : represented_by
  WINE_PACKAGE ||--o| WINE_SUBMISSION_CONTACT : contact
  WINE_PACKAGE ||--|{ WINE_PACKAGE_ITEM : contains
  WINE_PACKAGE ||--o{ WINE_PACKAGE_MESSAGE : conversation
  WINE_PACKAGE ||--o{ WINE_PACKAGE_EVENT : history
  WINE_PACKAGE ||--o{ WINE_PACKAGE_INVOICE : billed
  WINE_PACKAGE_INVOICE ||--o{ PAYMENT : paid_by
  WINE_PACKAGE_ITEM }o--o| VINTAGE : matched_to
  USER o|--o{ PRODUCER_MEMBERSHIP : member
  PRODUCER ||--o{ PRODUCER_MEMBERSHIP : has
```

## 3.4 Status design

Do not overload a single `status` field with unrelated workflows. Map
the current WinePackage status implementation first. If it cannot
represent the lifecycle cleanly, use separate state dimensions or
related workflow records.

Suggested editorial states:

-   `pending_assessment`
-   `under_assessment`
-   `information_requested`
-   `partially_approved`
-   `approved`
-   `rejected`
-   `withdrawn`

Suggested commercial states:

-   `not_applicable`
-   `quote_draft`
-   `quote_sent`
-   `awaiting_payment`
-   `partially_paid` (only if supported)
-   `paid`
-   `payment_failed`
-   `cancelled`
-   `refunded`

Suggested fulfilment states:

-   `not_ready`
-   `awaiting_shipment`
-   `in_transit`
-   `partially_received`
-   `received`
-   `discrepancy`
-   `cancelled`

Review status should reuse the existing WinePackage/review assignment
process wherever possible.

Use explicit transition services/policies. Do not allow clients to PATCH
arbitrary status strings.

------------------------------------------------------------------------

# 4. Public form specification

## 4.1 Form steps

Build a mobile-first multi-step form with a visible progress indicator
and a review/confirmation step.

### Step 1 --- Contact and company

Required:

-   First name.
-   Last name.
-   Email.
-   Phone (decide whether mandatory after usability review).
-   Company/winery/organisation name.
-   Business type: winery/producer, importer, distributor,
    agent/representative, retailer, other.
-   Country.

Optional:

-   Website.
-   Job title/role.
-   Business address only if genuinely needed at initial submission.

Do not ask for a password in the initial submission form. Do not ask for
a shipping address at this stage.

### Step 2 --- Wines

Allow adding/removing multiple wine entries. Keep required fields
minimal.

Recommended initial required fields:

-   Wine name.
-   Vintage or NV.
-   Country.
-   Region.

Recommended optional fields:

-   Grape variety/blend.
-   Alcohol percentage.
-   Retail price and currency.
-   Wholesale price and currency.
-   Production volume and unit.
-   Release date / pre-release status.
-   Description and winemaking notes.
-   Product URL.
-   Organic/biodynamic certification.
-   Closure.
-   Residual sugar for relevant styles.
-   Bottle/front-label image.
-   Technical sheet.

Avoid an overly long form. Editors can request missing details later.
Use conditional fields only when useful.

### Step 3 --- Service and submission details

Initial launch should support the Standard Wine Review service only
unless the current commercial model has already approved additional
services.

Collect:

-   Requested service.
-   Reason for submission or context.
-   Availability/release timing.
-   Expected timing constraints, if relevant.
-   Additional message.

Future service types may include fast-track reviews, portfolio
assessments and promotional packages. Payment must not guarantee a
score, review outcome or favourable coverage.

### Step 4 --- Review and declaration

Show a clear summary of:

-   Contact/company.
-   Wine count and wine details.
-   Requested service.
-   Terms and conditions.
-   Privacy notice.
-   Editorial independence statement.
-   Confirmation that submitter is authorised to provide the
    wines/information.

Require explicit acceptance of the relevant terms. Record the
terms/privacy version and acceptance timestamp.

## 4.2 Form behaviour

-   Allow users to add and remove multiple wines.
-   Preserve data when navigating between steps.
-   Validate both client-side and server-side.
-   Show field-level errors and a useful summary.
-   Prevent accidental duplicate submissions using an idempotency key or
    equivalent.
-   Do not trust frontend validation.
-   Support accessible labels, keyboard navigation and screen readers.
-   Ensure the form works on narrow mobile screens.
-   Use appropriate file upload progress and error handling.
-   Do not upload files to public buckets.
-   Do not expose internal IDs or trust hidden form fields for
    authorisation.

## 4.3 Confirmation page

After successful submission:

-   Show a reference number.
-   Confirm that the request is pending editorial assessment.
-   Explain that submission does not mean acceptance.
-   Explain that payment is not due yet.
-   Explain that the user must verify their email to access the package.
-   Explain the next steps and expected communication channel.
-   Provide a safe resend-verification option without exposing whether
    an account exists.

------------------------------------------------------------------------

# 5. Account provisioning, verification and package claiming

## 5.1 Account lifecycle

Use the existing User/authentication system. Do not create a second
authentication mechanism.

Preferred flow:

1.  Public submission is saved with contact email and no assumed
    authenticated identity.
2.  Send a one-time email verification/claim link.
3.  Verify mailbox ownership.
4.  If no User exists, provision an account in the project's supported
    unconfirmed/pending state, or create it after verification.
5.  Send a secure password setup link using the existing authentication
    mechanism.
6.  After password setup, associate the package with the authenticated
    User.
7.  If a User already exists, leave their credentials and account state
    untouched. They must authenticate through the normal login flow
    before the package is attached to their account.
8.  Once claimed, show the package under My Wine Packages.

The implementation must decide whether the project can safely create an
unconfirmed Devise User without a password, or whether account creation
should happen only after verification. Do not invent a password, set a
reusable default password or store a raw token.

## 5.2 Existing email behaviour

-   Public submission must work even if the email already belongs to a
    User.
-   Response text must be generic and must not reveal account existence.
-   Never automatically sign in the submitter.
-   Never reset an existing password as a side effect of submission.
-   Never attach a package to an existing account until the person has
    authenticated or completed an explicitly approved secure
    account-claim flow.
-   Provide the normal password recovery route.

## 5.3 Token security

For verification, claim and password setup:

-   Generate cryptographically secure random tokens.
-   Store only a digest/hash of the token where practical.
-   Set short, documented expiry.
-   Make single-use tokens.
-   Revoke/rotate tokens when resent.
-   Rate-limit creation and redemption.
-   Avoid tokens in application logs, analytics, referrers or error
    trackers.
-   Use HTTPS.
-   Use generic error responses for invalid/expired tokens.
-   Do not allow a token for one package to access another package.
-   Ensure claim tokens cannot change the email address or take over an
    existing User account.

## 5.4 Multiple packages and shared business email

A verified email may submit multiple packages. Support claiming multiple
eligible packages through the same verified contact, but require
authentication for existing accounts.

Do not assume one email address equals one Producer. Multiple people may
use a shared winery email, and one person may represent several
producers.

------------------------------------------------------------------------

# 6. Package conversations and attachments

## 6.1 Conversation model

Each WinePackage has one chronological conversation thread.

Participants:

-   Submitter/contact.
-   Assigned Editor(s).
-   Admins with appropriate permissions.

Capabilities:

-   Public messages visible to the submitter and authorised staff.
-   Private internal notes visible only to authorised Editors/Admins.
-   Attachments.
-   Read/unread indication.
-   Message timestamps and sender identity.
-   Message history.
-   In-app notification and email notification for new public messages.

Do not build a general-purpose chat system. Keep messages attached to
WinePackage.

## 6.2 Message rules

-   Save the message before queuing notifications.
-   Use a database transaction for message persistence and notification
    event creation where appropriate.
-   Use ActiveJob for email delivery.
-   Make notification jobs idempotent.
-   Retry transient failures.
-   Do not lose the message if email delivery fails.
-   Do not send internal notes to the submitter.
-   Do not include private attachments in notification emails.
-   Email should contain a short preview and a link to the package.
-   Initial release supports replies in Wine Words, not email-to-message
    replies.
-   Sanitize/render message bodies safely; prevent stored XSS.
-   Apply message length and attachment limits.
-   Rate-limit guest and authenticated message creation.
-   Consider a message status such as `pending_review` for suspicious
    guest content if needed.

## 6.3 Guest conversation access

A verified anonymous submitter can access only the specific package and
its public conversation through a secure, expiring, revocable access
link or a short-lived session established after verification.

Prefer exchanging the one-time email token for a secure, HTTP-only
session/cookie rather than leaving a long-lived bearer token in the URL.
Apply appropriate SameSite, Secure and HttpOnly cookie settings, CSRF
protections and session expiry.

When the person creates an account, transfer access by authenticated
package claiming. Revoke guest access where appropriate.

## 6.4 Internal notes

Internal notes must be excluded at the query/service/policy level from:

-   Submitter API responses.
-   Guest package views.
-   Email notifications.
-   User-facing notification payloads.
-   Exports intended for submitters.

Test this explicitly.

------------------------------------------------------------------------

# 7. Editorial assessment and Trade Management

Add a Trade Management section to the existing administration interface.
Reuse current admin navigation, role/permission patterns and UI
components.

## 7.1 Submission queue

Provide:

-   Search by reference, contact, company and Producer.
-   Filters by submission date, country, region and
    editorial/commercial/fulfilment status.
-   Sort by newest, oldest and last activity.
-   Assignment to an Editor.
-   Counts for new, under assessment, information requested, awaiting
    payment and awaiting arrival.

## 7.2 Assessment details

Display:

-   Original contact/company snapshot.
-   Email verification state.
-   Existing User match state without exposing account information to
    unauthorised users.
-   Existing Producer match or unlinked company.
-   Submitted wine details and attachments.
-   Possible duplicate warnings.
-   Conversation.
-   Audit history.

Editor actions:

-   Start assessment.
-   Request more information.
-   Match existing Producer.
-   Create Producer.
-   Match a wine to existing Wine/Vintage.
-   Flag possible duplicate.
-   Approve/reject individual wine items.
-   Partially approve package.
-   Reject package with reason.
-   Withdraw/cancel with reason.
-   Assign reviewer(s) later in the existing workflow.

## 7.3 Partial approval

A package may contain five wines, of which three are approved and two
rejected or held for more information.

The invoice should include only approved, billable items/services.
Rejected items must not silently be billed.

Define package-level status derivation carefully. Do not allow a package
to be labelled fully approved if some items remain undecided.

## 7.4 Producer matching

-   Search existing Producer records.
-   Show enough identifying information to avoid accidental duplicate
    matches.
-   Permit Editor/Admin to create a Producer when necessary.
-   Keep the original company name snapshot.
-   Record who performed the match and when.
-   Do not automatically create membership or ownership.
-   Provide a separate invitation/claim process for Producer access.

## 7.5 Internal notes and audit

Editors can add internal notes, but these must be separate from public
conversation messages or explicitly marked private with strict policies.

Record important changes with actor and timestamp. Audit logs must not
contain secrets, payment card data or raw access tokens.

------------------------------------------------------------------------

# 8. Commercial workflow: quotes, invoices and payment

## 8.1 Commercial sequence

1.  Submission received --- free.
2.  Editorial assessment --- no payment required.
3.  Editor approves all or selected wines.
4.  Editor chooses the service and billable quantities.
5.  Editor confirms a quotation.
6.  System generates/sends an invoice or payment request.
7.  Submitter pays.
8.  Verified payment event updates the financial record.
9.  Shipping instructions become available.
10. Admin override is possible only with explicit permission, reason and
    audit event.

Rejected submissions do not receive an invoice. More information
requests do not trigger billing.

## 8.2 Pricing configuration

Do not hardcode prices in React or scattered service objects.

Create an Admin-managed service/pricing configuration or reuse an
existing product/pricing model if appropriate.

Support:

-   Service name and description.
-   Unit of charge (per wine, per package, etc.).
-   Currency.
-   Unit price.
-   Tax treatment.
-   Active/inactive state.
-   Effective dates/versioning if needed.
-   Optional discount or adjustment with reason.

The Editor must be able to override price only with permission and a
recorded reason.

Snapshot all pricing data on the quote/invoice so historical documents
do not change when catalogue prices change.

## 8.3 Quote versus invoice

Decide with the accountant whether the business process needs a formal
quote followed by a tax invoice, or whether an approved invoice/payment
request is appropriate.

Keep the model flexible enough to support both. Do not call a document a
tax invoice unless it satisfies applicable Australian requirements.

Tax/GST treatment must be confirmed by the business/accountant. Do not
assume all customers, countries or services have identical tax
treatment.

## 8.4 Payment provider

Stripe is a reasonable initial option if it fits the business's country,
currency and accounting requirements.

Use hosted checkout or hosted invoice payment pages. Do not
collect/store card data in the Wine Words application.

Configuration and implementation requirements:

-   Separate test and live credentials.
-   Store secrets in deployment environment variables/secret manager,
    never source control.
-   Configure webhook endpoint and signing secret.
-   Verify webhook signatures.
-   Make webhook processing idempotent.
-   Handle duplicate, delayed and out-of-order events.
-   Store provider IDs and transaction status, not card details.
-   Support failed, pending, paid, cancelled and refunded states.
-   Record partial payments only if the business process needs them.
-   Reconcile provider state with internal records.
-   Never trust the frontend success redirect as proof of payment.
-   Do not release shipping instructions until a verified successful
    payment event or authorised override.
-   Test refunds and disputes.
-   Provide a manual payment recording workflow only for authorised
    roles, with reference and audit event.

If Stripe is deferred, first implement quote/invoice records and a
manual bank-transfer workflow. Payment integration should be a separate
phase and should not block the public submission launch.

## 8.5 Email invoice documents

Generate invoices server-side using the project's established
PDF/document approach. Store issued documents as immutable ActiveStorage
attachments or otherwise preserve a reproducible snapshot.

Email should include: - Package reference. - Approved wine/service
summary. - Total and currency. - Due date. - Payment
instructions/link. - Invoice document. - Contact details for billing
questions.

------------------------------------------------------------------------

# 9. Shipping and fulfilment

Shipping details are collected after package acceptance and payment, not
in the initial public submission form.

After payment:

1.  Send shipping instructions and destination.
2.  Allow submitter to confirm shipping contact/address if needed.
3.  Record courier and tracking number.
4.  Record dispatch date.
5.  Notify Editor of shipment.
6.  Record arrival date and recipient.
7.  Record received quantities and condition/discrepancies.
8.  Handle partial deliveries.
9.  Notify submitter of receipt.
10. Move accepted items into the existing review workflow.

Do not expose the shipping destination publicly. Restrict it to
authorised staff and the relevant submitter.

Support: - Tracking URL/number. - Courier. - Number of packages. -
Expected delivery date (optional). - Actual received date. - Received
bottle quantities per WinePackageItem. - Damaged/missing samples and
notes. - Admin override with audit history.

Do not assume that every submitted wine must be shipped immediately
after approval; define any submission windows and deadlines in the
guidelines.

------------------------------------------------------------------------

# 10. Cloudflare Turnstile, rate limiting and abuse protection

This is a mandatory part of the public submission implementation, not a
later cosmetic enhancement.

## 10.1 Cloudflare configuration

In Cloudflare dashboard:

1.  Open the Cloudflare account for the Wine Words domain.
2.  Navigate to **Turnstile**.
3.  Create a new widget for the production Wine Words domain.
4.  Choose the appropriate widget mode after testing compatibility with
    the React form. Managed mode is a sensible starting point.
5.  Add all legitimate hostnames:
    -   Production custom domain(s).
    -   Relevant Cloudflare Pages/Workers preview hostname(s), if the
        form is tested there.
    -   Local development hostname only if needed for local testing.
6.  Create a separate staging widget where practical.
7.  Record the Site Key and Secret Key.
8.  Configure the Site Key in the frontend environment.
9.  Configure the Secret Key only in the Rails API environment.
10. Never expose the Secret Key in Vite variables, browser bundles, Git,
    logs or client responses.

Exact dashboard labels may change; use the current Cloudflare Turnstile
documentation when configuring the account.

Official documentation: - https://developers.cloudflare.com/turnstile/ -
https://developers.cloudflare.com/turnstile/get-started/ -
https://developers.cloudflare.com/turnstile/get-started/server-side-validation/

## 10.2 Environment variables

Suggested names; adapt to existing configuration conventions:

Frontend: - `VITE_TURNSTILE_SITE_KEY`

Rails API: - `TURNSTILE_SECRET_KEY` - `TURNSTILE_EXPECTED_HOSTNAMES` -
`TURNSTILE_ENABLED` - `TURNSTILE_VERIFY_URL` only if the project
intentionally makes the endpoint configurable; otherwise use the
official endpoint in code/config.

Use separate values for development, staging and production. Do not
commit real values.

For local development, use Cloudflare's documented test keys or a
deliberately controlled development bypass. A bypass must never be
enabled in production.

## 10.3 Client integration

-   Render the Turnstile widget in the public submission flow.
-   Obtain a fresh token for the submission action.
-   Include the token in the API request.
-   Handle success, expiry, timeout and error callbacks.
-   Reset/reissue the widget after a failed/expired attempt.
-   Do not consider a browser-side successful challenge sufficient.
-   Do not persist Turnstile tokens in local storage or long-lived form
    drafts.
-   Do not log tokens.

## 10.4 Server-side verification

Rails must validate the token with Cloudflare's Siteverify endpoint
before accepting the public submission.

Requirements:

-   Use server-to-server HTTPS.
-   Send the secret and response token.
-   Include the remote IP only where appropriate and in accordance with
    privacy policy.
-   Validate the returned success flag.
-   Validate expected hostname.
-   Validate action if an action is configured.
-   Validate cdata if used.
-   Handle timeout, network failure and malformed responses safely.
-   Fail closed for production public submissions when verification
    cannot be completed.
-   Do not trust a token supplied by a client without Siteverify.
-   Treat tokens as single-use; a token must not be replayed.
-   Do not log the secret or token.
-   Add tests for valid, invalid, expired, duplicate/replayed and
    unavailable verification responses.

Turnstile is one layer, not a substitute for rate limiting or
validation.

## 10.5 Rate limiting

Use the existing Rails rate-limiting solution if one exists and is
correctly configured. Otherwise assess Rack::Attack or the project's
current middleware.

Apply separate limits to: - Public submission creation. - Email
verification resend. - Token redemption. - Password setup/resend. -
Guest package access. - Guest conversation messages. - Attachment
uploads. - Contact form endpoints if relevant.

Rate-limit by a combination of IP, normalized email/contact and relevant
resource where appropriate. Be careful with shared winery/NAT IPs; do
not make ordinary trade offices unusable.

Use: - A low initial burst allowance. - A reasonable rolling-window
limit. - Progressive cooldown for repeated abuse. - Generic responses
that do not reveal account existence. - `429 Too Many Requests` with
appropriate retry guidance.

Tune thresholds using logs/metrics rather than guessing permanently.
Ensure rate-limit storage works across multiple Rails instances (shared
Redis or another suitable shared store); process-local memory limits are
insufficient in a multi-instance deployment.

## 10.6 Additional anti-abuse controls

-   Cloudflare WAF rules for obvious malicious traffic where suitable.
-   Request body and upload size limits at edge, proxy and Rails layers.
-   Strict server-side parameter allowlists.
-   Honeypot field only as supplemental detection.
-   Submission idempotency.
-   Email verification before package claiming.
-   Attachment type/size validation.
-   Safe error handling.
-   Monitoring for submission spikes and email delivery spikes.
-   Admin ability to flag/disable abusive contacts or packages.
-   Do not block legitimate users solely because their IP is shared or
    geolocation is unusual.

------------------------------------------------------------------------

# 11. Application security requirements

## 11.1 Authentication and authorisation

-   Reuse existing authentication and role policies.
-   Public submission endpoint is narrowly scoped.
-   Public users cannot set `user_id`, `producer_id`, approval status,
    price, invoice status, payment status or review status.
-   Authenticated submitters cannot access another user's packages by
    changing an ID.
-   Editors/Admins have explicit policies for assessment and commercial
    actions.
-   Internal notes are staff-only.
-   Producer membership permissions are not inferred from a submission.
-   Guest tokens grant access only to one package and allowed actions.
-   Use strong random tokens, hashed at rest, expiry and revocation.
-   Do not auto-login an existing account based on an email submission.

## 11.2 Input validation and injection

-   Strong parameters/explicit DTO allowlists.
-   Validate string lengths, numeric ranges, dates, currency and URLs.
-   Normalize email consistently.
-   Reject malformed nested wine arrays and unexpected attributes.
-   Escape/render user content safely.
-   Prevent stored/reflected XSS in wine descriptions and messages.
-   Use parameterized queries/ActiveRecord safe query patterns.
-   Prevent mass assignment of protected fields.
-   Avoid arbitrary URL fetching from user-supplied wine/product URLs
    (SSRF risk).
-   If external URL previews are ever introduced, use a hardened
    allowlisted fetcher.

## 11.3 File upload security

Use the existing ActiveStorage setup and Cloudflare R2 if already
configured.

-   Private storage for submission files and message attachments.
-   Allow only required file types.
-   Verify actual content/signature where possible, not only filename or
    browser MIME.
-   Set per-file and per-package size limits.
-   Generate safe storage keys; do not trust original filenames as
    paths.
-   Restrict download access through authorised controllers/services.
-   Use short-lived signed URLs where direct download is appropriate.
-   Consider malware scanning/quarantine before staff downloads.
-   Prevent SVG/HTML execution from untrusted upload origins.
-   Strip metadata from public derivative images if appropriate.
-   Do not attach private documents to public catalogue records by
    default.
-   Ensure R2 bucket permissions do not make private objects publicly
    readable.

## 11.4 Privacy and personal information

-   Publish a privacy notice explaining collection and use of contact,
    company and submission information.
-   Collect only information needed for submission and fulfilment.
-   Restrict shipping/contact details to relevant staff and submitter.
-   Define retention/deletion policy for rejected, abandoned and
    completed packages.
-   Avoid placing personal data in URLs, analytics, logs or error
    messages.
-   Do not expose contact details to other producers or reviewers unless
    required.
-   Define who can export/download submission information.
-   Confirm Australian privacy, spam and consumer-law obligations with
    appropriate professional advice.

## 11.5 Email security

-   Configure SPF, DKIM and DMARC for sending domains.
-   Use existing Brevo/Resend infrastructure and existing delivery
    abstraction.
-   Do not send raw access tokens in logs.
-   Use single-use expiring action links.
-   Use generic account-related responses.
-   Rate-limit outbound messages to prevent abuse.
-   Add email delivery failure monitoring and retry handling.
-   Avoid exposing private messages/attachments in emails.
-   Include a safe link back to Wine Words rather than relying on email
    replies.

## 11.6 Payment security

-   Hosted payment page only; never store card data.
-   Verify webhook signatures.
-   Idempotent webhook processing.
-   Store provider references and event IDs.
-   Handle replay and out-of-order events.
-   Separate test/live secrets.
-   Audit manual payment overrides and refunds.
-   Never treat a browser redirect as proof of payment.

## 11.7 Operational security

-   Secrets only in deployment secret configuration.
-   Least-privilege access to Cloudflare, R2, email and payment
    provider.
-   Separate development/staging/production resources where practical.
-   Dependency and container scanning consistent with existing CI.
-   Security tests for public endpoints and object-level authorisation.
-   Structured logs with PII/token redaction.
-   Error tracking must scrub request bodies, tokens, email verification
    URLs and payment secrets.

------------------------------------------------------------------------

# 12. Email and notification configuration

Reuse the existing Wine Words notification/bell and email delivery
infrastructure.

## 12.1 Required email templates

1.  Submission received.
2.  Verify submission email.
3.  Set up password / activate account.
4.  Submission claim confirmation.
5.  New message from Editor.
6.  New reply from submitter.
7.  Additional information requested.
8.  Submission approved.
9.  Submission partially approved.
10. Submission rejected.
11. Quote/invoice issued.
12. Payment reminder.
13. Payment received.
14. Shipping instructions.
15. Tracking update.
16. Package received.
17. Discrepancy/damaged samples.
18. Review progress/completion.

## 12.2 Delivery behaviour

-   Use existing mailer/service conventions.
-   Queue emails asynchronously.
-   Use retry policies for transient failures.
-   Persist the underlying event/message before delivery.
-   Avoid duplicate notifications on job retry.
-   Track delivery result where provider supports it.
-   Do not let email failure roll back a successfully created
    package/message.
-   Provide an Admin retry/resend mechanism with audit history.
-   Respect notification preferences where appropriate, while retaining
    essential transactional messages.

## 12.3 Message email content

Subject example:

`New message about Wine Package #WP-1234`

Body should contain: - Sender/role. - Package reference. - Short
plain-text preview. - Link to view the conversation. - No internal note
content. - No private attachment URL.

The email is a notification; replies are made in Wine Words in the
initial release.

------------------------------------------------------------------------

# 13. API design

First inspect existing API namespace, serializers and authentication
conventions. The following are conceptual endpoints; adapt paths to the
project's established conventions and avoid duplicate endpoints.

## 13.1 Public endpoints

-   `POST /api/v1/wine_packages` --- public submission.
-   `POST /api/v1/wine_package_email_verifications` --- verify/resend
    workflow as appropriate.
-   `POST /api/v1/wine_package_claims` --- claim a package after secure
    verification/authentication.

The public create endpoint must accept only permitted submission fields
and Turnstile token. It must not accept privileged package fields.

## 13.2 Authenticated submitter endpoints

-   `GET /api/v1/my/wine_packages`
-   `GET /api/v1/my/wine_packages/:id`
-   `PATCH /api/v1/my/wine_packages/:id` --- only explicitly permitted
    fields/actions.
-   `GET /api/v1/wine_packages/:id/messages`
-   `POST /api/v1/wine_packages/:id/messages`
-   `POST /api/v1/wine_packages/:id/message_attachments` if separate
    upload flow is needed.
-   Shipping/tracking endpoints only when the package is at the
    appropriate stage.

## 13.3 Editor/Admin endpoints

Use the existing admin namespace/policy structure for:

-   Submission queue and filters.
-   Submission assessment details.
-   Producer matching/creation.
-   Item approval/rejection.
-   Information requests.
-   Quote and invoice creation.
-   Payment reconciliation/refund actions.
-   Shipping/receipt management.
-   Reviewer assignment.
-   Internal notes.
-   Audit/event history.

Do not implement status updates as arbitrary PATCHes. Use explicit
command/action endpoints or service methods with policy checks and
transition validation.

## 13.4 API response security

-   Serializers must expose only fields appropriate to the caller.
-   Public submission response returns reference and next-step
    information, not internal IDs/secrets.
-   Guest serializer excludes internal notes, staff-only metadata and
    unrelated User information.
-   Submitter serializer excludes internal assessment notes and other
    submitters' data.
-   Admin serializer is role/policy restricted.
-   Do not serialize raw token digests, provider secrets or internal
    storage keys.

------------------------------------------------------------------------

# 14. Frontend implementation

Use existing React/Vite patterns, routing, state management, API client,
form library and design system. Do not introduce a new framework without
a strong reason.

## 14.1 Public Trade pages

-   Trade landing page.
-   Submit a Wine multi-step form.
-   Submission confirmation page.
-   Email verification/claim page.
-   Submission Guidelines page.

## 14.2 Authenticated pages

-   My Wine Packages list.
-   WinePackage details.
-   Package timeline.
-   Conversation/messages.
-   Attachments.
-   Quote/invoice/payment view.
-   Shipping and tracking view.

## 14.3 Admin pages

-   Trade Management dashboard.
-   Submission queue.
-   Submission details.
-   Wine-item assessment.
-   Producer matching.
-   Commercial quote/invoice editor.
-   Fulfilment/receipt panel.
-   Internal conversation notes.
-   Audit history.

## 14.4 Frontend UX requirements

-   Mobile-first and accessible.
-   Clear pending/approved/rejected/payment/fulfilment indicators.
-   Do not show irrelevant actions before the package reaches the
    correct state.
-   Distinguish public messages from internal notes.
-   Show upload progress and retry states.
-   Avoid losing form data on transient errors.
-   Prevent duplicate submission clicks.
-   Handle expired guest links gracefully.
-   Show login/claim actions without disclosing account existence.
-   Use consistent Wine Words styling.

------------------------------------------------------------------------

# 15. Detailed implementation phases and AI prompts

Each phase should be a separate implementation task/PR where practical.
Run relevant tests after each phase. Do not ask an AI coding agent to
implement all phases in one pass.

## Phase 0 --- Repository baseline and architecture audit

**Goal:** Understand the current Wine Words implementation and produce a
reuse map.

### Tasks

-   Inspect both repositories and current branches.
-   Read relevant models, migrations, services, policies, controllers,
    serializers, routes, React pages and tests.
-   Identify existing WinePackage workflow and statuses.
-   Identify existing notification, email and ActiveStorage patterns.
-   Identify authentication modules and account confirmation/password
    setup behaviour.
-   Identify current deployment and environment configuration.
-   Identify current security/rate-limit protections.
-   Document all gaps against this plan.
-   Do not modify code.

### AI prompt

``` text
You are working on Wine Words, consisting of:
- wine_words_api (Rails API)
- wine_words_frontend (React/Vite)

Perform a read-only architecture audit for the planned Trade portal and public wine submission workflow.

Inspect the actual repositories. Do not assume models, routes, gems, services or features exist based on this plan.

Specifically inspect:
1. WinePackage and WinePackageItem models, associations, validations, status transitions and existing creation workflows.
2. Wine, Vintage, Review and Producer models.
3. ProducerMembership and role/permission policies.
4. User authentication, email confirmation, password setup and password recovery.
5. Notifications and email delivery.
6. ActiveStorage and current storage providers.
7. Existing billing/payment code.
8. API routes, controllers, serializers and service conventions.
9. Frontend routes, navigation, API client, forms and UI components.
10. Existing rate limiting, Cloudflare configuration and security tests.
11. CI, deployment and environment-variable conventions.

Deliver:
- Existing architecture map.
- Reusable components.
- Required changes.
- Proposed migrations, only where necessary.
- API and frontend work breakdown.
- Security risks.
- Test gaps.
- Recommended implementation order.

Do not modify files or generate migrations in this phase.
Cite actual file paths and relevant code locations in the report.
```

**Acceptance criteria** - Both repositories have been inspected. -
Existing functionality and gaps are documented. - No duplicate domain
model is proposed without justification. - Implementation dependencies
are identified.

## Phase 1 --- Domain design and technical specification

**Goal:** Finalise the data model, status transitions, access rules and
API contract before migrations.

### Tasks

-   Map current WinePackage lifecycle.
-   Define nullable User/Producer associations for public submissions.
-   Define contact snapshot ownership.
-   Define wine item snapshot fields.
-   Define message and internal-note permissions.
-   Define package event/audit structure.
-   Define account verification and claiming states.
-   Define editorial/commercial/fulfilment state separation.
-   Define partial approval behaviour.
-   Define API request/response contracts.
-   Define retention and privacy requirements.

### AI prompt

``` text
Based on the Phase 0 repository audit, produce the detailed technical specification for the Wine Words Trade submission feature.

The existing WinePackage must remain the central operational entity. Do not introduce a parallel WineSubmission aggregate.

Support:
- Anonymous public submissions.
- Authenticated submissions.
- Existing or not-yet-registered Producers.
- Multiple WinePackageItems.
- Original submitted wine data independent of catalogue records.
- Email verification and secure account claiming.
- Package-specific public messages and private internal notes.
- Editorial assessment and partial item approval.
- Separate commercial, fulfilment and review progress where required.

For each proposed model/field:
- Explain why it is needed.
- Identify whether it already exists.
- Define nullability, indexes, constraints and associations.
- Define data retention implications.

Produce:
1. ER diagram.
2. State transition tables.
3. Authorization matrix.
4. API contract.
5. Migration plan.
6. Security threat model.
7. Test plan.

Do not modify code.
```

**Acceptance criteria** - Model design reviewed against actual schema. -
No redundant fields/models. - Authorization matrix covers guest, User,
Editor and Admin. - State transitions and partial approval are
unambiguous.

## Phase 2 --- Trade navigation and public information pages

**Goal:** Establish the public Trade experience without yet enabling
package creation.

### Tasks

-   Add responsive Trade header menu.
-   Add Submit a Wine page/landing content.
-   Add Submission Guidelines.
-   Add My Wine Packages menu destination with appropriate
    authentication/claim handling.
-   Add future Trade Membership and Promotional Opportunities links only
    if they can be presented honestly; otherwise defer them.
-   Add page metadata and accessible navigation.
-   Ensure public pages do not require authentication.

### AI prompt

``` text
Implement the public Trade navigation and informational pages in wine_words_frontend.

Add a responsive Trade menu containing:
- Submit a Wine
- My Wine Packages
- Submission Guidelines

The Submit a Wine page should explain the process:
1. Submit wines.
2. Editorial assessment.
3. Approval and quotation/invoice.
4. Payment.
5. Shipping.
6. Receipt and review.

Explain that submission is free, acceptance is subject to editorial assessment, and payment does not guarantee a positive review or score.

Use the existing React/Vite routing, header, styling and component conventions.
Make the pages accessible and mobile-first.

Do not implement a new authentication system.
Do not create placeholder functionality that appears operational when it is not.
Add frontend tests for navigation and public access.
```

**Acceptance criteria** - Trade menu works at desktop and mobile
breakpoints. - Public pages are accessible without login. - Existing
navigation is not broken. - Guidelines do not make unsupported promises
about acceptance, fees or turnaround.

## Phase 3 --- Public submission backend and WinePackage integration

**Goal:** Create public packages safely, without requiring a User or
Producer.

### Tasks

-   Add/adjust schema only as justified by Phase 1.
-   Allow `user_id` and `producer_id` to be nullable where required.
-   Preserve existing internal package creation behaviour.
-   Create a submission service,
    e.g. `WinePackages::SubmitPublicRequest`.
-   Create package and items in a transaction.
-   Store original contact and wine information.
-   Set source and pending editorial state server-side.
-   Add idempotency protection.
-   Add public API endpoint.
-   Add request/service/model tests.
-   Do not create Wine/Vintage catalogue records automatically.

### AI prompt

``` text
Implement the public WinePackage submission backend in wine_words_api.

Use the existing WinePackage and WinePackageItem models and current project conventions.

Requirements:
- Anonymous visitors can submit.
- Authenticated users can submit.
- No Producer record is required.
- No User is required for an anonymous submission.
- Contact details are preserved as a submission snapshot.
- One package can contain multiple wine items.
- Original submitted wine information is retained.
- Catalogue Wine/Vintage associations remain optional until editorial matching.
- Source and initial editorial status are assigned by the server.
- The client cannot set user_id, producer_id, approval, invoice, payment, shipping or review status.
- Create package and all items transactionally.
- Use idempotency protection to prevent accidental duplicate packages.
- Preserve existing internal WinePackage workflows.

Implement the public API endpoint using existing routing, service and serializer patterns.

Add tests for:
- Anonymous submission.
- Authenticated submission.
- Multiple wines.
- Missing/invalid fields.
- Transaction rollback.
- Duplicate request handling.
- Protected fields/mass assignment.
- Existing package workflows remaining unchanged.

Do not implement email account claiming in this phase.
```

**Acceptance criteria** - Anonymous submission creates a WinePackage and
items. - Failure creating any item rolls back the transaction. - Client
cannot set privileged associations/statuses. - Existing internal package
workflows pass their tests.

## Phase 4 --- Cloudflare Turnstile, rate limiting and public abuse controls

**Goal:** Protect public submission and guest endpoints before public
launch.

### Tasks

-   Create Turnstile widgets for development/staging/production as
    appropriate.
-   Configure site keys and secret keys in correct environments.
-   Add frontend Turnstile component.
-   Add Rails server-side Siteverify service.
-   Validate hostname/action and response success.
-   Fail closed in production on verification errors.
-   Add replay/expiry tests.
-   Configure shared rate-limit storage.
-   Add limits for submission, verification, guest access, messages and
    uploads.
-   Add request size limits.
-   Add abuse monitoring.
-   Document local test mode and production configuration.

### AI prompt

``` text
Implement Cloudflare Turnstile and public abuse protection for Wine Words.

First inspect existing Cloudflare, Rails middleware, rate limiting and frontend configuration. Reuse existing infrastructure where suitable.

Turnstile:
- Frontend site key comes from VITE_TURNSTILE_SITE_KEY.
- Secret key is server-only in TURNSTILE_SECRET_KEY.
- Verify tokens server-side with Cloudflare Siteverify.
- Validate success, expected hostname and configured action.
- Treat tokens as single-use.
- Handle expiry, replay, timeout, network failure and malformed responses.
- Fail closed for production public submissions.
- Never log tokens or secrets.
- Use documented test keys or an explicit development-only bypass outside production.

Rate limiting:
- Protect public submission creation.
- Protect verification and resend endpoints.
- Protect guest package access.
- Protect guest messages and uploads.
- Use shared storage suitable for multiple Rails instances.
- Return safe 429 responses.
- Avoid revealing whether an email belongs to an account.
- Tune limits to avoid blocking legitimate shared winery office IPs.

Also add:
- Request size limits.
- Strong parameter allowlists.
- Idempotency protection.
- Abuse logging/metrics without unnecessary PII.
- Tests for all security paths.

Do not treat Turnstile as a replacement for server-side validation, authorization or rate limiting.

Update deployment/environment documentation with exact configuration steps.
```

**Acceptance criteria** - Invalid/missing/replayed Turnstile token
cannot create a public package in production. - Secret is not present in
frontend build output. - Rate limits work across multiple API
instances. - Production cannot accidentally use a development bypass. -
Security tests cover failure conditions.

## Phase 5 --- Public multi-step submission frontend

**Goal:** Deliver the complete Submit a Wine experience.

### Tasks

-   Build contact/company step.
-   Build repeatable wine item form.
-   Build service/context step.
-   Build review/declaration step.
-   Integrate Turnstile.
-   Integrate public API.
-   Support file upload.
-   Preserve form state during navigation.
-   Prevent double submission.
-   Show reference/confirmation.
-   Add accessible validation and mobile layout.

### AI prompt

``` text
Implement the public Submit a Wine form in wine_words_frontend and connect it to the public WinePackage API.

Build a mobile-first multi-step form:

1. Contact and company:
   name, email, phone, company name, business type, country, optional website.

2. Wines:
   repeatable wine entries with wine name, vintage/NV, country, region, grape blend, alcohol percentage, retail/wholesale price and currency, production volume, release date, description, product URL, optional bottle image and technical sheet.

3. Service and context:
   requested service (only currently configured services), availability/release information and message.

4. Review and declaration:
   summary, terms, privacy notice and editorial independence acknowledgement.

Requirements:
- No login or Producer record required.
- Support multiple wines.
- Keep required fields minimal.
- Validate client-side and display server errors.
- Integrate Cloudflare Turnstile using the public site key.
- Send the Turnstile token to the API.
- Handle expiry/reset/error.
- Prevent duplicate submissions.
- Preserve entered data during step navigation and recoverable errors.
- Do not persist Turnstile tokens.
- Do not expose private API secrets.
- Use existing API client, routing, design system and form conventions.
- Ensure keyboard/screen-reader accessibility and mobile usability.

After success, show a reference number and explain email verification and editorial assessment.

Add component and end-to-end tests.
```

**Acceptance criteria** - Complete anonymous and authenticated
submission works. - Multiple items work. - Turnstile is required in
production. - Form errors are understandable. - Duplicate clicks do not
create duplicate packages.

## Phase 6 --- Email verification, account provisioning and package claiming

**Goal:** Give submitters reliable access without forcing login before
submission.

### Tasks

-   Inspect Devise/current authentication modules.
-   Choose whether to create an unconfirmed User before verification or
    create after verification.
-   Implement email verification token.
-   Implement secure claim token/session exchange.
-   Implement password setup for new accounts.
-   Handle existing account without enumeration.
-   Support multiple packages for one verified email.
-   Associate package with authenticated User after claim.
-   Add resend/expiry/revocation.
-   Add tests for account takeover and enumeration.

### AI prompt

``` text
Implement email verification, account provisioning and WinePackage claiming.

Reuse the existing User/authentication implementation. Do not build a separate authentication system.

Requirements:
- Public submission is allowed whether or not a User exists.
- Send a verification/claim email after submission.
- Verify email ownership before guest access or account claiming.
- For a new email, provision an account using the existing supported confirmation/password setup flow. Decide from the actual authentication configuration whether to create a pending User before verification or create the User after verification.
- Send a secure password setup link.
- For an existing email, do not change credentials, reset the password, reveal account existence or automatically log in.
- Existing account owners must authenticate normally before package association.
- Support claiming multiple eligible packages associated with the same verified contact.
- Preserve original WineSubmissionContact data.
- Use secure random single-use tokens, store token digests, expire and revoke tokens.
- Do not log tokens.
- Rate-limit token issuance and redemption.
- Use generic public responses to prevent account enumeration.
- Use secure HTTP-only session/cookie handling for guest access where appropriate.
- Ensure a token for one package cannot access another package.

Add security tests for:
- Existing account email.
- New email.
- Expired/replayed token.
- Token revocation.
- Wrong package.
- Account enumeration.
- Unauthorized package claim.
- Multiple packages.
- Password setup and normal password recovery.

Document the final account lifecycle.
```

**Acceptance criteria** - New submitter can verify and set a password. -
Existing account is never silently authenticated or modified. - Verified
guest can access only the intended package. - Claiming associates the
package with the authenticated User. - Tokens are expiring, single-use
and not stored in plaintext.

## Phase 7 --- My Wine Packages

**Goal:** Give submitters one place to manage all authorised packages.

### Tasks

-   Build package list.
-   Build package details.
-   Show submitted wines and editorial decisions.
-   Show status/timeline.
-   Show messages.
-   Show invoices/payment.
-   Show shipping/receipt.
-   Show review links when available.
-   Support guest access via verified package access.
-   Apply strict object-level authorisation.

### AI prompt

``` text
Implement My Wine Packages in the Wine Words frontend and API.

This is the user's view of WinePackage records. Do not create a separate My Wine Submissions domain or model.

Support:
- Authenticated User's packages.
- Packages claimed by verified submitters.
- Secure guest access to a specific package where no account has been created.
- Package list with reference, Producer/company, date and status.
- Package details with wines, item decisions, progress, messages, commercial records, shipping and review progress as available.
- Clear status indicators.
- Responsive mobile-first UI.

The API must enforce ownership/claim authorization for every package and nested resource. Do not rely on frontend filtering.

Exclude internal notes, staff-only data and unrelated User details from submitter responses.

Add request, policy, serializer and frontend tests for cross-user access attempts.
```

**Acceptance criteria** - User sees only authorised packages. - Guest
sees only the package granted by verified access. - Internal information
never appears in submitter responses. - Existing package management
remains functional.

## Phase 8 --- Trade Management and editorial assessment

**Goal:** Give Editors/Admins a controlled assessment workflow.

### Tasks

-   Add submission dashboard and filters.
-   Add assignment.
-   Add assessment details.
-   Add Producer matching/creation.
-   Add wine catalogue matching.
-   Add per-item approve/reject/request-information.
-   Add partial package decisions.
-   Add internal notes.
-   Add event history.
-   Add explicit state transition services and policies.

### AI prompt

``` text
Implement Trade Management for Editors and Admins.

Use existing WinePackage, WinePackageItem, Producer, Wine/Vintage catalogue, role and permission patterns.

Build:
- Submission queue.
- Search and filters.
- Submission details.
- Contact/company information.
- Email verification state.
- Submitted wine details and attachments.
- Possible duplicate indicators.
- Producer matching or creation.
- Catalogue wine/vintage matching.
- Per-item approval/rejection.
- Partial package approval.
- Information requests.
- Editor assignment.
- Internal notes.
- Audit history.

Rules:
- Do not automatically create published Wine/Vintage records.
- Do not automatically grant ProducerMembership.
- Require reasons for rejection and overrides.
- Only authorised Editors/Admins can assess.
- Submitters cannot set editorial status.
- Preserve original submission snapshots.
- Ensure package-level state accurately reflects item-level decisions.

Use explicit transition services/actions rather than arbitrary status updates.

Add comprehensive policy, request, service and UI tests.
```

**Acceptance criteria** - Editors can assess and decide each item. -
Partial approval works. - Producer matching is audited. - No
unauthorised user can perform editorial actions. - Internal notes are
private.

## Phase 9 --- Package conversations and attachments

**Goal:** Implement the package-specific communication channel.

### Tasks

-   Add `WinePackageMessage` if no existing suitable message/comment
    model can be reused safely.
-   Support public messages and private internal notes.
-   Support attachments through ActiveStorage.
-   Add read/unread handling.
-   Add message authorization.
-   Add guest access.
-   Add sanitization and rate limits.
-   Update package last activity.
-   Add audit events.

### AI prompt

``` text
Implement conversations associated with WinePackage.

Inspect existing comments/messages first. Reuse an existing model only if it supports the required package-specific access and public/internal visibility without compromising other features. Otherwise create WinePackageMessage.

Requirements:
- One chronological conversation per WinePackage.
- Submitter and authorised Editor/Admin can send public messages.
- Editors/Admins can create private internal notes.
- Guest submitters can participate only through verified package-specific access.
- Support ActiveStorage attachments with private access.
- Add read/unread indicators.
- Record sender and timestamps.
- Update package last activity.
- Sanitize message content and prevent stored XSS.
- Rate-limit guest and authenticated message creation.
- Restrict attachment type and size.
- Persist message before scheduling email/notification jobs.
- Internal notes must never be returned to submitters or guest users.

Do not build a general chat application.
Do not support email-to-message replies in this phase.

Add tests for visibility, sender authorization, attachment access, XSS and cross-package access.
```

**Acceptance criteria** - Submitter and Editor can converse within a
package. - Private notes are invisible to submitters. - Attachments are
private and authorised. - Message creation survives email delivery
failure.

## Phase 10 --- Notification and email integration

**Goal:** Notify the correct participant for each package event/message.

### Tasks

-   Reuse existing notification/bell system.
-   Add message notification type.
-   Add email templates.
-   Add background jobs.
-   Add retry/idempotency.
-   Add resend/admin visibility.
-   Add delivery monitoring.

### AI prompt

``` text
Integrate WinePackage events and messages with existing Wine Words notifications and email infrastructure.

Reuse existing notification models, services, mailers, Brevo/Resend delivery abstraction and ActiveJob configuration.

Implement notifications/emails for:
- Submission received.
- Email verification.
- Password setup.
- New Editor message.
- Submitter reply.
- Additional information requested.
- Approval/partial approval/rejection.
- Quote/invoice issued.
- Payment received.
- Shipping instructions.
- Tracking update.
- Package received.
- Review completed.

Requirements:
- Save domain event/message before sending.
- Queue email asynchronously.
- Make jobs idempotent.
- Retry transient errors.
- Do not roll back a package/message if email delivery fails.
- Do not send internal notes.
- Do not expose private attachments.
- Use secure links.
- Avoid account enumeration.
- Add delivery status/error monitoring.
- Provide authorised resend functionality with audit history.

Add tests for duplicate jobs, retry and email content/privacy.
```

**Acceptance criteria** - Correct recipient receives each
notification. - No duplicate email on job retry. - Internal notes are
never emailed. - Email failures do not lose domain events.

## Phase 11 --- Quotes, invoices and commercial administration

**Goal:** Allow Editors/Admins to charge for approved review services.

### Tasks

-   Confirm pricing and service catalogue with business owner.
-   Confirm quote/invoice and GST requirements with accountant.
-   Implement service/pricing configuration or reuse existing pricing
    model.
-   Support per-item services and partial approval.
-   Implement quote approval.
-   Generate immutable invoice snapshot/PDF.
-   Add invoice email and payment instructions.
-   Add manual bank transfer status initially if payment provider is
    deferred.
-   Add audit trail.

### AI prompt

``` text
Implement the WinePackage commercial workflow without yet assuming a payment provider.

Inspect existing Wine Words subscription/billing models and reuse appropriate infrastructure.

Support:
- Admin-managed review services and prices.
- Editor selection of services for approved WinePackageItems.
- Partial approval and billing only for accepted/billable items.
- Quote draft and approval.
- Invoice generation.
- Immutable price, tax, currency, quantity and description snapshots.
- Invoice PDF stored privately.
- Invoice email.
- Due date and payment instructions.
- Manual bank transfer recording for authorised staff if required.
- Cancellation and credit/refund-ready data model.

Keep quotes, invoices, payments and WinePackage lifecycle distinct.
Do not hardcode pricing in the frontend.
Do not assume GST treatment; make it configurable and document that the business/accountant must confirm it.

Add tests for totals, rounding, partial approval, historical price snapshots, permissions and duplicate invoice prevention.
```

**Acceptance criteria** - Editor can create an invoice for approved
items. - Rejected items are not billed. - Invoice is immutable after
issue, with corrections handled through appropriate credit/reissue
workflow. - Financial records are separate from package status.

## Phase 12 --- Stripe payment integration (or alternative)

**Goal:** Accept payment safely after approval/invoice.

### Tasks

-   Confirm Stripe account, supported countries/currencies and business
    requirements.
-   Configure test/live API keys and webhook secret.
-   Implement hosted checkout/invoice payment link.
-   Implement verified webhook.
-   Implement idempotency and reconciliation.
-   Handle failure, cancellation, refund and duplicate/out-of-order
    events.
-   Release shipping only after confirmed payment or authorised
    override.

### AI prompt

``` text
Implement Stripe payment integration for WinePackage invoices.

Use Stripe-hosted Checkout or hosted invoice payment pages. Do not collect or store card details in Wine Words.

Requirements:
- Separate test and production configuration.
- Secrets in deployment environment only.
- Verify webhook signatures.
- Persist provider event IDs and process idempotently.
- Handle duplicate, delayed and out-of-order webhook events.
- Handle payment success, failure, cancellation and refund.
- Do not trust frontend redirect as payment confirmation.
- Reconcile internal invoice/payment state with provider references.
- Do not release shipping instructions until verified payment success or explicit authorised Admin override.
- Audit manual overrides and refunds.
- Do not log secrets or payment-sensitive information.

Add webhook integration tests using provider test fixtures and failure scenarios.
Document dashboard setup, webhook endpoint, events subscribed, environment variables and operational reconciliation.
```

**Acceptance criteria** - Payment is confirmed only by verified provider
event or documented authorised manual process. - Duplicate webhooks do
not duplicate payments. - Shipping gate works. - Refunds and failures
are represented correctly.

## Phase 13 --- Shipping and fulfilment

**Goal:** Manage physical wine sample delivery and receipt.

### Tasks

-   Collect shipping details after approval/payment.
-   Send shipping instructions.
-   Record courier/tracking.
-   Support partial deliveries.
-   Record quantities received per item.
-   Record damaged/missing samples.
-   Notify submitter and Editor.
-   Move items into existing review assignment flow.

### AI prompt

``` text
Implement WinePackage shipping and fulfilment.

Use existing package/item structures where possible.

After confirmed payment:
- Make shipping instructions available.
- Collect/confirm delivery contact and address.
- Record courier, tracking number/URL and dispatch date.
- Record package count if needed.
- Support partial deliveries.
- Record received date, recipient and quantities per WinePackageItem.
- Record damaged/missing samples and discrepancies.
- Notify submitter and Editor.
- Keep shipping state separate from invoice/payment and review state.
- Restrict address and tracking data to authorised participants.

Do not automatically mark all wines received when only part of the package arrives.

Add tests for payment gate, Admin override, partial receipt, discrepancies and access control.
```

**Acceptance criteria** - Shipping instructions are gated by
payment/override. - Partial deliveries are represented accurately. -
Received quantities are tracked per wine item. - Sensitive delivery
details are access controlled.

## Phase 14 --- Review workflow integration

**Goal:** Connect received wine samples to existing review operations.

### Tasks

-   Reuse existing review assignment and review lifecycle.
-   Link accepted/received WinePackageItems to appropriate Wine/Vintage
    records.
-   Allow Editor to create/match catalogue entries.
-   Assign reviewers.
-   Track review progress.
-   Link published reviews back to package.
-   Notify submitter at agreed milestones.
-   Preserve editorial independence.

### AI prompt

``` text
Integrate WinePackageItem fulfilment with the existing Wine Words review workflow.

Inspect existing Wine, Vintage, Review and reviewer assignment functionality.

Requirements:
- Only eligible received wine items can enter review assignment, unless an authorised exception is recorded.
- Match/create catalogue records through existing editorial controls.
- Preserve submitted wine snapshot.
- Link the WinePackageItem to the correct catalogue Wine/Vintage.
- Assign reviewer(s) using existing workflow.
- Track review progress without duplicating review status logic.
- Link published review to the package.
- Notify submitter when configured milestones occur.
- Payment must not influence review score or editorial outcome.

Add tests for item eligibility, matching, assignment, publication linkage and permissions.
```

**Acceptance criteria** - Existing review process is reused. - Only
eligible items enter review. - Submitted snapshots remain available. -
Published review links are correct.

## Phase 15 --- Security hardening, observability and production readiness

**Goal:** Complete security and operational checks before launch.

### Tasks

-   Run full API/frontend suites.
-   Add end-to-end anonymous and authenticated scenarios.
-   Test object-level authorisation.
-   Test account enumeration and claim abuse.
-   Test Turnstile failures and replay.
-   Test rate limits.
-   Test malicious uploads and message XSS.
-   Test webhook replay.
-   Test email delivery failure.
-   Configure monitoring/alerts.
-   Review logs for PII/secrets.
-   Review Cloudflare WAF and DNS/SSL configuration.
-   Run dependency/security scans.
-   Conduct production smoke test.

### AI prompt

``` text
Perform a production-readiness and security review of the Wine Words Trade portal.

Review both repositories and deployment configuration.

Test:
- Anonymous submission and Turnstile enforcement.
- Existing/new email behaviour.
- Account claiming and package ownership.
- Cross-user and cross-package access.
- Internal note isolation.
- Message and attachment security.
- Rate limits and abuse handling.
- Package status transition permissions.
- Partial approval and billing.
- Invoice duplication.
- Payment webhook signature/replay/idempotency.
- Shipping payment gate.
- Partial receipt.
- Email retry/duplicate behaviour.
- PII and secret leakage in logs/error tracking.
- Existing Wine Words functionality regression.

Run the complete test suites and relevant security/dependency scans.

Produce:
- Findings ranked by severity.
- Fixes for confirmed issues.
- Remaining risks and mitigations.
- Production deployment checklist.
- Rollback plan.
- Post-deployment smoke test plan.

Do not declare production-ready while critical/high-severity findings remain unresolved.
```

**Acceptance criteria** - No unresolved critical/high security issues. -
Existing app regression tests pass. - Monitoring and rollback steps
documented. - Production configuration reviewed.

------------------------------------------------------------------------

# 16. Configuration checklist

All values below are examples of variable names. Inspect current
deployment configuration and avoid duplicating existing variables.

## 16.1 Frontend environment

Potential variables:

``` dotenv
VITE_API_BASE_URL=
VITE_GOOGLE_CLIENT_ID=
VITE_TURNSTILE_SITE_KEY=
```

Only public values belong in `VITE_*`. Never put the Turnstile secret,
Stripe secret or mail credentials in frontend variables.

## 16.2 Rails API environment

Potential variables:

``` dotenv
TURNSTILE_SECRET_KEY=
TURNSTILE_EXPECTED_HOSTNAMES=
TURNSTILE_ENABLED=true

# Only if Stripe is selected
STRIPE_SECRET_KEY=
STRIPE_WEBHOOK_SECRET=
STRIPE_PUBLISHABLE_KEY=

# Existing mail/storage/auth variables should be reused.
```

Use the exact variable names chosen by implementation and document them
in `.env.example` with blank/example values only.

## 16.3 Cloudflare

Configure:

-   Turnstile production widget.
-   Separate staging widget if staging is used.
-   Correct hostnames.
-   Site key in frontend.
-   Secret key in Rails deployment secrets.
-   WAF/rate-limit rules where appropriate.
-   SSL/TLS and HTTPS.
-   R2 private bucket/CORS configuration if file storage uses R2.
-   Worker/Pages environment values for the correct deployment
    environment.

Do not assume the frontend Worker and Rails API share environment
variables. Configure each platform separately.

## 16.4 Render/deployment

For the Rails API deployment:

-   Add Turnstile secret to the API service environment.
-   Add payment secrets only when payment phase is deployed.
-   Confirm shared Redis/rate-limit store availability if required.
-   Confirm ActiveJob worker execution and retry behaviour.
-   Confirm ActiveStorage private R2 credentials and bucket policy.
-   Confirm outbound email delivery.
-   Confirm migrations run safely.
-   Confirm health checks and logs do not expose secrets.

For the frontend deployment:

-   Add Turnstile site key.
-   Confirm correct API URL and CORS.
-   Rebuild after environment changes.
-   Verify no secret appears in built assets.

## 16.5 Email domain

Review current Wine Words Brevo/Resend setup:

-   SPF.
-   DKIM.
-   DMARC.
-   From address.
-   Reply-to address.
-   Bounce/complaint handling.
-   Delivery monitoring.

Use existing sender/domain where appropriate; do not create unnecessary
new mail infrastructure.

## 16.6 ActiveStorage / Cloudflare R2

Verify:

-   Private bucket.
-   Credentials stored only server-side.
-   Correct CORS for intended upload flow.
-   Signed URL expiry.
-   File size limits.
-   Content type validation.
-   Access-controlled downloads.
-   Backup/retention policy.
-   No public access to invoices, technical sheets, private messages or
    shipping documents.

------------------------------------------------------------------------

# 17. Documentation deliverables

Documentation is part of implementation and must be updated in the
repositories, not left only in this planning file.

## 17.1 API repository documentation

Create or update documentation in `wine_words_api/docs/`:

1.  `trade_portal_overview.md`
    -   Domain overview.
    -   User journeys.
    -   WinePackage lifecycle.
    -   Roles and permissions.
2.  `trade_submission_api.md`
    -   Public submission endpoint.
    -   Authenticated endpoints.
    -   Editor endpoints.
    -   Request/response examples.
    -   Validation and errors.
    -   Idempotency.
3.  `trade_account_claiming.md`
    -   Email verification.
    -   Account provisioning.
    -   Existing account behaviour.
    -   Guest package access.
    -   Token expiry/revocation.
    -   Security model.
4.  `trade_conversations.md`
    -   Message model.
    -   Public/internal visibility.
    -   Attachments.
    -   Notification behaviour.
    -   Guest access.
5.  `trade_billing_and_payments.md`
    -   Services/pricing.
    -   Quote/invoice lifecycle.
    -   Tax configuration.
    -   Payment provider.
    -   Webhooks and reconciliation.
    -   Refunds/manual overrides.
6.  `trade_shipping_and_fulfilment.md`
    -   Shipping instructions.
    -   Tracking.
    -   Partial receipt.
    -   Discrepancy handling.
    -   Review handoff.
7.  `cloudflare_turnstile_setup.md`
    -   Dashboard setup.
    -   Hostnames.
    -   Environment variables.
    -   Frontend integration.
    -   Siteverify.
    -   Test keys/local development.
    -   Troubleshooting and rotation.
8.  `trade_security.md`
    -   Threat model.
    -   Authorization matrix.
    -   Rate limits.
    -   Upload security.
    -   PII handling.
    -   Token management.
    -   Payment security.
    -   Incident response.
9.  `trade_operations_runbook.md`
    -   Failed email.
    -   Expired claim link.
    -   Turnstile outage.
    -   Payment mismatch.
    -   Refund.
    -   Lost package.
    -   Manual override.
    -   Re-send invoice/instructions.

## 17.2 Frontend repository documentation

Create or update:

1.  `docs/trade_portal.md`
    -   Navigation and routes.
    -   Public submission form.
    -   My Wine Packages.
    -   Editor/admin screens.
    -   Responsive/accessibility behaviour.
2.  `docs/trade_api_integration.md`
    -   API client calls.
    -   Authentication and guest access.
    -   Error handling.
    -   Uploads.
    -   Message notifications.
3.  `docs/trade_turnstile.md`
    -   Site key configuration.
    -   Widget lifecycle.
    -   Local/staging/production behaviour.
    -   Troubleshooting.
4.  `docs/trade_testing.md`
    -   Unit/component tests.
    -   Playwright scenarios.
    -   Test account and test data setup.

## 17.3 Root/project documentation

Add a concise implementation overview linking to the detailed API and
frontend documents.

Update: - README where user-facing features are described. -
`.env.example` files. - Deployment runbooks. - Architecture diagrams. -
API documentation/OpenAPI schema if the project uses one. - Release
notes/changelog. - Admin operating instructions.

Never commit real secrets, production tokens, customer data or live
invoice examples.

------------------------------------------------------------------------

# 18. Testing strategy and acceptance scenarios

## 18.1 Backend tests

-   Model validations and associations.
-   Public submission service transaction.
-   Public API request validation.
-   Turnstile Siteverify service.
-   Rate limiting.
-   Email verification and claim tokens.
-   Account provisioning.
-   Existing account non-disclosure.
-   Package ownership policies.
-   Editor/Admin policies.
-   Message visibility.
-   Attachment access.
-   Notification jobs.
-   Partial approval.
-   Quote/invoice totals and snapshots.
-   Payment webhook signature/idempotency.
-   Shipping gates and overrides.
-   Partial receipt.
-   Review integration.

## 18.2 Frontend tests

-   Trade menu navigation.
-   Multi-step form navigation.
-   Add/remove wine item.
-   Client/server validation.
-   Turnstile success/expiry/error.
-   Submission success and duplicate prevention.
-   Email verification.
-   Password setup.
-   Existing account login/claim route.
-   My Wine Packages list/details.
-   Message creation and attachments.
-   Internal notes absent from submitter UI.
-   Invoice/payment display.
-   Shipping progress.
-   Responsive/mobile layout.

## 18.3 End-to-end scenarios

1.  Anonymous new email submits two wines and verifies email.
2.  New submitter sets password and sees package.
3.  Anonymous existing email submits without being logged in.
4.  Existing account owner logs in and claims package.
5.  Authenticated user submits for an authorised Producer.
6.  Authenticated user cannot submit for an unrelated Producer.
7.  Editor requests a technical sheet.
8.  Submitter replies with attachment.
9.  Editor adds internal note; submitter cannot see it.
10. Editor approves two of three wines.
11. Editor invoices only approved wines.
12. Payment webhook succeeds and duplicate webhook is ignored.
13. Shipping instructions are released.
14. Only part of the wine package arrives.
15. Editor records discrepancy.
16. Received items enter existing review process.
17. Published review is linked to the correct package.
18. User cannot access another package by changing its ID.
19. Guest token expires/revokes correctly.
20. Turnstile invalid/replayed token is rejected.
21. Rate limits return safe 429 responses.
22. Email provider outage does not lose messages or packages.

------------------------------------------------------------------------

# 19. Deployment and rollout strategy

## 19.1 Recommended release sequence

Do not deploy all capabilities simultaneously.

### Release A --- Public intake

-   Trade menu.
-   Guidelines.
-   Anonymous/authenticated submission.
-   Turnstile.
-   Email verification.
-   Admin assessment queue.

### Release B --- Submitter access and communication

-   Account provisioning/claiming.
-   My Wine Packages.
-   Package messages and attachments.
-   Email/in-app notifications.

### Release C --- Commercial operations

-   Service/pricing configuration.
-   Quotes/invoices.
-   Manual payment tracking if needed.
-   Stripe hosted payment and webhooks when ready.

### Release D --- Fulfilment and review

-   Shipping details.
-   Tracking.
-   Partial receipt.
-   Review workflow handoff.
-   Submitter progress view.

This allows the business to validate submission volume and operational
process before payment integration is complete.

## 19.2 Feature flags

Where appropriate, use feature flags/configuration to control:

-   Public submission availability.
-   Turnstile enforcement (production must not accidentally bypass).
-   Guest package access.
-   Account provisioning.
-   Conversations.
-   Online payment.
-   Fast-track service.
-   Additional trade services.

A disabled feature must not leave a broken or misleading public UI.

## 19.3 Database rollout

-   Review migrations against production data.
-   Add nullable columns before changing application assumptions.
-   Backfill in controlled batches if needed.
-   Add indexes and constraints safely.
-   Deploy compatible code before enforcing stricter constraints.
-   Preserve old package records and workflows.
-   Take/verify backups before risky schema changes.
-   Prepare rollback steps for each release.

## 19.4 Production smoke tests

After each release:

-   Open Trade menu.
-   Submit a test package using a controlled test contact.
-   Verify Turnstile server validation.
-   Verify email delivery.
-   Verify package/item creation.
-   Verify Editor queue.
-   Verify account claiming.
-   Verify message and attachment access.
-   Verify notification/email.
-   Verify payment only in provider test mode until commercial approval.
-   Verify private files are not publicly accessible.
-   Verify existing Reviews, Articles, Users and Wine Packages still
    work.

Remove or clearly label test records after validation.

------------------------------------------------------------------------

# 20. Decisions still requiring business confirmation

The technical plan can proceed, but these commercial/product details
should be decided before the corresponding phases.

  -----------------------------------------------------------------------
  Decision                            Suggested default
  ----------------------------------- -----------------------------------
  Initial paid service                Standard Wine Review only

  Fast-track service                  Future phase

  Submission fee                      No fee at initial submission

  Editorial rejection                 No invoice

  Partial approval                    Bill only accepted items/services

  Payment timing                      After editorial approval and
                                      invoice

  Payment method                      Stripe hosted payment, or bank
                                      transfer initially

  Invoice/tax treatment               Confirm with accountant

  Payment due period                  Admin-configurable

  Shipping destination                Provided after acceptance/payment

  Sample quantity                     Defined in Submission Guidelines

  Review turnaround                   Publish only a realistic,
                                      operationally supported estimate

  Guest access                        Verified email, package-specific,
                                      expiring access

  Account creation                    New email: verify then
                                      provision/activate and set
                                      password; existing email:
                                      authenticate normally

  Conversation                        Package-specific, in-app replies,
                                      email notifications

  Internal notes                      Editor/Admin only

  Producer membership                 Separate authorised process
  -----------------------------------------------------------------------

------------------------------------------------------------------------

# 21. Definition of done

The initial Trade submission release is complete when:

-   [ ] Trade menu is public and responsive.
-   [ ] Anyone can submit without login or Producer record.
-   [ ] Multiple wines can be included in one WinePackage.
-   [ ] WinePackage remains the central entity.
-   [ ] Original contact and wine details are preserved.
-   [ ] Catalogue records are not automatically published.
-   [ ] Cloudflare Turnstile is verified server-side.
-   [ ] Rate limiting and abuse protection are active.
-   [ ] Email verification works.
-   [ ] New-account password setup works securely.
-   [ ] Existing accounts are not automatically logged in or modified.
-   [ ] Package claiming is secure.
-   [ ] My Wine Packages displays authorised packages.
-   [ ] Editors can assess and partially approve/reject wines.
-   [ ] Producer matching does not automatically grant membership.
-   [ ] Submitter and Editor can converse within a package.
-   [ ] Internal notes and private attachments remain private.
-   [ ] Email and in-app notifications work.
-   [ ] Quotes/invoices can be generated for approved items.
-   [ ] Payment is confirmed securely before shipping release, unless an
    authorised override is recorded.
-   [ ] Shipping and partial receipt are tracked.
-   [ ] Existing review workflow is reused.
-   [ ] API and frontend tests pass.
-   [ ] Security and operational documentation is complete.
-   [ ] Deployment, rollback and support procedures are documented.

------------------------------------------------------------------------

# 22. Recommended implementation order

My recommendation is to execute the work in this order:

1.  Phase 0--1: audit and finalise architecture.
2.  Phase 2: Trade navigation and guidelines.
3.  Phase 3--4: public submission backend, Turnstile and abuse
    protection.
4.  Phase 5: public multi-step form.
5.  Phase 6--7: account claiming and My Wine Packages.
6.  Phase 8--10: editorial assessment, conversations and notifications.
7.  Phase 11: quotes and invoices.
8.  Phase 12: payment integration.
9.  Phase 13--14: fulfilment and review integration.
10. Phase 15: final security review and production readiness.

**Important implementation instruction:** complete the repository audit
before asking a coding agent to generate migrations or modify models.
The current Wine Words code may already contain part of the required
package, contact, notification, review or billing functionality. Reuse
it and keep this feature integrated with the existing domain rather than
creating a parallel system.

The intended result is a simple experience for the wine trade --- submit
wines without bureaucracy --- backed by a controlled, auditable Wine
Words workflow from initial submission through editorial decision,
payment, shipping and publication.
