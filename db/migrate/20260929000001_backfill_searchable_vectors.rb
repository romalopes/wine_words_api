# Repairs the search index for rows that predate the `searchable` columns.
#
# 20260928000001/2 added the tsvector columns and their GIN indexes but had
# nothing to put in them: the `before_save` callback only fills a vector for
# rows written *after* that deploy, so every pre-existing review and article was
# left NULL. A NULL tsvector satisfies no `@@` match, so `?query=` returned an
# empty list for data that was sitting right there — search looked broken while
# the code was fine.
#
# Batched through the model — i.e. through the same expression the callback uses
# — rather than a hand-written UPDATE, so there is no second copy of the vector
# definition to drift away from the first.
#
# The `respond_to?` guard exists because migrations get replayed: a fresh
# `db:setup` runs this file long after the model may have changed, and a repair
# that cannot run must say so instead of crashing the deploy. The durable,
# re-runnable repair path is `bin/rails search:reindex`.
class BackfillSearchableVectors < ActiveRecord::Migration[7.0]
  def up
    [Review, Article].each do |model|
      unless model.respond_to?(:reindex_search_vectors!)
        say "#{model.name} no longer exposes reindex_search_vectors!; skipping (run `bin/rails search:reindex`)"
        next
      end

      status = model.search_vector_status
      if status[:missing].zero?
        say "#{model.name}: all #{status[:total]} rows already indexed"
        next
      end

      # One transaction per model (migrations are transactional): acceptable
      # because the repair is bounded by these two tables, and a half-indexed
      # table is worse than a slow migration.
      say_with_time("Reindexing #{status[:missing]} of #{status[:total]} #{model.table_name} rows") do
        model.reindex_search_vectors!(batch_size: 500)
      end
    end
  end

  def down
    # Data repair — there is nothing to undo. Re-running `up` is idempotent.
  end
end
