# Social authentication

Google, Apple, Microsoft and Facebook sign-in for Wine Prediction.

Email/password authentication is unchanged and remains fully supported. Social
providers are **additional ways to authenticate the same `User`** — they never
create a parallel identity, session or account system.

---

## 1. Architecture

```
        Google   Apple   Microsoft   Facebook
             \      |        |         /
              \     |        |        /
            provider credential (verified server-side)
                        |
                        v
                  Rails API  /api/v1/auth/:provider
                        |
                        v
                       User                 <- canonical application identity
                    /        \
                   /          \
          UserIdentity        Account  (exactly one, unchanged)
        /   |    |    \
   Google Apple Microsoft Facebook
```

`UserIdentity` holds the *authentication* identity; `User` holds the
*application* identity. A User may have any number of identities while keeping
exactly one Account, one role set (Guest / Reader / Reviewer / Admin / Editor),
one subscription and one Stripe customer.

### Why a separate table

* No provider columns (`google_id`, `apple_id`, …) are ever added to `users` or
  `accounts`.
* The **provider UID** (`sub` / app-scoped id) is the identity key — never the
  email. Emails change, Apple may return a private relay address, and Facebook
  may return nothing at all.
* `(provider, provider_uid)` carries a **unique database index**, so one
  provider identity can never belong to two Users.

```
user_identities
  id, user_id, provider, provider_uid, email, created_at, updated_at

  index (provider, provider_uid) UNIQUE      <- identity hijack protection
  index (user_id, provider)      UNIQUE      <- one identity per provider per User
  foreign key user_id -> users.id
```

Supported providers: `google`, `apple`, `microsoft`, `facebook` (string-backed
enum on `UserIdentity`).

---

## 2. Endpoints

### Sign in (anonymous)

| Method | Path | Body |
|---|---|---|
| POST | `/api/v1/auth/google` | `{ "credential": "<ID token>" }` |
| POST | `/api/v1/auth/apple` | `{ "credential": "<identity token>", "nonce": "<raw nonce>" }` |
| POST | `/api/v1/auth/microsoft` | `{ "credential": "<ID token>" }` |
| POST | `/api/v1/auth/facebook` | `{ "credential": "<user access token>" }` |

The response is the **same payload as email/password sign-in**, with the
ordinary devise-jwt token in the `Authorization` response header. There is no
separate social session mechanism.

### Connected sign-in methods (authenticated)

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/v1/auth/identities` | list connected providers + `password_authentication` flag |
| POST | `/api/v1/auth/identities/:provider` | connect an additional provider |
| DELETE | `/api/v1/auth/identities/:id` | disconnect a provider |

---

## 3. Identity resolution rules

`Authentication::SocialLogin` implements three explicit cases.

**Case 1 — the provider identity already exists**
`(provider, provider_uid)` matches a `UserIdentity` → authenticate its `User`.
Nothing is created. This works even when the provider stops sending an email
(Apple only includes `email` in the *first* identity token).

**Case 2 — the identity is new, but the verified email belongs to an existing User**
The identity is linked onto that User **only when the provider actually vouches
for the address** and it is not an Apple private relay address:

| Provider | Auto-links on verified email? | Why |
|---|---|---|
| Google | Yes, when `email_verified` is true | Google asserts it explicitly |
| Microsoft | Yes, when the address matches the directory-authoritative `preferred_username` (or an explicit `email_verified`) | `email` may disagree with the UPN |
| Apple | Yes, for a normal address only | relay addresses prove nothing about the person's mailbox |
| Facebook | **No** | Meta supplies no verification signal |

If the address cannot be trusted the request fails with
`409 account_exists`: the person is told to sign in the way they normally do and
connect the provider from **Account settings**. A duplicate User is never
created and an external identity is never silently attached.

**Case 3 — neither the identity nor a matching User exists**
`User` + `UserIdentity` are created inside a single transaction. The User goes
through the existing creation workflow, so the model hooks still assign the
**Guest** role and the **FREE** subscription, and the Account is built by the
existing Account workflow. A social-only User has no password
(`encrypted_password` is blank); email/password users are completely unaffected.

### Account linking and the last authentication method

* An identity that already belongs to another User is **never transferred** —
  the request fails with `409 identity_taken`.
* A User must always keep at least one way to sign in. Disconnecting the only
  method fails with `409 last_authentication_method`.
---

## 4. Provider configuration

A provider is usable only when **both** sides are configured — this is
deliberate, so a half-configured provider degrades safely instead of failing
halfway through a sign-in:

1. The frontend public id (`VITE_*`) decides whether the "Continue with …"
   button (and the "Connect another" button in **Account settings**) is
   rendered at all. Absent id → no button.
2. The backend variable decides whether the endpoint works. Absent variable →
   `503 provider_not_configured` ("This sign-in method is not available right
   now.") if the endpoint is called directly.

Values take effect differently in each process:

* **Rails** (dotenv-rails): edit `wine_prediction_api/.env.development`, then
  **restart the server** (`bin/rails server`).
* **Vite**: edit `wine_prediction/.env.development`, then **restart
  `npm run dev`** (Vite reads `import.meta.env` when the dev server starts and
  bakes the values into production builds).

### Environment variables (backend — Render in production, never Vite)

| Variable | Provider | Notes |
|---|---|---|
| `GOOGLE_CLIENT_ID` | Google | audience for ID token verification |
| `APPLE_CLIENT_ID` | Apple | the Apple **Services ID** (web client id) |
| `APPLE_TEAM_ID` | Apple | only needed for the authorization-code exchange |
| `APPLE_KEY_ID` | Apple | only needed for the authorization-code exchange |
| `APPLE_PRIVATE_KEY` | Apple | PKCS#8 PEM; literal `\n` escapes are converted |
| `MICROSOFT_CLIENT_ID` | Microsoft | audience for ID token verification |
| `MICROSOFT_TENANT_ID` | Microsoft | `common` (default), `organizations`, `consumers`, or a tenant id/domain |
| `FACEBOOK_APP_ID` | Facebook | also used to check the token's `app_id` |
| `FACEBOOK_APP_SECRET` | Facebook | **server-side only**; never sent to React |
| `FACEBOOK_GRAPH_VERSION` | Facebook | defaults to `v21.0` |

No Google client secret is required: ID tokens are verified against Google's
published JWKS, so there is no secret to leak.

### Environment variables (frontend — Vite)

Only public identifiers. These are compiled into the bundle and are safe to
expose; **no secret is ever placed here.**

| Variable | Notes |
|---|---|
| `VITE_GOOGLE_CLIENT_ID` | Google client id |
| `VITE_APPLE_CLIENT_ID` | Apple Services ID |
| `VITE_APPLE_REDIRECT_URI` | defaults to `window.location.origin` |
| `VITE_MICROSOFT_CLIENT_ID` | Microsoft application (client) id |
| `VITE_MICROSOFT_TENANT_ID` | must match the backend value (default `common`) |
| `VITE_FACEBOOK_APP_ID` | Facebook app id |
| `VITE_FACEBOOK_GRAPH_VERSION` | defaults to `v21.0` |

A provider whose client id is absent is simply **not offered** by the UI
(`availableProviders()`), and its endpoint returns
`503 provider_not_configured` if called directly.

### Development vs production

The provider popups are SDK-driven, so the provider dashboards need the
origins/redirect URIs registered. Because the flow is popup-based, no backend
callback URL is involved.

| Provider | Environment | Authorised origin / redirect | Frontend | Backend |
|---|---|---|---|---|
| Google | Development | `http://localhost:5173` | `http://localhost:5173` | `http://localhost:3000` |
| Google | Production | `https://<vercel-app-domain>` | Vercel | Render |
| Apple | Development | HTTPS Return URL on a tunnel (plain `http://localhost:5173` is rejected by Apple — see "Apple" below) | `http://localhost:5173` via tunnel | `http://localhost:3000` |
| Apple | Production | `https://<vercel-app-domain>` (Services ID return URL) | Vercel | Render |
| Microsoft | Development | `http://localhost:5173` (SPA redirect URI) | `http://localhost:5173` | `http://localhost:3000` |
| Microsoft | Production | `https://<vercel-app-domain>` (SPA redirect URI) | Vercel | Render |
| Facebook | Development | `http://localhost:5173` (Valid OAuth Redirect URI) | `http://localhost:5173` | `http://localhost:3000` |
| Facebook | Production | `https://<vercel-app-domain>` | Vercel | Render |

Keep the two environments on **separate provider applications** (or separate
origins on one app) and never use production secrets locally.
---

### Setting up each provider (development)

#### Google

1. In the [Google Cloud Console](https://console.cloud.google.com/):
   * create (or select) a project,
   * go to **APIs & Services → OAuth consent screen** → choose **External**,
     fill in the app details and add the scopes `openid`, `email`, `profile`,
   * while the consent screen is in **Testing** mode, add your own address
     under **Test users** so you can sign in.
2. Go to **Credentials → Create credentials → OAuth client ID → Web
   application**.
3. Under **Authorised JavaScript origins** add `http://localhost:5173` (and
   later the production URL from the table above).
4. Copy the **client ID** and put it in both places:

   ```
   # wine_prediction_api/.env.development
   GOOGLE_CLIENT_ID=xxxx.apps.googleusercontent.com
   ```

   ```
   # wine_prediction/.env.development
   VITE_GOOGLE_CLIENT_ID=xxxx.apps.googleusercontent.com
   ```

5. Restart the Rails server and the Vite dev server.

No client secret is needed anywhere — the Rails verifier checks the ID token
against Google's published JWKS, and that token (`google.accounts.id.prompt`
in `socialProviders.js`) never leaves the sign-in call.

#### Apple

1. In the [Apple Developer](https://developer.apple.com/account) portal:
   * **Certificates, IDs & Profiles → Identifiers** — create an **App ID**
     (enable *Sign in with Apple*) and a **Services ID**. The Services ID
     (e.g. `com.wineprediction.web`) is the *only* id this implementation
     needs.
   * Configure the Services ID: enable **Sign in with Apple** and register
     the authorised **Domain** plus the **Return URL**.
2. Use the **Services ID** for both variables:

   ```
   # wine_prediction_api/.env.development
   APPLE_CLIENT_ID=com.wineprediction.web
   ```

   ```
   # wine_prediction/.env.development
   VITE_APPLE_CLIENT_ID=com.wineprediction.web
   ```

3. `APPLE_TEAM_ID`, `APPLE_KEY_ID` and `APPLE_PRIVATE_KEY` are **not required**
   here. They are only needed for the server-side Apple authorization-code
   exchange, which this implementation does not use — the identity token is
   verified directly against Apple's public keys.
4. Restart the Rails server and the Vite dev server.

**Apple HTTPS/localhost workaround.** Apple requires an **HTTPS** Return URL, so
plain `http://localhost:5173` is rejected for the development environment. To
test Apple locally:

1. Start an HTTPS tunnel to the dev server, e.g.
   `ngrok http 5173` → `https://abcd-1234.ngrok.io`.
2. Register that tunnel host as the Services ID **Domain** and
   `https://abcd-1234.ngrok.io` as the **Return URL**.
3. Set `VITE_APPLE_REDIRECT_URI=https://abcd-1234.ngrok.io` (it must match the
   registered Return URL exactly) and restart the Vite dev server.
4. Open the app **through the tunnel URL** (`window.location.origin` is no
   longer used for the Apple call once the override is set).

Production needs no workaround: the Vercel URL is already HTTPS.

#### Microsoft

1. In the [Entra admin center](https://entra.microsoft.com) (or the Azure
   portal):
   * **Identity → Applications → App registrations → New registration** —
     give it a name and, under **Supported account types**, select
     *Accounts in any organizational directory and personal Microsoft
     accounts* to match the default `common` tenant policy.
   * Leave **Redirect URI** blank for now — it is added under the platform
     configuration in the next step.
2. On the new registration page go to **Authentication → Add a platform →
   Single-page application (SPA)** and add the **Redirect URIs**
   `http://localhost:5173` and (for production) `https://<vercel-app-domain>`.
3. Request **no** API permissions and create **no** client secret. The frontend
   (`socialProviders.js`) asks only for the default `openid email profile`
   scopes, and the Rails verifier checks the ID token against Microsoft's
   v2.0 keys — Graph permissions and a secret are unnecessary.
4. Copy the **Application (client) ID** from the registration's Overview page
   into both places:

   ```
   # wine_prediction_api/.env.development
   MICROSOFT_CLIENT_ID=00000000-0000-0000-0000-000000000000
   MICROSOFT_TENANT_ID=common
   ```

   ```
   # wine_prediction/.env.development
   VITE_MICROSOFT_CLIENT_ID=00000000-0000-0000-0000-000000000000
   VITE_MICROSOFT_TENANT_ID=common
   ```

5. The tenant values **must match**: the API independently re-checks the
   token's issuer and `tid` claim against `MICROSOFT_TENANT_ID`, so a mismatch
   rejects every Microsoft sign-in. Use `organizations` (organisation-only) or
   `consumers` (personal-only) on both sides if you want to restrict the
   audience — see "Microsoft account types" below.
6. Restart the Rails server and the Vite dev server.

#### Facebook

1. In [Meta for Developers](https://developers.facebook.com):
   * create an app (type Consumer/None) and add the **Facebook Login**
     product — or open an existing app that has it,
   * under **Facebook Login → Settings**, the frontend (`socialProviders.js`)
     asks only for `public_profile,email`, so request **no other permissions**,
   * set the **Site URL** and **Valid OAuth Redirect URIs** to
     `http://localhost:5173` for development (plus the production URL later),
   * switch the app to **Live** if anyone other than its admins/developers/
     test users must be able to sign in (in Development mode only those can).
2. Copy the **App ID** and **App secret** from **Settings → Basic**:

   ```
   # wine_prediction_api/.env.development
   FACEBOOK_APP_ID=123456789012345
   FACEBOOK_APP_SECRET=your-app-secret-here
   # FACEBOOK_GRAPH_VERSION=v21.0   # optional — v21.0 is the default
   ```

   ```
   # wine_prediction/.env.development
   VITE_FACEBOOK_APP_ID=123456789012345
   # VITE_FACEBOOK_GRAPH_VERSION=v21.0   # optional — v21.0 is the default
   ```

3. Keep `FACEBOOK_APP_SECRET` **backend-only**: the Rails verifier uses it to
   build the app access token for `GET /debug_token`, and it must never be
   added to a `VITE_*` variable (Vite compiles those into the public bundle).
4. Restart the Rails server and the Vite dev server.

---

### Verifying the setup

1. Restarted both servers? Check the exact place values are read:
   Rails — `wine_prediction_api/.env.development` via dotenv-rails;
   Vite — `wine_prediction/.env.development` via `import.meta.env`.
2. Ask the API directly which providers are usable:

   ```
   cd wine_prediction_api
   bundle exec rails runner 'Authentication::PROVIDERS.each { |p| puts "#{p}: #{Authentication.configured?(p)}" }'
   ```
3. Open `/login`: "Continue with …" appears only for providers whose
   `VITE_*` id is set — a hidden button means the frontend variable is
   missing, not a code bug.
4. Quick endpoint smoke test (a dummy credential is rejected when the
   provider is configured, but gives `503 provider_not_configured` when the
   backend variable is missing):

   ```
   curl -s -o /dev/null -w '%{http_code}\n' -X POST \
     http://localhost:3000/api/v1/auth/google \
     -H 'Content-Type: application/json' -d '{"credential":"x"}'
   ```
5. After a real sign-in, **Account settings → Sign-in methods** lists the
   connected provider, and the remaining configured providers are offered
   under "Connect another".
---

## 5. Microsoft account types

Wine Prediction supports **both personal and organisational Microsoft
accounts**. `MICROSOFT_TENANT_ID` selects the policy:

| Value | Accepts |
|---|---|
| `common` *(default, recommended)* | personal + organisational |
| `organizations` | organisational only (rejects the MSA tenant) |
| `consumers` | personal only |
| `<tenant-guid-or-domain>` | exactly that one tenant |

Only the minimum scopes — `openid email profile` — are requested. **No
Microsoft Graph permission is needed**: the ID token alone establishes identity.
The `sub` claim is used as the identity key (`oid` is not), and the token's
`tid` is checked against its verified issuer so an unverified tenant cannot be
trusted.

---

## 6. Apple private relay

If a person chooses **Hide My Email**, Apple returns an address such as

```
abc123xyz@privaterelay.appleid.com
```

`Authentication::Claims::PRIVATE_RELAY_DOMAINS` is the single place to extend if
Apple introduces another relay domain.

How it is handled:

* The Apple **`sub`** is the identity key, so the account still resolves
  perfectly on every later sign-in — including when Apple omits the email
  entirely, which it does after the first authorisation.
* A relay address is **never used to auto-link** onto an existing User
  (`Claims#private_relay_email?` blocks Case 2). Someone signing in with Apple
  Hide My Email gets their own account, or connects Apple from Account settings
  while signed in.
* Relay addresses are ordinary valid strings to us — nothing in the schema
  assumes the email equals the person's real mailbox, so email-based features
  remain compatible.
---

## 7. Security

* **Nothing from the frontend is trusted.** React sends only the provider's
  credential. The backend derives the provider, the provider UID, the email and
  the verification status itself.
* **Tokens are verified properly**: signature (RS256/ES256 against the
  provider's published JWKS), issuer, audience, expiry and algorithm
  allow-list. Tokens without `sub` or without `exp` are rejected.
* **Apple nonce** is compared against the SHA-256 digest Apple echoes back.
* **Facebook** tokens are validated with `GET /debug_token` (proving validity,
  expiry and that the token belongs to *our* app) before identity is read from
  `/me` with that validated token.
* **Secrets never reach React**, are never logged, and are never committed.
  `Authentication::HttpClient` logs nothing at all, so access tokens,
  authorization codes and provider secrets cannot leak into the application log.
* **Error responses** carry only a safe message plus a stable `code`
  (`invalid_credential`, `invalid_nonce`, `invalid_tenant`,
  `provider_not_configured`, `account_exists`, `identity_taken`,
  `last_authentication_method`, `unsupported_provider`, `provider_unavailable`,
  `provider_error`). No tokens, secrets or stack traces.
* **JWKS caching**: key sets are cached for an hour and refetched once when an
  unknown `kid` appears (standard key-rotation handling).

---

## 8. Audit logging

Social authentication uses the existing audit mechanism (`Auditable` /
`LogService`) and respects the *Save logs to database* setting on the
Configuration page:

| Event | Description |
|---|---|
| Sign-in | `User logged in with Google` / `Apple` / `Microsoft` / `Facebook` |
| Linking | `Google identity connected`, `Microsoft identity connected`, … |
| Unlinking | `Google identity disconnected`, … |

Credentials, tokens, authorization codes and provider secrets are **never**
written to the log.

---

## 9. Provider independence of authorization

The provider used has **no effect** on authorization:

* roles are untouched (`Admin` / Super User stays `Admin` after any social login),
* subscriptions and `UserSubscription` records are untouched,
* the Stripe customer and subscription are untouched (no duplicate customer is
  ever created),
* the Account remains exactly one.

The provider therefore never determines role or plan; the `User` does.

---

## 10. Testing

Provider *verification* is the only thing stubbed in the request specs —
everything after it (identity resolution, linking, roles, subscriptions,
Account, JWT issuance, audit logging) runs for real.

| Spec | Covers |
|---|---|
| `spec/requests/api/v1/sessions_spec.rb` | email/password sign-in regression: identical payload/JWT, and a social-only User has no password |
| `spec/models/user_identity_spec.rb` | associations, enum, validations, DB uniqueness |
| `spec/services/authentication/oidc_verifier_spec.rb` | Google: valid, expired, wrong audience/issuer, bad signature, unknown `kid`, unsigned token |
| `spec/services/authentication/apple_spec.rb` | nonce digest, private relay, missing email, expiry, audience, issuer |
| `spec/services/authentication/microsoft_spec.rb` | tenant policies (personal / organisational / concrete), `tid`↔`iss`, UPN trust |
| `spec/services/authentication/facebook_spec.rb` | `debug_token` validation, app-id match, `/me` mismatch, no-verified-email policy |
| `spec/requests/api/v1/social_auth_spec.rb` | sign-in end to end, new/existing User, no duplicates, safe errors |
| `spec/requests/api/v1/social_auth_integrity_spec.rb` | roles, subscriptions, Stripe, Account, four-provider linking, audit |
| `spec/requests/api/v1/user_identities_spec.rb` | linking endpoints, hijack prevention, last-method protection |

Invitations: Wine Prediction has no invitation system at present, so none is
integrated. The design keeps `UserIdentity` separate from invitation logic, so a
future email-based invitation flow can hook into Case 2/3 resolution by email
without provider-specific changes.
