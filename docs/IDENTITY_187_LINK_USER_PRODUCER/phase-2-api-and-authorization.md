# Phase 2: API and Authorization

**Status:** ✅ Complete

## New Routes (`config/routes.rb`)

```ruby
namespace :api do
  namespace :v1 do
    resources :users, only: [] do
      resources :producer_memberships, only: [:index, :create, :destroy]
    end
    get "users/:id", to: "users#show"
    get "account/producers", to: "accounts#my_producers"
  end
end
```

### Routes Added
| Method | Path | Controller#Action | Auth |
|--------|------|-------------------|------|
| GET | `/api/v1/users/:user_id/producer_memberships` | `producer_memberships#index` | Admin |
| POST | `/api/v1/users/:user_id/producer_memberships` | `producer_memberships#create` | Admin |
| DELETE | `/api/v1/users/:user_id/producer_memberships/:id` | `producer_memberships#destroy` | Admin |
| GET | `/api/v1/users/:id` | `users#show` | Admin |
| GET | `/api/v1/account/producers` | `accounts#my_producers` | Authenticated user |

## New Controller: `Api::V1::ProducerMembershipsController`

**File:** `app/controllers/api/v1/producer_memberships_controller.rb`

```ruby
class Api::V1::ProducerMembershipsController < ApplicationController
  before_action :require_admin!
  before_action :set_user

  def index
    @memberships = @user.producer_memberships.includes(:producer, :created_by)
    render json: @memberships, each_serializer: ProducerMembershipSerializer
  end

  def create
    @membership = @user.producer_memberships.build(producer_id: params[:producer_id])
    @membership.created_by = current_user
    if @membership.save
      render json: @membership, serializer: ProducerMembershipSerializer, status: :created
    else
      render json: { errors: @membership.errors }, status: :unprocessable_entity
    end
  end

  def destroy
    @membership = @user.producer_memberships.find(params[:membership_id])
    @membership.destroy
    head :no_content
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  end
end
```

## Updated Controllers

### UsersController (`app/controllers/api/v1/users_controller.rb`)
- Added `show` action for `GET /api/v1/users/:id` (admin only)
- Returns `UserDetail` with `producer_memberships`, `analytics_opt_out`

### AccountsController (`app/controllers/api/v1/accounts_controller.rb`)
- Added `my_producers` action for `GET /api/v1/account/producers`
- Returns `ProducerSummary[]` scoped to `current_user`

### ProducersController (`app/controllers/api/v1/producers_controller.rb`)
- Updated authorization for `update`, `upload_logo`, `remove_logo`:
  ```ruby
  def ensure_producer_editor!
    return if current_user.wine_manager?
    return if current_user.producers.include?(@producer)
    render json: { error: "Not authorized" }, status: :forbidden
  end
  ```

## Authorization Matrix

| Endpoint | Admin | Editor/Reviewer | Linked User | Other |
|----------|-------|-----------------|-------------|-------|
| `GET /users/:id` | ✅ | ❌ | ❌ | ❌ |
| `GET /users/:id/producer_memberships` | ✅ | ❌ | ❌ | ❌ |
| `POST /users/:id/producer_memberships` | ✅ | ❌ | ❌ | ❌ |
| `DELETE /users/:id/producer_memberships/:id` | ✅ | ❌ | ❌ | ❌ |
| `GET /account/producers` | ✅ | ✅ | ✅ | ❌ (auth required) |
| `PATCH /producers/:id` | ✅ | ✅ | ✅ (if linked) | ❌ |
| `POST /producers/:id/logo` | ✅ | ✅ | ✅ (if linked) | ❌ |
| `DELETE /producers/:id/logo` | ✅ | ✅ | ✅ (if linked) | ❌ |

## Serializer: `ProducerMembershipSerializer`
Returns:
```json
{
  "id": 1,
  "producer": { "id": 1, "name": "Chateau Margaux", "slug": "chateau-margaux", "country": "France" },
  "created_by": { "id": 2, "display_name": "Admin User" },
  "created_at": "2026-10-21T23:46:37.000Z"
}
```

## Tests
- `spec/requests/api/v1/producer_memberships_spec.rb` - 12 examples, 0 failures
  - Admin-only access (403 for non-admins)
  - List memberships
  - Create membership
  - Prevent duplicate membership
  - Destroy membership
  - Returns 404 for non-existent user/membership