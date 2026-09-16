# The single application-level authentication response.
#
# Every way of signing in — email/password, Google, Apple, Microsoft,
# Facebook — renders exactly this payload, so the React app has ONE
# authenticated state and no provider-specific branches. It is the same
# information the app already relied on: identity, roles and subscription are
# all read from the existing User/Role/UserSubscription records, never from the
# authentication provider.
module UserSessionPayload
  private

  # Renders the authenticated user payload. HTTP 200 by default, matching the
  # existing Devise sessions response.
  def render_user_session(user, status: :ok)
    current_sub = user.user_subscriptions.current.first

    render json: {
      user: {
        id: user.id,
        email: user.email,
        user_name: user.user_name,
        roles: user.role_names,
        # Parity with GET /users/me: the Subscribe page derives its CTA
        # enablement (Choose plan / Manage subscription) from these fields.
        # Without them the cards render disabled until a hard refresh.
        subscription: user.subscription ? { id: user.subscription.id, name: user.subscription.name } : nil,
        billing_provider: current_sub&.billing_provider,
        can_manage_billing: Billing.configured?,
        subscription_status: current_sub&.status
      }
    }, status: status
  end
end