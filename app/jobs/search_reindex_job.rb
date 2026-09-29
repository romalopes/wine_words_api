# Repairs the search vectors of records that index another record's values.
#
# The vectors are built from associations, not just a row's own columns: a
# review indexes its wine, producer, region, grape, country, vintage year and
# author, and an article indexes its tags, category and author. Editing the
# review or the article refreshes it, but renaming a *wine* does not — so
# without this job a rename silently leaves the old name searchable and the new
# one invisible.
#
# The affected rows are resolved by SearchVectorDependent *before* this job is
# enqueued (its ids travel in the payload), which keeps the graph logic next to
# the models that define it and means a destroy cannot take the source away
# before it has been read.
#
# Idempotent and safe to retry: reindexing produces the same vector, and ids for
# rows that no longer exist are simply skipped by the query.
class SearchReindexJob < ApplicationJob
  queue_as :background

  # Only the two searchable models are addressable — the name arrives as a
  # string from a job payload, so it is checked against a whitelist rather than
  # handed to `const_get` unchecked.
  REINDEXABLE = %w[Review Article].freeze

  def perform(model_name, ids)
    return unless REINDEXABLE.include?(model_name)

    ids = Array(ids).compact.uniq
    return if ids.empty?

    Object.const_get(model_name).where(id: ids).reindex_search_vectors!(batch_size: 200)
  end
end
