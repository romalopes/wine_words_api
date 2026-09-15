# frozen_string_literal: true

# API endpoints for user impersonation (admin only).
#
# An admin can "act as" another (non-admin) user. Impersonation state is stored
# in two places depending on the client:
#
#   * Web/SSR requests: session[:impersonated_user_id]
#   * API/React requests: an +impersonated_user_id+ claim in the Bearer JWT
#
# On start, the endpoint returns a fresh JWT carrying the claim so the React app
# can store it and send it on subsequent requests. On stop, a fresh JWT without
# the claim is returned.
module Api
  module V1
    class ImpersonationsController < ApplicationController
      # POST /api/v1/impersonations  body: { user_id: <id> }
      # Starts impersonating the given user. Returns a new JWT with the
      # impersonated_user_id claim and the effective user representation.
      def create
        return unless authorize_admin!
        return unless (target_user = find_target_user)
        return unless ensure_not_admin_target!(target_user)
        return unless ensure_not_nested!

        # Set session for Web/SSR clients and issue a new JWT for API clients.
        session[:impersonated_user_id] = target_user.id
        token = issue_jwt_for(real_current_user, impersonated_user_id: target_user.id)

        render json: {
          token: token,
          impersonating: true,
          effective_user: user_json(target_user),
          real_user: user_json(real_current_user),
        }
      end

      # DELETE /api/v1/impersonations
      # Stops the active impersonation. Returns a fresh JWT without the claim.
      def destroy
        unless impersonating?
          render json: { error: "Not currently impersonating" }, status: :unprocessable_entity
          return
        end

        session.delete(:impersonated_user_id)
        token = issue_jwt_for(real_current_user)

        render json: {
          token: token,
          impersonating: false,
          effective_user: user_json(real_current_user),
          real_user: user_json(real_current_user),
        }
      end

      # GET /api/v1/impersonations
      # Returns the current impersonation status and both user representations.
      def show
        if impersonating?
          target_user = User.find_by(id: impersonated_user_id)
          render json: {
            impersonating: true,
            effective_user: target_user ? user_json(target_user) : nil,
            real_user: user_json(real_current_user),
          }
        else
          render json: { impersonating: false, effective_user: nil, real_user: user_json(real_current_user) }
        end
      end

      private

      # Guard methods render an error and return false on failure; they return
      # true when the caller may proceed.

      def authorize_admin!
        return true if real_current_user&.admin?

        render json: { error: "Only admins can impersonate other users" }, status: :forbidden
        false
      end

      def find_target_user
        user = User.find_by(id: params[:user_id])
        return user if user

        render json: { error: "User not found" }, status: :not_found
        nil
      end

      def ensure_not_admin_target!(target_user)
        return true unless target_user.admin?

        render json: { error: "Cannot impersonate another admin" }, status: :forbidden
        false
      end

      def ensure_not_nested!
        return true unless impersonating?

        render json: { error: "Already impersonating a user. Stop the current session first." },
               status: :conflict
        false
      end

      def user_json(user)
        return nil unless user

        current_sub = user.user_subscriptions.current.first
        # Payload parity with GET /users/me: the Subscribe page derives its CTA
        # enablement (Choose plan / Manage subscription) from these fields.
        # Without them the cards render disabled until a hard refresh.
        {
          id: user.id,
          email: user.email,
          user_name: user.user_name,
          roles: user.role_names,
          subscription: user.subscription ? { id: user.subscription.id, name: user.subscription.name } : nil,
          billing_provider: current_sub&.billing_provider,
          can_manage_billing: Billing.configured?,
          subscription_status: current_sub&.status
        }
      end
    end
  end
end
