class Api::V1::ProducerMembershipsController < ApplicationController
  before_action :require_catalogue_manager!, except: :index_for_producer

  # GET /api/v1/users/:user_id/producer_memberships
  def index
    user = User.find(params[:user_id])
    memberships = user.producer_memberships.includes(:producer, :created_by)
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
    memberships = producer.producer_memberships.includes(:user, :created_by)
    render json: memberships.map { |pm| membership_json(pm) }
  end

  # POST /api/v1/users/:user_id/producer_memberships
  def create
    user = User.find(params[:user_id])
    producer = Producer.find(params[:producer_id])

    membership = user.producer_memberships.build(producer: producer, created_by: current_user)

    if membership.save
      render json: membership_json(membership), status: :created
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
      created_at: membership.created_at
    }
  end
end