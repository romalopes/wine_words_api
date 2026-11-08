require "rails_helper"

RSpec.describe WinePackages::Notifications::Lifecycle do
  let(:producer) { Producer.create!(name: "Lifecycle Producer") }

  def user(name, email, role: nil)
    record = User.create!(first_name: name, email: email, password: "password123")
    record.roles << Role.find_or_create_by!(name: role) if role
    record
  end

  let!(:admin) { user("Lifecycle Admin", "lifecycle-admin@example.com", role: "Admin") }
  let!(:editor) { user("Lifecycle Editor", "lifecycle-editor@example.com", role: "Editor") }
  let!(:reviewer) { user("Lifecycle Reviewer", "lifecycle-reviewer@example.com", role: "Reviewer") }
  let!(:owner) { user("Lifecycle Owner", "lifecycle-owner@example.com") }
  let!(:manager) { user("Lifecycle Manager", "lifecycle-manager@example.com") }
  let!(:contributor) { user("Lifecycle Contributor", "lifecycle-contributor@example.com") }

  before do
    ProducerMembership.create!(user: owner, producer: producer, membership_type: "owner", created_by: admin)
    ProducerMembership.create!(user: manager, producer: producer, membership_type: "manager", created_by: admin)
    ProducerMembership.create!(user: contributor, producer: producer, membership_type: "contributor", created_by: admin)
  end

  let(:package) do
    WinePackage.create!(producer: producer, created_by: owner, requested_by: owner,
                        source: "producer_request", status: "requested")
  end

  it "delivers submissions to every admin/editor but not reviewers" do
    described_class.deliver!(package, event: "requested", actor: owner)

    expect(Notification.where(wine_package: package).pluck(:recipient_id)).to contain_exactly(admin.id, editor.id)
    expect(Notification.where(recipient: reviewer, wine_package: package)).to be_empty
  end

  it "delivers decisions to producer owners/managers, excluding the actor and contributors" do
    package.update!(rejection_reason: "No capacity")
    described_class.deliver!(package, event: "rejected", actor: manager)

    notifications = Notification.where(wine_package: package, notification_type: "wine_package_rejected")
    expect(notifications.pluck(:recipient_id)).to contain_exactly(owner.id)
    expect(notifications.first.message).to include("No capacity")
    expect(Notification.where(recipient: contributor, wine_package: package)).to be_empty
  end

  it "is idempotent per recipient and day" do
    2.times { described_class.deliver!(package, event: "requested", actor: owner) }

    expect(Notification.where(wine_package: package, notification_type: "wine_package_submitted").count).to eq(2)
  end
end
