# Phase 2: API and Authorization

## Summary
Added API routes and controllers for producer membership management, user detail retrieval, and current user's producers. Updated producer authorization to allow linked users edit access.

## Changes

### Routes (`config/routes.rb`)
```ruby
namespace :api do
  namespace :v1 do
    # Admin-only user management
    resources :users, only: [:index, :show] do
      member do
        patch :assign_roles
        patch :assign_subscription
      end
      resources :producer_memberships, only: [:index, :create, :destroy]
    end
    
    # Current user's linked producers
    namespace :account do
      get :producers
    end
    
    # Producers with updated authorization
    resources :producers do
      member do
        post :logo_upload
        delete :logo_remove
      end
    end
  end
end
```

### Controller: `app/controllers/api/v1/producer_memberships_controller.rb`
```ruby
module Api::V1
  class ProducerMembershipsController < ApplicationController
    before_action :ensure_admin
    before_action :set_user
    before_action :set_membership, only: [:destroy]

    def index
      render json: @user.producer_memberships.includes(:producer, :created_by).as_json(
        include: { producer: { only: [:id, :name, :slug, :country] }, created_by: { only: [:id, :display_name] } }
      )
    end

    def create
      @membership = @user.producer_memberships.build(producer_id: params[:producer_id], created_by: current_user)
      if @membership.save
        render json: @membership.as_json(include: { producer: { only: [:id, :name, :slug, :country] }, created_by: { only: [:id, :display_name] } }), status: :created
      else
        render json: { errors: @membership.errors.full_messages }, status: :unprocessable_content
      end
    end

    def destroy
      @membership.destroy
      head :no_content
    end

    private

    def set_user
      @user = User.find(params[:user_id])
    end

    def set_membership
      @membership = @user.producer_memberships.find(params[:id])
    end
  end
end
```

### UsersController Updates (`app/controllers/api/v1/users_controller.rb`)
Added `show` action:
```ruby
def show
  @user = User.includes(:roles, :subscription, producer_memberships: [:producer, :created_by]).find(params[:id])
  render json: @user.as_json(
    include: {
      roles: { only: [:id, :name] },
      subscription: { only: [:id, :name] },
      producer_memberships: { include: { producer: { only: [:id, :name, :slug, :country] }, created_by: { only: [:id, :display_name] } } }
    }
  )
end
```

### AccountsController Updates (`app/controllers/api/v1/accounts_controller.rb`)
Added `my_producers` action:
```ruby
def my_producers
  producers = current_user.producers.select(:id, :name, :slug, :country, :email, :producer_type, :founded_year)
  render json: producers.as_json
end
```

### ProducersController Authorization Update
Updated `ensure_wine_manager` to also allow linked users:
```ruby
def ensure_wine_manager
  unless current_user.wine_manager? || current_user.producers.include?(@producer)
    render json: { error: "Not authorized" }, status: :forbidden
  end
end
```

This allows:
- Wine managers (Admin/Editor/Reviewer): Full access (create, update, delete, logo)
- Linked users: Update, logo_upload, logo_remove only
- Unlinked users: No mutation access

---

*Completed: 2026-10-22*