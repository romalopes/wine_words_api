require "rails_helper"

RSpec.describe "current-role Pundit policies" do
  def user_with_role(name, email)
    User.create!(email: email, password: "password123").tap do |user|
      user.roles << Role.find_or_create_by!(name: name)
    end
  end

  let(:reader) { user_with_role("Reader", "policy-reader@example.com") }
  let(:reviewer) { user_with_role("Reviewer", "policy-reviewer@example.com") }
  let(:editor) { user_with_role("Editor", "policy-editor@example.com") }
  let(:admin) { user_with_role("Admin", "policy-admin@example.com") }

  it "keeps catalogue writes unavailable to readers and available to wine managers" do
    category = Category.new(name: "Policy category")

    expect(CategoryPolicy.new(reader, category).create?).to be_falsey
    expect(CategoryPolicy.new(reviewer, category).create?).to be_truthy
    expect(CategoryPolicy.new(editor, category).create?).to be_truthy
    expect(CategoryPolicy.new(admin, category).create?).to be_truthy
  end

  it "keeps destructive wine actions restricted to catalogue managers" do
    wine = Wine.new(name: "Policy wine")

    expect(WinePolicy.new(reviewer, wine).destroy?).to be_falsey
    expect(WinePolicy.new(editor, wine).destroy?).to be_truthy
    expect(WinePolicy.new(admin, wine).destroy?).to be_truthy
  end

  it "scopes wine packages to managers, reviewers, and recorders" do
    producer = Producer.create!(name: "Policy producer")
    own = WinePackage.create!(producer: producer, reviewer: reviewer, created_by: admin)
    recorded = WinePackage.create!(producer: producer, reviewer: reader, created_by: reviewer)
    other = WinePackage.create!(producer: producer, reviewer: reader, created_by: reader)

    reviewer_ids = WinePackagePolicy::Scope.new(reviewer, WinePackage.all).resolve.pluck(:id)
    expect(reviewer_ids).to contain_exactly(own.id, recorded.id)
    expect(WinePackagePolicy::Scope.new(editor, WinePackage.all).resolve).to include(own, recorded, other)
  end

  it "keeps article projects private to their creator unless the user is a catalogue manager" do
    own = ArticleProject.create!(name: "Own project", created_by: reviewer)
    other = ArticleProject.create!(name: "Other project", created_by: reader)

    expect(ArticleProjectPolicy.new(reviewer, own).update?).to be_truthy
    expect(ArticleProjectPolicy.new(reviewer, other).update?).to be_falsey
    expect(ArticleProjectPolicy.new(editor, other).update?).to be_truthy
  end

  it "uses the real admin role for administrative policy decisions" do
    expect(AdministrationPolicy.new(reader, :administration).access?).to be_falsey
    expect(AdministrationPolicy.new(admin, :administration).access?).to be_truthy
  end
end
