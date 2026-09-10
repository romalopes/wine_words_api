class Api::V1::LogsController < ApplicationController
  before_action :authenticate_admin!

  # GET /api/v1/logs?lines=500
  # Returns the last `lines` lines of the current Rails environment log file.
  def index
    count = (params[:lines] || 500).to_i
    count = 500 if count <= 0
    render json: { logs: recent_log_lines(count) }
  end

  private

  def authenticate_admin!
    return render json: { error: "Authentication required" }, status: :unauthorized unless current_user
    return if current_user.admin?

    render json: { error: "Forbidden" }, status: :forbidden
  end

  # Reads the tail of log/development.log (or log/<env>.log) without
  # loading the entire file into memory for large logs.
  def recent_log_lines(count)
    path = Rails.root.join("log", "#{Rails.env}.log")
    return [] unless File.exist?(path)

    # Use tail to read the last `count` lines efficiently.
    IO.popen(["tail", "-n", count.to_s, path.to_s], err: [:child, :out]) do |io|
      io.read
    end.lines.map(&:chomp)
  rescue StandardError
    []
  end
end
