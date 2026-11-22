require "rails_helper"

# Regression: the public trade-submission intake claimed Turnstile protection
# but never verified it (security audit issue #23, Medium).
RSpec.describe "Trade submission Turnstile gate", type: :request do
  let(:payload) do
    {
      contact_snapshot: { contact_name: "Audit Bot", email: "audit@example.com" },
      wines: [ { wine_name: "Audit Wine", vintage: 2020, quantity: 1 } ]
    }
  end

  let(:pass_result) { Turnstile::Verifier::Result.new(success: true, error_codes: []) }
  let(:fail_result) { Turnstile::Verifier::Result.new(success: false, error_codes: [ "bad-token" ]) }

  it "rejects the submission and creates nothing when Turnstile fails" do
    allow(Turnstile::Verifier).to receive(:call).and_return(fail_result)

    expect {
      post "/api/v1/trade/submissions", params: payload, as: :json
    }.not_to change(WinePackage, :count)

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "accepts the submission when Turnstile passes" do
    allow(Turnstile::Verifier).to receive(:call).and_return(pass_result)

    expect {
      post "/api/v1/trade/submissions",
           params: payload.merge(turnstile_token: "tok"), as: :json
    }.to change(WinePackage, :count).by(1)

    expect(response).to have_http_status(:created)
  end
end
