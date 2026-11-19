require "rails_helper"

# Request specs for the Trade portal (IDENTITY_206): public submission, guest
# access, claiming, the submitter area and the editorial/commercial chain.
# Each example runs in a rolled-back transaction.
RSpec.describe "Api::V1::Trade", type: :request do
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  # Seed reference roles OUTSIDE the per-example transaction so User creation
  # (and its assign_default_role callback) only ever SELECTs them. Concurrent
  # find_or_create_by! INSERTs on the roles unique index have deadlocked
  # (PG::TRDeadlockDetected) when two connections inserted the same name.
  before(:all) do
    %w[Guest Admin Editor Reviewer Reader].each do |name|
      Role.find_or_create_by!(name: name)
    end
  end

  def user_with_role(role_name, first_name, email)
    user = User.create!(first_name: first_name, email: email, password: "password123")
    user.roles << Role.find_or_create_by!(name: role_name)
    user
  end

  let(:editor) { user_with_role("Editor", "Trade Editor", "trade-editor@example.com") }
  let(:admin) { user_with_role("Admin", "Trade Admin", "trade-admin@example.com") }
  let(:other_user) { User.create!(first_name: "Other", email: "other@example.com", password: "password123") }

  let(:valid_submission) do
    {
      contact_snapshot: {
        company_name: "Bodega Ejemplo", contact_name: "Maria Ruiz",
        email: "maria@bodega-ejemplo.es", country: "Spain", role: "winery"
      },
      wines: [
        { wine_name: "Tinto Reserva", vintage: 2019, region: "Rioja",
          grape_varieties: "Tempranillo", abv: 13.5, volume_ml: 750,
          trade_price: "12.50", retail_price: "22.00",
          sample_available: true, sample_quantity: 2 }
      ]
    }
  end

  def submit_trade_submission!(payload = valid_submission)
    post "/api/v1/trade/submissions", params: payload, as: :json
  end

  describe "POST /api/v1/trade/submissions (public)" do
    it "creates a trade submission without authentication" do
      expect { submit_trade_submission! }.to change(WinePackage, :count).by(1)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      package = WinePackage.find(body["package_reference"])

      expect(package.trade_submission?).to be(true)
      expect(package.editorial_pending?).to be(true)
      expect(package.producer_id).to be_nil
      expect(package.contact_email).to eq("maria@bodega-ejemplo.es")
      expect(package.items.count).to eq(1)
      expect(package.items.first.snapshot_wine_name).to eq("Tinto Reserva")
      expect(package.wine_package_events.exists?(event_type: "trade_submitted")).to be(true)
      expect(body["guest_token"]).to be_present
      expect(package.guest_token_valid?(body["guest_token"])).to be(true)
    end

    it "does not rotate the guest token when the confirmation email is delivered" do
      # Regression: the confirmation mailer once called generate_guest_token!,
      # rotating the digest and invalidating the link returned to the submitter.
      submit_trade_submission!
      token = response.parsed_body["guest_token"]
      package = WinePackage.find(response.parsed_body["package_reference"])

      TradeSubmissionsMailer.confirmation(package.id, token).deliver_now

      expect(package.reload.guest_token_valid?(token)).to be(true)
    end

    it "rejects a submission without a contact snapshot" do
      submit_trade_submission!(wines: valid_submission[:wines])
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "does not require a company name (name + email only)" do
      # Phase 4 UX: anonymous submitters are asked only for their name and
      # email; the producer link is established later during assessment.
      minimal = valid_submission.dup
      minimal[:contact_snapshot] = valid_submission[:contact_snapshot]
        .except(:company_name)
      submit_trade_submission!(minimal)

      expect(response).to have_http_status(:created)
      package = WinePackage.find(response.parsed_body["package_reference"])
      expect(package.contact_snapshot["company_name"]).to be_blank
      expect(package.contact_snapshot["contact_name"]).to eq("Maria Ruiz")
    end

    it "stores NV and MV vintages as labels with a nil year" do
      payload = valid_submission.dup
      payload[:wines] = [
        { wine_name: "Solera Blend", vintage: "NV" },
        { wine_name: "Vertical Set", vintage: "MV" },
        { wine_name: "Tinto Crianza", vintage: "2019" }
      ]
      submit_trade_submission!(payload)

      expect(response).to have_http_status(:created)
      package = WinePackage.find(response.parsed_body["package_reference"])
      nv, mv, year = package.items.order(:id)

      expect(nv.snapshot_vintage_label).to eq("NV")
      expect(nv.proposed_vintage_year).to be_nil
      expect(nv.snapshot_vintage_display).to eq("NV")
      expect(mv.snapshot_vintage_label).to eq("MV")
      expect(mv.proposed_vintage_year).to be_nil
      expect(year.snapshot_vintage_label).to be_nil
      expect(year.proposed_vintage_year).to eq(2019)
      expect(year.snapshot_vintage_display).to eq("2019")
    end

    it "rejects a submission with zero wines" do
      submit_trade_submission!(contact_snapshot: valid_submission[:contact_snapshot], wines: [])
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "cannot mass-assign protected fields" do
      payload = valid_submission.merge(
        producer_id: 1, user_id: 1, status: "approved"
      )
      submit_trade_submission!(payload)
      package = WinePackage.find(response.parsed_body["package_reference"])

      expect(package.producer_id).to be_nil
      expect(package.editorial_pending?).to be(true)
    end

    it "is idempotent for a repeated idempotency key" do
      submit_trade_submission!
      first = response.parsed_body

      # First keyed call creates its own package (this key has never been
      # seen); the second keyed call replays the FIRST KEYED package.
      post "/api/v1/trade/submissions",
           params: valid_submission.merge(idempotency_key: "same-key"), as: :json
      second = response.parsed_body

      post "/api/v1/trade/submissions",
           params: valid_submission.merge(idempotency_key: "same-key"), as: :json
      third = response.parsed_body

      expect(third["package_reference"]).to eq(second["package_reference"])
      expect(third["replayed"]).to be(true)
      expect(WinePackage.count).to eq(2)
    end
  end

  # The submission wizard calls this before showing the login / sign-up choice
  # to an anonymous submitter, so it must answer without a session.
  describe "GET /api/v1/trade/submissions/check_email (public)" do
    it "reports an existing account by email, case-insensitively" do
      other_user

      get "/api/v1/trade/submissions/check_email",
          params: { email: "  Other@Example.com " }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["exists"]).to be(true)
    end

    it "reports an unknown email as not existing" do
      get "/api/v1/trade/submissions/check_email",
          params: { email: "new-submitter@example.com" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["exists"]).to be(false)
    end

    it "rejects a blank email" do
      get "/api/v1/trade/submissions/check_email", params: { email: " " }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["exists"]).to be(false)
    end
  end

  # The public form must reach the editorial team, not only the submitter.
  describe "editorial team notification" do
    let(:reader) { user_with_role("Reader", "Trade Reader", "trade-reader@example.com") }

    it "creates one in-app notification and one email per Editor/Admin" do
      editor
      admin
      reader

      # Jobs are performed so the queued MailDeliveryJobs land in
      # ActionMailer::Base.deliveries, the convention used across the suite.
      perform_enqueued_jobs { submit_trade_submission! }
      package = WinePackage.find(response.parsed_body["package_reference"])

      staff_mails = ActionMailer::Base.deliveries.select do |mail|
        mail.subject.start_with?("New trade submission ##{package.id}")
      end
      expect(staff_mails.map { |mail| mail.to.first })
        .to contain_exactly(editor.email, admin.email)

      [ editor, admin ].each do |staff|
        notification = staff.notifications.find_by(
          notification_type: "trade_submission_received", wine_package: package
        )

        expect(notification).to be_present
        expect(notification.delivered_at).to be_present
        expect(notification.notifiable).to eq(package)
        expect(notification.target_path).to eq("/admin/trade/packages/#{package.id}")
        expect(notification.message).to include("submitted")
      end

      expect(reader.notifications.where(notification_type: "trade_submission_received")).to be_empty
    end

    it "does not notify the submitter about their own submission" do
      editor
      admin
      sign_in editor

      submit_trade_submission!
      package = WinePackage.find(response.parsed_body["package_reference"])

      expect(editor.notifications.where(notification_type: "trade_submission_received")).to be_empty
      expect(admin.notifications.find_by(
        notification_type: "trade_submission_received", wine_package: package
      )).to be_present
    end

    it "does not duplicate the notification or email on an idempotent replay" do
      editor
      payload = valid_submission.merge(idempotency_key: "notify-key")

      post "/api/v1/trade/submissions", params: payload, as: :json
      # The first call's own jobs (confirmation, staff alert, web push) are not
      # what this example is about — start from an empty queue.
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear

      expect {
        post "/api/v1/trade/submissions", params: payload, as: :json
      }.not_to change {
        editor.notifications.where(notification_type: "trade_submission_received").count
      }
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs).to be_empty
    end
  end

  describe "guest access" do
    let(:guest_token) do
      submit_trade_submission!
      response.parsed_body["guest_token"]
    end
    # Depends on guest_token so the submission is created before the lookup:
    # a bare `order(:created_at).last` returns nil in examples that reference
    # `package` before `guest_token` (earlier examples' rows are rolled back).
    let(:package) { guest_token; WinePackage.order(:created_at).last }

    it "shows the package for a valid token" do
      get "/api/v1/trade/guest_packages/#{guest_token}"
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["id"]).to eq(package.id)
    end

    it "404s for an invalid token" do
      get "/api/v1/trade/guest_packages/not-a-token"
      expect(response).to have_http_status(:not_found)
    end

    it "404s after the token is revoked" do
      package.revoke_guest_token!
      get "/api/v1/trade/guest_packages/#{guest_token}"
      expect(response).to have_http_status(:not_found)
    end

    it "allows a guest to read and post conversation messages" do
      post "/api/v1/trade/packages/#{package.id}/messages",
           params: { body: "Hello!", guest_token: guest_token }, as: :json
      expect(response).to have_http_status(:created)

      get "/api/v1/trade/packages/#{package.id}/messages", params: { guest_token: guest_token }
      expect(response.parsed_body.map { |m| m["body"] }).to include("Hello!")
    end

    it "does not let a guest post internal notes" do
      post "/api/v1/trade/packages/#{package.id}/messages",
           params: { body: "sneaky", guest_token: guest_token, internal_note: true }, as: :json
      expect(WinePackageMessage.last.internal_note).to be(false)
    end
  end

  describe "claiming (Phase 5)" do
    let(:guest_token) do
      submit_trade_submission!
      response.parsed_body["guest_token"]
    end
    # Depends on guest_token so the submission is created before the lookup:
    # a bare `order(:created_at).last` returns nil in examples that reference
    # `package` before `guest_token` (earlier examples' rows are rolled back).
    let(:package) { guest_token; WinePackage.order(:created_at).last }

    it "links the package to the claiming user and revokes the token" do
      sign_in other_user
      post "/api/v1/trade/guest_packages/#{guest_token}/claim"

      expect(response).to have_http_status(:ok)
      expect(package.reload.submitter_id).to eq(other_user.id)
      expect(package.guest_token_revoked_at).to be_present
      expect(package.wine_package_events.exists?(event_type: "package_claimed")).to be(true)
    end

    it "rejects a second claim by another user" do
      sign_in other_user
      post "/api/v1/trade/guest_packages/#{guest_token}/claim"
      expect(response).to have_http_status(:ok)

      # The first claim revokes the token, so a second claim with the same
      # token is a uniform 404 (§Phase 5: token validity must not be probeable
      # — a revoked token must look exactly like an unknown one).
      sign_in editor
      post "/api/v1/trade/guest_packages/#{guest_token}/claim"
      expect(response).to have_http_status(:not_found)
    end

    it "never sets requested_by_id" do
      sign_in other_user
      post "/api/v1/trade/guest_packages/#{guest_token}/claim"
      expect(package.reload.requested_by_id).to be_nil
    end
  end

  describe "editorial assessment (Phase 7)" do
    let!(:package) do
      submit_trade_submission!
      WinePackage.order(:created_at).last
    end

    it "drives the editorial chain from per-wine decisions" do
      sign_in editor
      item = package.items.first

      patch "/api/v1/admin/trade/packages/#{package.id}/assess",
            params: { decisions: { item.id.to_s => "approved" } }, as: :json
      expect(response).to have_http_status(:ok)
      expect(package.reload.status).to eq("approved")

      # approve -> quote -> invoice -> paid chain
      post "/api/v1/admin/trade/packages/#{package.id}/quotes",
           params: { service_type: "review",
                     items: [{ wine_package_item_id: item.id, description: "Review",
                               quantity: 1, unit_price: "150.00" }],
                     subtotal: "150.00", tax: "0", total: "150.00" }, as: :json
      expect(response).to have_http_status(:created)
      quote = WinePackageQuote.order(:created_at).last

      post "/api/v1/admin/trade/packages/#{package.id}/quotes/#{quote.id}/send"
      expect(quote.reload.status).to eq("sent")

      post "/api/v1/admin/trade/packages/#{package.id}/quotes/#{quote.id}/accept"
      expect(response).to have_http_status(:created)
      expect(package.reload.status).to eq("invoiced")
      invoice = WinePackageInvoice.order(:created_at).last
      expect(invoice.invoice_number).to start_with("WW-")
    end

    it "supports partial approval" do
      # A two-wine package: the same submission carries both lines, so the
      # mixed decision lands on one package (not two separate submissions).
      two_wine_submission = valid_submission.deep_dup
      two_wine_submission[:wines] << {
        wine_name: "Blanco Reserva", vintage: 2020, region: "Rioja",
        grape_varieties: "Viura", volume_ml: 750
      }
      Trade::Submissions::Create.call(two_wine_submission)
      sign_in editor
      package = WinePackage.order(:created_at).last
      first, second = package.items.order(:id)

      patch "/api/v1/admin/trade/packages/#{package.id}/assess",
            params: { decisions: {
              first.id.to_s => "approved",
              second.id.to_s => { decision: "information_requested", note: "Send tech sheet" }
            } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(package.reload.status).to eq("partially_approved")
      expect(second.reload.item_status).to eq("information_requested")
    end

    it "forbids non-editors" do
      sign_in other_user
      patch "/api/v1/admin/trade/packages/#{package.id}/assess", params: { decisions: {} }, as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "payment and shipping gate (Phases 11/12)" do
    let!(:package) do
      submit_trade_submission!
      p = WinePackage.order(:created_at).last
      p.items.update_all(item_status: "approved")
      p.update!(status: "approved")
      quote = p.wine_package_quotes.create!(
        created_by: editor, service_type: "review",
        items: [{ "description" => "Review", "quantity" => 1, "unit_price" => 100 }],
        subtotal: 100, tax: 0, total: 100, status: "sent"
      )
      # The commercial chain is approved → quoted → invoiced (§Phase 10);
      # generating the invoice requires the package to be quoted already.
      p.update!(status: "quoted")
      quote.update!(status: "accepted")
      Trade::Invoices::GenerateFromQuote.call(quote, by: editor)
      p
    end
    let(:invoice) { package.wine_package_invoices.last }

    it "refuses shipping release before payment" do
      sign_in editor
      post "/api/v1/admin/trade/packages/#{package.id}/release_shipping"
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "releases shipping after the webhook settles the invoice" do
      Trade::Payments::HandleSettled.call(
        invoice: invoice, payment_intent_id: "pi_123", metadata: { "trade_invoice_id" => invoice.id }
      )
      expect(package.reload.status).to eq("paid")

      sign_in editor
      post "/api/v1/admin/trade/packages/#{package.id}/release_shipping"
      expect(response).to have_http_status(:ok)
      expect(package.reload.status).to eq("shipping_released")
    end

    it "allows an audited admin override of the payment gate" do
      # Overriding the payment gate is an Admin-only action (the Release
      # service refuses overrides from non-admins).
      sign_in admin
      post "/api/v1/admin/trade/packages/#{package.id}/release_shipping",
           params: { override: true, reason: "Paid by bank transfer" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(package.reload.shipping_override_reason).to eq("Paid by bank transfer")
    end

    it "records item receipt with condition" do
      sign_in editor
      Trade::Payments::HandleSettled.call(invoice: invoice)
      package.transition_to!("shipping_pending", actor: editor)
      package.release_shipping!(by: editor)
      package.transition_to!("in_transit", actor: editor)
      package.transition_to!("arrived", actor: editor)

      item = package.items.first
      patch "/api/v1/admin/trade/packages/#{package.id}/items/#{item.id}/receipt",
            params: { condition: "damaged", notes: "One bottle broken" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(item.reload.condition).to eq("damaged")
      expect(item.received_at).to be_present
    end
  end

  describe "messages on a trade submission" do
    let(:reader) do
      user_with_role("Reader", "Trade Reader", "trade-message-reader@example.com")
    end

    it "notifies the editorial team (in-app + email) for each message" do
      editor
      admin
      reader
      package = WinePackage.create!(
        source: "trade_submission",
        status: "editorial_pending",
        contact_snapshot: {
          "company_name" => "Bodega Ejemplo",
          "contact_name" => "Maria Ruiz",
          "email" => "maria@bodega-ejemplo.es",
          "country" => "Spain",
          "role" => "winery"
        },
        created_by: reader,
        submitter: reader
      )
      sign_in reader

      perform_enqueued_jobs do
        post "/api/v1/trade/packages/#{package.id}/messages",
             params: { body: "Hi, any update on my review request?" },
             as: :json
      end

      expect(response).to have_http_status(:created)

      message = WinePackageMessage.last
      expect(message.body).to eq("Hi, any update on my review request?")
      expect(message.sender).to eq(reader)
      expect(message.sender_type).to eq("submitter")
      expect(message.internal_note).to be(false)

      expect(package.wine_package_events.map(&:event_type))
        .to include("message_sent")

      notifications = editor.notifications
                               .where(notification_type: "trade_message_received",
                                      wine_package: package)
      expect(notifications.count).to eq(1)
      expect(notifications.first.delivered_at).to be_present
      expect(notifications.first.target_path).to eq("/admin/trade/packages/#{package.id}")
      expect(notifications.first.message)
        .to include("Hi, any update on my review request?")

      emails = ActionMailer::Base.deliveries.select do |mail|
        mail.subject.start_with?("New message on trade submission")
      end
      expect(emails.flat_map(&:to)).to contain_exactly(editor.email, admin.email)
    end
  end

  describe "admin messages on a trade submission" do
    let(:submitter_user) do
      user_with_role("Reader", "Maria Ruiz", "admin-msg-submitter@example.com")
    end

    def create_package
      WinePackage.create!(
        source: "trade_submission",
        status: "editorial_pending",
        contact_snapshot: {
          "company_name" => "Bodega Ejemplo",
          "contact_name" => "Maria Ruiz",
          "email" => "maria@bodega-ejemplo.es",
          "country" => "Spain",
          "role" => "winery"
        },
        created_by: submitter_user,
        submitter: submitter_user
      )
    end

    it "lets an editor reply and notifies the submitter (in-app + email)" do
      submitter_user
      package = create_package
      sign_in editor

      perform_enqueued_jobs do
        post "/api/v1/admin/trade/packages/#{package.id}/messages",
             params: { body: "Thanks — we are reviewing your Rioja this week." },
             as: :json
      end

      expect(response).to have_http_status(:created)

      message = WinePackageMessage.last
      expect(message.sender).to eq(editor)
      expect(message.sender_type).to eq("editor")
      expect(message.internal_note).to be(false)

      notification = submitter_user.notifications.find_by(
        notification_type: "trade_message_received", wine_package: package
      )
      expect(notification).to be_present
      expect(notification.delivered_at).to be_present
      expect(notification.target_path).to eq("/trade/my-packages/#{package.id}")
      expect(notification.message).to include("we are reviewing your Rioja")

      emails = ActionMailer::Base.deliveries.select do |mail|
        mail.subject.start_with?("New message on trade submission")
      end
      expect(emails.flat_map(&:to)).to include(submitter_user.email)
      # The editor who replied is not emailed about their own message.
      expect(emails.flat_map(&:to)).not_to include(editor.email)
    end

    it "lists the shared thread for staff" do
      submitter_user
      package = create_package
      package.wine_package_messages.create!(
        sender: submitter_user, sender_type: "submitter", body: "Any news?"
      )
      sign_in editor

      get "/api/v1/admin/trade/packages/#{package.id}/messages"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |m| m["body"] }).to include("Any news?")
    end

    it "lets the submitter read their own message thread" do
      submitter_user
      package = create_package
      package.wine_package_messages.create!(
        sender: submitter_user, sender_type: "submitter", body: "Any news?"
      )
      sign_in submitter_user

      get "/api/v1/admin/trade/packages/#{package.id}/messages"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |m| m["body"] }).to include("Any news?")
    end

    it "forbids non-staff accounts that are not the submitter" do
      submitter_user
      package = create_package
      sign_in other_user

      get "/api/v1/admin/trade/packages/#{package.id}/messages"

      expect(response).to have_http_status(:forbidden)
    end
  end
end