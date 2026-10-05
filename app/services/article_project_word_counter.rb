require "cgi"

class ArticleProjectWordCounter
  BLOCK_TAGS = %r{</?(?:address|article|blockquote|br|div|h[1-6]|li|p|section|table|td|th|tr|ul|ol)[^>]*>}i
  REMOVED_TAGS = %r{<(script|style)\b[^>]*>.*?</\1\s*>}im

  def self.count(html)
    text = html.to_s.gsub(REMOVED_TAGS, " ")
    text = text.gsub(BLOCK_TAGS, " ")
    text = ActionController::Base.helpers.strip_tags(text)
    CGI.unescapeHTML(text).squish.split(/\s+/).reject(&:blank?).length
  end
end