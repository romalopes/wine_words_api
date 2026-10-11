#!/usr/bin/env ruby
# Phase 12 Performance Benchmarks
# Run: bundle exec ruby bin/phase12_performance.rb

require_relative "../config/environment"
require "benchmark"

# Setup test data
user = User.find_or_create_by!(email: "perf@test.com") do |u|
  u.password = "password123"
  u.first_name = "Perf"
  u.last_name = "User"
  u.email_verified_at = Time.current
end
reviewer_role = Role.find_or_create_by!(name: "Reviewer")
user.roles << reviewer_role unless user.roles.exists?(name: "Reviewer")
article = Article.find_or_create_by!(title: "Perf Test Article", user: user) do |a|
  a.body = "Body"
  a.status = "published"
  a.published_at = Time.current
end

# Create some events
100.times do |i|
  Analytics::Event.create!(
    viewable_type: "Article",
    viewable_id: article.id,
    identity: "account:#{user.id}",
    visitor_key: SecureRandom.hex(32),
    viewed_at: Time.current - rand(30).days,
    source: "direct",
    accepted: true
  )
end

scope = Analytics::Scope.new(user)
period_result = Analytics::Period.resolve({period: "30d"}, max_range_days: 400, history_from: Analytics::Event.accepted.minimum(:viewed_at), history_to: Analytics::Event.accepted.maximum(:viewed_at))
period = period_result.first

if period.nil?
  puts "Failed to resolve period: #{period_result}"
  exit 1
end

output = []

output << "=== EXPLAIN ANALYZE for Summary ==="
output << "EXPLAIN ANALYZE " + Analytics::Event.accepted.where(viewable_type: "Article", viewable_id: article.id).in_window(period.start_at, period.end_at).to_sql
output << "EXPLAIN ANALYZE " + Analytics::Event.accepted.where(viewable_type: "Article", viewable_id: article.id).in_window(period.start_at, period.end_at).select(:identity).distinct.to_sql

output << "=== EXPLAIN ANALYZE for TopContent ==="
output << "EXPLAIN ANALYZE " + Article.where(id: article.id).to_sql

output << "=== Benchmark Summary (100 iterations) ==="
times = []
100.times { times << Benchmark.realtime { Analytics::Summary.call(scope, period, {}) } }
output << "Summary: min=#{(times.min*1000).round(2)}ms avg=#{(times.sum/times.size*1000).round(2)}ms max=#{(times.max*1000).round(2)}ms p95=#{(times.sort[(times.size*0.95).floor]*1000).round(2)}ms"

output << "=== Benchmark TopContent (100 iterations) ==="
times = []
100.times { times << Benchmark.realtime { Analytics::TopContent.call(scope, period, {}) } }
output << "TopContent: min=#{(times.min*1000).round(2)}ms avg=#{(times.sum/times.size*1000).round(2)}ms max=#{(times.max*1000).round(2)}ms p95=#{(times.sort[(times.size*0.95).floor]*1000).round(2)}ms"

output << "=== Benchmark ContentDetail (100 iterations) ==="
times = []
100.times { times << Benchmark.realtime { Analytics::ContentDetail.call(scope, period, "Article", article.id, {}) } }
output << "ContentDetail: min=#{(times.min*1000).round(2)}ms avg=#{(times.sum/times.size*1000).round(2)}ms max=#{(times.max*1000).round(2)}ms p95=#{(times.sort[(times.size*0.95).floor]*1000).round(2)}ms"

output << "=== Benchmark Timeseries (100 iterations) ==="
times = []
100.times { times << Benchmark.realtime { Analytics::Timeseries.call(scope, period, {grouping: "day"}) } }
output << "Timeseries: min=#{(times.min*1000).round(2)}ms avg=#{(times.sum/times.size*1000).round(2)}ms max=#{(times.max*1000).round(2)}ms p95=#{(times.sort[(times.size*0.95).floor]*1000).round(2)}ms"

output << "=== Benchmark WineInsights (100 iterations) ==="
times = []
100.times { times << Benchmark.realtime { Analytics::WineInsights.call(scope, period, {}) } }
output << "WineInsights: min=#{(times.min*1000).round(2)}ms avg=#{(times.sum/times.size*1000).round(2)}ms max=#{(times.max*1000).round(2)}ms p95=#{(times.sort[(times.size*0.95).floor]*1000).round(2)}ms"

# Write to file
File.write("docs/IDENTITY_172-Content Analytics/phase12-evidence/performance-benchmarks.txt", output.join("\n"))
puts "Done! Results written to phase12-evidence/performance-benchmarks.txt"