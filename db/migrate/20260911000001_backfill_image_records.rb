# One-time data migration. Existing Active Storage attachments (name = 'images')
# on Wine/Article/Review/Producer become application-level Image records. Each
# Image owns the SAME underlying blob — the attachment row is simply re-pointed
# at the new Image and renamed 'images' -> 'file' (has_one_attached name). No
# file is copied or re-uploaded, and existing blob URLs stay valid because the
# blob key is unchanged.
class BackfillImageRecords < ActiveRecord::Migration[8.1]
  IMAGEABLE_TYPES = {
    "Wine"     => Wine,
    "Article"  => Article,
    "Review"   => Review,
    "Producer" => Producer
  }.freeze

  def up
    attachments = ActiveStorage::Attachment
      .where(name: "images", record_type: IMAGEABLE_TYPES.keys)
      .order(:record_type, :record_id, :created_at, :id)

    attachments.group_by { |a| [a.record_type, a.record_id] }.each do |(type, id), group|
      klass = IMAGEABLE_TYPES[type]
      record = klass&.find_by(id: id)
      next unless record

      group.each_with_index do |att, idx|
        image = Image.create!(
          imageable: record,
          position: idx + 1,
          primary: idx.zero?
        )
        # Re-point the attachment at the Image record without touching its blob.
        att.update_columns(record_type: "Image", record_id: image.id, name: "file")
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Existing attachments were folded into Image records and cannot be restored automatically."
  end
end