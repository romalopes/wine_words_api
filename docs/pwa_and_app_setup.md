# PWA & Native App Setup Guide for Wine Words

> This guide assumes a working local dev environment (`npm run dev`, `bin/rails server`) and that the **Rails API** is already deployed to Render (or another host) with a valid domain (e.g., `wine-words-api.onrender.com`).  
> Follow the steps to get the PWA working on any phone and turn the codebase into native Android and iOS apps.

## 1️⃣ Prerequisites

| Item | Why |
|------|-----|
| Node.js ≥ 18 | Build PWA, run Capacitor |
| Ruby ≥ 3.2 | Run Rails API |
| RubyGems (`bundler`, `rails`, `rails db`) | Manage gems |
| PostgreSQL | Rails DB |
| Git | Version control |
| Domain (e.g., `wine-words.beachvolleyballhub.com`) | Required for HTTPS & PWA manifest |
| Google Play Console account ($25 one‑time) | Android publishing |
| Apple Developer Program ($99/yr) | iOS publishing |
| Android Studio (with SDK) | Build Android app |
| Xcode (macOS) | Build iOS app |
| Google Play Console | Android store listing |
| Apple Developer Program | iOS store listing |

## 2️⃣ Backend (Rails API) – Render Setup

1. **Add environment variables** in the Render dashboard → *Environment* → *Add Variable*:

   ```
   DATABASE_URL=postgresql://<user>:<password>@<host>/<db>
   RAILS_MASTER_KEY=…               # contents of config/master.key
   SECRET_KEY_BASE=<64‑byte hex string>
   APP_HOST=wine-words-api.onrender.com
   ALLOWED_HOSTS=wine-prediction-api-mq4a.onrender.com,wine-words-api.onrender.com,api.wine-words.beachvolleyballhub.com,wine-words.romalopes.workers.dev
   FRONTEND_URL=https://wine-words.beachvolleyballhub.com
   MAIL_TRANSPORT=auto
   MAIL_FROM=Wine Words <verified@yourdomain>
   VAPID_PUBLIC_KEY=…                # generated in step 3
   VAPID_PRIVATE_KEY=…               # generated in step 3
   VAPID_SUBJECT=mailto:support@yourdomain
   # (optional) BREVO_API_KEY, STRIPE_*, SOLID_QUEUE_* etc.
   ```

   *Generate keys*  

   ```bash
   bundle exec rails credentials:edit   # set SECRET_KEY_BASE if missing
   bundle exec rails runner "require 'web-push'; puts WebPush.generate_key"
   # copy the two strings printed
   ```

2. **Enable Solid Queue** (Render provides a background worker). Verify it is **Active** in the Render dashboard.

3. **Run migrations** (Render does this automatically on each deploy, but verify locally):

   ```bash
   cd wine_words_api
   bin/rails db:prepare
   ```

4. **Verify the API works** (replace `<host>` with your actual domain):

   ```bash
   curl -i https://<host>/api/v1/health
   # should return 200 OK
   ```
## 3️⃣ Frontend (PWA) – Build & Deploy

1. **Set API base URL** in `.env.development` or CI env:

   ```
   VITE_API_BASE_URL=https://api.wine-words.beachvolleyballhub.com/api/v1
   ```

2. **Build the PWA** (production):

   ```bash
   cd wine_words
   VITE_API_BASE_URL=https://api.wine-words.beachvolleyballhub.com/api/v1 \
   VITE_MOBILE_LAYOUT_ENABLED=true \
   VITE_PWA_ENABLED=true \
   VITE_OFFLINE_ENABLED=true \
   npm run build
   ```

   This creates `dist/` with service worker, manifest, and assets.

3. **Deploy to Cloudflare Workers**:

   ```bash
   npx wrangler@4.149.0 deploy
   ```

## 4️⃣ Native Android App (Capacitor)

1. **Install Android Studio** (includes SDK, emulator, build tools).  
   Download: https://developer.android.com/studio  

2. **Add SDK tools to PATH** (optional):

   ```bash
   export ANDROID_HOME=$HOME/Library/Android/sdk
   export PATH=$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator
   ```

3. **Sync Capacitor project**:

   ```bash
   cd wine_words
   npm run native:sync   # runs `cap copy` and builds web assets
   ```

4. **Open Android project**:

   ```bash
   npx cap open android
   ```

5. **Build debug APK** (quick test):

   - Android Studio: **Build → Build Bundle(s)/APK(s) → Build APK(s)**.
   - Install `app-debug.apk` on device (`adb install` or drag‑and‑drop).

## 5️⃣ Native iOS App (Capacitor)

1. **Install Xcode** from the Mac App Store (requires macOS). Includes iOS SDK and build tools.

2. **Open iOS project**:

   ```bash
   cd wine_words
   npx cap open ios
   ```

3. **Sign the app**:

   - Xcode: select project → **Signing & Capabilities**.
   - Choose your Apple ID / team (requires Apple Developer account).
   - Bundle ID is `com.winewords.app`; match it in App Store Connect.

4. **Test on real device** (free Apple ID limited to 7‑day provisioning):

   - Connect iPhone via USB, select device, press **Run** (⌘R).
   - For longer testing, use TestFlight.

5. **Publish to App Store**:

   1. Enroll in **Apple Developer Program** ($99/yr).
   2. App Store Connect: create app record (bundle ID, screenshots, privacy policy URL).
   3. Xcode: **Product → Archive**, then **Distribute App → App Store Connect**.
   4. Fill metadata, submit for review (24‑48 h).
## 6️⃣ PWA‑Specific Configuration

| File | Purpose | Key Settings |
|------|---------|--------------|
| `wine_words/vite.config.ts` | Vite dev & build config | `server: { host: "0.0.0.0", port: 5173 }`, `proxy: { "/api": { target: "http://127.0.0.1:3000", changeOrigin: true } }` |
| `wine_words/.env.development` | Local dev env | `VITE_API_BASE_URL=http://192.168.1.6:3000/api/v1` (or `http://localhost:3000`) |
| `wine_words/wrangler.jsonc` | Cloudflare Workers config | `preview_services = [{ name = "wine-words", ... }]` |
| `src/manifest.webmanifest` | PWA manifest (generated in `dist/`) | `name`, `short_name`, `icons`, `start_url`, `display: "standalone"`, `theme_color`, `background_color` |
| `src/service-worker.ts` (Workbox) | Service worker & caching | Workbox `precacheAndRoute`, `registerRoute` for `/api/*`, `offlinePage` fallback. |

**Important:** PWA requires **HTTPS**. Render and Cloudflare provide HTTPS automatically.

## 7️⃣ Testing & Validation Checklist

- [ ] API reachable: `curl -I https://api.wine-words.beachvolleyballhub.com/api/v1/health` → `200`.
- [ ] No 403 errors in browser console for `/api/*`.
- [ ] `manifest.webmanifest` loads without syntax errors.
- [ ] Service worker shows **activated** in DevTools → Application → Service Workers.
- [ ] Offline mode works: app shell loads, cached content shows “offline” labels.
- [ ] Android: `adb install app-debug.apk` works; signed AAB uploads to Google Play without errors.
- [ ] iOS: Xcode builds without signing errors; TestFlight or App Store submission succeeds.

## 8️⃣ Cost Summary (first year)

| Item | Approx. Cost |
|------|--------------|
| Google Play Console (one‑time) | **$25** |
| Apple Developer Program (annual) | **$99** |
| Render free tier (API + DB) | **$0** (or $5‑$7/mo for always‑on) |
| Cloudflare Workers (PWA) | **$0** (free tier) |
| Domain renewal | **$10‑$20/yr** |
| Email service (Brevo/Resend) | **$0** (free tier) |
| **Total first‑year cost** | **≈ $124** (plus optional hosting upgrades) |

---

*Happy coding! 🎉*