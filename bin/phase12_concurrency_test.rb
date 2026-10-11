#!/usr/bin/env ruby
# Phase 12 Concurrency Test - Rolling Deduplication
# Run: bundle exec ruby bin/phase12_concurrency_test.rb

require_relative "../config/environment"

# Clean up first
Analytics::Event.delete_all

# Create a user who is NOT the author
author = User.find_or_create_by!(email: "author@test.com") do |u|
  u.password = "password123"
  u.first_name = "Author"
  u.last_name = "User"
  u.email_verified_at = Time.current
end

user = User.find_or_create_by!(email: "perf@test.com") do |u|
  u.password = "password123"
  u.first_name = "Perf"
  u.last_name = "User"
  u.email_verified_at = Time.current
end
reviewer_role = Role.find_or_create_by!(name: "Reviewer")
user.roles << reviewer_role unless user.roles.exists?(name: "Reviewer")

article = Article.find_or_create_by!(title: "Perf Test Article", user: author) do |a|
  a.body = "Body"
  a.status = "published"
  a.published_at = Time.current
end

content_type = "Article"
content_id = article.id
identity = "account:#{user.id}"
source = "direct"

results = { accepted: 0, rejected: 0, errors: [] }
mutex = Mutex.new

threads = 5.times.map do
  Thread.new do
    begin
      result = Analytics::Ingest.call(
        event_type: "view",
        content_type: content_type,
        content_id: content_id,
        identity: identity,
        source: source,
        referrer: "https://example.com",
        viewport: "1920x1080",
        current_user: user
      )
      mutex.synchronize do
        if result.accepted
          results[:accepted] += 1
        else
          results[:rejected] += 1
        end
      end
    rescue => e
      mutex.synchronize { results[:errors] << e.message }
    end
  end
end

threads.each(&:join)

output = []
output << "Results: #{results}"
output << "Expected: accepted=1, rejected=4"
if results[:accepted] == 1 && results[:rejected] == 4 && results[:errors].empty?
  output << "PASS: Rolling deduplication working correctly"
else
  output << "FAIL: Rolling deduplication NOT working correctly"
end

# Write to file
File.write("docs/IDENTITY_172-Content Analytics/phase12-evidence/concurrency-dedup-run1.txt", output.join("\n"))
puts output.join("\n")