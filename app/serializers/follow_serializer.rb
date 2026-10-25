# One Follow row: the signed-in user's subscription to a Producer, Wine,
# Review or Article. The serializer returns enough target detail for the
# Following page to render a row (label + link) without an extra request.
class FollowSerializer
  def initialize(follow, base_url = nil)
    @follow = follow
    @base_url = base_url
  end

  def as_json
    {
      id: @follow.id,
      followable_type: @follow.followable_type,
      followable_id: @follow.followable_id,
      target_label: target_label,
      target_slug: target_slug,
      target_path: target_path,
      following: true,
      created_at: iso(@follow.created_at)
    }
  end

  private

  def target
    @follow.followable
  end

  def target_label
    case target
    when Producer, Wine then target.name
    when Review, Article then target.title
    end
  end

  def target_slug
    target&.slug
  end

  def target_path
    slug = target_slug
    return nil if slug.blank?

    case target
    when Producer then "/producers/#{slug}"
    when Wine then "/wines/#{slug}"
    when Review then "/reviews/#{slug}"
    when Article then "/articles/#{slug}"
    end
  end

  def iso(time)
    time&.iso8601
  end
end