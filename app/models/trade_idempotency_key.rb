# Trade idempotency key (IDENTITY_206 Phase 3): maps a client-supplied
# idempotency key to the WinePackage created by the first submission, so
# retries return the original package instead of duplicating it.
#
# Only the SHA-256 digest of the key is stored — the raw key is client state
# and never needs to be read back.
class TradeIdempotencyKey < ApplicationRecord
  belongs_to :wine_package
end
