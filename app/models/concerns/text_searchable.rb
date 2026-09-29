# Full-text search for models that keep a weighted `searchable` tsvector
# column (Review, Article), so both listings search and rank identically.
#
# The HTTP API keeps a single `query` parameter: the same term both filters the
# scope (`searchable @@ to_tsquery(…)`) and scores it (`ts_rank_cd`, exposed as
# a `rank` column) so results can be ordered by relevance.
#
# An including model must define SORT_ORDERS: the whitelist of accepted `sort`
# values mapped to lambdas that receive the column qualifier and the rank
# expression. One whitelist therefore drives both the flat feed (`reviews.`
# columns) and the grouped window function (`r.` subquery alias).
module TextSearchable
  extend ActiveSupport::Concern

  # Free-text search only runs from this many characters, mirroring
  # MIN_SEARCH_LENGTH on the frontend: shorter input is too broad to be useful,
  # would fire a request on every keystroke, and matches almost the whole table.
  MIN_TERM_LENGTH = 3

  DEFAULT_SORT = "relevance"

  # Relevance is meaningless without a term to rank against, so it degrades to
  # this sort rather than ordering by a `rank` column that was never selected.
  UNRANKED_FALLBACK_SORT = "recent"

  class << self
    # Build a tsquery string from raw user input, or nil when the term is not
    # searchable (blank, or only punctuation / short words).
    #
    # Every remaining word becomes a prefix match and the words are ANDed
    # together, which is what the product spec asks for: `barossa shiraz`
    # requires both words (in any field, thanks to the weighted vector) while
    # `char` still finds Chardonnay, Charles and Charbono.
    #
    # Stripping everything that is not alphanumeric is also what makes the
    # input safe: `to_tsquery` parses its argument and raises a syntax error on
    # stray operators, so an unsanitised term from a plain text box would be a
    # 500 rather than an empty result set.
    def build_tsquery(term)
      words = term.to_s
                  .unicode_normalize(:nfc)
                  .downcase
                  .split(/[^[:alnum:]]+/)
                  .reject { |word| word.length < MIN_TERM_LENGTH }
      return nil if words.empty?

      words.map { |word| "#{word}:*" }.join(" & ")
    end
  end

  class_methods do
    # Rebuild the tsvector of every row from its current column and association
    # values.
    #
    # This is the repair path for a vector that is missing or stale: rows that
    # existed before the `searchable` column was added, rows written by an
    # import that skipped callbacks, or rows whose indexed associations changed
    # (a renamed wine, a re-tagged article). Without it, `text_search` silently
    # matches nothing, because a NULL tsvector never satisfies `@@`.
    #
    # Batched, and it reuses each record's own `search_vector_sql`, so there is
    # no second copy of the vector definition to drift out of step. Returns the
    # number of rows reindexed.
    def reindex_search_vectors!(batch_size: 500)
      reindexed = 0
      in_batches(of: batch_size) do |batch|
        batch.each do |record|
          record.refresh_search_vector!
          reindexed += 1
        end
        yield reindexed if block_given?
      end
      reindexed
    end

    # How much of this table is actually searchable. `missing` is the number of
    # rows a search can never return, which is the number an index repair would
    # fix (see Api::V1::HealthController#search_index).
    def search_vector_status
      total = count
      missing = where(searchable: nil).count
      { total: total, indexed: total - missing, missing: missing }
    end

    # The tsquery a term would be searched with, or nil when it is not
    # searchable. Callers use this to know whether a `rank` column exists.
    def searchable_term(term)
      TextSearchable.build_tsquery(term)
    end

    # Restrict the scope to rows matching `term` and expose their relevance
    # score as `rank`. A term that is not searchable leaves the scope untouched,
    # so a stray keystroke shows the normal listing instead of an empty page.
    def text_search(term)
      tsquery = searchable_term(term)
      return all if tsquery.nil?

      where("#{table_name}.searchable @@ to_tsquery('english', ?)", tsquery)
        .select(
          "#{table_name}.*, ts_rank_cd(#{table_name}.searchable, " \
          "to_tsquery('english', #{connection.quote(tsquery)})) AS rank"
        )
    end

    # Whitelisted `sort` values, declared by the including model.
    def sort_orders
      const_get(:SORT_ORDERS)
    end

    # SQL ORDER BY fragment for a requested sort. Values outside the whitelist
    # fall back to the default and relevance degrades when there is no rank, so
    # the request parameter is never interpolated into the statement.
    #
    # `columns` qualifies the physical columns (the table name in a normal
    # query, the subquery alias inside the grouped window function); `rank` is
    # the relevance expression, which is a SELECT alias rather than a column.
    def search_order_sql(sort, ranked: true, columns: "#{table_name}.", rank: "rank")
      key = sort_orders.key?(sort.to_s) ? sort.to_s : TextSearchable::DEFAULT_SORT
      key = TextSearchable::UNRANKED_FALLBACK_SORT if key == TextSearchable::DEFAULT_SORT && !ranked
      key = sort_orders.key?(key) ? key : sort_orders.keys.first

      sort_orders.fetch(key).call(columns, rank)
    end

    # Order a relation by the requested sort, replacing any earlier ORDER BY —
    # a plain `order` would only append, which silently demotes relevance below
    # the default recency ordering.
    def ordered_for_search(sort, ranked: true)
      reorder(Arel.sql(search_order_sql(sort, ranked: ranked)))
    end
  end

  # Persist a freshly computed vector for this row.
  #
  # `update_columns` on purpose: this repairs the index, so it must not run
  # validations, must not re-enter the search callback, and must not look like
  # an edit of the record (no updated_at churn) — otherwise a backfill would
  # rewrite every timestamp in the table and a reindex could loop.
  def refresh_search_vector!
    update_columns(searchable: self.class.connection.select_value(search_vector_sql))
  end

  private

  # Quote a value for inclusion in the vector expression.
  def sql_quote(value)
    self.class.connection.quote(value)
  end

  # The SELECT that produces this row's tsvector from its own column and
  # association values. Including models must implement it; keeping it here as
  # the single definition is what lets `refresh_search_vector!`, the
  # `before_save` callback and the backfill all agree.
  #
  # It must work for an unsaved record too — the callback runs before the row
  # exists — so it interpolates quoted values rather than selecting from the
  # table.
  def search_vector_sql
    raise NotImplementedError, "#{self.class.name} must implement #search_vector_sql"
  end
end
