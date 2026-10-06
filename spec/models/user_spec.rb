require "rails_helper"

RSpec.describe User, type: :model do
  def create_user(attrs = {})
    User.create!({ first_name: "Test User #{SecureRandom.hex(2)}", email: "test-#{SecureRandom.hex(4)}@example.com",
                   password: "password123" }.merge(attrs))
  end

  def with_role(user, role_name)
    role = Role.find_or_create_by!(name: role_name)
    user.roles << role unless user.roles.exists?(id: role.id)
    user
  end

  let(:guest)       { with_role(create_user, "Guest") }
  let(:reader)      { with_role(create_user, "Reader") }
  let(:reviewer)    { with_role(create_user, "Reviewer") }
  let(:editor)      { with_role(create_user, "Editor") }
  let(:admin)       { with_role(create_user, "Admin") }
  let(:admin_also_reviewer) do
    u = create_user
    %w[Admin Reviewer].each do |name|
      role = Role.find_or_create_by!(name: name)
      u.roles << role unless u.roles.exists?(id: role.id)
    end
    u
  end

  describe "account-backed identity" do
    it "creates exactly one persisted Account even when no names are supplied" do
      user = create_user(first_name: nil)
      expect(user.account).to be_persisted
      expect(Account.where(user: user).count).to eq(1)
      expect(user.display_name).to eq(user.email)
      user.update!(email: "changed@example.com")
      expect(Account.where(user: user).count).to eq(1)
    end

    it "persists supplied nested account information atomically" do
      user = User.create!(email: "nested@example.com", password: "password123",
                          account_attributes: { first_name: "Renée", last_name: "Smith" })
      expect(user.reload.display_name).to eq("Renée Smith")
      expect(Account.where(user: user).count).to eq(1)
    end

    it "does not persist a user whose account is invalid" do
      expect {
        expect { create_user(first_name: "x" * 81) }.to raise_error(ActiveRecord::RecordInvalid)
      }.not_to change(Account, :count)
      expect(User.where.missing(:account)).to be_empty
    end

    it "creates an account even when validations are bypassed" do
      user = User.new(email: "no-validation@example.com")
      user.save!(validate: false)
      expect(user.account).to be_persisted
    end

    it "does not expose a username attribute or JWT claim" do
      user = create_user
      expect(user.attributes).not_to have_key("user_name")
      expect(user.jwt_payload).not_to have_key(:user_name)
    end
  end

  describe "#admin?" do
    it "is true for users with the Admin role" do
      expect(admin.admin?).to be true
    end

    it "is false for users without the Admin role" do
      expect(guest.admin?).to be false
      expect(reader.admin?).to be false
      expect(reviewer.admin?).to be false
      expect(editor.admin?).to be false
    end
  end

  describe "#super_admin?" do
    # The system has a single "Admin" tier, so super_admin? is an alias for
    # admin? and is used by views (e.g. the Users & Roles admin panel) to gate
    # the most privileged actions. If a separate SuperAdmin role is ever added,
    # this spec should be updated alongside the User model.
    it "is true for users with the Admin role" do
      expect(admin.super_admin?).to be true
    end

    it "is false for users without the Admin role" do
      expect(guest.super_admin?).to be false
      expect(reader.super_admin?).to be false
      expect(reviewer.super_admin?).to be false
      expect(editor.super_admin?).to be false
    end

    it "is true for users who hold both Admin and Reviewer" do
      expect(admin_also_reviewer.super_admin?).to be true
    end
  end

  describe "#reviewer?" do
    it "is true for users with the Reviewer role" do
      expect(reviewer.reviewer?).to be true
    end

    it "is false for users without the Reviewer role" do
      expect(guest.reviewer?).to be false
      expect(reader.reviewer?).to be false
      expect(editor.reviewer?).to be false
    end
  end

  describe "#wine_manager?" do
    it "is true for Admins (they outrank Editors)" do
      expect(admin.wine_manager?).to be true
    end

    it "is true for Editors" do
      expect(editor.wine_manager?).to be true
    end

    # Reviewers are content managers: they authenticate the wines we review, so
    # they may create/update/delete wines, vintages and reviews, and they are
    # trusted with the rest of the catalogue.
    it "is true for Reviewers" do
      expect(reviewer.wine_manager?).to be true
      expect(admin_also_reviewer.wine_manager?).to be true
    end

    it "is false for Readers and Guests" do
      expect(reader.wine_manager?).to be false
      expect(guest.wine_manager?).to be false
    end
  end

  describe "#catalogue_manager?" do
    # The narrow tier that "sees everything" — deliberately NOT widened to
    # Reviewers, so a Reviewer still manages only their own wine packages (see
    # WinePackageAuthorizable) even though they are wine managers.
    it "is true for Admins and Editors" do
      expect(admin.catalogue_manager?).to be true
      expect(editor.catalogue_manager?).to be true
    end

    it "is false for Reviewers, Readers and Guests" do
      expect(reviewer.catalogue_manager?).to be false
      expect(reader.catalogue_manager?).to be false
      expect(guest.catalogue_manager?).to be false
    end
  end
end
