# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.config.content_security_policy do |policy|
  policy.default_src :self, :https
  policy.font_src    :self, :https, :data
  policy.img_src     :self, :https, :data
  policy.object_src  :none
  policy.script_src  :self, :https, :unsafe_inline, :unsafe_eval
  policy.style_src   :self, :https, :unsafe_inline
  policy.connect_src :self, :https, :data,
    "https://hagen.challenges.cloudflare.com",
    "https://brunhild.challenges.cloudflare.com",
    "https://*.alg13.dnstest.challenges.cloudflare.com",
    "https://*.mldsa44.dnstest.challenges.cloudflare.com",
    "https://dnstest.dev",
    "https://ca2.cloudflarecaptcha.com",
    "https://ca1.cloudflarecaptcha.com"
  policy.frame_src   :self,
    "https://hagen.challenges.cloudflare.com",
    "https://brunhild.challenges.cloudflare.com",
    "https://*.alg13.dnstest.challenges.cloudflare.com",
    "https://*.mldsa44.dnstest.challenges.cloudflare.com",
    "https://dnstest.dev",
    "https://ca2.cloudflarecaptcha.com",
    "https://ca1.cloudflarecaptcha.com"
  policy.form_action :self

  # Specify URI for violation reports
  # policy.report_uri "/csp-violation-report-endpoint"
end

# Generate session nonces for permitted importmap, inline scripts, and inline styles.
Rails.application.config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
Rails.application.config.content_security_policy_nonce_directives = %w(script-src style-src)

# Report violations without enforcing the policy.
# Rails.application.config.content_security_policy_report_only = true