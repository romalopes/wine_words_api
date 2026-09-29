# frozen_string_literal: true

# Search-index maintenance.
#
# The `searchable` tsvector columns are filled by a `before_save` callback, so
# only rows written through the model are indexed. Anything else needs an
# explicit rebuild:
#
#   * rows that existed before the column did (the 2026-09-28 migrations added
#     it with no backfill, which left every pre-existing row unsearchable);
#   * rows written by a bulk import or `update_all`;
#   * rows whose *indexed associations* changed — a renamed producer, wine,
#     region or grape, a re-tagged article. Those are covered by
#     SearchReindexJob, but this task is the backstop.
#
# Usage:
#   bin/rails search:status                   # how much of each table is indexed
#   bin/rails search:reindex                  # rebuild every review and article
#   bin/rails search:reindex MODEL=reviews    # one model only
#   bin/rails search:reindex BATCH_SIZE=100   # smaller batches for big tables
#
# Idempotent: re-running produces identical vectors and touches no timestamps.
namespace :search do
  desc "Report how many reviews and articles have a search vector"
  task status: :environment do
    search_model_names.each do |name|
      status = Object.const_get(name).search_vector_status
      puts format(
        "%-9s total=%-6d indexed=%-6d missing=%d",
        name.downcase + "s", status[:total], status[:indexed], status[:missing]
      )
    end
  end

  desc "Rebuild the searchable tsvector of every review and article"
  task reindex: :environment do
    batch_size = (ENV["BATCH_SIZE"].presence || 500).to_i
    batch_size = 500 if batch_size <= 0

    selected = search_model_names
    if ENV["MODEL"].present?
      requested = ENV["MODEL"].downcase
      selected = selected.select { |name| name.downcase + "s" == requested || name.downcase == requested }
      if selected.empty?
        abort "Unknown MODEL=#{ENV['MODEL']} (expected: #{search_model_names.map { |n| n.downcase + 's' }.join(', ')})"
      end
    end

    selected.each do |name|
      model = Object.const_get(name)
      status = model.search_vector_status
      puts "#{name}: #{status[:missing]} of #{status[:total]} rows missing a vector"

      started = Time.current
      count = model.reindex_search_vectors!(batch_size: batch_size) do |done|
        # Progress on long tables: one line per batch keeps CI logs readable.
        puts "  … #{done}/#{status[:total]}"
      end
      puts "#{name}: reindexed #{count} rows in #{(Time.current - started).round(1)}s"

      after = model.search_vector_status
      raise "#{name} still has #{after[:missing]} unindexed rows" unless after[:missing].zero?
    end

    puts "✅ Search index rebuilt."
  end
end

# Resolved lazily inside the tasks: a rake file is loaded before the
# `:environment` task, so naming the models here would autoload them during
# boot.
def search_model_names
  %w[Review Article]
end
