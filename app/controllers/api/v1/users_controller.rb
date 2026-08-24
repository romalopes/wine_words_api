class Api::V1::UsersController < ApplicationController
  def me
    render json: {
      user: { id: current_user.id, email: current_user.email, name: current_user.name }
    }
  end
end