class AddFacebookIdToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :facebook_id, :text, null: true
  end
end
