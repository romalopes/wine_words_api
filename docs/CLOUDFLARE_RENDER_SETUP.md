# Connecting Cloudflare with Render for beachvolleyballhub.com

**Domain:** `beachvolleyballhub.com`  
**Sub‑domains used:**  
- `beachvolleyballhub.com` → Frontend (Cloudflare Workers)  
- `api.beachvolleyballhub.com` → Backend (Render)  
- `wine-words.beachvolleyballhub.com` → Frontend (Cloudflare Workers)  
- `api.wine-words.beachvolleyballhub.com` → Backend (Render)  

**Last updated:** 14 October 2026  

## Prerequisites
- Cloudflare account with the domain `beachvolleyballhub.com` added to your zone.
- Cloudflare Workers already deployed:
  - Frontend 1: `beachvolleyballhub.romalopes.workers.dev`
  - Frontend 2: `wine-words.romalopes.workers.dev`
- Render services running:
  - API 1: `beachvolleyballproject-dev.onrender.com`
  - API 2: `wine-words-api.onrender.com`
- Access to Render dashboard to add custom domains.
## 1. Cloudflare DNS Configuration

In the Cloudflare dashboard for `beachvolleyballhub.com`, go to **DNS → Records** and create the following CNAME records.

| Type | Name | Target (value) | Proxy status | TTL |
|------|------|----------------|--------------|-----|
| CNAME | `@` (or leave blank for apex) | `beachvolleyballhub.romalopes.workers.dev` | **Proxied** (orange cloud) – recommended for Workers | Auto |
| CNAME | `api` | `beachvolleyballproject-dev.onrender.com` | **DNS only** (grey cloud) – required for Render custom domain validation | Auto |
| CNAME | `wine-words` | `wine-words.romalopes.workers.dev` | **Proxied** (orange cloud) | Auto |
| CNAME | `api.wine-words` | `wine-words-api.onrender.com` | **DNS only** (grey cloud) | Auto |

> **Note:**  
> - Keep the TTL set to “Auto” (or a low value like 300 seconds) while testing.  
> - The proxy status must be **DNS only** for the API records because Render validates the CNAME target directly; if you proxy through Cloudflare, Render may not be able to verify the domain.  
> - For the Workers frontends you may enable proxying (orange cloud) to benefit from Cloudflare’s caching and security features; ensure you add the appropriate route in the Workers dashboard (see next section).

## 2. Configure Workers Routes

Cloudflare Workers need a route that tells Workers which incoming hostnames should trigger your script.

1. In the Cloudflare dashboard, go to **Workers → Overview**.  
2. Select your **beachvolleyballhub** worker → **Triggers** → **Add a route**.  
   - Route: `beachvolleyballhub.com/*`  
   - Save.  
3. Repeat for the **wine-words** worker:  
   - Route: `wine-words.beachvolleyballhub.com/*`  

> If you prefer a single worker that handles both frontends, you can add both routes to the same worker and use conditional logic based on the incoming host header.

## 3. Render Custom‑Domain Setup

For each Render service, add the corresponding subdomain as a custom domain.

### API 1 (`beachvolleyballproject-dev.onrender.com`)
1. Open the Render dashboard → select the service → **Settings → Custom Domains**.  
2. Click **Add custom domain**, enter `api.beachvolleyballhub.com`.  
3. Render will show a DNS target (usually the same `.onrender.com` hostname). Verify that the CNAME you created in Cloudflare points to this target.  
4. Click **Save**. Render will provision a TLS certificate for the custom domain (may take a few minutes).

### API 2 (`wine-words-api.onrender.com`)
1. Repeat the same steps for the second service, adding the custom domain `api.wine-words.beachvolleyballhub.com`.  
2. Ensure the CNAME `api.wine-words` points to `wine-words-api.onrender.com`.

> **Important:**  
> - Render requires the custom domain to be added **before** it will serve traffic.  
> - Keep the `.onrender.com` URLs available during rollout for fallback testing.

## 4. SSL/TLS Considerations

- **Cloudflare side:** With the Workers records proxied (orange cloud), Cloudflare will issue a universal SSL certificate for the hostname. Set the **SSL/TLS encryption mode** to **Full (strict)** if your origin (Render) has a valid certificate (Render provides one for custom domains).  
- **Render side:** Once you add a custom domain, Render automatically provisions a Let’s Encrypt certificate. Verify that the certificate is active in the Render dashboard under the service’s **Custom Domains** tab.  
- **End‑to‑end:** For maximum security, use **Full (strict)** in Cloudflare and ensure Render’s certificate is valid. If you encounter certificate errors, temporarily switch to **Flexible** while debugging, but revert to Full (strict) as soon as possible.

## 5. Verification Steps

After DNS propagation (usually a few minutes, but can take up to 24 hours), run the following checks:

```bash
# 1. Verify DNS records
dig +short beachvolleyballhub.com CNAME
dig +short api.beachvolleyballhub.com CNAME
dig +short wine-words.beachvolleyballhub.com CNAME
dig +short api.wine-words.beachvolleyballhub.com CNAME

# 2. Test HTTPS endpoints (should return 200 or appropriate frontend content)
curl -I https://beachvolleyballhub.com
curl -I https://api.beachvolleyballhub.com
curl -I https://wine-words.beachvolleyballhub.com
curl -I https://api.wine-words.beachvolleyballhub.com

# 3. Optional: Test a specific API route (adjust as needed)
curl -i https://api.beachvolleyballhub.com/health
curl -i https://api.wine-words.beachvolleyballhub.com/health
```

Expected outcomes:
- The frontend URLs serve your Worker‑rendered React/Vue/etc. app.
- The API URLs reach your Render Rails (or Node/Python) service; a root request may return 404 (normal) while specific endpoints return JSON.
- No TLS errors, mixed‑content warnings, or CORS blockers when the frontend calls the API.

## 6. Rollback & Troubleshooting

- **Keep the original provider URLs** (`*.workers.dev` and `*.onrender.com`) accessible during rollout.  
- If a custom domain fails, revert the Cloudflare route or DNS record to point directly to the worker subdomain (for frontends) or temporarily remove the custom domain in Render (for APIs).  
- Record the previous DNS values before editing, and allow time for propagation when re‑applying changes.  
- Check Cloudflare’s **Firewall → Events** and Render’s **Logs** for request failures.

## 7. References

- Cloudflare Docs – Managing DNS records: https://developers.cloudflare.com/dns/manage-dns-records/how-to/create-dns-records/  
- Cloudflare Workers – Routes: https://developers.cloudflare.com/workers/platform/triggers/routes/  
- Render Docs – Custom Domains: https://render.com/docs/custom-domains  
- Render + Cloudflare guide: https://render.com/docs/configure-cloudflare-dns  

---

*This guide mirrors the structure of the existing `wine_words_domain_setup.md` but is tailored to the beachvolleyballhub.com domain and its sub‑domains.*
