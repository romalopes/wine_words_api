# Wine Words — Custom Domain Setup Guide

**Domain:** `wine-words.com`  
**Goal:** Connect the new Wine Words frontend, Rails API, and legacy Substack archive using one domain.  
**Updated:** 10 October 2026

## 1. Recommended architecture

| Public URL | Purpose | Platform |
|---|---|---|
| https://wine-words.com | Main React frontend | Vercel |
| https://www.wine-words.com | Redirect to the main domain | Vercel |
| https://api.wine-words.com | Rails API | Render |
| https://archive.wine-words.com | Legacy articles | Substack |

The custom-domain plan below uses Vercel for the apex and `www`. The frontend also runs on Cloudflare Workers at its existing provider URL.

Existing service URLs (retain while migrating):
- Frontend (Vercel): https://wine-words.vercel.app
- Frontend (Cloudflare Workers): https://wine-words.romalopes.workers.dev/
- API: https://wine-words-api.onrender.com
- Legacy Substack publication: use its existing `[publication].substack.com` URL (not yet specified).

```text
wine-words.com ───────────────→ Vercel (React)
www.wine-words.com ───────────→ redirect to wine-words.com
api.wine-words.com ───────────→ Render (Rails API)
archive.wine-words.com ───────→ Substack (legacy articles)
                                       
Rails API ─────→ Neon or Supabase PostgreSQL
          └────→ Cloudflare R2 object storage
```

**Recommendation:** Buy the domain through Cloudflare if pricing and availability suit you, and use Cloudflare DNS regardless of the registrar. Webcentral is also workable.

## 2. Useful dashboards and documentation

| Service | Dashboard / entry point | Setup documentation |
|---|---|---|
| Cloudflare | https://dash.cloudflare.com/ | https://developers.cloudflare.com/dns/manage-dns-records/how-to/create-dns-records/ |
| Cloudflare Registrar | https://dash.cloudflare.com/ | https://developers.cloudflare.com/registrar/ |
| Webcentral | https://www.webcentral.au/ | https://www.webcentral.au/support/ |
| Vercel | https://vercel.com/dashboard | https://vercel.com/docs/domains/set-up-custom-domain |
| Render | https://dashboard.render.com/ | https://render.com/docs/custom-domains |
| Render + Cloudflare | https://dashboard.render.com/ | https://render.com/docs/configure-cloudflare-dns |
| Substack | https://substack.com/ | https://support.substack.com/hc/en-us/articles/360051222571-How-do-I-set-up-my-custom-domain-on-Substack |
| DNS verification | https://dnschecker.org/ | — |
| Brevo (optional email) | https://app.brevo.com/ | https://help.brevo.com/ |
| Resend (optional email) | https://resend.com/domains | https://resend.com/docs/dashboard/domains/introduction |

## 3. Step 1 — Register domain and choose DNS manager

### Option A: Purchase through Cloudflare (preferred)

1. Open [Cloudflare](https://dash.cloudflare.com/), sign in, and check whether `wine-words.com` is available for registration.
2. Purchase the domain, enable auto-renewal and account MFA.
3. Open the domain → **DNS → Records**. Cloudflare will be your DNS manager.
4. Keep the existing Vercel and Cloudflare Workers frontend deployments and Render API available while configuring DNS.

### Option B: Purchase through Webcentral

1. Open [Webcentral](https://www.webcentral.au/), purchase `wine-words.com`, and locate the domain's DNS or nameserver settings.
2. **Choice 1:** Keep Webcentral nameservers and add the records in its DNS panel.
3. **Choice 2 (preferred):** Add the domain as a site in [Cloudflare](https://dash.cloudflare.com/), carefully review/import all existing DNS records, then replace the nameservers at Webcentral with the two assigned by Cloudflare.
4. Wait until Cloudflare marks the zone **Active**. After a nameserver switch, manage DNS only in Cloudflare, not in Webcentral.
5. Preserve any existing MX, TXT, SPF, DKIM, DMARC, and other records during migration. If DNSSEC is enabled, follow Cloudflare's DNSSEC migration guidance before changing nameservers.

**Important:** The registrar (where you buy the domain) and DNS host (where you configure records) can be different. You do not need to transfer the domain registration from Webcentral to Cloudflare.

## 4. Step 2 — Connect the frontend to Vercel

1. Visit [Vercel dashboard](https://vercel.com/dashboard) and open the existing Wine Words frontend project.
2. Go to **Settings → Domains**.
3. Add `wine-words.com` and `www.wine-words.com`.
4. Make `wine-words.com` canonical; configure `www.wine-words.com` to redirect permanently to it.
5. Copy the exact DNS values Vercel shows for **this project**.
6. At your authoritative DNS host, create the Vercel records and remove conflicting old records for the same hosts.
7. Return to Vercel and verify the domain and TLS certificate.

Typical records (examples only; **use Vercel's displayed targets**):

| Type | Name | Value | Cloudflare proxy |
|---|---|---|---|
| A | `@` | Vercel-provided IP (often `76.76.21.21`) | DNS only initially |
| CNAME | `www` | Vercel-provided hostname (often `cname.vercel-dns-0.com`) | DNS only initially |

See [Vercel domain documentation](https://vercel.com/docs/domains/set-up-custom-domain). Vercel provisions HTTPS certificates after successful verification.

## 5. Step 3 — Connect the Rails API to Render

1. Open [Render dashboard](https://dashboard.render.com/).
2. Select the existing `wine_words_api` service.
3. Go to **Settings → Custom Domains → Add Custom Domain**.
4. Enter `api.wine-words.com`.
5. Create this DNS record at your authoritative DNS provider:

| Type | Name | Value | Cloudflare proxy |
|---|---|---|---|
| CNAME | `api` | `wine-words-api.onrender.com` | **DNS only** for verification |

6. Return to Render and click **Verify**; confirm the SSL/TLS certificate is issued.
7. Test `https://api.wine-words.com` and an actual existing API endpoint (the root URL may legitimately return 404 if Rails has no root route).

Documentation: [Render custom domains](https://render.com/docs/custom-domains), [Render Cloudflare DNS](https://render.com/docs/configure-cloudflare-dns).

**Do not point the apex `wine-words.com` to Render**: the apex belongs to Vercel. Avoid a wildcard domain record unless there is a specific need.

## 6. Step 4 — Connect the legacy Substack archive

1. Open your Substack publication dashboard. Its direct settings URL typically has the form `https://YOUR-PUBLICATION.substack.com/publish/settings`.
2. Go to **Settings → Domain** and choose **Add custom domain**.
3. Enter `archive.wine-words.com`, complete Substack's custom-domain payment/setup, then copy the DNS instructions it displays.
4. Add the following record:

| Type | Name | Value | Cloudflare proxy |
|---|---|---|---|
| CNAME | `archive` | `target.substack-custom-domains.com` | **DNS only — required** |

5. Return to Substack → **Domain → Check status**. Verification may take up to 36 hours.
6. Keep the original Substack URL accessible while checking redirects and legacy article links.
7. **Do not enable Substack's root-domain redirect**: the root `wine-words.com` belongs to Vercel, not Substack.

Substack's current help page states a **one-time USD $50 custom-domain fee** (check at checkout): [official setup guide](https://support.substack.com/hc/en-us/articles/360051222571-How-do-I-set-up-my-custom-domain-on-Substack).

## 7. Consolidated DNS record checklist

The following is the intended configuration **after each service has supplied and verified its values**:

| Type | Host | Target | Notes |
|---|---|---|---|
| A | `@` | Exact Vercel-provided IP | Main frontend |
| CNAME | `www` | Exact Vercel-provided CNAME | Redirect configured at Vercel |
| CNAME | `api` | `wine-words-api.onrender.com` | DNS only during Render verification |
| CNAME | `archive` | `target.substack-custom-domains.com` | DNS only |

Do not add a second, conflicting A/CNAME record for the same hostname. DNS does not itself implement the `www` HTTP redirect: configure that in Vercel.

## 8. Step 5 — Update Wine Words application configuration

### Frontend environment (Vercel and Cloudflare Workers)

Set the production environment variable for both frontend builds:

```dotenv
VITE_API_BASE_URL=https://api.wine-words.com/api/v1
```

Rebuild/redeploy the Vite frontend: `VITE_*` values are baked into the client bundle at build time. Keep localhost development configuration separate.

### Rails CORS

Allow the actual production frontend origins (and only necessary development/preview origins). Example for `rack-cors`:

```ruby
# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'https://wine-words.com', 'https://www.wine-words.com',
            'https://wine-words.vercel.app', 'https://wine-words.romalopes.workers.dev'
    resource '/api/*',
             headers: :any,
             methods: %i[get post put patch delete options]
  end
end
```

Adjust to your existing authentication strategy and configuration; if using cross-origin cookie credentials, explicitly configure `credentials: true` and avoid wildcard origins. The API at `api.wine-words.com` is a separate **origin**, even though it shares the registrable domain.

### Authentication, callbacks, and URLs

- Update OAuth/Google authorized JavaScript origins and redirect URIs where applicable, using exact frontend/API callback URLs required by your implementation.
- Update Rails mailer host, password-reset links, invitation links, and canonical frontend URLs.
- Check `config.hosts` / Rails HostAuthorization if you restrict allowed hostnames.
- Check cookie `SameSite`, `Secure`, domain, and CSRF settings if you use session-cookie authentication.
- Update webhook allowlists, CSP `connect-src`, analytics settings, and any hardcoded Render/Vercel/Cloudflare Workers URLs.
- Leave Cloudflare R2 storage configuration and Neon/Supabase database URLs unchanged: domain routing does not require a database or object-storage migration.
- Deploy and test login, logout, password reset, image uploads, API calls, and cross-origin requests.

## 9. Step 6 — Make the legacy archive discoverable

Add a frontend route at `https://wine-words.com/archive` with an introduction and link to `https://archive.wine-words.com`.

For older articles, consider a staged content migration rather than copying everything at once. When republishing content, preserve attribution and avoid duplicate SEO pages with appropriate canonical tags or redirects where you control them. Check existing Substack article links before changing them.

## 10. Test and verify

```bash
# DNS records
 dig +short wine-words.com A
 dig +short www.wine-words.com CNAME
 dig +short api.wine-words.com CNAME
 dig +short archive.wine-words.com CNAME

# HTTPS response headers
 curl -I https://wine-words.com
 curl -I https://www.wine-words.com
 curl -I https://api.wine-words.com
 curl -I https://archive.wine-words.com

# Test CORS preflight on a real API route (replace endpoint as needed)
 curl -i -X OPTIONS 'https://api.wine-words.com/api/v1/categories/counts' \
   -H 'Origin: https://wine-words.com' \
   -H 'Access-Control-Request-Method: GET'
```

Expected outcomes:

- [ ] `https://wine-words.com` loads the production React application.
- [ ] `https://www.wine-words.com` permanently redirects to the canonical URL.
- [ ] `https://api.wine-words.com` reaches Rails with valid HTTPS (root 404 may be normal).
- [ ] `https://archive.wine-words.com` loads legacy Substack articles with valid HTTPS.
- [ ] Frontend network requests use `https://api.wine-words.com/api/v1`.
- [ ] Login, OAuth, reset emails, images, comments, and articles work.
- [ ] No unexpected CORS failures, mixed-content errors, or TLS warnings.
- [ ] Existing Vercel/Cloudflare Workers/Render provider URLs still work until deliberately retired.

## 11. Rollout and rollback

**Suggested order:** register domain → configure DNS → verify Vercel → verify Render → configure Substack → update frontend API URL and Rails CORS → test → publish the new domain.

Keep the original `wine-words.vercel.app`, `wine-words.romalopes.workers.dev`, and `wine-words-api.onrender.com` URLs available during rollout. If a custom hostname fails, use the existing provider URLs for troubleshooting; restore previous frontend environment settings and redeploy if necessary. Record old DNS values before editing and allow time for propagation.

## 12. Later: branded email

When ready, configure `contact@wine-words.com` or `no-reply@wine-words.com` with an email provider. Add the **exact** SPF/DKIM/DMARC, verification, and (if receiving email) MX records specified by your chosen provider. Avoid creating multiple SPF TXT records at the same hostname; merge permitted senders into one SPF policy. The email DNS records coexist with the website/API/archive records.

Useful links: [Brevo](https://app.brevo.com/), [Resend Domains](https://resend.com/domains), [Cloudflare DNS records](https://developers.cloudflare.com/dns/manage-dns-records/how-to/create-dns-records/).
