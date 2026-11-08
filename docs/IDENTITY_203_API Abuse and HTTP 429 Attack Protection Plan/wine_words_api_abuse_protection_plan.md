# Wine Words --- API Abuse and HTTP 429 Attack Protection Plan

**Project:** Wine Words\
**Repository:** `romalopes/wine_words_api`\
**Related frontend:** `romalopes/wine_words_frontend`\
**Document type:** Implementation plan\
**Priority:** High --- security and availability\
**Status:** Proposed\
**Primary objective:** Reduce the risk that abusive or automated traffic
overwhelms the Wine Words API, database, email services, or other
resources, while ensuring legitimate users are not unnecessarily
blocked.

------------------------------------------------------------------------

## 1. Executive summary

Wine Words already has some request-throttling protection through
`rack-attack`, but the previous repository review identified important
gaps:

-   Rate limits cover only a small subset of endpoints.
-   `Rack::Attack.cache.store` is configured with
    `ActiveSupport::Cache::MemoryStore`.
-   MemoryStore is process-local and is not a reliable shared counter
    store when the application runs in multiple processes or instances.
-   Edge protection must be verified separately. Hosting a frontend on
    Cloudflare Workers does **not** automatically mean the Rails API is
    protected by Cloudflare WAF or API rate limiting.
-   Expensive and abuse-prone operations need limits appropriate to
    their cost.

HTTP 429 (`Too Many Requests`) is a response status, not the attack
itself. It is commonly returned when a rate limit is exceeded. The goal
is not to eliminate all 429 responses: it is to reject abusive traffic
safely, preserve API availability, and avoid throttling legitimate
users.

### Target architecture

1.  **Cloudflare edge controls** --- filter and challenge abusive
    traffic before it reaches Render, where supported by the active
    Cloudflare plan and DNS configuration.
2.  **Rails/Rack::Attack controls** --- enforce application-aware limits
    by IP, authenticated user, account, and operation.
3.  **Shared rate-limit storage** --- use a production-ready shared
    store, evaluating the existing Solid Cache setup before adding
    Redis.
4.  **Monitoring and response** --- record throttling events, detect
    abnormal patterns, and alert on meaningful increases.
5.  **Automated tests and staged rollout** --- validate limits,
    concurrency, legitimate-user behaviour, and recovery.

Do not assume any proposed limit or Cloudflare feature is available
until the current production configuration and plan have been checked.

------------------------------------------------------------------------

## 2. Goals

-   Protect API availability from request floods, brute-force attempts,
    scraping, spam, and resource exhaustion.
-   Apply consistent rate limits across all Rails processes and
    instances.
-   Protect authentication and account-recovery flows.
-   Protect expensive operations such as search, discovery, uploads,
    email delivery, and analytics.
-   Keep limits fair for legitimate users, including users behind shared
    IP addresses.
-   Return a consistent, documented HTTP 429 response with useful retry
    information where possible.
-   Make abusive traffic observable without logging passwords, tokens,
    or unnecessary personal information.
-   Keep the solution compatible with the current
    Rails/Render/Cloudflare architecture and prefer existing
    infrastructure where practical.
-   Avoid unnecessary paid services and new operational dependencies.

## 3. Non-goals

This task does not aim to:

-   Guarantee protection against every form of DDoS attack. Cloudflare
    and application rate limits are only parts of a broader resilience
    strategy.
-   Replace authentication, authorization, input validation, or normal
    application security controls.
-   Block all automated clients. Some integrations and legitimate
    automation may need explicit policies.
-   Introduce Redis by default. Redis is an option only if the existing
    shared cache cannot meet the requirements.
-   Treat every HTTP 429 as evidence of an attack. Normal users and
    clients can exceed reasonable limits.
-   Change product functionality or user subscription entitlements
    unless a separate product decision explicitly requires it.

------------------------------------------------------------------------

## 4. Phase 0 --- Confirm the current production architecture

### Objectives

Establish the real production request path and verify the current code
before changing security controls.

### Tasks

1.  Inspect the `romalopes/wine_words_api` repository and the deployed
    production branch.
2.  Confirm:
    -   Rails and Rack versions.
    -   `rack-attack` version and middleware registration.
    -   All rules in `config/initializers/rack_attack.rb`.
    -   The configured cache store in each environment.
    -   Solid Cache gem, database, and production configuration.
    -   Number of Render services, instances, and processes.
    -   Whether the API hostname is proxied through Cloudflare.
    -   Whether the Render `onrender.com` hostname remains directly
        reachable.
    -   Cloudflare plan, WAF availability, rate-limiting rule
        availability, and current rules.
3.  Identify all API routes and classify them by risk and expected
    request cost.
4.  Check whether requests can reach the Rails application through
    alternate hostnames or deployment URLs.
5.  Review existing Sentry, structured logging, and health-check
    configuration.
6.  Record current request volume and existing 429 rates, if metrics are
    available.

### Deliverables

-   Current request-flow diagram.
-   Inventory of existing throttles and cache configuration.
-   Endpoint risk classification.
-   List of confirmed Cloudflare and Render capabilities.
-   Baseline metrics and identified gaps.

### AI implementation prompt

> Audit the Wine Words API repository (`romalopes/wine_words_api`) for
> protection against abusive request traffic and HTTP 429 conditions.
>
> Inspect the actual code and configuration before making
> recommendations. Review `rack-attack`, middleware registration,
> cache-store configuration, Solid Cache, routes, authentication flows,
> uploads, analytics, email delivery, search, and other expensive
> operations.
>
> Also inspect deployment configuration and documentation relevant to
> Render and Cloudflare. Do not assume that Cloudflare Workers hosting
> the frontend means the API is protected by Cloudflare.
>
> Produce: 1. A factual inventory of existing protections, with file
> paths and relevant code references. 2. A list of unprotected or
> insufficiently protected endpoints. 3. An explanation of whether
> rate-limit counters are shared across all production processes and
> instances. 4. A diagram or written description of the production
> request path and possible origin bypasses. 5. A prioritized gap
> analysis.
>
> Do not modify files in this phase. Do not claim a feature exists
> unless the repository or deployment configuration confirms it.

------------------------------------------------------------------------

## 5. Phase 1 --- Design the rate-limiting policy

### Objectives

Define sensible limits based on endpoint risk, expected legitimate use,
and resource cost.

The values below are **initial proposals for testing**, not final
production settings. Confirm actual endpoint usage and adjust them using
baseline metrics.

### Initial policy matrix

  ------------------------------------------------------------------------
  Operation                  Suggested initial limit Key
  --------------------- ---------------------------- ---------------------
  Login attempts                       10 per minute IP, plus
                                                     account-aware
                                                     protection

  Registration                            5 per hour IP

  Password reset                          5 per hour IP, plus
  requests                                           account-aware
                                                     protection

  Public invitation           Existing 30 per minute IP
  requests                                 initially 

  General API requests                120 per minute IP, with route
                                                     exceptions

  Search                               60 per minute User or IP

  Wine discovery /                     30 per minute User or IP
  expensive matching                                 

  Review creation                        20 per hour Authenticated user

  Comment creation                       20 per hour Authenticated user

  Upload initiation                      10 per hour Authenticated user

  Analytics                  Review existing 300 per IP / visitor
  views/events                  minute/IP and 60 per 
                                minute/visitor rules 
  ------------------------------------------------------------------------

The exact limits must be configurable and tested. Do not blindly apply a
single global limit to every route.

### Key design decisions

-   Use IP limits for anonymous traffic and as one signal for
    authenticated traffic.
-   Use authenticated user IDs for user-generated operations.
-   Consider account-aware limits for login and password recovery, but
    avoid allowing an attacker to lock out a victim merely by repeatedly
    targeting their account.
-   Use separate limits for expensive operations.
-   Consider both short bursts and sustained usage. A short-window
    throttle alone may allow high daily volume.
-   Exempt or separately configure health checks and trusted internal
    service traffic.
-   Do not trust arbitrary client-supplied forwarding headers. Confirm
    that the application derives the client IP safely from the trusted
    proxy chain.
-   Make limits configurable rather than scattering numeric values
    through the initializer.

### AI implementation prompt

> Design a rate-limiting policy for the Wine Words API based on the
> Phase 0 audit.
>
> Classify each route by abuse risk, resource cost, authentication
> requirement, and expected legitimate usage. Propose limits for
> anonymous IPs, authenticated users, and account-sensitive flows.
>
> Review the initial policy matrix in this plan, but change values where
> the code, product behaviour, or measured traffic justifies it.
>
> Pay special attention to login, registration, password recovery,
> search, wine discovery, review/comment creation, uploads, invitations,
> analytics, and email-triggering actions.
>
> Explain how to prevent account lockout attacks and unfair blocking of
> users behind shared IP addresses. Identify routes that need separate
> burst and sustained limits.
>
> Produce a final policy table and document the rationale. Do not
> implement the rules yet.

------------------------------------------------------------------------

## 6. Phase 2 --- Replace process-local rate-limit storage

### Objectives

Ensure rate-limit counters are shared by all production application
processes and instances.

### Current concern

The previous review found this configuration:

``` ruby
Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
```

MemoryStore is local to a process. Multiple processes can therefore
maintain independent counters, and restarts reset those counters.

### Preferred approach

Evaluate the existing Solid Cache production configuration first.

Tasks:

1.  Confirm Solid Cache is installed and configured in production.
2.  Confirm it uses a shared persistent backend accessible by all API
    processes and instances.
3.  Confirm cache entries expire as expected.
4.  Check whether Solid Cache's performance and concurrency
    characteristics are appropriate for high-frequency rate-limit
    counter updates.
5.  Verify that the cache API and increment/expiry behaviour used by the
    installed Rack::Attack version are compatible.
6.  Ensure rate-limit keys have a namespace and bounded retention.
7.  Test simultaneous requests and multiple processes.
8.  Document cache failure behaviour.

### Important technical decision

Do not assume that Solid Cache is automatically suitable merely because
it is installed. Rate limiting requires reliable, atomic counter
behaviour under concurrency. Verify the exact store semantics and
Rack::Attack integration.

If Solid Cache cannot provide the required atomicity or throughput,
evaluate Redis or another shared store with atomic increment and expiry
operations. Document the additional cost and operational burden before
introducing it.

### Failure behaviour

Decide explicitly what happens if the shared cache is unavailable:

-   Security-sensitive endpoints should not silently become unlimited.
-   Avoid taking the entire API offline because a cache has a temporary
    issue.
-   Consider conservative fallback limits or temporary fail-closed
    behaviour for especially sensitive operations.
-   Log and alert on cache failures.
-   Test the selected behaviour.

### AI implementation prompt

> Implement reliable shared storage for Wine Words Rack::Attack
> counters.
>
> Start by inspecting the exact installed versions of Rack::Attack,
> Rails, and Solid Cache, plus the production cache configuration.
>
> Determine whether Solid Cache provides the atomic increment and expiry
> semantics needed by the installed Rack::Attack integration under
> concurrent requests and across multiple application processes.
>
> If it is suitable, configure and use it. If it is not suitable,
> present a justified alternative such as Redis before introducing a new
> service.
>
> Remove the process-local MemoryStore configuration from the production
> rate-limiting path. Preserve appropriate development and test
> behaviour.
>
> Add automated tests demonstrating that counters are shared across
> independent cache clients or processes, expire correctly, and behave
> safely during concurrent requests.
>
> Document the chosen cache-failure behaviour. Do not claim distributed
> protection based only on a single-process test.

------------------------------------------------------------------------

## 7. Phase 3 --- Expand Rails/Rack::Attack protection

### Objectives

Apply the approved policy consistently across the API.

### Tasks

1.  Keep the existing Rack::Attack implementation and refactor it where
    needed.
2.  Add named throttles for the approved endpoint groups.
3.  Use route-aware discriminators where appropriate.
4.  Use authenticated user IDs for logged-in write operations.
5.  Use IP-based throttles for anonymous traffic.
6.  Add account-aware safeguards for authentication without creating an
    easy account-lockout denial of service.
7.  Protect endpoints that trigger email, external API calls, image
    processing, or other expensive work.
8.  Ensure health checks and trusted internal calls are handled
    intentionally.
9.  Ensure rate limiting runs early enough in the request lifecycle to
    avoid expensive controller work.
10. Review request parsing and body-size limits separately; throttling
    alone does not prevent oversized request attacks.
11. Return a consistent JSON error response for API clients.
12. Include `Retry-After` where the configured throttle can calculate a
    meaningful retry time.
13. Ensure throttled requests do not create database records, send
    emails, enqueue jobs, or perform other side effects.

### Suggested response contract

Use the API's existing error-response conventions if they already
provide a consistent structure. Otherwise, agree on a response similar
to:

``` json
{
  "error": {
    "code": "rate_limit_exceeded",
    "message": "Too many requests. Please try again later."
  }
}
```

Return HTTP status `429`. Do not expose internal throttle keys, secrets,
or implementation details.

### AI implementation prompt

> Implement the approved Wine Words rate-limiting policy using the
> existing Rack::Attack integration.
>
> Inspect current routes and controllers and use the actual endpoint
> paths and HTTP methods. Do not invent routes.
>
> Add separate, clearly named throttles for authentication,
> registration, password recovery, search/discovery, user-generated
> content, uploads, invitations, analytics, and other expensive
> operations identified in the audit.
>
> Use safe IP identification and authenticated user IDs where
> appropriate. Avoid account-lockout denial-of-service vulnerabilities.
> Preserve existing valid behaviour and existing limits unless the
> approved policy explicitly changes them.
>
> Return the API's standard JSON error format with HTTP 429 and a
> meaningful `Retry-After` header where possible.
>
> Ensure throttled requests are rejected before expensive controller
> work or side effects.
>
> Add focused request and middleware tests. Update relevant
> documentation and environment configuration. Do not introduce
> arbitrary limits without explaining their rationale.

------------------------------------------------------------------------

## 8. Phase 4 --- Configure Cloudflare edge protection

### Objectives

Reject or challenge abusive traffic before it reaches the Render API.

### Tasks

1.  Confirm the production API hostname and DNS record.
2.  Confirm that the API hostname is proxied through Cloudflare, rather
    than assuming the frontend Worker configuration protects it.
3.  Inspect the active Cloudflare plan and available WAF, DDoS, and
    rate-limiting features.
4.  Create narrowly scoped rules for the API hostname and sensitive
    routes.
5.  Start with conservative thresholds and observe traffic before
    tightening.
6.  Apply managed challenges or blocks only where suitable.
7.  Avoid challenging API clients in ways that break legitimate mobile,
    browser, or integration requests.
8.  Keep Cloudflare and Rails limits complementary rather than
    duplicating identical rules without purpose.
9.  Review IPv4/IPv6, proxy headers, and trusted client-IP handling.
10. Test both the normal Cloudflare path and direct-origin access.

### Suggested edge policy to evaluate

  Traffic                               Initial approach
  ------------------------------------- ------------------------------------------------
  General API traffic                   Conservative rate limit
  Login and password recovery           Tighter route-specific limits
  Registration and public invitations   Tighter route-specific limits
  Obvious abusive automation            Challenge or block, based on evidence
  Normal browser/API traffic            Allow
  Health checks                         Explicitly account for monitoring requirements

Cloudflare feature availability and rule limits depend on the current
account plan and product configuration. Verify them in the dashboard and
current documentation.

### Critical: direct-origin bypass

A proxied Cloudflare DNS record does not necessarily prevent someone
from calling the Render service's default hostname directly.

Investigate the options available for this Render deployment. Possible
approaches include:

-   An origin-verification secret added by a Cloudflare rule and checked
    by the application, with careful secret handling and rotation.
-   Network-level origin restrictions, if supported by the hosting
    platform.
-   Another supported architecture that ensures requests must pass
    through the intended edge.

Do not assume that a static secret header is equivalent to a
network-level restriction. It is an additional control and must not be
exposed to browser code. Test the actual Render origin hostname and any
alternate routes.

### AI implementation prompt

> Review and design Cloudflare edge protection for the Wine Words
> production API.
>
> Confirm the actual API hostname, DNS proxy status, Cloudflare plan,
> available WAF/rate-limiting features, and Render origin configuration.
> Do not assume that the Cloudflare Workers frontend automatically
> protects the API.
>
> Propose narrowly scoped rate-limiting and security rules for general
> API traffic and sensitive endpoints. Keep browser and API clients
> working correctly.
>
> Investigate whether the Render origin can be accessed directly through
> its default hostname. Recommend a practical origin-protection approach
> supported by the actual hosting configuration. Explain the limitations
> of any shared-secret header approach and how secrets would be stored
> and rotated.
>
> Provide dashboard configuration steps, rule expressions, test cases,
> rollback steps, and any plan limitations. Do not make unsupported
> claims about Cloudflare features or Render network controls.

------------------------------------------------------------------------

## 9. Phase 5 --- Protect expensive operations and infrastructure

### Objectives

Prevent a small number of requests from consuming disproportionate
resources.

Rate limiting is only one part of this work.

### Tasks

Review and protect:

-   Database-intensive search and filtering.
-   Wine discovery and recommendation calculations.
-   Image and file uploads.
-   Image transformations and background jobs.
-   Email delivery and password-reset messages.
-   Analytics ingestion.
-   External API calls.
-   Large request bodies and expensive JSON parsing.
-   Long-running requests and job queues.

Consider:

-   Request body-size limits at the edge and application/server layers.
-   Upload size and content-type validation.
-   Per-user upload quotas.
-   Job queue concurrency and retry policies.
-   Database query timeouts and connection-pool sizing.
-   Pagination and maximum page sizes.
-   Caching of safe, frequently requested read operations.
-   Idempotency for operations that may be retried.
-   Limits on email and external-provider usage.

Do not rely on rate limits as a substitute for authorization,
validation, or resource limits.

### AI implementation prompt

> Audit Wine Words for resource-exhaustion risks beyond request
> frequency.
>
> Identify endpoints and jobs that can trigger expensive database
> queries, image processing, email delivery, external API calls, or
> long-running work.
>
> Review upload size/type validation, pagination, query complexity, job
> concurrency, retry behaviour, database timeouts, and external-provider
> quotas.
>
> Recommend targeted safeguards that complement Rack::Attack and
> Cloudflare. Distinguish protections that belong at Cloudflare, the web
> server, Rails, the database, or the job-processing layer.
>
> Implement only the approved changes, with tests and documentation.
> Preserve normal product functionality.

------------------------------------------------------------------------

## 10. Phase 6 --- Monitoring, logging, and alerting

### Objectives

Make abuse visible and distinguish attacks from normal traffic or
misconfigured clients.

### Events and metrics

Capture, where practical:

-   Total requests and requests per route.
-   HTTP 429 count and rate.
-   Throttle rule name.
-   Anonymized or appropriately protected client IP information.
-   Authenticated user/account identifier where available and justified.
-   User agent and request method where useful.
-   Cloudflare action and Ray ID, if available.
-   Cache errors and rate-limit-store failures.
-   Request latency and error rate.
-   Database and job queue saturation.
-   Email and external-provider usage.

Avoid logging passwords, authentication tokens, session cookies, full
sensitive request bodies, or unnecessary personal information. Apply
retention and access controls to security logs.

### Alerts to consider

-   Sudden increase in 429 responses.
-   High request volume from one IP or a group of IPs.
-   Login or password-reset spikes.
-   Repeated requests to expensive endpoints.
-   High 5xx rate or API latency.
-   Database connection saturation.
-   Cache or rate-limit-store failures.
-   Unexpected email or background-job volume.

Use the existing Sentry setup where it is appropriate. Do not send one
Sentry error event for every normal throttled request; that can create
noise and consume event quotas. Prefer aggregated metrics or
sampled/security-specific events.

### AI implementation prompt

> Add observability for Wine Words rate limiting and abuse prevention.
>
> Inspect existing Sentry and logging conventions first. Record
> structured throttle events with rule name, route, method, response
> status, and appropriately protected client/account identifiers.
>
> Add useful metrics for 429 rates, traffic spikes, cache failures,
> authentication abuse, API latency, and resource saturation.
>
> Avoid logging credentials, tokens, cookies, or sensitive request
> bodies. Avoid flooding Sentry with one event per expected 429
> response.
>
> Define actionable alert thresholds based on available baseline
> metrics. Document dashboards, alert routing, log retention, and an
> incident investigation workflow.

------------------------------------------------------------------------

## 11. Phase 7 --- Automated security and regression tests

### Objectives

Prove that the protections work and do not break normal usage.

### Required test scenarios

#### Rack::Attack behaviour

-   A request below the threshold succeeds.
-   A request exceeding the threshold returns 429.
-   The response follows the API error contract.
-   `Retry-After` is present and meaningful where supported.
-   The throttle resets after its period.
-   Different authenticated users have independent user-level limits.
-   Anonymous requests are limited using a correctly derived IP.
-   Spoofed forwarding headers cannot bypass IP throttles.
-   Existing analytics and invitation limits continue to work.

#### Shared storage and concurrency

-   Independent cache clients see the same counter.
-   Multiple application processes share limits.
-   Concurrent requests cannot exceed the intended threshold because of
    race conditions.
-   Expired keys are cleaned up.
-   Cache failures follow the documented fallback policy.

#### Business-flow safety

-   A throttled login does not authenticate.
-   A throttled password reset does not send an email.
-   A throttled review/comment does not create a record.
-   A throttled upload does not initiate expensive processing.
-   A throttled invitation does not send an invitation.
-   Normal traffic from shared IP addresses is not excessively blocked.

#### Cloudflare and deployment tests

-   Requests through the Cloudflare API hostname behave as expected.
-   Direct Render-origin access is tested.
-   Edge rules do not block legitimate API clients.
-   Cloudflare challenges do not break API requests.
-   Production and staging configurations are consistent where intended.

### AI implementation prompt

> Add comprehensive automated tests for the Wine Words API
> abuse-protection implementation.
>
> Cover Rack::Attack throttles, response status and JSON format,
> Retry-After, reset behaviour, IP identification, authenticated user
> discrimination, spoofed proxy headers, shared cache behaviour,
> concurrency, and cache failure.
>
> Add request-level tests proving that throttled operations do not
> perform side effects such as database writes, email delivery, uploads,
> or background-job enqueueing.
>
> Test legitimate users behind shared IP addresses and ensure
> user-specific limits behave as designed.
>
> Add deployment/integration test instructions for Cloudflare and the
> Render origin. Do not claim that Cloudflare edge behaviour is covered
> by Rails request specs.
>
> Run the relevant test suite and report exact commands, results, and
> any remaining gaps.

------------------------------------------------------------------------

## 12. Phase 8 --- Staged rollout and load testing

### Objectives

Introduce the controls without unexpectedly blocking legitimate users or
destabilizing production.

### Rollout sequence

1.  Deploy shared rate-limit storage.
2.  Deploy application throttles with conservative initial limits.
3.  Observe traffic and 429 metrics.
4.  Adjust limits using real usage data.
5.  Enable Cloudflare rules in a conservative mode where supported.
6.  Test legitimate user flows and API clients.
7.  Tighten rules gradually.
8.  Perform controlled load and abuse simulations against staging.
9.  Confirm production alerts and incident procedures.
10. Record final limits and operational ownership.

### Load-test scenarios

-   Normal expected traffic.
-   Short burst from one IP.
-   Sustained traffic from one IP.
-   Traffic distributed across multiple IPs.
-   Concurrent login attempts.
-   Password-reset request flood.
-   Expensive search/discovery requests.
-   Upload initiation flood.
-   Multiple application processes receiving requests simultaneously.
-   Rate-limit cache unavailable or slow.

Use staging or an explicitly approved test environment. Do not run
destructive or high-volume tests against production without a defined
test window, authorization, and safeguards.

### Acceptance criteria

-   Rate limits are shared across all production API
    processes/instances.
-   Sensitive endpoints have documented and tested limits.
-   Expensive operations have appropriate safeguards.
-   Requests over a limit receive HTTP 429 with the agreed response
    contract.
-   Normal user flows work within the approved limits.
-   Throttled requests do not perform protected side effects.
-   Cloudflare protection is verified on the actual API hostname.
-   Direct-origin exposure is understood and mitigated to the extent
    supported by the hosting platform.
-   Monitoring and alerts are operational.
-   Automated tests pass.
-   Rollback instructions are documented.

### AI implementation prompt

> Prepare and execute a staged rollout and controlled load-test plan for
> Wine Words abuse protection.
>
> Use staging wherever possible. Define realistic traffic profiles and
> test burst traffic, sustained traffic, distributed sources,
> authentication abuse, expensive endpoints, concurrent processes, and
> cache failure.
>
> Measure API latency, error rates, 429 rates, database load, job queue
> load, and cache performance.
>
> Verify that legitimate user flows remain functional and that limits
> are shared across processes.
>
> Do not run uncontrolled load tests against production. Provide a
> rollout checklist, rollback plan, results, and final recommended
> thresholds.

------------------------------------------------------------------------

## 13. Phase 9 --- Documentation and operational runbook

Create or update documentation in the API repository.

Suggested files:

``` text
docs/
  security/
    api-rate-limiting.md
    cloudflare-api-protection.md
    abuse-monitoring.md
    incident-response.md
```

Document:

-   Rate-limit policy and rationale.
-   How to change limits safely.
-   Cache backend and failure behaviour.
-   Cloudflare rules and plan dependencies.
-   Origin-protection design and limitations.
-   How to identify a throttle event.
-   How to distinguish abuse from a legitimate client issue.
-   How to respond to a traffic spike.
-   How to temporarily adjust a rule.
-   How to roll back a problematic deployment.
-   How to rotate any origin-verification secret.

### AI implementation prompt

> Write operational documentation for the completed Wine Words API
> abuse-protection work.
>
> Document the actual implementation, not the original proposal where it
> differs. Include the final throttle matrix, cache architecture,
> Cloudflare configuration, origin-access limitations, monitoring,
> alerts, testing, deployment, rollback, and incident-response
> procedures.
>
> Include examples of how to investigate HTTP 429 responses and how to
> adjust limits safely. Do not include secrets or sensitive production
> values.

------------------------------------------------------------------------

## 14. Suggested implementation order

  ------------------------------------------------------------------------
                         Order Phase                 Priority
  ---------------------------- --------------------- ---------------------
                             1 Confirm production    Critical
                               architecture and      
                               existing protection   

                             2 Approve rate-limit    Critical
                               policy                

                             3 Replace process-local Critical
                               counter storage       

                             4 Expand                Critical
                               Rails/Rack::Attack    
                               protection            

                             5 Configure Cloudflare  High
                               edge protection       

                             6 Protect expensive     High
                               operations            

                             7 Add monitoring and    High
                               alerting              

                             8 Automated tests and   Critical
                               controlled load       
                               testing               

                             9 Documentation and     Medium
                               incident runbook      
  ------------------------------------------------------------------------

Phases can overlap where useful, but do not roll out aggressive limits
before the endpoint policy and legitimate traffic expectations have been
reviewed.

------------------------------------------------------------------------

## 15. Security decisions requiring confirmation

Before implementation is considered complete, explicitly answer:

1.  Is the API hostname proxied through Cloudflare?
2.  Can the Render default hostname bypass Cloudflare?
3.  Can the Render deployment restrict origin access at the network
    layer?
4.  Does the selected shared cache provide atomic counter increments and
    expiry across all processes?
5.  What is the expected normal request volume for each sensitive
    endpoint?
6.  What should happen when the rate-limit store is unavailable?
7.  Which routes are consumed by browser clients, mobile/PWA clients,
    integrations, and background jobs?
8.  What monitoring and alerting are available on the current
    infrastructure plan?
9.  What are the final approved thresholds and who can change them?

------------------------------------------------------------------------

## 16. Definition of done

The task is complete only when:

-   [ ] The production architecture and current protection have been
    audited.
-   [ ] The final endpoint rate-limit policy is documented.
-   [ ] Rate-limit counters use a verified shared store, not
    process-local MemoryStore in production.
-   [ ] Authentication and account-recovery abuse is addressed.
-   [ ] Search, discovery, uploads, email-triggering operations,
    analytics, and user-generated content are protected appropriately.
-   [ ] HTTP 429 responses follow the API contract.
-   [ ] Proxy/IP identification is safe against spoofing.
-   [ ] Cloudflare protection is configured and tested on the real API
    hostname.
-   [ ] Direct-origin access has been tested and its mitigation
    documented.
-   [ ] Resource-exhaustion safeguards have been reviewed.
-   [ ] Monitoring and actionable alerts are active.
-   [ ] Automated tests cover limits, concurrency, cache failure, and
    side effects.
-   [ ] Controlled load tests have been completed in an appropriate
    environment.
-   [ ] Rollback and incident-response instructions are documented.
-   [ ] No secrets or sensitive information are committed to the
    repository.

## 17. Important implementation principle

**Do not optimize for returning fewer 429 responses. Optimize for
keeping Wine Words available and fair to legitimate users.**

A healthy system may return 429 when a client exceeds a sensible limit.
The security objective is to ensure that abusive traffic is rejected
early, counters work across the entire deployment, expensive resources
remain protected, and legitimate users can continue using Wine Words.
