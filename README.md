# How to run the project

Before starting the project, please set the env variables required for it to run:

```
RAILS_ENV=
DOCKER_UID=
DOCKER_GID=
DOCKER_USER=
DB_HOST=
DB_USERNAME=
DB_PASSWORD=
```

Then, to start the project, run the following command:

`docker-compose up --build`

# Getting Started

This is a POC project for the Doorkeeper gem usability, so first let's add it in our Gemfile

```
gem 'doorkeeper'
```

Now let's install Doorkeeper and generate its migration by running the following commands:

```bash
bundle exec rails generate doorkeeper:install
bundle exec rails generate doorkeeper:migration
```

After that, go to the migration just created and remove `null: false` for the `redirtect_uri` field on the `oauth_applications` table, because it will not be needed. The `create_table` migration should look like this:

```ruby
create_table :oauth_applications do |t|
  t.string  :name,    null: false
  t.string  :uid,     null: false
  t.string  :secret,  null: false
  t.text    :redirect_uri
  t.string  :scopes,       null: false, default: ''
  t.boolean :confidential, null: false, default: true
  t.timestamps             null: false
end

add_index :oauth_applications, :uid, unique: true
```

Now for the `oauth_access_tokens` table, remove the `previous_refresh_token` field so that when a refresh token is used, the previous will be instantly revoked. The `create_table` migration should look like this:

```ruby
create_table :oauth_access_tokens do |t|
  t.references :resource_owner, index: true
  t.references :application
  t.string :token, null: false

  t.string   :refresh_token
  t.integer  :expires_in
  t.datetime :revoked_at
  t.datetime :created_at, null: false
  t.string   :scopes
end

add_index :oauth_access_tokens, :token, unique: true
add_index :oauth_access_tokens, :refresh_token, unique: true
add_foreign_key(
  :oauth_access_tokens,
  :oauth_applications,
  column: :application_id
)
```

As for the `oauth_access_grants` table, leave it as it is.

Run 

```bash
bundle exec rails db:migrate
```

This POC focuses on working with a Rails API without Doorkeeper Scopes. To configure that, go to the `config/initializers/doorkeeper.rb` file and add the following two lines:

```ruby
default_scopes :public
api_only
base_controller 'ActionController::API'
```

## Password Flow

### Doorkeeper-Devise Configuration

One of the grant flows that will be used is `password`, and for that, we will be using [Devise](https://github.com/heartcombo/devise) as the authentication solution to handle user passwords more conveniently.

To configure Doorkeeper with Devise, go to `config/initializers/doorkeeper.rb` file, and set the `resource_owner_from_credentials` block like this:

```ruby
resource_owner_from_credentials do |_routes|
  user = User.find_for_database_authentication(email: params[:username])
  if user&.valid_for_authentication? { user.valid_password?(params[:password]) } && user&.active_for_authentication?
    request.env['warden'].set_user(user, scope: :user, store: false)
    user
  end
end
```

Then add `password` on grant_flows.

```ruby
grant_flows %w[password]
```

To request the access token, send the `username`, `password` and `grant_type` to the `POST /oauth/token` endpoint.

```json
// Request Body
{
  "username": "username",
  "password": "password",
  "grant_type": "password"
}
```

This will send us back our `access_token` and `refresh_token`.

## Authorization Code Flow

For the `authorization_code` grant, let's define `resource_owner_authenticator` on the Doorkeeper initializer

```ruby
resource_owner_authenticator do
  app = Doorkeeper::Application.find_by_uid(params[:client_id])
  app
end
```

Don't forget to set or add `authorization_code` as grant_flow

```ruby
grant_flows %w[authorization_code]
```

Proceed to create our `oauth_application` directly from the console setting `redirect_uri` as `urn:ietf:wg:oauth:2.0:oob`. This will tell Doorkeeper to display the authorization code instead of redirecting to a client application, because we are working on an API, this will work for us.

```ruby
Doorkeeper::Application.create(name: 'POC App', redirect_uri: "urn:ietf:wg:oauth:2.0:oob")
```

The snippet above will create an application with an `uid` and a `secret`, which will be our `client_id` and `client_secret` respectively.

Now make a request to the `POST /oauth/authorize` endpoint with the following parameters

```json
{
  "client_id": "GENERATED_APPLICATION_UID",
  "redirect_uri": "urn:ietf:wg:oauth:2.0:oob",
  "response_type": "code"
}
```

The response will be like this:

```json
{
  "status": "redirect",
  "redirect_uri": {
    "action": "show",
    "code": "AUTHORIZATION_CODE"
  }
}
```

We will take the code and send it to the `POST /oauth/token` endpoint with the following params:

```json
{
  "client_id": "GENERATED_APPLICATION_UID",
  "client_secret": "GENERATED_APPLICATION_SECRET",
  "code": "AUTHORIZATION_CODE_PREVIOUSLY_GENERATED",
  "redirect_uri": "urn:ietf:wg:oauth:2.0:oob",
  "grant_type": "authorization_code"
}
```

And this will send us back our `access_token` and `refresh_token`.

## PKCE Flow

This flow is an extension of the authorization code flow, where a couple of new properties (`code_challenge` and `code_challenge_method`) will be required to request the authorization code. Also, a new one (`code_verifier`) to request the token.

The `code_verifier` should be a high-entropy cryptographic random string with a minimum of 43 characters and a maxium of 239 characters. Should only use A-Z, a-z, "-", ".", "_" "~" characters.

The `code_challenge_method` is an optional parameter which available values are `plain` and `S256` (this is the recommended).

The `code_challenge` is the SHA256 Hash value for the `code_verifier` safe base64-encoded url.

```ruby
code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier))[0]
```

To request the authorization code make a request to the `POST /oauth/authorize` token with the following parameters 

```json
{
  "client_id": "GENERATED_APPLICATION_UID",
  "code_challenge_method": "S256",
  "code_challenge": "ENCODED_CODE_VERIFIER",
  "redirect_uri": "urn:ietf:wg:oauth:2.0:oob",
  "response_type": "code"
}
```

And now to request a token, make a request to the `POST /oauth/token` endpoint with the same parametes used for the authorization code flow, but adding the `code_verifier`

```json
{
  "client_id": "GENERATED_APPLICATION_UID",
  "client_secret": "GENERATED_APPLICATION_SECRET",
  "code": "AUTHORIZATION_CODE_PREVIOUSLY_GENERATED",
  "code_verifier": "CODE_VERIFIER",
  "redirect_uri": "urn:ietf:wg:oauth:2.0:oob",
  "grant_type": "authorization_code"
}
```

And this will send us back our `access_token` and `refresh_token`. However, for this flow the `refresh_token` won't work.

## Client Credentials Flow

For this flow, only set or add `client_credentials` to the grant_flows

```ruby
grant_flows %w[client_credentials]
```

To request the `access_token`, we have to make a request to the `POST /oauth/token` endpoint, sending only the `client_id`, `client_secret` and `grant_type`.

```json
{
  "client_id": "GENERATED_APPLICATION_UID",
  "client_secret": "GENERATED_APPLICATION_SECRET",
  "grant_type": "client_credentials"
}
```

## Assertion Flow

For this flow, it will be necessary to install `doorkeeper-grants_assertion`

```Gemfile
gem 'doorkeeper-grants_assertion'
```

And then configure the `resource_owner_from_assertion` block where we are going to make a `GET` request to the selected auth API provider, sending the access_token that will come from the client. In this case I used the [Faraday](https://github.com/lostisland/faraday) gem to make the HTTP requests.

```ruby
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
```

Set or add `assertion` to the grant flows

```ruby
grant_flows %w[assertion]
```

## Refresh Token Flow

For this flow, let's add `use_refresh_token` inside our `Doorkeeper.configure` to be able to use it.

To get a new `access_token` from the `refresh_token`, make a request to the `POST /oauth/token` with the following parameters

```json
{
  "refresh_token": "GENERATED_REFRESH_TOKEN",
  "grant_type": "refresh_token"
}
```

Because the `previous_refresh_token` field wa deleted from the `ouath_access_tokens` table, the refresh token can be used only once.

This flow won't work for `client_credentials` or `pkce` flows.
