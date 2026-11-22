require "rails_helper"

# Static regression guard for the stored-XSS fixes (security audit issue #23).
# These ERB forms build HTML inside inline <script> blocks; every value that
# comes from the catalogue or user content must be escaped (escapeHtml) and the
# JSON payload injected into a <script> must use json_escape (j), never raw.
RSpec.describe "Server-rendered form XSS sinks", type: :model do
  def read(rel) = File.read(Rails.root.join(rel))

  {
    "app/views/wines/_form.html.erb" => [
      "j((@wine.grapes",
      # renderSelected builds DOM nodes (textContent) rather than innerHTML
      "tag.appendChild(removeBtn)"
    ],
    "app/views/articles/_form.html.erb" => [
      "escapeHtml(review.title)", "escapeHtml(wine.name)"
    ],
    "app/views/articles/edit.html.erb" => [
      "escapeHtml(review.title)", "escapeHtml(wine.name)"
    ],
    "app/views/reviews/_form.html.erb" => [
      "escapeHtml(wine.name)"
    ]
  }.each do |rel, needles|
    it "#{rel} escapes dynamic markup" do
      src = read(rel)
      expect(src).not_to match(/raw\s*\([^)]*to_json/)
      expect(src).not_to include('"<strong>" + review.title')
      expect(src).not_to include('"<strong>" + wine.name')
      needles.each { |needle| expect(src).to include(needle) }
    end
  end
end
