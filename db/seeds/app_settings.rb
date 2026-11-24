# frozen_string_literal: true
#
# Idempotent seed for AppSetting records.
# Loaded from db/seeds.rb (or run directly: bin/rails runner db/seeds/app_settings.rb)
#
# Each setting uses find_or_initialize_by(key:) so it's safe to re-run.
# Built-in defaults from AppSetting::DEFAULTS are used when no value is set.

puts "Seeding AppSettings..."

# Core feature flags and infrastructure
{
  # Logging & diagnostics
  "logs_enabled" => true,
  "analytics_diagnostics_enabled" => false,
  "analytics_diagnostics_email" => "analytics@winewords.com",
  "analytics_diagnostics_frequency" => "weekly",

  # Email & mail transport
  "mail_transport" => "auto",
  "use_test_email" => true,
  # "test_email" => "test@winewords.com",
  "test_email" => "support@beachvolleyballhub.com",

  # Account lifecycle
  "hard_delete_enabled" => true,

  # Follow notifications (IDENTITY_192)
  "follow_notifications_enabled" => true,

  # Wine review fee (IDENTITY_214)
  "wine_review_fee_amount" => "50.00",
  "wine_review_fee_currency" => "AUD",

  # Invoice settings (IDENTITY_214 Phase 12)
  "invoice_gst_rate" => "0.10",
  # "invoice_from_email" => "billing@winewords.com",
  "invoice_from_email" => ENV["INVOICE_FROM_EMAIL"].presence || ENV["MAIL_FROM"] || "support@beachvolleyball.com",

  # Sample shipping address (IDENTITY_206 Phase 12)
  # Where submitters send their wine samples - shown in shipping instructions email
  # "sample_shipping_address" => "Wine Words Sample Reception\nLevel 1, 123 Example Street\nSydney NSW 2000\nAustralia",
  "sample_shipping_address" => "Wine Words Sample Reception\n3/142 Coogee Bay Road\nCoogee NSW 2034\nAustralia",

  # Invoice payment bank details (IDENTITY_214 Phase 12)
  # Shown in the invoice PDF payment instructions section
  "invoice_bank_name" => "Commonwealth Bank of Australia",
  "invoice_account_name" => "Wine Words Pty Ltd",
  "invoice_bsb" => "062-000",
  "invoice_account_number" => "1234 5678",

  # Taste parameters visibility (IDENTITY_193)
  "show_taste_parameters" => "true",
}.each do |key, value|
  setting = AppSetting.find_or_initialize_by(key: key)
  setting.value = value.to_s
  setting.save!
  # Verify the value was persisted
  reloaded = AppSetting.find_by(key: key)
  if reloaded&.value == value.to_s
    puts "  Set #{key} = #{value} ✓"
  else
    raise "Failed to persist #{key}: expected '#{value}', got '#{reloaded&.value}'"
  end
end

# Set test_email from MAIL_REPLY_TO env if present (dev convenience)
if ENV["MAIL_REPLY_TO"].present?
  setting = AppSetting.find_or_initialize_by(key: "test_email")
  setting.value = ENV["MAIL_REPLY_TO"]
  setting.save!
  # Verify the value was persisted
  reloaded = AppSetting.find_by(key: "test_email")
  if reloaded&.value == ENV["MAIL_REPLY_TO"]
    puts "  Set test_email from MAIL_REPLY_TO = #{ENV['MAIL_REPLY_TO']} ✓"
  else
    raise "Failed to persist test_email from MAIL_REPLY_TO"
  end
end

puts "AppSettings seeded successfully! (#{AppSetting.count} total)"