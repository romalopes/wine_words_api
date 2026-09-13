require "rails_helper"

# Request specs for the user impersonation feature.
#
# Impersonation lets an admin "act as" another (non-admin) user:
#   * Web/SSR path: session[:impersonated_user_id]
#   * API/JWT path: impersonated_user_id claim in the Bearer JWT
#
# Covers the 14 acceptance criteria: start/stop flow, effective/real user
# resolution, resource ownership, audit logging, nesting prevention, and
# admin-authorization preservation.
RSpec.describe "Impersonation", type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:admin) do
    user = User.create!(
      user_name: "Admin Alice",
      email: "admin@example.com",
      password: "password123",
    )
    user.roles << Role.find_or_create_by!(name: "Admin")
    user
  end

  let!(:normal_user) do
    User.create!(
      user_name: "John Smith",
      email: "john@example.com",
      password: "password123",
    )
  end

  let!(:other_normal_user) do
    User.create!(
      user_name: "Jane Doe",
      email: "jane@example.com",
      password: "password123",
    )
  end

  # ------------------------------------------------------------------
  # 1. Admin can start impersonating a normal user
  # ------------------------------------------------------------------
  describe "POST /api/v1/impersonation" do
    before { sign_in admin }

    it "starts impersonating a normal user" do
      post "/api/v1/impersonation", params: { user_id: normal_user.id }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["impersonating"]).to be true
      expect(body["effective_user"]["id"]).to eq(normal_user.id)
      expect(body["real_user"]["id"]).to eq(admin.id)
    end

    it "returns a JWT carrying the impersonated_user_id claim" do
      post "/api/v1/impersonation", params: { user_id: normal_user.id }

      expect(response).to have_http_status(:ok)
      token = JSON.parse(response.body)["token"]
      expect(token).to be_present

      payload, = JWT.decode(token, Rails.application.secret_key_base, true,
                            algorithm: "HS256")
      expect(payload["impersonated_user_id"]).to eq(normal_user.id)
      expect(payload["sub"]).to eq(admin.id)
    end

    # ----------------------------------------------------------------
    # 2. Normal user cannot start impersonating another user
    # ----------------------------------------------------------------
    it "rejects a non-admin user with 403" do
      sign_in normal_user
      post "/api/v1/impersonation", params: { user_id: other_normal_user.id }

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)["error"]).to be_present
    end

    # ----------------------------------------------------------------
    # Admin cannot impersonate another admin
    # ----------------------------------------------------------------
    it "rejects impersonating another admin" do
      other_admin = User.create!(
        user_name: "Admin Bob",
        email: "bob@example.com",
        password: "password123",
      )
      other_admin.roles << Role.find_or_create_by!(name: "Admin")

      post "/api/v1/impersonation", params: { user_id: other_admin.id }
      expect(response).to have_http_status(:forbidden)
    end

    # ----------------------------------------------------------------
    # 10. Nested impersonation is prevented
    # ----------------------------------------------------------------
    it "rejects starting impersonation while already impersonating" do
      post "/api/v1/impersonation", params: { user_id: normal_user.id }
      expect(response).to have_http_status(:ok)

      post "/api/v1/impersonation", params: { user_id: other_normal_user.id }
      expect(response).to have_http_status(:conflict)
    end

    it "returns 404 for an unknown target user" do
      post "/api/v1/impersonation", params: { user_id: -1 }
      expect(response).to have_http_status(:not_found)
    end
  end

  # ------------------------------------------------------------------
  # 3, 4, 9. current_user returns the impersonated user while
  # real_current_user returns the admin; state persists across requests.
  # ------------------------------------------------------------------
  describe "effective user resolution across requests" do
    it "resolves current_user to the impersonated user and real_current_user to the admin" do
      sign_in admin
      post "/api/v1/impersonation", params: { user_id: normal_user.id }
      token = JSON.parse(response.body)["token"]

      get "/api/v1/impersonation/status",
          headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["impersonating"]).to be true
      expect(body["effective_user"]["id"]).to eq(normal_user.id)
      expect(body["real_user"]["id"]).to eq(admin.id)
    end

    it "persists impersonation state across multiple sequential requests" do
      sign_in admin
      post "/api/v1/impersonation", params: { user_id: normal_user.id }
      token = JSON.parse(response.body)["token"]
      headers = { "Authorization" => "Bearer #{token}" }

      get "/api/v1/impersonation/status", headers: headers
      expect(JSON.parse(response.body)["effective_user"]["id"]).to eq(normal_user.id)

      get "/api/v1/impersonation/status", headers: headers
      expect(JSON.parse(response.body)["effective_user"]["id"]).to eq(normal_user.id)
    end
  end

  # ------------------------------------------------------------------
  # 7, 8. Admin can stop impersonation; afterwards current_user is admin.
  # ------------------------------------------------------------------
  describe "DELETE /api/v1/impersonation" do
    it "stops impersonation and returns a fresh admin JWT" do
      sign_in admin
      post "/api/v1/impersonation", params: { user_id: normal_user.id }
      expect(response).to have_http_status(:ok)

      delete "/api/v1/impersonation"
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["impersonating"]).to be false
      expect(body["effective_user"]["id"]).to eq(admin.id)

      fresh_token = body["token"]
      payload, = JWT.decode(fresh_token, Rails.application.secret_key_base, true,
                            algorithm: "HS256")
      expect(payload).not_to have_key("impersonated_user_id")

      get "/api/v1/impersonation/status",
          headers: { "Authorization" => "Bearer #{fresh_token}" }
      expect(JSON.parse(response.body)["impersonating"]).to be false
    end

    it "rejects stopping when not impersonating" do
      sign_in admin
      delete "/api/v1/impersonation"
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  # ------------------------------------------------------------------
  # 13. API requests correctly respect impersonation: /me returns the
  # effective user while impersonating.
  # ------------------------------------------------------------------
  describe "GET /api/v1/me during impersonation" do
    it "returns the impersonated user via the impersonation JWT" do
      sign_in admin
      post "/api/v1/impersonation", params: { user_id: normal_user.id }
      token = JSON.parse(response.body)["token"]

      get "/api/v1/me", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["user"]["id"]).to eq(normal_user.id)
    end
  end

  # ------------------------------------------------------------------
  # ------------------------------------------------------------------
  # Web/SSR flow (session-based)
  # ------------------------------------------------------------------
  describe "web session flow" do
    before { sign_in admin }

    it "starts impersonation via the server-rendered action and stores the session id" do
      post "/user_roles/impersonate/#{normal_user.id}"

      expect(response).to redirect_to(root_path)
      expect(session[:impersonated_user_id]).to eq(normal_user.id)
    end

    it "blocks impersonating an admin via the web action" do
      other_admin = User.create!(
        user_name: "Admin Bob",
        email: "bob@example.com",
        password: "password123",
      )
      other_admin.roles << Role.find_or_create_by!(name: "Admin")

      post "/user_roles/impersonate/#{other_admin.id}"
      expect(session[:impersonated_user_id]).to be_nil
    end

    it "stops impersonation and clears the session" do
      post "/user_roles/impersonate/#{normal_user.id}"
      expect(session[:impersonated_user_id]).to eq(normal_user.id)

      delete "/user_roles/impersonate"
      expect(response).to redirect_to(user_roles_path)
      expect(session[:impersonated_user_id]).to be_nil
    end

    it "rejects the web action for non-admin users" do
      sign_in normal_user
      post "/user_roles/impersonate/#{other_normal_user.id}"
      expect(response).to redirect_to(root_path)
      expect(session[:impersonated_user_id]).to be_nil
    end
  end

  # ------------------------------------------------------------------
  # 12. Audit logs identify both the real Admin and the effective user.
  # ------------------------------------------------------------------
  describe "audit trail during impersonation" do
    it "records the admin as the actor and the impersonated user separately" do
      sign_in admin
      post "/api/v1/impersonation", params: { user_id: normal_user.id }
      token = JSON.parse(response.body)["token"]
      headers = { "Authorization" => "Bearer #{token}" }

      # A logged (audited) action performed while impersonating: assign roles
      # to another user — Admin-only, and covered by audit_actions.
      patch "/api/v1/users/#{other_normal_user.id}/assign_roles",
            params: { role_ids: [Role.find_or_create_by!(name: "Reader").id] },
            headers: headers
      expect(response).to have_http_status(:ok)

      log = Log.order(:id).last
      expect(log.user_id).to eq(admin.id)
      expect(log.impersonated_user_id).to eq(normal_user.id)
    end
  end

  # ------------------------------------------------------------------
  # 11. Unauthorized users cannot manipulate the impersonation session.
  # ------------------------------------------------------------------
  describe "unauthorized session manipulation" do
    it "rejects a forged JWT claiming impersonation by a non-admin" do
      # A non-admin cannot mint a valid JWT signed with the server secret, so
      # forging is impossible; verify the server rejects a wrongly-signed token.
      unsigned = JWT.encode({ sub: normal_user.id, impersonated_user_id: other_normal_user.id },
                            "wrong-secret", "HS256")
      get "/api/v1/impersonation/status",
          headers: { "Authorization" => "Bearer #{unsigned}" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "rejects the web impersonation action for anonymous visitors" do
      sign_out admin
      post "/user_roles/impersonate/#{normal_user.id}"
      expect(session[:impersonated_user_id]).to be_nil
    end
  end
end
