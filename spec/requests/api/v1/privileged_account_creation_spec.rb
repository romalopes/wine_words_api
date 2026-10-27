require "rails_helper"

RSpec.describe "Privileged account creation", type: :request do
  def user_with_role(role_name)
    User.create!(
      first_name: role_name,
      last_name: "Actor",
      email: "#{role_name.downcase}-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      roles: [ Role.find_or_create_by!(name: role_name) ]
    )
  end

  let(:admin) { user_with_role("Admin") }
  let(:editor) { user_with_role("Editor") }
  let(:reader) { user_with_role("Reader") }
  let(:reader_role) { Role.find_or_create_by!(name: "Reader") }
  let(:reviewer_role) { Role.find_or_create_by!(name: "Reviewer") }
  let(:editor_role) { Role.find_or_create_by!(name: "Editor") }
  let(:admin_role) { Role.find_or_create_by!(name: "Admin") }

  def create_account(actor, attributes)
    sign_in actor
    post "/api/v1/users", params: { user: attributes }, as: :json
  end

  it "lets an admin create an unclaimed passwordless account with optional email" do
    create_account(admin, first_name: "Ada", last_name: "Lovelace", email: nil, role_ids: [ reader_role.id ])

    expect(response).to have_http_status(:created)
    created = User.find(JSON.parse(response.body).fetch("id"))
    expect(created).to be_unclaimed
    expect(created.email).to be_nil
    expect(created.encrypted_password).to be_blank
    expect(created.roles).to contain_exactly(reader_role)
  end

  it "lets an editor create Reader and Reviewer accounts" do
    create_account(editor, first_name: "Editorial", last_name: "Reviewer", email: "reviewer@example.com",
                           role_ids: [ reviewer_role.id, reader_role.id ])

    expect(response).to have_http_status(:created)
    expect(User.find(JSON.parse(response.body).fetch("id")).role_names).to contain_exactly("Reader", "Reviewer")
  end

  it "prevents editors from assigning Editor or Admin and admins from assigning Admin" do
    create_account(editor, first_name: "Bad", last_name: "Elevation", role_ids: [ editor_role.id ])
    expect(response).to have_http_status(:forbidden)

    sign_out editor
    create_account(admin, first_name: "Another", last_name: "Elevation", role_ids: [ admin_role.id ])
    expect(response).to have_http_status(:forbidden)
  end

  it "rejects non-managers" do
    create_account(reader, first_name: "No", last_name: "Access", role_ids: [ reader_role.id ])
    expect(response).to have_http_status(:forbidden)
  end

  it "creates producer memberships transactionally with the server-derived actor" do
    producer = Producer.create!(name: "Invitation Estate #{SecureRandom.hex(3)}")
    create_account(admin, first_name: "Producer", last_name: "Owner", role_ids: [ reader_role.id ],
                          producer_memberships: [ { producer_id: producer.id, membership_type: "owner",
                                                    created_by_id: reader.id } ])

    expect(response).to have_http_status(:created)
    membership = User.find(JSON.parse(response.body).fetch("id")).producer_memberships.sole
    expect(membership.producer).to eq(producer)
    expect(membership.created_by).to eq(admin)
  end

  it "rolls back the user when a nested membership is invalid" do
    admin
    expect {
      create_account(admin, first_name: "Invalid", last_name: "Membership", role_ids: [ reader_role.id ],
                            producer_memberships: [ { producer_id: -1, membership_type: "owner" } ])
    }.not_to change(User, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "normalizes email, rejects duplicates, and ignores lifecycle/password mass assignment" do
    User.create!(email: "existing@example.com", password: "password123")
    create_account(admin, first_name: "Duplicate", last_name: "Email", email: " EXISTING@example.com ",
                          role_ids: [ reader_role.id ])
    expect(response).to have_http_status(:unprocessable_entity)

    sign_out admin
    create_account(admin, first_name: "Safe", last_name: "Fields", email: "safe@example.com",
                          role_ids: [ reader_role.id ], account_status: "active", password: "attacker-password")
    created = User.find(JSON.parse(response.body).fetch("id"))
    expect(created).to be_unclaimed
    expect(created.encrypted_password).to be_blank
  end

  it "lets managers add an invitation email only while the account is unclaimed" do
    target = User.create!(first_name: "Email", last_name: "Later", account_status: :unclaimed,
                          roles: [ reader_role ])
    sign_in editor
    patch "/api/v1/users/#{target.id}/invitation_email",
          params: { user: { email: " Later@Example.com " } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(target.reload.email).to eq("later@example.com")

    target.update!(password: "password123", account_status: :active)
    patch "/api/v1/users/#{target.id}/invitation_email",
          params: { user: { email: "other@example.com" } }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
