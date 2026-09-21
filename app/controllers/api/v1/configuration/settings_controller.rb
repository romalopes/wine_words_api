# Admin-only CRUD for custom (user-added) app_settings rows, nested under
# /api/v1/configuration/settings. The three built-in keys (logs_enabled,
# use_test_email, test_email) are managed exclusively through the parent
# configuration endpoint and are explicitly excluded here.
module Api::V1::Configuration
  class SettingsController < ApplicationController
    before_action :authenticate_admin!
    before_action :find_setting, only: [:update, :destroy]

    RESERVED_KEYS = %w[logs_enabled use_test_email test_email].freeze

    # GET /api/v1/configuration/settings
    def index
      settings = AppSetting.order(:key).map { |s| serialized(s) }
      render json: settings
    end

    # POST /api/v1/configuration/settings
    def create
      key = params.fetch(:key, "").strip
      value = params.fetch(:value, "").to_s

      raise(ActiveRecord::RecordInvalid, AppSetting.new(key: key, value: value)) if key.empty?
      raise(ActiveRecord::RecordInvalid, AppSetting.new(key: key, value: value)) if RESERVED_KEYS.include?(key)

      setting = AppSetting.new(key: key, value: value)
      setting.save!
      render json: serialized(setting), status: :created
    end

    # PATCH /api/v1/configuration/settings/:id
    def update
      new_value = params.fetch(:value, @setting.value).to_s
      @setting.update!(value: new_value)
      render json: serialized(@setting)
    end

    # DELETE /api/v1/configuration/settings/:id
    def destroy
      raise(ActiveRecord::RecordInvalid, @setting) if RESERVED_KEYS.include?(@setting.key)
      @setting.destroy
      render json: { key: @setting.key }
    end

    private

    def find_setting
      @setting = AppSetting.find(params.fetch(:id))
    end

    def serialized(setting)
      {
        id: setting.id,
        key: setting.key,
        value: setting.value,
        updated_at: setting.updated_at.iso8601(3)
      }
    end
  end
end