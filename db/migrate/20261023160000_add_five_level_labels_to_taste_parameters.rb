class AddFiveLevelLabelsToTasteParameters < ActiveRecord::Migration[8.1]
  LABELS_BY_SLUG = {
    "sweetness" => ["Dry", "Off-dry", "Medium-dry", "Medium-sweet", "Sweet"],
    "acidity" => ["Low", "Medium (-)", "Medium", "Medium (+)", "High"],
    "tannin" => ["Low", "Medium (-)", "Medium", "Medium (+)", "High"],
    "alcohol" => ["Low", "Medium (-)", "Medium", "Medium (+)", "High"],
    "body" => ["Light", "Medium (-)", "Medium", "Medium (+)", "Full"],
    "fruit" => ["Light", "Medium (-)", "Medium", "Medium (+)", "Pronounced"]
  }.freeze

  def up
    (1..5).each { |level| add_column :taste_parameters, "label_#{level}", :string }

    LABELS_BY_SLUG.each do |slug, labels|
      execute <<~SQL.squish
        UPDATE taste_parameters
        SET label_1 = #{quote(labels[0])}, label_2 = #{quote(labels[1])},
            label_3 = #{quote(labels[2])}, label_4 = #{quote(labels[3])},
            label_5 = #{quote(labels[4])}
        WHERE slug = #{quote(slug)}
      SQL
    end

    # Preserve custom parameters' existing endpoints and make their intermediate
    # states explicit rather than silently replacing editorial terminology.
    execute <<~SQL.squish
      UPDATE taste_parameters
      SET label_1 = COALESCE(NULLIF(label_1, ''), NULLIF(low, ''), 'Low'),
          label_2 = COALESCE(NULLIF(label_2, ''), 'Medium (-)'),
          label_3 = COALESCE(NULLIF(label_3, ''), 'Medium'),
          label_4 = COALESCE(NULLIF(label_4, ''), 'Medium (+)'),
          label_5 = COALESCE(NULLIF(label_5, ''), NULLIF(high, ''), 'High')
    SQL

    (1..5).each { |level| change_column_null :taste_parameters, "label_#{level}", false }
  end

  def down
    (1..5).each { |level| remove_column :taste_parameters, "label_#{level}" }
  end
end