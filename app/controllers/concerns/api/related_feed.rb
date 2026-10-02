# Shared helpers for the "more <things>" footer on a detail page
# (Api::V1::ArticlesController#related, Api::V1::ReviewsController#related).
#
# The footer lists the newest records sharing the current one's categories. When
# the record sits in several categories the slots are dealt round-robin rather
# than taken from the first category, so one category cannot take every slot
# while the others go unrepresented.
#
# A record that belongs to NO category has nothing to intersect on, so it falls
# back to the newest records overall (see #related_buckets). That footer is
# related by recency rather than by topic — deliberate, because the alternative
# is an empty section on every uncategorised page.
module Api
  module RelatedFeed
    extend ActiveSupport::Concern

    DEFAULT_LIMIT = 5
    MAX_LIMIT = 10

    private

    # The requested row count, defaulted and clamped. A missing or nonsensical
    # `limit` must not produce an unbounded query.
    def related_limit(default = DEFAULT_LIMIT, max = MAX_LIMIT)
      limit = params[:limit].to_i
      limit = default if limit <= 0
      limit.clamp(1, max)
    end

    # The lists #round_robin should deal from, one per category, so a record in
    # several categories cannot have its footer dominated by the first one.
    #
    # Categorised: one list per category, each capped at `per_category` (a few
    # more than `limit` so self-exclusion and cross-category duplicates cannot
    # leave the footer short).
    #
    # Uncategorised: a single list of the newest `limit` records on the scope.
    # Callers pass `scope` already filtered for visibility and with the current
    # record excluded, so this only has to add the ordering and the cap.
    def related_buckets(record, scope, join:, foreign_key:, per_category:, limit:)
      category_ids = record.category_ids
      return [ scope.order(related_order).limit(limit).to_a ] if category_ids.empty?

      category_ids.map do |category_id|
        scope.where(id: join.where(category_id: category_id).select(foreign_key))
             .order(related_order)
             .limit(per_category)
             .to_a
      end
    end

    # Published records first, newest first. `published_at` is NULL for drafts,
    # and only a content manager ever sees those, so they sort last instead of
    # jumping to the top of the footer. Raw SQL because `order` has no
    # NULLS LAST direction.
    def related_order
      Arel.sql("published_at DESC NULLS LAST, created_at DESC, id DESC")
    end

    # Deals `limit` items across the per-category lists, one from each list per
    # pass, skipping ids already taken (a record in two of the categories must
    # not appear twice) and skipping the nil holes left by short lists.
    #
    # A single-list input (the uncategorised case) simply yields that list's
    # first `limit` rows.
    def round_robin(lists, limit)
      taken = Set.new
      result = []
      loop do
        added = false
        lists.each do |list|
          row = list.shift
          next if row.nil? || taken.include?(row.id)

          taken << row.id
          result << row
          added = true
          # Return rather than break: `break` would only leave the inner loop and
          # the outer one would start another pass and overshoot the limit.
          return result if result.length >= limit
        end
        # A whole pass that gave nothing: every list is exhausted. A pass that
        # only met duplicates still counts as progress-free, but the duplicates
        # were shifted off, so the lists can only shrink from here.
        break unless added
      end
      result
    end
  end
end
