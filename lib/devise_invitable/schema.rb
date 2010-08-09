module Devise::Schema
  
  # Public: Add invitation_token and invitation_sent_at columns in the
  # resource's database table.
  #
  # Examples
  #
  #   # For a resource's creation migration:
  #   create_table :the_resources do
  #     t.database_authenticatable :null => false # you need at least this
  #     t.invitable
  #     ...
  #   end
  #   add_index :the_resources, :invitation_token # for invitable
  #
  #   # or if the resource's table already exists, define a migration:
  #   change_table :the_resources do |t|
  #     t.string   :invitation_token, :limit => 20
  #     t.datetime :invitation_sent_at
  #     t.index    :invitation_token # for invitable
  #   end
  #
  #   # And allow null encrypted_password and password_salt:
  #   change_column :the_resources, :encrypted_password, :string, :null => true
  #   change_column :the_resources, :password_salt,      :string, :null => true
  #
  # Returns nothing.
  def invitable
    apply_devise_schema :invitation_token,   String,  :limit => 20
    apply_devise_schema :invitation_sent_at, DateTime
  end
  
end