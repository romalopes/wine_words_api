require "rails_helper"

# Contact Messages inbox authorization (IDENTITY_209 Phase 1): Admins and
# Editors only, enforced by Pundit independently of any frontend menu.
RSpec.describe ContactMessagePolicy do
  def user_with_role(name, email)
    User.create!(email: email, password: "password123").tap do |user|
      user.roles << Role.find_or_create_by!(name: name)
    end
  end

  let(:reader) { user_with_role("Reader", "contact-policy-reader@example.com") }
  let(:reviewer) { user_with_role("Reviewer", "contact-policy-reviewer@example.com") }
  let(:editor) { user_with_role("Editor", "contact-policy-editor@example.com") }
  let(:admin) { user_with_role("Admin", "contact-policy-admin@example.com") }
  let(:message) { ContactMessage.new }

  it "denies anonymous visitors" do
    policy = described_class.new(nil, message)

    expect(policy.index?).to be(false)
    expect(policy.show?).to be(false)
    expect(policy.update?).to be(false)
  end

  it "denies Readers and Reviewers" do
    [ reader, reviewer ].each do |user|
      policy = described_class.new(user, message)

      expect(policy.index?).to be(false)
      expect(policy.show?).to be(false)
      expect(policy.update?).to be(false)
    end
  end

  it "allows Editors and Admins" do
    [ editor, admin ].each do |user|
      policy = described_class.new(user, message)

      expect(policy.index?).to be(true)
      expect(policy.show?).to be(true)
      expect(policy.update?).to be(true)
    end
  end
end
