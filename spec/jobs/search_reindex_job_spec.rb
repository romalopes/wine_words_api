require "rails_helper"

# A search vector is built from other records' values, so the row that owns a
# vector is rarely the row that changes. Renaming a wine has to reach every
# review of every one of its vintages, and none of that happens inside
# Review#save: it is SearchVectorDependent's job to notice, and this job's job
# to repair. `Review.text_search` is asserted against directly because that is
# what the user-visible endpoint calls — a vector that looks rebuilt but does not
# match is no use to anyone.
RSpec.describe SearchReindexJob do
  include ActiveJob::TestHelper

  let(:country) do
    Country.find_or_create_by!(code: Producer::DEFAULT_COUNTRY_CODE) { |c| c.name = "Australia" }
  end
  let(:author) do
    User.create!(first_name: "Taster", email: "taster@example.com", password: "password123")
  end
  let(:region) { Region.create!(name: "Barossa Valley", country: country) }
  let(:producer) { Producer.create!(name: "Blefing Peak") }
  let(:grape) { Grape.create!(name: "Shiraz") }

  # Names are invented rather than real words: the english dictionary stems both
  # the vector and the query, so a word like "Empty" would make the assertion
  # about stemming rather than about the index being rebuilt.
  #
  # A review hangs off a vintage rather than a wine, so every wine here needs one
  # to be reviewable at all; building it here and reading it back in create_review
  # keeps that plumbing out of the examples.
  def create_wine(name, producer: self.producer, year: 2019)
    wine = Wine.create!(name: name, producer: producer, color: "Red")
    wine.regions << region
    wine.grapes << grape
    Vintage.create!(wine: wine, year: year)
    wine
  end

  def create_review(wine, title: "Cellar note")
    Review.create!(vintage: wine.vintages.first, user: author, title: title,
                   comment: "Tight, chalky and still young.", score: 90, status: "published")
  end

  # Examples run inside a transaction that is rolled back, so after_commit never
  # fires on its own, and calling it by hand stands in for the commit the example
  # never performs. The job then reads the same connection, which is the only
  # place the change it has to repair is visible.
  def commit(record)
    record.run_callbacks(:commit) { perform_enqueued_jobs }
  end

  describe "renaming a record another vector indexes" do
    it "makes the new name findable and retires the old one" do
      wine = create_wine("Granmutter")
      review = create_review(wine)
      expect(Review.text_search("granmutter").pluck(:id)).to eq([review.id])

      wine.update!(name: "Tarnhide")
      commit(wine)

      expect(Review.text_search("tarnhide").pluck(:id)).to eq([review.id])
      expect(Review.text_search("granmutter")).to be_empty
    end

    it "reaches every review of every vintage, not only the one edited" do
      older = create_review(create_wine("Granmutter"))
      newer = create_review(create_wine("Granmutter"))
      expect(Review.text_search("granmutter").pluck(:id).size).to eq(2)

      producer.update!(name: "Fenmolton Crossing")
      commit(producer)

      expect(Review.text_search("fenmolton").pluck(:id)).to contain_exactly(older.id, newer.id)
      expect(Review.text_search("blefing")).to be_empty
    end

    it "follows the dependency through a region rename" do
      wine = create_wine("Granmutter")
      review = create_review(wine)

      region.update!(name: "Wolloga Paddocks")
      commit(region)

      expect(Review.text_search("wolloga").pluck(:id)).to eq([review.id])
      expect(Review.text_search("barossa")).to be_empty
    end

    it "reaches an article through the tag attached to it" do
      tag = Tag.find_or_create_by_name("vermeer")
      article = Article.create!(title: "Harvest notes", body: "A wet January.",
                                status: "published", user: author)
      ArticleTag.create!(article: article, tag: tag)
      # The join refreshes the vector itself, so the tag is searchable without a
      # second save of the article.
      expect(Article.text_search("vermeer").pluck(:id)).to eq([article.id])

      tag.update!(name: "rembrandt")
      commit(tag)

      expect(Article.text_search("rembrandt").pluck(:id)).to eq([article.id])
      expect(Article.text_search("vermeer")).to be_empty
    end
  end

  describe "link rows, where the link itself is the indexed value" do
    it "drops a region that is no longer linked" do
      wine = create_wine("Granmutter")
      create_review(wine)
      expect(Review.text_search("barossa")).not_to be_empty

      link = wine.wine_regions.find_by!(region: region)
      link.destroy
      commit(link)

      expect(Review.text_search("barossa")).to be_empty
    end

    it "indexes a grape that was only just linked" do
      wine = create_wine("Granmutter")
      wine.grapes = []
      create_review(wine)
      expect(Review.text_search("shiraz")).to be_empty

      link = WineGrape.create!(wine: wine, grape: grape)
      commit(link)

      expect(Review.text_search("shiraz")).not_to be_empty
    end
  end

  describe "what gets enqueued" do
    # Same stand-in for the missing commit, minus running the job: these examples
    # are about the payload the callback hands over.
    def enqueue_only(record)
      record.run_callbacks(:commit)
    end

    it "names the searchable model and only the rows that need repairing" do
      wine = create_wine("Granmutter")
      review = create_review(wine)
      untouched = create_review(create_wine("Klongaberry", producer: Producer.create!(name: "Other Gully")))

      wine.update!(name: "Tarnhide")

      expect { enqueue_only(wine) }
        .to have_enqueued_job(SearchReindexJob).with("Review", [review.id])
      expect(untouched.reload.searchable.to_s).not_to include("tarnhide")
    end

    it "enqueues one job per target model when a record feeds both" do
      review = create_review(create_wine("Granmutter"))
      article = Article.create!(title: "Harvest notes", body: "A wet January.",
                                status: "published", user: author)

      author.update!(first_name: "Terence Taster")

      # The payloads read off the queue rather than a matcher chain, which would
      # otherwise demand one job carrying both argument lists.
      queued = enqueued_jobs.select { |job| job[:job] == SearchReindexJob }
      expect(queued.map { |job| job[:args] })
        .to contain_exactly(["Review", [review.id]], ["Article", [article.id]])
    end

    it "stays quiet when nothing a vector depends on changed" do
      wine = create_wine("Granmutter")

      wine.update!(color: "White")

      expect { enqueue_only(wine) }.not_to have_enqueued_job(SearchReindexJob)
    end

    it "skips an empty target instead of enqueueing a job that repairs nothing" do
      stray = Producer.create!(name: "Mivale Ridge")

      stray.update!(name: "Mivale Crossing")

      expect { enqueue_only(stray) }.not_to have_enqueued_job(SearchReindexJob)
    end
  end

  describe "#perform" do
    it "will not constantise a class outside the searchable whitelist" do
      expect { described_class.perform_now("User", [author.id]) }.not_to raise_error
      expect { described_class.perform_now("Object", [1]) }.not_to raise_error
    end

    it "ignores ids whose rows have already gone" do
      wine = create_wine("Granmutter")
      review = create_review(wine)

      expect { described_class.perform_now("Review", [review.id, 999_999]) }.not_to raise_error
      expect(Review.find(review.id).searchable).to be_present
    end
  end
end
