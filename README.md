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

This a POC project for Doorkeeper usability, so first we have to add it in our Gemfile

```
gem 'doorkeeper'
```

Now we have to install doorkeeper and generate its migration by running the following commands:

`bundle exec rails generate doorkeeper:install`  
`bundle exec rails generate doorkeeper:migration`

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

Now for `oauth_access_tokens` table, remove `previous_refresh_token` field so once we use a refresh toke this will be instantly revoked. The table create migration should look like this:

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

And to be able to use refresh token, uncomment `use_refresh_token` line.