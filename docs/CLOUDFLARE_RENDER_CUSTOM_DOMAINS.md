# Cloudflare + Render custom domain setup

Updated: 2026-10-14

## Architecture

| Project | Public URL | Origin/service |
|---|---|---|
| BeachVolleyballHub frontend | https://beachvolleyballhub.com | Cloudflare Worker `beachvolleyballhub` (`beachvolleyballhub.romalopes.workers.dev`) |
| BeachVolleyballHub Rails API | https://api.beachvolleyballhub.com | Render `beachvolleyballproject-dev.onrender.com` |
| Wine Words frontend | https://wine-words.beachvolleyballhub.com | Cloudflare Worker `wine-words` (`wine-words.romalopes.workers.dev`) |
| Wine Words Rails API | https://api.wine-words.beachvolleyballhub.com | Render `wine-words-api.onrender.com` |

The registered domain is **beachvolleyballhub.com** (not beachvolleybalhub.com). Keep both original service URLs functional until all integrations are migrated.

## Phase 1: Activate Cloudflare DNS

1. Open https://dash.cloudflare.com and choose `beachvolleyballhub.com`.
2. If it is not already an **Active** zone, add it and select the Free plan.
3. Review imported DNS records. Preserve any existing email MX/TXT records.
4. At the domain registrar, replace nameservers with the two assigned by Cloudflare.
5. Wait for Active status. Avoid creating duplicate DNS records.

## Phase 2: Attach frontend custom domains

Cloudflare dashboard → Workers & Pages → select Worker → Settings → Domains & Routes → Add → Custom Domain (the UI may show a Domains tab).

- Worker `beachvolleyballhub`: add `beachvolleyballhub.com`.
- Worker `wine-words`: add `wine-words.beachvolleyballhub.com`.

Cloudflare creates DNS records and TLS certificates automatically. **Do not manually CNAME these hosts to `workers.dev`**. Resolve any existing conflicting DNS records first. Test both HTTPS frontend URLs.

Optional: add `www.beachvolleyballhub.com` to the Worker and set a canonical redirect to the apex domain.

## Phase 3: Attach Render API custom domains

In https://dashboard.render.com, open each web service → Settings → Custom Domains → Add Custom Domain:

- BeachVolleyballHub API: `api.beachvolleyballhub.com`
- Wine Words API: `api.wine-words.beachvolleyballhub.com`

Then Cloudflare → beachvolleyballhub.com → DNS → Records → Add record:

| Type | Name | Target | Proxy | TTL |
|---|---|---|---|---|
| CNAME | `api` | `beachvolleyballproject-dev.onrender.com` | DNS only (grey cloud) | Auto |
| CNAME | `api.wine-words` | `wine-words-api.onrender.com` | DNS only (grey cloud) | Auto |

Return to each Render service and click Verify. Wait for Render's TLS certificate to become valid. DNS-only is recommended during verification; leave it DNS-only initially for easier troubleshooting. Do not add wildcard DNS records or point the apex domain at Render.

## Phase 4: Update frontend production configuration

Use the *actual* variable names used by the frontend code; these are examples:

BeachVolleyballHub:
```env
VITE_API_URL=https://api.beachvolleyballhub.com
```
Wine Words:
```env
VITE_API_URL=https://api.wine-words.beachvolleyballhub.com
```

Update each Worker's frontend build/deployment configuration and **rebuild/redeploy**: Vite typically embeds environment values at build time. Preserve separate local/development values and avoid committing secrets. Search for old `onrender.com` API URLs hardcoded in frontend source.

## Phase 5: Update Rails CORS and hosts

Edit `config/initializers/cors.rb` in each Rails API, **merging** the new origins with existing development and preview origins rather than replacing configuration blindly.

BeachVolleyballHub allowed production origin:
```ruby
"https://beachvolleyballhub.com"
```
Optional if configured: `https://www.beachvolleyballhub.com`. Keep the existing Worker hostname during migration.

Wine Words allowed production origin:
```ruby
"https://wine-words.beachvolleyballhub.com"
```
Keep the existing Worker hostname during migration.

Example Rack::Cors allow block (merge with current rules):
```ruby
allow do
  origins "https://wine-words.beachvolleyballhub.com", "https://wine-words.romalopes.workers.dev"
  resource "*", headers: :any,
    methods: %i[get post put patch delete options], credentials: true
end
```

Use `credentials: true` only if browser credentialed requests need it. Do not use `*` for origins with credentials. If Rails `config.hosts` is restrictive, add the new **API** hostname for each application. Redeploy the APIs after changes.

## Phase 6: Update external integrations

- Google OAuth: add frontend URLs to Authorized JavaScript origins; add exact callback URLs where required.
- Authentication: verify cookies (`Secure`, `SameSite`), CSRF handling and allowed redirects.
- Email delivery: update links for invitations, confirmation and password resets, and any frontend base URL environment variable.
- Stripe: inspect checkout success/cancel URLs and webhook URLs (change only those actually using old domains).
- Cloudflare R2 / Active Storage: test uploads and generated object URLs; update bucket CORS only if browser requests require it.
- Monitoring and analytics: update allowed domains and callback URLs where necessary.

## Phase 7: Validation and troubleshooting

```bash
# DNS lookup (the Cloudflare Worker custom domains may return Cloudflare IPs)
dig +short beachvolleyballhub.com
dig +short wine-words.beachvolleyballhub.com
dig +short api.beachvolleyballhub.com CNAME
dig +short api.wine-words.beachvolleyballhub.com CNAME

# HTTP checks; /up assumes Rails health route exists
curl -I https://beachvolleyballhub.com
curl -I https://wine-words.beachvolleyballhub.com
curl -i https://api.beachvolleyballhub.com/up
curl -i https://api.wine-words.beachvolleyballhub.com/up

# CORS preflight example (adjust method/path to a real endpoint)
curl -i -X OPTIONS 'https://api.wine-words.beachvolleyballhub.com/articles' \
  -H 'Origin: https://wine-words.beachvolleyballhub.com' \
  -H 'Access-Control-Request-Method: GET'
```

Check browser DevTools Network and Console for CORS and mixed-content failures. Test SPA deep-link refresh, login/logout, OAuth, email flows, authenticated endpoints and image uploads. If Render verification fails, confirm the CNAME is DNS-only and has propagated. If an API gives 502, check Render logs and service health. Do not disable the old hostnames before successful validation.

## Official references

- Cloudflare Workers custom domains: https://developers.cloudflare.com/workers/configuration/routing/custom-domains/
- Render custom domains: https://render.com/docs/custom-domains
- Render with Cloudflare DNS: https://render.com/docs/configure-cloudflare-dns
