class PrivilegedAccountCreation
  Result = Data.define(:user, :errors, :forbidden) do
    def success?
      errors.empty?
    end

    def forbidden?
      forbidden
    end
  end

  ADMIN_ASSIGNABLE_ROLES = %w[editor reviewer reader guest].freeze
  EDITOR_ASSIGNABLE_ROLES = %w[reviewer reader].freeze

  def self.call(actor:, attributes:)
    new(actor:, attributes:).call
  end

  def initialize(actor:, attributes:)
    @actor = actor
    @attributes = attributes.deep_symbolize_keys
  end

  def call
    return Result.new(user: nil, errors: [ "Forbidden" ], forbidden: true) unless actor&.catalogue_manager?

    user = User.new(
      first_name: attributes[:first_name],
      last_name: attributes[:last_name],
      email: attributes[:email],
      account_status: :unclaimed
    )
    user.require_account_names = true

    roles = requested_roles
    role_error = validate_roles(roles)
    return Result.new(user:, errors: [ role_error ], forbidden: true) if role_error

    User.transaction do
      user.save!
      user.roles = roles
      create_memberships!(user)
    end

    Result.new(user: user.reload, errors: [], forbidden: false)
  rescue ActiveRecord::RecordInvalid => e
    Result.new(user: user, errors: e.record.errors.full_messages, forbidden: false)
  rescue ActiveRecord::RecordNotFound
    Result.new(user: user, errors: [ "Role or producer was not found" ], forbidden: false)
  end

  private

  attr_reader :actor, :attributes

  def requested_roles
    ids = Array(attributes[:role_ids]).compact_blank.map(&:to_i).uniq
    return [ Role.find_or_create_by!(name: "Reader") ] if ids.empty?

    Role.where(id: ids).to_a.tap do |roles|
      raise ActiveRecord::RecordNotFound unless roles.size == ids.size
    end
  end

  def validate_roles(roles)
    allowed = actor.admin? ? ADMIN_ASSIGNABLE_ROLES : EDITOR_ASSIGNABLE_ROLES
    disallowed = roles.map(&:name) - allowed
    display_names = disallowed.map { |name| Role.names[name] || name.humanize }
    "You cannot assign these roles: #{display_names.join(', ')}" if disallowed.any?
  end

  def create_memberships!(user)
    Array(attributes[:producer_memberships]).each do |membership|
      membership = membership.deep_symbolize_keys
      user.producer_memberships.create!(
        producer: Producer.find(membership[:producer_id]),
        membership_type: membership[:membership_type],
        created_by: actor
      )
    end
  end
end
