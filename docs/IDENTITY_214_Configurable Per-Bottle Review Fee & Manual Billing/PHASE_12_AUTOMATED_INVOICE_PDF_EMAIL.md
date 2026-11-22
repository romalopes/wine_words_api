# Phase 12 — Automated Invoice PDF Generation & Email Sending
**Status:** ✅ Implemented (Core)
**Date:** 2026-11-22
**Depends on:** Phase 5 (Staff API), Phase 6 (Admin UI)

---

## 1. Objective

Extend the manual billing workflow with **optional automation**:
- Generate professional PDF invoices on demand (Prawn, pure Ruby)
- Email PDF to package owner with branded template (Solid Queue background job)
- Allow staff to trigger send at any time (not just on approval)
- Track send status and automatically derive overdue state

---

## 2. Implementation Summary

### Backend Changes

| File | Purpose |
|------|---------|
| `Gemfile` | Added `prawn` and `matrix` gems |
| `db/migrate/20261122043944_add_email_tracking_to_wine_package_invoices.rb` | Email tracking columns |
| `app/services/wine_packages/invoice_pdf_service.rb` | Prawn-based PDF generator |
| `app/mailers/invoice_mailer.rb` | Invoice email with PDF attachment |
| `app/views/invoice_mailer/invoice_email.html.erb` | HTML email template |
| `app/views/invoice_mailer/invoice_email.text.erb` | Text email template |
| `app/jobs/invoice_mailer_job.rb` | Solid Queue background job |
| `app/controllers/api/v1/wine_package_invoices_controller.rb` | New PDF/email endpoints |
| `app/services/wine_packages/billing_summary.rb` | Email tracking + overdue |
| `app/models/app_setting.rb` | Added `invoice_gst_rate` config |
| `app/controllers/api/v1/configurations_controller.rb` | Admin GST rate config |

### New API Endpoints

| Endpoint | Method | Permission | Purpose |
|----------|--------|------------|---------|
| `/api/v1/wine_packages/:id/invoices/:iid/pdf` | GET | `view_billing?` | Download PDF |
| `/api/v1/wine_packages/:id/invoices/:iid/generate_pdf` | POST | `manage_billing?` | Preview PDF |
| `/api/v1/wine_packages/:id/invoices/:iid/send_email` | POST | `manage_billing?` | Queue email |

### Invoice Serialization Updates

Added fields to invoice JSON:
```json
{
  "email_sent_at": "2026-11-22T10:30:00Z",
  "email_send_count": 1,
  "reminder_sent_at": null,
  "overdue": true
}
```

### Configuration

Added `invoice_gst_rate` to AppSetting:
- Default: `0.10` (10% GST for Australia)
- Admin editable via `GET/PATCH /api/v1/configuration`
- Validated: non-negative, max 4 decimal places

Added `invoice_from_email` to AppSetting:
- Sender address used by `InvoiceMailer` (replaces the hard-coded
  `billing@winewords.com`)
- Default: `INVOICE_FROM_EMAIL` env var if set, else `billing@winewords.com`
- Admin editable via `GET/PATCH /api/v1/configuration`
- Validated: must be a single, plausible email address (blank rejected);
  a blank stored value self-heals back to the default

### Database Migration

Added columns to `wine_package_invoices`:
- `email_sent_at` (datetime)
- `email_send_count` (integer, default 0)
- `reminder_sent_at` (datetime)
- Index on `email_sent_at`
---

## 3. Trigger Points for Invoice Sending

| Trigger | When | Who Initiates |
|---------|------|---------------|
| **On billable confirmation** | After staff confirms billable count | Staff clicks "Confirm & Send Invoice" |
| **On invoice recording** | After staff records external invoice | Staff clicks "Generate & Send PDF" |
| **Manual anytime** | Any time after invoice exists (sent/draft) | Staff clicks "Resend Invoice" |
| **Reminder** | Before/after due date | Future: automated job |

**Default:** Manual trigger only. No automatic sending on package approval unless staff explicitly chooses it.

---

## 4. PDF Invoice Generation

### Library
**Prawn** — pure Ruby, no dependencies, fast, fits Rails 8 + Solid Queue.

### Template Features
- Wine Words logo (top-left, 72 pt, embedded PNG) + wordmark beside it
- Wine Words branding (maroon/teal gradient header)
- Invoice meta (number, date, due date, status)
- Bill-to section from contact_snapshot / producer / user
- Line item: "Wine Review Fee (per bottle)" × billable count
- Totals: Subtotal, GST (configurable rate), Total
- Payment instructions (bank transfer details)
- Footer: package reference, payment terms, company details

### Logo Asset
The "wine words" wordmark (`wine_words/public/wine_words.jpg`, 240×80 banner)
is copied into the API at `app/assets/images/wine_words_logo.jpg` and embedded
by `InvoicePdfService#draw_header` at 150 pt wide (≈50 pt tall, preserving the
3:1 ratio) as the primary header branding, with the tagline rendered beneath
it. Note: the frontend source file is a **WebP with a `.jpg` extension** —
Prawn cannot embed WebP, so the asset was converted to a true JPEG via `sips`.
The wordmark already contains the brand name, so the separate "WINE WORDS"
text line is omitted when the logo is present; if the asset file is missing
the service falls back to the text-only wordmark, so PDF generation can never
fail on packaging. Regression spec: the streamed PDF must contain an image
XObject (`/Subtype /Image`).

### Data Sources
| Field | Source |
|-------|--------|
| Invoice number, dates, totals | `wine_package_invoices` |
| Billable count, unit fee | `wine_package_invoices` (snapshot) |
| Package owner contact | `wine_package.contact_snapshot` or linked user |
| Package reference | `wine_package.id` |

---

## 5. Email Sending

### Email Template
**Subject:** `Wine Words Invoice #WW-2026-0042 — Review of 5 bottles (AUD 275.00)`

**Body:** HTML + Text versions with invoice summary and payment instructions.

### Delivery Mechanism
- **Background job:** `InvoiceMailerJob` (Solid Queue)
- **Attachment:** PDF generated on-the-fly, attached as `invoice-WW-2026-0042.pdf`
- **Tracking:** Record `email_sent_at` on invoice, emit `invoice_emailed` event
- **Retry:** Standard Solid Queue retry (exponential backoff)

---

## 6. Invoice Status & Overdue Logic

### Derived Overdue (Automatic Display)
| Condition | Display Status |
|-----------|----------------|
| `status == sent` AND `due_at < now` AND `!paid?` | **Overdue** (red badge) |
| `status == sent` AND `due_at >= now` | **Pending** (yellow badge) |
| `status == paid` | **Paid** (green badge) |
| `status == cancelled` | **Cancelled/Waived** (gray badge) |
| `status == draft` | **Draft** (muted badge) |

**No automatic status transition** — overdue is purely a display derivation. Staff still manually marks paid/cancelled.

---

## 7. UI Integration (Pending Phase 6)

### Admin UI (`TradeAdminPackageDetail.tsx`)
- "Download PDF" button per invoice
- "Email Invoice" button → triggers send, shows toast
- Status badge shows derived overdue (red "Overdue — 5 days")
- Send history shows `email_sent_at`, `send_count`, `reminder_sent_at`

### Owner View (`TradePackageDetail.tsx`)
- "Download Invoice" button (PDF)
- Status badge with derived overdue
- No send buttons

---

## 8. Tests

| Test Suite | Result |
|------------|--------|
| `spec/requests/api/v1/configurations_spec.rb` | ✅ 25 examples, 0 failures |
| `spec/requests/api/v1/trade_spec.rb` | ✅ 34 examples, 0 failures |
| `spec/requests/api/v1/trade/pricing_spec.rb` | ✅ 2 examples, 0 failures |
| `spec/models/wine_package_spec.rb` | ✅ 72 examples, 0 failures |

**Total:** 133 examples, 0 failures

---

## 9. Files Changed

| File | Change Type |
|------|-------------|
| `Gemfile` | Added `prawn`, `matrix` |
| `db/migrate/20261122043944_add_email_tracking_to_wine_package_invoices.rb` | New migration |
| `app/services/wine_packages/invoice_pdf_service.rb` | New PDF service |
| `app/mailers/invoice_mailer.rb` | New mailer |
| `app/views/invoice_mailer/invoice_email.html.erb` | HTML email template |
| `app/views/invoice_mailer/invoice_email.text.erb` | Text email template |
| `app/jobs/invoice_mailer_job.rb` | New background job |
| `app/controllers/api/v1/wine_package_invoices_controller.rb` | Added PDF/email endpoints |
| `app/services/wine_packages/billing_summary.rb` | Added email tracking + overdue |
| `app/models/app_setting.rb` | Added `invoice_gst_rate` |
| `app/controllers/api/v1/configurations_controller.rb` | Admin GST rate config |
| `spec/requests/api/v1/configurations_spec.rb` | Added GST rate tests |

---

## 10. Phase Status Update

| Phase | Status |
|-------|--------|
| 0 | ✅ Completed |
| 1 | ✅ Completed |
| 2 | ✅ Completed |
| 3 | ✅ Completed |
| 4 | ✅ Completed |
| 5 | ✅ Completed (Core) |
| 6 | ⏳ Pending |
| 7 | ⏳ Pending |
| 8 | ⏳ Pending |
| 9 | ⏳ Pending |
| 10 | ⏳ Pending |
| 11 | ⏳ Pending |
| **12** | ✅ **Implemented (Core)** |

---

## 11. Remaining Work (Phase 6 UI)

- [ ] Admin UI: `TradeAdminPackageDetail.tsx` billing panel with PDF/Email buttons
- [ ] Admin UI: Status badges with derived overdue
- [ ] Admin UI: Send history display
- [ ] Owner UI: `TradePackageDetail.tsx` download button
- [ ] Request specs for new PDF/email endpoints
- [ ] Phase 12b: Overdue reminder job
- [ ] Phase 12c: Auto-send on record (configurable)