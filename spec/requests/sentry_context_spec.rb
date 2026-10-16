require 'rails_helper'
require 'devise'
require 'jwt'

RSpec.describe 'Sentry context', type: :request do
  let(:user) do
    User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    )
  end

  def bearer_for(user)
    now = Time.current.to_i
    payload = user.jwt_payload.merge(
      "sub" => user.id,
      "scp" => "user",
      "iat" => now,
      "exp" => now + 1.hour.to_i,
      "jti" => SecureRandom.uuid
    )
    secret = Devise::JWT.config.secret.presence || Rails.application.secret_key_base
    algorithm = Devise::JWT.config.algorithm || "HS256"
    "Bearer #{JWT.encode(payload, secret, algorithm)}"
  end

  before do
    # Initialize Sentry with test configuration using a dummy DSN
    Sentry.init do |config|
      config.dsn = 'https://test@example.com/123'
    end
  end

  after do
    # Clear scope if Sentry is initialized
    if Sentry.respond_to?(:initialized?) && Sentry.initialized?
      if Sentry.respond_to?(:get_current_scope)
        scope = Sentry.get_current_scope
        if scope.respond_to?(:clear)
          scope.clear
        end
      end
    end
  end

  describe 'set_sentry_context' do
    context 'when user is authenticated' do
      before do
        header = bearer_for(user)
        get '/api/v1/health', headers: { "Authorization" => header }
        puts "Response status: #{response.status}" if defined?(response)
      end

      it 'sets user context in Sentry' do
        scope = Sentry.get_current_scope
        expect(scope.user).not_to be_nil
        expect(scope.user[:id]).to eq(user.id)
      end

      it 'sets user_id tag as string' do
        scope = Sentry.get_current_scope
        expect(scope.tags).not_to be_nil
        expect(scope.tags['user_id']).to eq(user.id.to_s)
      end

      it 'sets account_tier tag' do
        scope = Sentry.get_current_scope
        expect(scope.tags).not_to be_nil
        expect(scope.tags['account_tier']).to be_present
      end
    end

    context 'when user is not authenticated' do
      before do
        get '/api/v1/health/detailed'
      end

      it 'clears user context' do
        scope = Sentry.get_current_scope
        expect(scope.user).to eq({})
      end

      it 'clears tags' do
        scope = Sentry.get_current_scope
        expect(scope.tags).to eq({})
      end

    end
  end
end
