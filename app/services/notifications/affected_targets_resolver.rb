# frozen_string_literal: true

# Computes the normalized set of followable targets [(type, id)] affected by a
# domain event. This snapshot is stored on the NotificationEvent, so later
# relationship edits never change the event's audience.
#
# Propagation rules (issue #192):
#   Review  -> the Review, its Vintage's Wine, that Wine's Producer
#   Article -> the Article, each linked Vintage's Wine, every direct Producer,
#              every Producer inherited through linked Vintages' Wines
#   Wine    -> the Wine, its Producer
#   Vintage -> its Wine, the Wine's Producer (vintages are not followable)
#   Producer-> the Producer
module Notifications
  class AffectedTargetsResolver
    def initialize(subject)
      @subject = subject
    end

    def resolve
      case @subject
      when Review then review_targets
      when Article then article_targets
      when Wine then wine_targets
      when Vintage then wine_targets(@subject.wine)
      when Producer then [target("Producer", @subject.id)]
      else
        raise ArgumentError, "unknown event subject #{@subject.class.name}"
      end
    end

    private

    def target(type, id)
      { "type" => type, "id" => id }
    end

    def review_targets
      wine = @subject.vintage&.wine
      producer = wine&.producer

      [
        target("Review", @subject.id),
        (target("Wine", wine.id) if wine),
        (target("Producer", producer.id) if producer)
      ].compact
    end

    def article_targets
      targets = [target("Article", @subject.id)]

      @subject.vintages.includes(wine: :producer).find_each do |vintage|
        wine = vintage.wine
        targets << target("Wine", wine.id) if wine
        targets << target("Producer", wine.producer_id) if wine&.producer_id
      end

      @subject.producers.find_each { |producer| targets << target("Producer", producer.id) }

      targets.uniq { |t| [t["type"], t["id"]] }
    end

    def wine_targets(wine = @subject)
      producer = wine.producer

      [
        target("Wine", wine.id),
        (target("Producer", producer.id) if producer)
      ].compact
    end
  end
end