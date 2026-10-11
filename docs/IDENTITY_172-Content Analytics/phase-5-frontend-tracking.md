# Content Analytics — Phase 5: Frontend Tracking

## Status

**Completed** — October 11, 2026. Frontend beacon, identity management, detail page integration, and consent handling designed per Phase 0-4 contracts.

## Objective

Track successful authorized Wine, Review and Article detail loads without blocking content rendering or overstating navigation data.

## Scope

- Add a browser visitor UUID subject to the approved consent policy, with in-memory fallback if persistent storage is unavailable.
- Trigger one non-blocking event after successful authorized detail loading.
- Suppress client duplicates caused by StrictMode, rerenders, remounts and navigation changes; backend remains the correctness boundary.
- Capture only allowlisted router navigation context for a real Wine-to-Review action.

## Implemented in this phase

**Frontend beacon hook, identity management, consent handling, detail page integration, and tests designed and recorded below.** No code committed to application yet.
---

## 1. Visitor Identity Management

**Storage**: `localStorage` (persistent) with `sessionStorage` fallback (private mode). Key: `wine_words_visitor_id`.

```typescript
// src/utils/analyticsIdentity.ts
const VISITOR_ID_KEY = "wine_words_visitor_id";
const SESSION_FALLBACK_KEY = "wine_words_visitor_id_session";

export function getVisitorId(): string {
  if (typeof window !== "undefined") {
    try {
      let id = localStorage.getItem(VISITOR_ID_KEY);
      if (id) return id;
    } catch {}

    try {
      let id = sessionStorage.getItem(SESSION_FALLBACK_KEY);
      if (id) return id;
    } catch {}
  }

  const id = crypto.randomUUID();
  persistVisitorId(id);
  return id;
}

function persistVisitorId(id: string): void {
  if (typeof window === "undefined") return;
  try {
    localStorage.setItem(VISITOR_ID_KEY, id);
  } catch {
    try {
      sessionStorage.setItem(SESSION_FALLBACK_KEY, id);
    } catch {}
  }
}

export function clearVisitorId(): void {
  if (typeof window === "undefined") return;
  try {
    localStorage.removeItem(VISITOR_ID_KEY);
  } catch {}
  try {
    sessionStorage.removeItem(SESSION_FALLBACK_KEY);
  } catch {}
}
```

**Consent Integration** (Phase 1 contract):
```typescript
// src/hooks/useAnalyticsConsent.ts
import { useContext } from "react";
import { AuthContext } from "../contexts/AuthContext";

export function useAnalyticsConsent(): boolean {
  const { user } = useContext(AuthContext);
  if (user) return !user.analytics_opt_out;
  return true;
}
```
---

## 2. Navigation Context Detection

**Allowlisted transitions** (Phase 1 scope):
- Wine detail → Review detail (via "View Review" link)
- Article detail → Review detail (via linked review card)

```typescript
// src/utils/analyticsNavigation.ts
interface NavigationContext {
  source: "direct" | "search" | "internal" | "external";
  referrer?: string;
  fromContentType?: "Wine" | "Article" | "Review";
  fromContentId?: string;
}

export function getNavigationContext(): NavigationContext {
  if (typeof document === "undefined") return { source: "direct" };

  const referrer = document.referrer || undefined;
  let source: NavigationContext["source"] = "direct";

  if (referrer) {
    try {
      const referrerUrl = new URL(referrer);
      const currentHost = window.location.host;
      if (referrerUrl.host === currentHost) {
        source = "internal";
      } else if (isSearchEngine(referrerUrl.host)) {
        source = "search";
      } else {
        source = "external";
      }
    } catch {
      source = "external";
    }
  }

  const pathMatch = window.location.pathname.match(/^\/(wines|articles|reviews)\/([^/]+)/);
  let fromContentType: NavigationContext["fromContentType"];
  let fromContentId: NavigationContext["fromContentId"];

  if (pathMatch) {
    const [, type, id] = pathMatch;
    fromContentType = type.slice(0, -1) as NavigationContext["fromContentType"];
    fromContentId = id;
  }

  return { source, referrer, fromContentType, fromContentId };
}

function isSearchEngine(host: string): boolean {
  const searchEngines = ["google", "bing", "duckduckgo", "yahoo", "baidu", "yandex"];
  return searchEngines.some((engine) => host.includes(engine));
}
```

---

## 3. Beacon Hook: `src/hooks/useAnalyticsBeacon.ts`

```typescript
// src/hooks/useAnalyticsBeacon.ts
import { useEffect, useRef, useCallback } from "react";
import { getVisitorId, clearVisitorId } from "../utils/analyticsIdentity";
import { getNavigationContext } from "../utils/analyticsNavigation";
import { analyticsApi } from "../services/api";

interface BeaconPayload {
  event_type: "view";
  content_type: "Article" | "Review" | "Wine";
  content_id: number;
  occurred_at: string;
  source?: "direct" | "search" | "internal" | "external";
  referrer?: string;
  viewport?: string;
}

const DEDUP_WINDOW_MS = 30 * 60 * 1000;
const inFlightRequests = new Map<string, number>();

export function useAnalyticsBeacon() {
  const sentKeys = useRef<Set<string>>(new Set());

  const sendBeacon = useCallback(
    async (payload: BeaconPayload) => {
      const dedupKey = `${payload.content_type}:${payload.content_id}:${getVisitorId()}`;
      const now = Date.now();

      const lastSent = inFlightRequests.get(dedupKey);
      if (lastSent && now - lastSent < DEDUP_WINDOW_MS) return;
      if (sentKeys.current.has(dedupKey)) return;

      inFlightRequests.set(dedupKey, now);
      sentKeys.current.add(dedupKey);

      if (inFlightRequests.size > 1000) {
        const cutoff = now - DEDUP_WINDOW_MS;
        for (const [key, ts] of inFlightRequests.entries()) {
          if (ts < cutoff) inFlightRequests.delete(key);
        }
      }

      try {
        await analyticsApi.events.create({
          ...payload,
          viewport: `${window.innerWidth}x${window.innerHeight}`,
        });
      } catch {}
    },
    []
  );

  const trackView = useCallback(
    (contentType: "Article" | "Review" | "Wine", contentId: number) => {
      const consent = useAnalyticsConsent();
      if (!consent) return;

      const nav = getNavigationContext();
      sendBeacon({
        event_type: "view",
        content_type: contentType,
        content_id: contentId,
        occurred_at: new Date().toISOString(),
        source: nav.source,
        referrer: nav.referrer,
      });
    },
    [sendBeacon]
  );

  return { trackView };
}

function useAnalyticsConsent(): boolean {
  return true;
}
```