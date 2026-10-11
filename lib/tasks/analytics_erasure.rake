# frozen_string_literal: true

# Erasure rake tasks (Phase 11).
#
# Usage:
#   rake analytics:erasure:account[account_id]      # Erase all events for an account
#   rake analytics:erasure:visitor[visitor_id]      # Erase all events for a visitor
#   rake analytics:erasure:identity["account:42"]   # Erase by full identity string
#
namespace :analytics do
  namespace :erasure do
    desc "Erase all analytics events for an account (anonymize + clear visitor_key)"
    task :account, [:account_id] => :environment do |t, args|
      account_id = args[:account_id]&.to_i
      unless account_id&.positive?
        puts "Error: account_id is required and must be a positive integer"
        puts "Usage: rake analytics:erasure:account[42]"
        exit 1
      end

      puts "=== Analytics Erasure: Account ##{account_id} ==="
      puts ""

      count = Analytics::Event.anonymize_account!(account_id)
      puts "Anonymized #{count} events for account:#{account_id}"
      puts "Identity changed to: visitor:erased-#{account_id}"
      puts "visitor_key cleared for all affected events"
      puts ""
      puts "ERASURE COMPLETE"
    end

    desc "Erase all analytics events for a visitor (anonymize + clear visitor_key)"
    task :visitor, [:visitor_id] => :environment do |t, args|
      visitor_id = args[:visitor_id]&.to_s
      unless visitor_id.present? && visitor_id.match?(/\A[0-9a-f-]{36}\z/i)
        puts "Error: visitor_id is required and must be a valid UUID"
        puts "Usage: rake analytics:erasure:visitor[550e8400-e29b-41d4-a716-446655440000]"
        exit 1
      end

      puts "=== Analytics Erasure: Visitor #{visitor_id} ==="
      puts ""

      count = Analytics::Event.anonymize_visitor!(visitor_id)
      puts "Anonymized #{count} events for visitor:#{visitor_id}"
      puts "Identity changed to: visitor:erased-#{visitor_id}"
      puts "visitor_key cleared for all affected events"
      puts ""
      puts "ERASURE COMPLETE"
    end

    desc "Erase all analytics events by full identity string"
    task :identity, [:identity] => :environment do |t, args|
      identity = args[:identity]&.to_s
      unless identity.present? && identity.match?(/\A(account:\d+|visitor:[0-9a-f-]{36})\z/i)
        puts "Error: identity is required and must be in format 'account:123' or 'visitor:uuid'"
        puts "Usage: rake analytics:erasure:identity['account:42']"
        puts "       rake analytics:erasure:identity['visitor:550e8400-e29b-41d4-a716-446655440000']"
        exit 1
      end

      puts "=== Analytics Erasure: Identity #{identity} ==="
      puts ""

      count = Analytics::Event.erasure!(identity)
      puts "Erased #{count} events for #{identity}"
      puts "Identity changed to: visitor:erased-#{identity.split(':').last}"
      puts "visitor_key cleared for all affected events"
      puts ""
      puts "ERASURE COMPLETE"
    end
  end
end