# How to run the project

You must set the env variables required for the project

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

This is a POC project for Doorkeeper usability, so first we have to add it in our Gemfile

```
gem 'doorkeeper'
```

Now we have to install doorkeeper and generate its migration by running the following commands:

```bash
bundle exec rails generate doorkeeper:install
bundle exec rails generate doorkeeper:migration
```

Now we go to the migration we've just created and remove `null: false` for redirtect_uri on `oauth_applications` table, because we don't really need it right now. So the table create migration should look like this:

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

Now for `oauth_access_tokens` table, remove `previous_refresh_token` field so once we use a refresh token this will be instantly revoked. The table create migration should look like this:

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

As for `oauth_access_grants` table, leave as it is.

Run 

```bash
bundle exec rails db:migrate
```

Now, as we are working on a Rails API and also working without using doorkeeper scopes, go to `config/initializers/doorkeeper.rb` and add the following two lines

```ruby
default_scopes :public
api_only
base_controller 'ActionController::API'
```

## Doorkeeper-Devise Configuration

One of the grant flows we are using is `password`, for this we are going to use [Devise](https://github.com/heartcombo/devise) as authentication solution so we can handle user passwords easily.

To configure doorkeeper with devise, go to `config/initializers/doorkeeper.rb`.

For this grant we set `resource_owner_from_credentials` block like this:

```ruby
resource_owner_from_credentials do |_routes|
  user = User.find_for_database_authentication(email: params[:username])
  if user&.valid_for_authentication? { user.valid_password?(params[:password]) } && user&.active_for_authentication?
    request.env['warden'].set_user(user, scope: :user, store: false)
    user
  end
end
```

And add `password` on grant_flows.

```ruby
grant_flows %w[password]
```

Now, to request the access token send the `username`, `password` and `grant_type` to `POST /oauth/token`.

```json
// Request Body
{
  "username": "username",
  "password": "password",
  "grant_type": "password"
}
```

And this will send us back our `access_token` and `refresh_token`.

## Doorkeeper Authorization Code Flow

For the `authorization_code` grant we define `resource_owner_authenticator` on the initializer

```ruby
resource_owner_authenticator do
  app = Doorkeeper::Application.find_by_uid(params[:client_id])
  app
end
```

And set or add `authorization_code` as grant_flow

```ruby
grant_flows %w[authorization_code]
```

Now we proceed to create our `oauth_application` directly from the console setting `redirect_uri` as `urn:ietf:wg:oauth:2.0:oob`  this will tell doorkeeper to display authorization code instead of redirecting to a client application, because we are working on an API this works for us.

```ruby
Doorkeeper::Application.create(name: 'POC App', redirect_uri: "urn:ietf:wg:oauth:2.0:oob")
```

This will create an application with an `uid` and a `secret`, which will be our `client_id` and `client_secret` respectively.

Now make a request to `POST /oauth/authorize` with the following parameters

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

We will take the code and send it to `POST /oauth/token` with the following params

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
