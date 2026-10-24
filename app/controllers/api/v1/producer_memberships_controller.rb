class Api::V1::ProducerMembershipsController < ApplicationController
  before_action :require_catalogue_manager!, except: :index_for_producer

  # GET /api/v1/users/:user_id/producer_memberships
  def index
    user = User.find(params[:user_id])
    memberships = user.producer_memberships.includes(producer: :country).includes(:created_by)
    render json: memberships.map { |pm| membership_json(pm) }
  end

  # GET /api/v1/producers/:id/memberships
  # Read-only view of the users linked to a producer. Wider than the write
  # endpoints: Reviewers may see who is linked (wine_manager?), but only
  # catalogue managers may create/unlink.
  def index_for_producer
    require_wine_manager!
    return if performed?

    producer = Producer.find(params[:id])
    memberships = producer.producer_memberships.includes(:user, :created_by).includes(producer: :country)
    render json: memberships.map { |pm| membership_json(pm) }
  end

  # POST /api/v1/users/:user_id/producer_memberships
  # Body: { producer_membership: { producer_id: 42, membership_type: "manager" } }
  # The legacy flat body ({ producer_id: 42 }) is still accepted for clients
  # that have not been updated yet, but `membership_type` is required.
  def create
    user = User.find(params[:user_id])

    if membership_params[:producer_id].blank?
      return render json: { errors: ["Producer can't be blank"] }, status: :unprocessable_entity
    end

    producer = Producer.find(membership_params[:producer_id])

    if user.producer_memberships.exists?(producer_id: producer.id)
      return render json: { errors: ["This user is already linked to this producer"] },
                    status: :conflict
    end

    membership = user.producer_memberships.build(
      producer: producer,
      membership_type: membership_params[:membership_type],
      # Actor is always server-derived; a client-supplied created_by_id is ignored.
      created_by: real_current_user
    )

    if membership.save
      render json: membership_json(membership), status: :created
    else
      render json: { errors: membership.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    render json: { errors: ["This user is already linked to this producer"] }, status: :conflict
  end

  # PATCH /api/v1/users/:user_id/producer_memberships/:id
  # Body: { producer_membership: { membership_type: "owner" } }
  def update
    user = User.find(params[:user_id])
    membership = user.producer_memberships.find(params[:id])

    if membership.update(membership_type: membership_params[:membership_type])
      render json: membership_json(membership)
    else
      render json: { errors: membership.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/users/:user_id/producer_memberships/:id
  def destroy
    user = User.find(params[:user_id])
    membership = user.producer_memberships.find(params[:id])
    membership.destroy!
    head :no_content
  end

  private

  def membership_params
    source = params[:producer_membership].present? ? params.require(:producer_membership) : params
    source.permit(:producer_id, :membership_type)
  end

  def require_catalogue_manager!
    head :forbidden unless real_current_user&.catalogue_manager?
  end

  def require_wine_manager!
    head :forbidden unless real_current_user&.wine_manager?
  end

  def membership_json(membership)
    {
      id: membership.id,
      user: {
        id: membership.user.id,
        display_name: membership.user.display_name,
        email: membership.user.email
      },
      producer: {
        id: membership.producer.id,
        name: membership.producer.name,
        slug: membership.producer.slug,
        country: membership.producer.country&.name
      },
      created_by: membership.created_by ? { id: membership.created_by.id, display_name: membership.created_by.display_name } : nil,
      created_at: membership.created_at,
      updated_at: membership.updated_at,
      membership_type: membership.membership_type,
      can_edit: membership.can_edit_producer?
    }
  end
end
