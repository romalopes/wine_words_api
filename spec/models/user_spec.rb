require "rails_helper"

RSpec.describe User, type: :model do
  def create_user(attrs = {})
    User.create!({ user_name: "Test User #{SecureRandom.hex(2)}", email: "test-#{SecureRandom.hex(4)}@example.com",
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
