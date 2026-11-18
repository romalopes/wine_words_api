require "rails_helper"

# In-app staff notifications for a contact message (IDENTITY_209 Phase 2):
# active Editors and Admins only, once per message, retry-safe.
RSpec.describe ContactMessages::NotifyStaff do
  before(:all) do
    %w[Guest Admin Editor Reviewer Reader].each do |name|
      Role.find_or_create_by!(name: name)
    end
  end

  def user_with_role(role_name, email)
    User.create!(first_name: role_name, email: email, password: "password123").tap do |user|
      user.roles << Role.find_or_create_by!(name: role_name)
    end
  end

  let!(:admin) { user_with_role("Admin", "notify-admin@example.com") }
  let!(:editor) { user_with_role("Editor", "notify-editor@example.com") }
  let!(:reviewer) { user_with_role("Reviewer", "notify-reviewer@example.com") }
  let!(:reader) { user_with_role("Reader", "notify-reader@example.com") }

  let(:message) do
    ContactMessage.create!(
      name: "Jane Smith",
      email: "jane@example.com",
      contact_type: "support",
      subject: "Cannot sign in",
      message: "Help please"
    )
  end

  def notifications_for(user)
    Notification.where(recipient: user, contact_message: message)
  end

  it "notifies every active Editor and Admin once" do
    described_class.call(contact_message: message)

    expect(notifications_for(admin).count).to eq(1)
    expect(notifications_for(editor).count).to eq(1)

    notification = notifications_for(editor).first
    expect(notification.notification_type).to eq("contact_message_received")
    expect(notification.delivered_at).to be_present
    expect(notification.target_path).to eq("/settings/contact-messages/#{message.id}")
    expect(notification.message).to include("Jane Smith")
    expect(notification.message).to include("Cannot sign in")
  end

  it "does not notify Reviewers, Readers or deleted accounts" do
    editor.soft_delete!

    described_class.call(contact_message: message)

    expect(notifications_for(reviewer)).to be_empty
    expect(notifications_for(reader)).to be_empty
    expect(notifications_for(editor)).to be_empty
    expect(notifications_for(admin).count).to eq(1)
  end

  it "is idempotent across retries" do
    described_class.call(contact_message: message)
    described_class.call(contact_message: message)

    expect(notifications_for(admin).count).to eq(1)
    expect(notifications_for(editor).count).to eq(1)
  end
end
