require "rails_helper"

# Unit coverage for the interleave that backs both "more articles" and "more
# reviews". It is the one piece of that feature that is not obvious from reading
# a single endpoint: an earlier version broke out of the inner loop and returned
# more rows than asked for, and the retry exited after a single pass and returned
# too few.
RSpec.describe Api::RelatedFeed do
  # The concern's methods are private controller methods, and `related_limit`
  # reads `params`. A bare host lets them be exercised without booting a request;
  # the wrappers are named differently on purpose, so `send` reaches the
  # concern's own (private) methods instead of the wrapper again.
  let(:host_class) do
    Class.new do
      include Api::RelatedFeed

      attr_accessor :requested_limit

      def params
        { limit: requested_limit }
      end

      def call_related_limit(default, max)
        send(:related_limit, default, max)
      end

      def call_round_robin(lists, limit)
        send(:round_robin, lists, limit)
      end

      def call_related_buckets(record, scope, join:, foreign_key:, per_category:, limit:)
        send(:related_buckets, record, scope,
             join: join, foreign_key: foreign_key,
             per_category: per_category, limit: limit)
      end
    end
  end

  let(:host) { host_class.new }

  # `described_class` is not in scope inside `Class.new`, so the constants are
  # named explicitly here.
  def call_limit(host)
    host.call_related_limit(Api::RelatedFeed::DEFAULT_LIMIT, Api::RelatedFeed::MAX_LIMIT)
  end

  describe "#related_limit" do
    it "defaults when no usable limit is requested" do
      expect(call_limit(host)).to eq(5)
      host.requested_limit = nil
      expect(call_limit(host)).to eq(5)
      host.requested_limit = 0
      expect(call_limit(host)).to eq(5)
      host.requested_limit = -3
      expect(call_limit(host)).to eq(5)
    end

    it "clamps to the maximum and honours the minimum" do
      host.requested_limit = 99
      expect(call_limit(host)).to eq(10)
      host.requested_limit = 1
      expect(call_limit(host)).to eq(1)
      host.requested_limit = 3
      expect(call_limit(host)).to eq(3)
    end
  end

  describe "#round_robin" do
    # Plain integers standing in for records: `round_robin` only reads `#id`.
    let(:row) { Struct.new(:id) }
    let(:list) { ->(*ids) { ids.map { |id| row.new(id) } } }

    it "deals one row per list per pass" do
      a = list.call(1, 3, 5)
      b = list.call(2, 4, 6)

      expect(host.call_round_robin([ a, b ], 4).map(&:id)).to eq([ 1, 2, 3, 4 ])
    end

    it "stops at exactly the limit instead of overshooting it" do
      rows_in = [ list.call(1, 2, 3, 4) ]

      expect(host.call_round_robin(rows_in, 3).map(&:id)).to eq([ 1, 2, 3 ])
    end

    it "fills the slots from the other lists when one runs out" do
      a = list.call(1, 2, 3)
      b = list.call(4)

      # Pass 1: 1, 4. Pass 2: 2. Pass 3: 3.
      expect(host.call_round_robin([ a, b ], 3).map(&:id)).to eq([ 1, 4, 2 ])
    end

    it "lists a record that appears in two lists only once" do
      a = list.call(1, 9)
      b = list.call(1, 8)

      result = host.call_round_robin([ a, b ], 4).map(&:id)

      # Pass 1: 1 from the first list, then the duplicate 1 in the second is
      # dropped. Pass 2: 9, then 8.
      expect(result).to eq([ 1, 9, 8 ])
      expect(result).to eq(result.uniq)
    end

    it "returns everything available when there is less than the limit" do
      result = host.call_round_robin([ list.call(1), list.call(2) ], 5).map(&:id)
      expect(result).to eq([ 1, 2 ])
    end

    it "returns nothing for no lists at all" do
      expect(host.call_round_robin([], 5)).to eq([])
    end
  end

  # The categorised path has one bucket per category; the uncategorised path has
  # a single bucket of the newest records overall. Both are exercised against
  # real rows because the resolver builds the buckets from a scope.
  describe "#related_buckets" do
    let(:author) do
      User.create!(
        user_name: "Bucket Author",
        email: "bucket-author@example.com",
        password: "password123"
      )
    end
    let(:burgundy) { Category.create!(name: "Bucket Burgundy") }
    let(:barossa) { Category.create!(name: "Bucket Barossa") }

    # `days_ago` keeps the expected ordering explicit.
    def create_article(title, categories: [], status: "published", days_ago: 5)
      article = Article.create!(title: title, status: status, user: author)
      article.update_column(:created_at, days_ago.days.ago)
      categories.each { |c| ArticleCategory.create!(article: article, category: c) }
      article
    end

    def buckets_for(article, limit: 5)
      scope = Article.where.not(id: article.id).visible_to(nil)
      host.call_related_buckets(
        article, scope,
        join: ArticleCategory, foreign_key: :article_id,
        per_category: [ limit, 5 ].min + 1, limit: limit
      )
    end

    it "returns one bucket per category, each capped at per_category" do
      current = create_article("Current", categories: [ burgundy, barossa ], days_ago: 1)
      create_article("Burgundy 1", categories: [ burgundy ], days_ago: 2)
      create_article("Burgundy 2", categories: [ burgundy ], days_ago: 3)

      buckets = buckets_for(current, limit: 2)

      expect(buckets.length).to eq(2)
      # per_category = [2, 5].min + 1 = 3
      expect(buckets.map(&:length)).to eq([ 2, 0 ])
    end

    it "returns a single bucket of the newest records when there are no categories" do
      current = create_article("Uncategorised current", days_ago: 1)
      newer = create_article("Newer", categories: [ burgundy ], days_ago: 2)
      older = create_article("Older", categories: [ barossa ], days_ago: 3)

      buckets = buckets_for(current, limit: 5)

      expect(buckets.length).to eq(1)
      # Recency decides, not category: both siblings are in a category of their own.
      expect(buckets.first.map(&:id)).to eq([ newer.id, older.id ])
      expect(buckets.first.map(&:id)).not_to include(current.id)
    end

    it "honours the limit on the uncategorised bucket" do
      current = create_article("Uncategorised current", days_ago: 1)
      siblings = 4.times.map { |i| create_article("Sibling #{i}", days_ago: 2 + i) }

      expect(buckets_for(current, limit: 3).first.map(&:id)).to eq(siblings.first(3).map(&:id))
    end

    it "only buckets rows the caller's scope allows" do
      current = create_article("Uncategorised current", days_ago: 1)
      published = create_article("Published", days_ago: 2)
      create_article("Someone else's draft", status: "draft", days_ago: 3)

      # The request spec covers the endpoint; this pins the contract that the
      # resolver never widens the scope it is handed.
      expect(buckets_for(current, limit: 5).first.map(&:id)).to eq([ published.id ])
    end
  end
end
