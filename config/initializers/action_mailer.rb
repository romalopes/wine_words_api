# frozen_string_literal: true

# Register the global test‑email interceptor once the application is fully
# initialized (so that AppSetting is loadable and the database exists).
Rails.application.config.after_initialize do
  # The interceptor file is autoloaded from app/mailers/
  ActionMailer::Base.register_interceptor(TestEmailInterceptor)
end