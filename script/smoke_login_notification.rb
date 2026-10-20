# Smoke test for the login-notification pipeline.
#
#   bin/rails runner script/smoke_login_notification.rb
#
# Covers the two reported failures:
#   1. ActiveJob::SerializationError: Unsupported argument type: LoginDetails
#      -> the job now passes a plain hash to the mailer; MailDeliveryJob
#         arguments must be plain-JSON serialisable.
#   2. RuntimeError: Couldn't determine a delay based on :exponentially_longer
#      -> Rails 8.1 renamed that strategy to :polynomial_longer.
#
# Uses the :test delivery method and the :test queue adapter so nothing is
# actually sent and no real queue is touched.

ENV["IP2LOCATION_API_KEY"] = nil # force "Unknown" location, no network call

user = User.order(:id).first
raise "no users in the database" if user.nil?

# Simulate what LoginNotifier puts in the job payload.
details_hash = LoginDetails.new(
  ip_address: "203.0.113.10",
  user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/604.1",
  browser: "Safari",
  browser_version: "17.0",
  os: "macOS 10.15.7",
  device: "Other",
  location: "Unknown",
  login_method: "password",
  logged_in_at: Time.current,
  mobile: false
).serializable_hash

puts "1. details_hash is plain-JSON serialisable..."
ActiveJob::Arguments.serialize([user.id, details_hash])
puts "   OK"

puts "2. :polynomially_longer is a valid retry delay..."
job = NewLoginNotificationJob.new(user.id, details_hash)
job.executions = 1
delay = job.send(:determine_delay, seconds_or_duration_or_algorithm: :polynomially_longer, executions: job.executions)
raise "delay must be positive, got #{delay.inspect}" unless delay.respond_to?(:positive?) && delay.positive?
puts "   OK (delay #{delay.round(1)}s after execution 1)"

puts "3. Mailer rehydrates LoginDetails from the hash..."
ActionMailer::Base.delivery_method = :test
ActionMailer::Base.deliveries.clear
message = SecurityMailer.new_login_email(user, details_hash).message
# For multipart/alternative messages the content lives in the parts, not in
# `message.body` (which is empty for multipart messages).
text_body = message.text_part&.body.to_s
html_body = message.html_part&.body.to_s
puts "   DEBUG parts=#{message.parts.map(&:content_type).inspect} text_len=#{text_body.length} html_len=#{html_body.length}"
body = text_body + html_body
%w[203.0.113.10 Safari 17.0 password].each do |needle|
  raise "mail body missing '#{needle}'" unless body.include?(needle)
end
raise "mail body must not contain an IP in the location slot" if text_body.include?("Location:         203")
puts "   OK (subject: #{message.subject.inspect})"

puts "4. Job round-trip: perform_now -> deliver_later serialisation -> delivery..."
ActiveJob::Base.queue_adapter = :test
NewLoginNotificationJob.perform_now(user.id, details_hash)
enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs
raise "expected a MailDeliveryJob to be enqueued, got #{enqueued.inspect}" if enqueued.empty?
raise "wrong job class: #{enqueued.first[:job]}" unless enqueued.first[:job] == ActionMailer::MailDeliveryJob

# Drain the test adapter: each stored entry is job.serialize plus symbol
# aliases (:job, :args, :queue) added by the TestAdapter. The original
# string keys ("job_class", "arguments", "queue_name") are what
# ActiveJob::Base.execute needs — the exact path that raised
# "Unsupported argument type: LoginDetails".
while (j = ActiveJob::Base.queue_adapter.enqueued_jobs.shift)
  ActiveJob::Base.execute(j)
end
raise "no mail delivered, deliveries: #{ActionMailer::Base.deliveries.inspect}" if ActionMailer::Base.deliveries.empty?
raise "wrong recipient: #{ActionMailer::Base.deliveries.first.to.inspect}" unless ActionMailer::Base.deliveries.first.to == [user.email]

puts "   OK (delivered to #{ActionMailer::Base.deliveries.first.to.join(', ')})"

puts "ALL SMOKE TESTS PASSED"
