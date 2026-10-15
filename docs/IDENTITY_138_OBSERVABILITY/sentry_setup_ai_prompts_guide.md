# End-to-End Sentry Setup Guide: React & Ruby on Rails

This guide provides a comprehensive, step-by-step blueprint for configuring **Sentry** across a modern full-stack web application with a **React frontend** and a **Ruby on Rails backend**. 

By the end of this setup, you will have:
- Unhandled error and crash tracking across both client and server.
- Full-stack **Distributed Tracing** to connect client UI events with backend API controllers and database queries.
- Actionable AI prompts to use with tools like Cursor, GitHub Copilot, or ChatGPT to automate configuration and maintenance.

---

## Architecture Overview

```
┌─────────────────────────┐               ┌─────────────────────────┐
│     React Frontend      │               │     Rails Backend       │
│                         │               │                         │
│  Sentry React SDK       │               │  Sentry Ruby / Rails    │
│  - Catches JS Crashes   │               │  - Catches Exceptions   │
│  - Captures Session     │               │  - Logs Slow Queries    │
│    Replays              │               │  - Captures Context     │
└────────────┬────────────┘               └────────────▲────────────┘
             │                                         │
             │   HTTP Request + `sentry-trace` Header  │
             └─────────────────────────────────────────┘
```

---

## Step 1: Project Setup & DSN Configuration

Before writing application code, set up your project environments inside Sentry.

### Steps
1. Log into your [Sentry Dashboard](https://sentry.io/).
2. Create two separate projects:
   - **Frontend:** Select Platform **JavaScript -> React**.
   - **Backend:** Select Platform **Ruby -> Rails**.
3. Retrieve the **DSN (Data Source Name)** URL for each project from **Project Settings > Client Keys (DSN)**.
4. Store these DSNs in your environment variable management system.

#### Example Environment Configuration

**Backend (`.env` or Rails Credentials):**
```bash
SENTRY_DSN=https://your_rails_dsn_key@o0.ingest.sentry.io/0000000
```

**Frontend (`.env.local` / Vite or CRA):**
```bash
# Vite:
VITE_SENTRY_DSN=https://your_react_dsn_key@o0.ingest.sentry.io/0000001

# Create React App:
REACT_APP_SENTRY_DSN=https://your_react_dsn_key@o0.ingest.sentry.io/0000001
```

---

### 🤖 AI Prompt: Environment & Secrets Setup
> *"Help me set up environment variables for a Ruby on Rails API backend and a Vite/React frontend. Ensure Sentry DSNs are securely injected via `.env` files locally and safely referenced without committing raw keys to version control."*

---

## Step 2: Ruby on Rails Backend Integration

Catch server-side exceptions, unhandled API errors, and database query bottlenecks.

### 1. Install Gems
Add the official Sentry gems to your `Gemfile`:

```ruby
gem "sentry-ruby"
gem "sentry-rails"
```

Execute in your terminal:
```bash
bundle install
```

### 2. Create Initializer
Create `config/initializers/sentry.rb`:

```ruby
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Capture 100% of transactions in dev/staging; lower in high-traffic production
  config.traces_sample_rate = Rails.env.production? ? 0.2 : 1.0

  # Filter out predictable or noisy exceptions
  config.excluded_exceptions += [
    'ActionController::RoutingError',
    'ActiveRecord::RecordNotFound'
  ]
end
```

### 3. Verify Integration
Run a quick test in your Rails console:

```bash
rails runner "Sentry.capture_exception(StandardError.new('Rails Sentry Verification Test'))"
```
Check your Sentry backend dashboard to confirm event arrival.

---

### 🤖 AI Prompts: Rails Integration

#### Prompt A: Sensitive Data Scrubbing
> *"Review my Rails `sentry.rb` initializer and write a data scrubber configuration that automatically redacts sensitive parameter keys like `:password`, `:credit_card`, and Authorization bearer tokens before events leave the server."*

#### Prompt B: Custom Error Context
> *"Show me how to use `Sentry.set_user` and `Sentry.set_tags` inside a Rails `before_action` in `ApplicationController` so every logged error includes the current user's ID and account tier."*

---

## Step 3: React Frontend Integration

Capture JavaScript runtime crashes, unhandled promise rejections, and browser render errors.

### 1. Install SDK
Run in your React project directory:

```bash
npm install --save @sentry/react
```

### 2. Initialize Sentry
Initialize Sentry at the earliest entry point of your application (e.g., `src/main.tsx` or `src/index.js`):

```javascript
import React from 'react';
import ReactDOM from 'react-dom/client';
import * as Sentry from "@sentry/react";
import App from './App';

Sentry.init({
  dsn: import.meta.env.VITE_SENTRY_DSN,
  integrations: [
    Sentry.browserTracingIntegration(),
    Sentry.replayIntegration(), // Captures video-like session replays for crashes
  ],
  tracesSampleRate: 1.0,
  replaysSessionSampleRate: 0.1,  # 10% of standard sessions
  replaysOnErrorSampleRate: 1.0,  # 100% of sessions with errors
});

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

### 3. Add Component Error Boundary
Prevent whole-app white screen crashes by wrapping component trees:

```javascript
import * as Sentry from "@sentry/react";

function FallbackComponent({ error, componentStack, resetError }) {
  return (
    <div role="alert">
      <h2>Something went wrong.</h2>
      <p>Our team has been notified.</p>
      <button onClick={resetError}>Try again</button>
    </div>
  );
}

export default function Root() {
  return (
    <Sentry.ErrorBoundary fallback={FallbackComponent} showDialog>
      <App />
    </Sentry.ErrorBoundary>
  );
}
```

---

### 🤖 AI Prompts: React Integration

#### Prompt A: Error Boundary Setup
> *"Show me how to integrate Sentry's `ErrorBoundary` with React Router v6 so that page navigation failures display a clean fallback UI while capturing full stack traces and router context in Sentry."*

#### Prompt B: User Context Injection
> *"How do I call `Sentry.setUser()` in my React AuthContext upon user login and clear it upon logout so frontend error reports are mapped to specific users?"*

---

## Step 4: Distributed Tracing (Linking Frontend to Backend)

Distributed tracing connects client actions directly to server API performance under a single **Trace ID**.

### 1. Configure Trace Propagation
Update `tracePropagationTargets` in your React frontend `Sentry.init`:

```javascript
Sentry.init({
  dsn: import.meta.env.VITE_SENTRY_DSN,
  integrations: [Sentry.browserTracingIntegration()],
  tracesSampleRate: 1.0,
  
  // Send sentry-trace headers to local dev server and production API endpoints
  tracePropagationTargets: [
    "localhost",
    /^https:\/\/api\.yourdomain\.com\/api/
  ],
});
```

### 2. Verify Headers
When your React app makes an HTTP request via `fetch` or `axios`, Sentry automatically attaches two HTTP headers:
- `sentry-trace`
- `baggage`

Rails reads these headers automatically via `sentry-rails` and groups both performance transactions under a unified timeline.

---

### 🤖 AI Prompt: Distributed Tracing & CORS
> *"I've enabled `tracePropagationTargets` in Sentry React. Check my Rails Rack CORS configuration to make sure headers like `sentry-trace` and `baggage` are explicitly allowed in cross-origin preflight requests."*

---

## Step 5: Testing & Verification Checklist

| Target | Test Action | Expected Result |
| :--- | :--- | :--- |
| **Rails Exception** | Run `Sentry.capture_exception(...)` in `rails console`. | Issue appears in Rails Sentry project dashboard within 10 seconds. |
| **React Exception** | Trigger an intentionally thrown error in a `useEffect` hook. | Issue appears in React Sentry project with component stack trace. |
| **Tracing** | Perform an API request from React UI that queries Rails. | Trace view in Sentry shows combined browser timeline + Rails request duration + SQL queries. |

---

## Useful Maintenance Prompts for AI Coding Assistants

#### Prompt 1: Filtering Noise
> *"Analyze my Sentry issue log summary below and suggest rules for `before_send` in both React and Rails to filter out third-party browser extension errors and crawler bot requests."*

#### Prompt 2: Source Maps Configuration
> *"Generate a step-by-step CI/CD pipeline script using GitHub Actions that uploads unminified JavaScript source maps to Sentry during React app build time so stack traces show readable code."*