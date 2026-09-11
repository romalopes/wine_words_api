# Shared image mutation helpers used by both the server-rendered controllers
# and the JSON API. Encapsulates validation (returns error messages), primary
# assignment/demotion and blob purging so the Rails UI and React app follow the
# exact same rules.
class ImageService
  # Attaches each uploaded file as a new Image record on `record`. Returns an
  # array of validation error message strings (empty when all images saved).
  def self.attach(record, files)
    Array(files).compact_blank.flat_map do |file|
      img = Image.new(imageable: record)
      img.file.attach(file)
      img.save
      img.errors.full_messages
    end
  end

  # Removes one of `record`'s images by Image id. Purges the underlying blob and
  #, if the removed image was primary, promotes the next remaining image.
  def self.remove(record, image_id)
    image = record.images.find_by(id: image_id)
    return unless image

    was_primary = image.primary?
    image.file.purge
    image.destroy
    return unless was_primary

    record.images.ordered.first&.update_columns(primary: true)
  end
end