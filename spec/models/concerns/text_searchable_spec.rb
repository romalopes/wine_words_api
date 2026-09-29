require "rails_helper"

# TextSearchable is the search layer shared by Review and Article: it turns a
# raw `query` param into a safe tsquery, filters + ranks the scope by the
# weighted `searchable` column, and maps the `sort` param onto a whitelist of
# ORDER BY fragments. The HTTP-level behaviour is covered by the grouped and
# search request specs; this one pins the pieces those endpoints rely on.
RSpec.describe TextSearchable do
  describe ".build_tsquery" do
    it "returns nil when there is nothing to search for" do
      expect(described_class.build_tsquery(nil)).to be_nil
      expect(described_class.build_tsquery("   ")).to be_nil
      expect(described_class.build_tsquery("...")).to be_nil
    end

    it "returns nil below MIN_TERM_LENGTH, which is what keeps short input unfiltered" do
      expect(described_class.build_tsquery("a")).to be_nil
      expect(described_class.build_tsquery("ab")).to be_nil
      expect(described_class.build_tsquery("ab c")).to be_nil
      expect(described_class.build_tsquery("abc")).to eq("abc:*")
    end

    it "ANDs each word as a prefix match so every word must appear somewhere" do
      expect(described_class.build_tsquery("barossa shiraz"))
        .to eq("barossa:* & shiraz:*")
    end

    it "normalises case and punctuation between words" do
      expect(described_class.build_tsquery("  Barossa,  SHIRAZ! "))
        .to eq("barossa:* & shiraz:*")
    end

    it "drops tsquery operators instead of letting to_tsquery raise on them" do
      # Unsanitised, each of these is a to_tsquery syntax error and therefore a
      # 500 from a plain text box.
      expect(described_class.build_tsquery(" & : ' ! | ) ( <>")).to be_nil
      expect(described_class.build_tsquery("bar & ! shiraz")).to eq("bar:* & shiraz:*")
      expect(described_class.build_tsquery("a:* & b")).to be_nil
    end

    it "keeps digits so a vintage year can be searched" do
      expect(described_class.build_tsquery("2021")).to eq("2021:*")
    end
  end

  describe "the sort whitelist" do
    it "falls back to relevance for an unknown value rather than using it" do
      expect(Article.search_order_sql("DROP TABLE", ranked: true))
        .to eq("rank DESC NULLS LAST, articles.id DESC")
      expect(Article.search_order_sql(nil, ranked: true))
        .to eq("rank DESC NULLS LAST, articles.id DESC")
    end

    it "degrades relevance to recency when there is no rank column to order by" do
      expect(Article.search_order_sql("relevance", ranked: false))
        .to eq("articles.created_at DESC, articles.id DESC")
      expect(Review.search_order_sql(nil, ranked: false))
        .to eq("reviews.created_at DESC, reviews.id DESC")
    end

    it "qualifies columns so the same whitelist works in the grouped subquery" do
      expect(Review.search_order_sql("score_high", columns: "r."))
        .to eq("r.score DESC NULLS LAST, r.id DESC")
      expect(Review.search_order_sql("oldest", columns: "r."))
        .to eq("r.created_at ASC, r.id ASC")
    end

    it "only accepts the sorts a model actually offers" do
      # Articles have no score, so a review sort must not reach the database.
      expect(Article.search_order_sql("score_low", ranked: true))
        .to eq("rank DESC NULLS LAST, articles.id DESC")
      expect(Article.search_order_sql("score_low", ranked: false))
        .to eq("articles.created_at DESC, articles.id DESC")
    end
  end

  # Shared by the describes below: an author because every searchable row indexes
  # one, and a builder because a vector is only interesting once something is in
  # it.
  let(:author) do
    User.create!(user_name: "Searcher", email: "searcher@example.com", password: "password123")
  end

  def create_article(title, body: nil, tag_names: [])
    article = Article.create!(title: title, body: body, status: "published", user: author)
    return article if tag_names.empty?

    # Join rows are written after the article is saved, while the vector is
    # built before it, so the join has to refresh the vector itself (see
    # ArticleTag#refresh_article_search_vector). This relies on that, and is
    # the only thing that makes a newly attached tag searchable.
    tag_names.each do |name|
      ArticleTag.create!(article: article, tag: Tag.find_or_create_by_name(name))
    end
    article
  end

  # Article stands in for the including model here because its vector spreads a
  # term across fields of different weight (A title, C body, D tag), which is
  # what makes relevance observable.
  describe "searching a weighted vector" do

    it "matches fields the ILIKE implementation never looked at" do
      in_body = create_article("Regional overview", body: "Shiraz dominates the plantings here.")
      create_article("Harvest diary", tag_names: ["vineyard"])

      expect(Article.text_search("shiraz").pluck(:title)).to contain_exactly(in_body.title)
      expect(Article.text_search("vineyard").pluck(:title)).to contain_exactly("Harvest diary")
    end

    it "requires every word of a multi-word term, but not in the same field" do
      both = create_article("Barossa gems", body: "The best shiraz vintages live here.")
      create_article("Barossa only", body: "No grape variety named here at all.")

      expect(Article.text_search("barossa shiraz").pluck(:title)).to contain_exactly(both.title)
    end

    it "matches prefixes, so a partial word still finds the whole one" do
      create_article("Chardonnay, chilled")
      create_article("Pinot Noir, cellared")

      expect(Article.text_search("char").pluck(:title)).to contain_exactly("Chardonnay, chilled")
    end

    it "ranks a title hit above a body-only hit" do
      create_article("Shiraz showcase", body: "A region overview.")
      create_article("Regional overview", body: "Shiraz dominates the plantings here.")

      ranked = Article.text_search("shiraz").ordered_for_search("relevance", ranked: true)
      # `to_a` rather than `pluck`, which replaces the SELECT list and would drop
      # the `rank` alias the ordering refers to.
      expect(ranked.map(&:title)).to eq(["Shiraz showcase", "Regional overview"])
    end

    it "leaves the scope untouched when the term is not searchable" do
      create_article("Chardonnay, chilled")

      expect(Article.text_search("c").pluck(:title)).to eq(["Chardonnay, chilled"])
      expect(Article.text_search(" & : ' !").pluck(:title)).to eq(["Chardonnay, chilled"])
    end

    it "returns nothing for a searchable term that matches nothing" do
      create_article("Chardonnay, chilled")

      expect(Article.text_search("zzzzq")).to be_empty
    end
  end

  # The vector is a column, so it is only as current as whatever last wrote it.
  # What the examples above cannot see is a row whose vector was never written at
  # all — which is how every row that predates the column ended up invisible to
  # search, while the endpoint kept answering 200 with an empty list.
  describe "keeping the column built" do
    it "cannot match a row whose vector is missing" do
      create_article("Shiraz showcase")
      # `update_columns`, because writing through the model would rebuild the
      # vector — the very behaviour this row is meant to lack.
      Article.update_all(searchable: nil)

      expect(Article.text_search("shiraz")).to be_empty
      expect(Article.search_vector_status).to eq(total: 1, indexed: 0, missing: 1)
    end

    it "repairs a missing vector, which is the whole point of the repair path" do
      article = create_article("Shiraz showcase")
      Article.update_all(searchable: nil)

      expect(Article.reindex_search_vectors!).to eq(1)
      expect(Article.text_search("shiraz").pluck(:title)).to contain_exactly(article.title)
      expect(Article.search_vector_status).to eq(total: 1, indexed: 1, missing: 0)
    end

    it "does not count a backfill as an edit" do
      article = create_article("Shiraz showcase")
      long_ago = Time.utc(2020, 1, 1)
      article.update_columns(searchable: nil, updated_at: long_ago)

      Article.reindex_search_vectors!

      # `sort=newest`, "last updated" labels and any cache key built on
      # updated_at must not move just because the index caught up.
      expect(article.reload.updated_at).to eq(long_ago)
    end

    it "is idempotent and reaches every row, however the batches fall" do
      titles = (1..5).map { |i| create_article("Shiraz showcase #{i}").title }
      Article.update_all(searchable: nil)

      # Two of the five land in the first batch, one in the last: nothing may
      # slip through the seams, and a second pass may not find new work.
      expect(Article.reindex_search_vectors!(batch_size: 2)).to eq(5)
      expect(Article.text_search("shiraz").pluck(:title)).to contain_exactly(*titles)
      expect(Article.reindex_search_vectors!(batch_size: 2)).to eq(5)
      expect(Article.search_vector_status).to eq(total: 5, indexed: 5, missing: 0)
    end
  end
end
