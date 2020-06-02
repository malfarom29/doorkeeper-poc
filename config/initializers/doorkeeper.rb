# frozen_string_literal: true

Doorkeeper.configure do
  orm :active_record
  default_scopes :public
  api_only
  base_controller 'ActionController::API'
  allow_blank_redirect_uri false

  resource_owner_from_credentials do |_routes|
    user = User.find_for_database_authentication(email: params[:username])
    if user&.valid_for_authentication? { user.valid_password?(params[:password]) } && user&.active_for_authentication?
      request.env['warden'].set_user(user, scope: :user, store: false)
      user
    end
  end

  resource_owner_authenticator do
    app = Doorkeeper::Application.find_by_uid(params[:client_id])
    app
  end

  resource_owner_from_assertion do
    case params[:provider]
    when 'google'
      conn = FaradayConnection::OAuthProvider::Google.new
      provider_id = conn.request_id(params[:access_token])
      User.find_by_google_id(provider_id)
    when 'facebook'
      conn = FaradayConnection::OAuthProvider::Facebook.new
      provider_id = conn.request_id(params[:access_token])
      User.find_by_facebook_id(provider_id)
    end
  end

  use_refresh_token
  grant_flows %w[password authorization_code client_credentials assertion]
end
