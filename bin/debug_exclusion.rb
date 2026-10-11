#!/usr/bin/env ruby
require_relative "../config/environment"

Analytics::Event.delete_all

user = User.find_by(email: "perf@test.com")
article = Article.find_by(title: "Perf Test Article")

puts "User: #{user.id}, roles: #{user.roles.pluck(:name)}"
puts "Article: #{article.id}, user_id: #{article.user_id}"
puts "Is author: #{user.author_of?('Article', article.id)}"

# Test the actual call
result = Analytics::Ingest.call(
  event_type: "view",
  content_type: "Article",
  content_id: article.id,
  identity: "account:#{user.id}",
  source: "direct",
  referrer: "https://example.com",
  viewport: "1920x1080",
  current_user: user
)

puts "Result: #{result.inspect}"
puts "Accepted: #{result.accepted}"
puts "Duplicate: #{result.duplicate}"
puts "Reason: #{result.reason}"
puts "Error code: #{result.error_code}"

# Check if event was created
event = Analytics::Event.last
if event
  puts "Event created: id=#{event.id}, accepted=#{event.accepted}, rejection_reason=#{event.rejection_reason}"
else
  puts "No event created"
end