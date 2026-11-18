require "rails_helper"

# Request specs for the public Contact form and the Contact Messages inbox
# (IDENTITY_209 Phases 1, 3 and 5).
RSpec.describe "Api::V1::ContactMessages", type: :request do
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  # Seed the roles once, outside the per-example transaction (the trade specs
  # document the deadlock this avoids).
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

  let(:admin) { user_with_role("Admin", "contact-admin@example.com") }
  let(:editor) { user_with_role("Editor", "contact-editor@example.com") }
  let(:reviewer) { user_with_role("Reviewer", "contact-reviewer@example.com") }
  let(:reader) { user_with_role("Reader", "contact-reader@example.com") }

  let(:valid_payload) do
    {
      name: "Jane Smith",
      email: "jane@example.com",
      contact_type: "general",
      subject: "Question about Wine Words",
      message: "I would like to know more about the platform.",
      turnstile_token: "test-token",
      website: ""
    }
  end

  def submit(overrides = {})
    post "/api/v1/contact_messages", params: valid_payload.merge(overrides), as: :json
  end

  def create_message(overrides = {})
    ContactMessage.create!(
      {
        name: "Jane Smith",
        email: "jane@example.com",
        contact_type: "general",
        subject: "A question",
        message: "Hello there"
      }.merge(overrides)
    )
  end

  describe "POST /api/v1/contact_messages (public)" do
    it "stores a valid message without authentication" do
      expect { submit }.to change(ContactMessage, :count).by(1)

      expect(response).to have_http_status(:created)
      message = ContactMessage.last
      expect(message.name).to eq("Jane Smith")
      expect(message.email).to eq("jane@example.com")
      expect(message.contact_type).to eq("general")
      expect(message.status).to eq("unread")
      expect(message.read_at).to be_nil
      expect(message.archived_at).to be_nil
    end

    it "returns a minimal receipt and never exposes internal data" do
      submit

      expect(response.parsed_body.keys).to eq([ "status" ])
      expect(response.parsed_body["status"]).to eq("received")
    end

    it "enqueues one email per configured recipient plus the staff notification" do
      with_env("CONTACT_NOTIFICATION_EMAILS" => "team@example.com, second@example.com") do
        submit
      end

      message = ContactMessage.last
      expect(ContactMessages::EmailJob).to have_been_enqueued.with(message.id, "team@example.com")
      expect(ContactMessages::EmailJob).to have_been_enqueued.with(message.id, "second@example.com")
      expect(ContactMessages::NotifyStaffJob).to have_been_enqueued.with(message.id)
    end

    it "still stores the message when no recipient is configured" do
      with_env("CONTACT_NOTIFICATION_EMAILS" => nil) do
        expect { submit }.to change(ContactMessage, :count).by(1)
      end

      expect(response).to have_http_status(:created)
      expect(ContactMessages::EmailJob).not_to have_been_enqueued
      expect(ContactMessages::NotifyStaffJob).to have_been_enqueued
    end

    it "rejects missing and invalid fields with field-level details" do
      submit(name: "", email: "not-an-email", contact_type: "spam", subject: "", message: "")

      expect(response).to have_http_status(:unprocessable_entity)
      body = response.parsed_body
      expect(body["error"]).to be_present
      expect(body["errors"]).to be_an(Array)
      expect(body["details"]).to include("name", "email", "contact_type", "subject", "message")
      expect(ContactMessage.count).to eq(0)
    end

    it "enforces the maximum lengths" do
      submit(subject: "a" * 181)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["details"]["subject"]).to be_present
    end

    it "discards honeypot submissions without storing or delivering anything" do
      with_env("CONTACT_NOTIFICATION_EMAILS" => "team@example.com") do
        expect { submit(website: "https://spam.example") }
          .not_to change(ContactMessage, :count)
      end

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["status"]).to eq("received")
      expect(ContactMessages::EmailJob).not_to have_been_enqueued
      expect(ContactMessages::NotifyStaffJob).not_to have_been_enqueued
    end

    it "rejects a failed Turnstile verification" do
      allow(Turnstile::Verifier).to receive(:call).and_return(
        Turnstile::Verifier::Result.new(
          success: false,
          error_codes: [ "invalid-input-response" ]
        )
      )

      expect { submit }.not_to change(ContactMessage, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to match(/could not verify/i)
    end

    it "ignores attempts to set internal fields" do
      submit(status: "read", read_at: Time.current.iso8601, message: "Hello there")

      message = ContactMessage.last
      expect(message.status).to eq("unread")
      expect(message.read_at).to be_nil
    end
  end

  describe "GET /api/v1/admin/contact_messages" do
    it "requires authentication" do
      get "/api/v1/admin/contact_messages", as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "forbids Readers and Reviewers" do
      [ reader, reviewer ].each do |user|
        sign_in user
        get "/api/v1/admin/contact_messages", as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    it "allows Editors and Admins" do
      [ editor, admin ].each do |user|
        sign_in user
        get "/api/v1/admin/contact_messages", as: :json

        expect(response).to have_http_status(:ok)
      end
    end

    it "lists newest first without message bodies and with an unread count" do
      archived = create_message(name: "Archived", status: "archived")
      older = create_message(name: "Older", status: "read")
      newer = create_message(name: "Newer")

      sign_in editor
      get "/api/v1/admin/contact_messages", as: :json

      body = response.parsed_body
      expect(body["items"].map { |item| item["id"] }).to eq([ newer.id, older.id, archived.id ])
      expect(body["items"].first).not_to have_key("message")
      expect(body["unread_count"]).to eq(ContactMessage.unread.count)
      expect(body["total_count"]).to eq(3)
    end

    it "filters by status and contact type, and searches name/email/subject" do
      billing = create_message(
        name: "Billing Person", email: "billing@example.com",
        contact_type: "business", subject: "Invoice question"
      )
      general = create_message(name: "Other Person", contact_type: "general", subject: "Hello")
      create_message(name: "Archived Person", status: "archived")

      sign_in editor

      get "/api/v1/admin/contact_messages", params: { status: "unread" }, as: :json
      expect(response.parsed_body["items"].map { |item| item["id"] })
        .to contain_exactly(billing.id, general.id)

      get "/api/v1/admin/contact_messages", params: { contact_type: "business" }, as: :json
      expect(response.parsed_body["items"].map { |item| item["id"] }).to eq([ billing.id ])

      get "/api/v1/admin/contact_messages", params: { search: "BILLING@EXAMPLE" }, as: :json
      expect(response.parsed_body["items"].map { |item| item["id"] }).to eq([ billing.id ])

      get "/api/v1/admin/contact_messages", params: { search: "invoice" }, as: :json
      expect(response.parsed_body["items"].map { |item| item["id"] }).to eq([ billing.id ])
    end

    it "paginates and bounds per_page" do
      3.times { |index| create_message(name: "Person #{index}") }

      sign_in editor
      get "/api/v1/admin/contact_messages", params: { page: 1, per_page: 2 }, as: :json

      body = response.parsed_body
      expect(body["items"].size).to eq(2)
      expect(body["total_count"]).to eq(3)
      expect(body["total_pages"]).to eq(2)
      expect(body["page"]).to eq(1)
      expect(body["per_page"]).to eq(2)

      get "/api/v1/admin/contact_messages", params: { page: 2, per_page: 500 }, as: :json
      expect(response.parsed_body["per_page"]).to eq(100)
    end

    it "falls back to a safe sort for unsupported input" do
      create_message(name: "First")

      sign_in editor
      get "/api/v1/admin/contact_messages",
          params: { sort: "id; DROP TABLE contact_messages", direction: "sideways" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(ContactMessage.count).to eq(1)
    end

    it "sorts by an allowlisted column and direction" do
      first = create_message(name: "First", subject: "Alpha")
      second = create_message(name: "Second", subject: "Beta")

      sign_in editor
      get "/api/v1/admin/contact_messages", params: { sort: "subject", direction: "asc" }, as: :json

      expect(response.parsed_body["items"].map { |item| item["id"] }).to eq([ first.id, second.id ])
    end
  end

  describe "GET /api/v1/admin/contact_messages/:id" do
    it "returns the full plain-text message to an Editor" do
      message = create_message(message: "Line one\nLine two")

      sign_in editor
      get "/api/v1/admin/contact_messages/#{message.id}", as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["message"]).to eq("Line one\nLine two")
      expect(response.parsed_body["name"]).to eq("Jane Smith")
    end

    it "forbids Readers" do
      message = create_message

      sign_in reader
      get "/api/v1/admin/contact_messages/#{message.id}", as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 404 for an unknown message" do
      sign_in editor
      get "/api/v1/admin/contact_messages/999999", as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/admin/contact_messages/:id" do
    it "marks read, unread and archived, and is idempotent" do
      message = create_message

      sign_in editor

      patch "/api/v1/admin/contact_messages/#{message.id}", params: { status: "read" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(message.reload.status).to eq("read")
      expect(message.read_at).to be_present

      patch "/api/v1/admin/contact_messages/#{message.id}", params: { status: "read" }, as: :json
      expect(response).to have_http_status(:ok)

      patch "/api/v1/admin/contact_messages/#{message.id}", params: { status: "unread" }, as: :json
      expect(message.reload.status).to eq("unread")
      expect(message.read_at).to be_nil

      patch "/api/v1/admin/contact_messages/#{message.id}", params: { status: "archived" }, as: :json
      expect(message.reload.status).to eq("archived")
      expect(message.archived_at).to be_present
    end

    it "accepts the status in a nested contact_message object" do
      message = create_message

      sign_in editor
      patch "/api/v1/admin/contact_messages/#{message.id}",
            params: { contact_message: { status: "read" } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(message.reload.status).to eq("read")
    end

    it "never changes sender identity or content" do
      message = create_message

      sign_in editor
      patch "/api/v1/admin/contact_messages/#{message.id}",
            params: { status: "read", subject: "Hijacked", message: "Replaced", name: "Other" },
            as: :json

      message.reload
      expect(message.subject).to eq("A question")
      expect(message.message).to eq("Hello there")
      expect(message.name).to eq("Jane Smith")
    end

    it "rejects an unsupported status" do
      message = create_message

      sign_in editor
      patch "/api/v1/admin/contact_messages/#{message.id}", params: { status: "deleted" }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(message.reload.status).to eq("unread")
    end

    it "forbids Reviewers" do
      message = create_message

      sign_in reviewer
      patch "/api/v1/admin/contact_messages/#{message.id}", params: { status: "read" }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(message.reload.status).to eq("unread")
    end
  end
end
