# Reset sequences to the current maximum primary key after importing explicit IDs.
# Run with: bin/rails runner db/seeds/reset_pk_sequences.rb
# Run while writes are paused to avoid racing with inserts.

ActiveRecord::Base.connection_pool.with_connection do |connection|
  connection.tables.sort.each do |table|
    primary_key, sequence = connection.pk_and_sequence_for(table)
    next unless primary_key && sequence

    connection.reset_pk_sequence!(table, primary_key, sequence)
    puts "Reset primary-key sequence for #{table}"
  end
end
