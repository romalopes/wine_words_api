# Be sure to restart your server when you modify this file.
#
# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.
#
# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # In development the React app runs on localhost:5173 and the API on
    # localhost:3000 — different origins. credentials: true is required so the
    # browser sends the Rails session cookie (used by the Web/SSR impersonation
    # flow) cross-origin. The explicit origin (not "*") is required by the CORS
    # spec when credentials are allowed.
    # origins "http://localhost:5173"
    origins "http://localhost:5173", "https://wine-prediction-app.vercel.app", "http://wine-prediction-mu.vercel.app", "https://wine-prediction-mu.vercel.app"

    resource "*",
      headers: :any,
      expose: ["Authorization"],
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end