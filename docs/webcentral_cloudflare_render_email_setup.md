# Webcentral Domain Setup for Cloudflare, Render, Vercel, Brevo and Resend

**Projects:** Wine Words and Beach Volleyball Project (BVP / Beach Volleyball Hub)  
**Purpose:** Use an existing domain registered at Webcentral for web hosting and authenticated transactional email without transferring the domain registration.

## 1. Key concepts

- **Webcentral** is your domain registrar. You can leave the registration and renewals there.
- **DNS hosting** controls records for the domain. DNS can stay at Webcentral or move to Cloudflare's DNS service (without transferring registration).
- **Render** hosts Rails APIs. Its `*.onrender.com` subdomains are not domains you own, so you cannot manage their DNS or authenticate them as your own sending domains with Brevo/Resend.
- **Vercel** can host React frontends.
- **Brevo or Resend** sends application emails; it authenticates your domain by asking you to publish DNS records.
- **Cloudflare R2 object storage** is independent of using Cloudflare as your DNS provider. You can use R2 while keeping DNS at Webcentral.

You **do not need to buy a domain from Cloudflare** or move your application hosting from Render/Vercel.

## 2. Two DNS approaches

### Option A — Keep DNS at Webcentral (fewest changes)

1. Log into Webcentral and find the DNS editor for your domain.
2. Add the custom-domain records provided by Render and/or Vercel.
3. Add the domain-verification, DKIM, SPF and DMARC records supplied by Brevo or Resend.
4. Verify each service in its own dashboard.

**Advantages:** No nameserver migration, lowest risk of disrupting existing email or website services.  
**Disadvantages:** DNS administration depends on Webcentral's interface and capabilities.

### Option B — Keep registration at Webcentral; move DNS to Cloudflare (recommended if you want unified DNS)

1. Inspect and export/copy **all existing DNS records** at Webcentral: A, AAAA, CNAME, MX, TXT (including SPF, DKIM, DMARC), CAA, SRV and any other custom records.
2. Check whether the domain currently receives mail or hosts a website. Preserve the necessary records.
3. Add the existing domain to Cloudflare and choose its Free plan if suitable.
4. Review Cloudflare's imported DNS records and manually add any missing records **before changing nameservers**.
5. If DNSSEC is enabled at the registrar, follow Cloudflare's migration instructions to avoid a DNSSEC mismatch (typically remove the old DS record before switching and re-enable DNSSEC afterward).
6. Cloudflare supplies two authoritative nameservers. Copy the **actual assigned values**.
7. In Webcentral domain management, replace the current nameservers with those two Cloudflare nameservers.
8. Wait for Cloudflare to show the zone as active; confirm DNS resolution, website and incoming/outgoing email still work.
9. From that point forward, maintain DNS records in **Cloudflare**, while renewing the domain at **Webcentral**.

**Important:** Do not change nameservers until existing DNS records are accounted for. Nameserver propagation/caching may take up to 24–48 hours in some environments.

## 3. Suggested architecture

The examples below are **placeholders**, not domains confirmed to be owned or available.

```text
Webcentral (domain registrar)
          |
          v
Cloudflare DNS (optional; alternatively Webcentral DNS)
          |
          +-- www.example.com.au  --> Vercel (React frontend)
          +-- api.example.com.au  --> Render (Rails API)
          +-- mail.example.com.au --> sending-domain authentication records
          |
          +-- Cloudflare R2      --> application object storage (separate service)

Rails on Render --HTTPS API--> Resend OR Brevo --> recipient inbox
```

For **Wine Words**, a possible arrangement with its own domain:

- `www.winewords.net` or `winewords.net` → Vercel
- `api.winewords.net` → Render
- `noreply@winewords.net` → authenticated sending address
- Or `noreply@mail.winewords.net` → isolated sending subdomain (verify that exact subdomain with the provider)

For **BVP**, if you later register a separate domain:

- `www.beachvolleyballhub.com.au` → Vercel
- `api.beachvolleyballhub.com.au` → Render
- `noreply@beachvolleyballhub.com.au` → authenticated sender

**Do not assume the above names are owned or available.** With only one existing domain, you can temporarily use separate subdomains for both applications, or acquire a second domain later for independent branding.

## 4. Configure Render custom API domain

1. In Render, open the correct Rails Web Service.
2. Go to **Settings → Custom Domains** and add your chosen API hostname (e.g. `api.example.com.au`).
3. Render will display the required DNS target and any verification instructions.
4. Create the DNS record in the authoritative DNS provider (Webcentral or Cloudflare).
5. If using Cloudflare, initially set the Render hostname record to **DNS only** (grey cloud), unless following Render's specific proxy guidance.
6. Return to Render and verify the custom domain and TLS certificate.
7. Test `https://api.example.com.au`.
8. Update frontend environment variables (for example `VITE_API_BASE_URL`), Rails CORS allowed origins, authentication redirects/callbacks, and any external webhook URLs as needed.
9. Keep the existing `*.onrender.com` address until migration is validated.

Existing services:

- Wine Words API: `https://wine-words-api.onrender.com`
- BVP development API: `https://beachvolleyballproject-dev.onrender.com`

**Note:** A custom domain does not change the underlying Render plan, memory limit, sleeping behavior, or availability.

## 5. Configure Vercel frontend domain

1. Open the Vercel project → **Settings → Domains**.
2. Add the intended apex and/or `www` domain.
3. Copy the exact A/CNAME instructions shown by Vercel into the authoritative DNS provider.
4. Verify the domain in Vercel, then test HTTPS and routing.
5. Choose a canonical hostname and configure redirects if desired.
6. Check that frontend API URLs point to the correct Render API hostname.

Wine Words currently uses `https://wine-words.vercel.app`; the BVP frontend may remain on its current deployment until a domain is configured.

## 6. Authenticate a sending domain with Brevo

1. Open Brevo's **Senders / Domains** settings (labels may vary).
2. Add the domain or sending subdomain that you control.
3. Copy the **exact** verification and authentication records Brevo supplies (typically ownership verification, DKIM and DMARC-related guidance).
4. Create these records in Webcentral DNS or Cloudflare DNS, whichever is authoritative.
5. Wait for DNS propagation and click Verify/Authenticate in Brevo.
6. Configure a verified sender address, e.g. `noreply@example.com.au`.
7. Configure the Rails application to send through Brevo's HTTPS API or supported mail transport.
8. Send a test message and inspect the authentication results in the received message headers.

## 7. Authenticate a sending domain with Resend

1. Open Resend → **Domains → Add Domain**.
2. Enter your owned domain or preferred sending subdomain.
3. Copy Resend's exact DNS instructions (often DKIM and an SPF/MX arrangement for its sending/return-path subdomain).
4. Add those records to the authoritative DNS provider.
5. Verify the domain in Resend.
6. Set the Rails sender address to one permitted by that verified domain.
7. Store the Resend API key in Render environment secrets; never commit it to Git.
8. Send a test message through the HTTPS API and confirm delivery/authentication.

**Recommendation:** For low-volume Rails transactional emails, an HTTPS API is usually easier to operate on a constrained hosting plan than Gmail SMTP. Check each provider's current free-plan limits and domain limits before deciding.

## 8. DNS record examples (illustrative only)

| Type | Host | Purpose | Value |
|---|---|---|---|
| CNAME | `api` | Render API | **Copy from Render** |
| CNAME | `www` | Vercel frontend | **Copy from Vercel** |
| TXT/CNAME | Provider-specified selector | DKIM | **Copy from Brevo/Resend** |
| TXT | Provider-specified hostname | Domain verification | **Copy from provider** |
| TXT | `_dmarc` or `_dmarc.mail` | DMARC policy | **Configure for the exact sending domain** |
| TXT | Provider-specified SPF hostname | SPF | **Copy from provider** |
| MX | Provider-specified return-path host, if requested | Sending/return-path handling | **Copy from provider** |

**Critical DNS rules:**

- Do not paste made-up DKIM keys or example DNS targets.
- Do not create multiple separate SPF TXT records at the **same hostname**. If more than one sender needs SPF at that name, combine mechanisms within SPF limits or use distinct subdomains.
- Preserve existing MX records used for **incoming mail**. A provider's return-path MX record is not automatically a replacement for your normal mailbox MX records.
- A domain used by both Brevo and Resend may require coordinated SPF/DKIM/DMARC setup; separate sending subdomains often simplify this.
- In Cloudflare, email-related CNAME records should generally be **DNS only**; Cloudflare's HTTP proxy is not an email proxy.
- Sending-domain DNS authentication does **not** create an inbox. For replies or support mail you still need a mailbox or forwarding provider.
- Start with a suitable DMARC monitoring policy if you're still configuring senders, then tighten it after validation.

## 9. Rails integration checklist

For each Rails project:

- [ ] Decide whether to use Brevo or Resend as the primary transactional email provider.
- [ ] Verify the sender domain/subdomain and sender address.
- [ ] Add API credentials to Render secrets.
- [ ] Configure Action Mailer or a provider-specific delivery adapter.
- [ ] Set the default `from` address and production `default_url_options`.
- [ ] Configure background email jobs/retries where appropriate.
- [ ] Test password reset, email verification, invitation and login alert messages.
- [ ] Check SPF, DKIM and DMARC results in recipient headers.
- [ ] Monitor provider API errors, bounce events and rate limits.
- [ ] Remove obsolete Gmail SMTP secrets only after the new path works.

## 10. Validation and troubleshooting

Use a terminal on macOS to inspect DNS (replace the example domain):

```bash
dig NS example.com.au +short
dig CNAME api.example.com.au +short
dig CNAME www.example.com.au +short
dig TXT example.com.au +short
dig TXT _dmarc.example.com.au +short
dig MX example.com.au +short
curl -I https://api.example.com.au
```

For DKIM, query the exact selector and hostname supplied by the email provider. The correct selector is not universal.

If verification fails:

1. Confirm which nameservers are authoritative.
2. Check the DNS record's **hostname** and **value**, especially whether the DNS panel auto-appends the zone name.
3. Ensure no conflicting CNAME and other records exist at the same owner name.
4. Allow DNS caches to expire and retry verification.
5. Inspect the provider's domain verification status and errors.

If browser calls fail after a custom-domain change, inspect Rails CORS settings, `VITE_API_BASE_URL`, HTTPS, redirect URLs, and Render service health. A Render 502 or memory-limit restart is not automatically a DNS or CORS problem.

## 11. Suggested rollout phases

### Phase 1 — Inventory and protect
- [ ] Confirm the exact Webcentral domain name and whether it already hosts website/email services.
- [ ] Record all current DNS entries and current nameservers.
- [ ] Decide whether DNS should stay at Webcentral or move to Cloudflare.

### Phase 2 — DNS management
- [ ] If using Cloudflare, import and validate DNS before changing nameservers.
- [ ] Switch nameservers at Webcentral only after validating all records.
- [ ] Confirm website, inbound email and DNS resolution.

### Phase 3 — Transactional email (can happen before custom web domains)
- [ ] Choose Brevo or Resend.
- [ ] Authenticate the owned domain or subdomain.
- [ ] Configure Rails HTTPS email delivery and test password reset/invitations.

### Phase 4 — Custom API and frontend domains (optional)
- [ ] Add API hostname in Render and publish its DNS record.
- [ ] Add frontend hostname in Vercel and publish its DNS record.
- [ ] Update app URLs, CORS and OAuth callback settings.
- [ ] Test production traffic before switching links publicly.

### Phase 5 — Repeat for the second project
- [ ] Decide whether to use the same domain with separate subdomains or buy a second branded domain.
- [ ] Repeat DNS/email/app verification without disrupting the first project.

## 12. Useful official documentation

- Cloudflare full DNS setup: https://developers.cloudflare.com/dns/zone-setups/full-setup/setup/
- Cloudflare DNSSEC: https://developers.cloudflare.com/dns/dnssec/
- Render custom domains: https://render.com/docs/custom-domains
- Vercel domains: https://vercel.com/docs/domains
- Brevo domain authentication: https://help.brevo.com/hc/en-us/articles/12163873383186-Authenticate-your-domain-with-Brevo-Brevo-code-DKIM-DMARC
- Resend domains: https://resend.com/docs/dashboard/domains/introduction
- Webcentral support: https://support.webcentral.au/

---

**Bottom line:** Keep the domain registration at Webcentral. You can manage DNS there or delegate DNS to Cloudflare. Add Render/Vercel DNS records for hosting and Brevo/Resend DNS records for sending email. No Cloudflare domain purchase or Render migration is required.
