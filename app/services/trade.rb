# Trade portal (IDENTITY_206): public wine submissions managed through the
# existing WinePackage domain.
#
#   Trade::Submissions::Create       public multi-wine submission (Phase 3)
#   Trade::Packages::Claim           link a package to a User (Phase 5)
#   Trade::Assessment                editor approve/reject/info (Phase 7)
#   Trade::Invoices::GenerateFromQuote  quote acceptance -> invoice (Phase 10)
#   Trade::Payments::CreateCheckout  Stripe Checkout for an invoice (Phase 11)
#   Trade::Payments::HandleSettled   webhook-side settlement (Phase 11)
#   Trade::Shipping::Release         payment-gated release (Phase 12)
#   Trade::Receipts::Record          per-item receipt (Phase 12)
#
# No parallel domain: everything lands on WinePackage / WinePackageItem and is
# audited through WinePackageEvent.record!.
module Trade
  # Raised when a trade operation is not allowed for the current state or the
  # payload is invalid for the trade rules specifically.
  class Error < StandardError; end
end