# frozen_string_literal: true

namespace :e2e do
  desc "Destructively reset and seed the dedicated Playwright database"
  task prepare: :environment do
    abort "RAILS_ENV must be e2e" unless Rails.env.e2e?

    database = ActiveRecord::Base.connection_db_config.database.to_s
    expected = ENV.fetch("E2E_DATABASE_NAME", "wine_words_api_e2e")
    abort "Refusing to reset unexpected database #{database.inspect}" unless database == expected

    # A previously interrupted Playwright/Rails process can leave an idle
    # PostgreSQL session behind even after its TCP server has stopped. PostgreSQL
    # refuses to drop a database while any such session remains connected, so
    # terminate only the *other* sessions on the safety-validated E2E database.
    connection = ActiveRecord::Base.connection
    connection.execute(<<~SQL.squish)
      SELECT pg_terminate_backend(pid)
      FROM pg_stat_activity
      WHERE datname = #{connection.quote(database)}
        AND pid <> pg_backend_pid()
    SQL

    ActiveRecord::Base.connection_pool.disconnect!
    %w[db:drop db:create db:schema:load].each do |task_name|
      task = Rake::Task[task_name]
      task.reenable
      task.invoke
    end

    load Rails.root.join("db/seeds/e2e.rb")
  end
end
