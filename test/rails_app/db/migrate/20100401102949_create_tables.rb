class CreateTables < (Rails.version < '5.1' ? ActiveRecord::Migration : ActiveRecord::Migration[5.0])
  def change
    create_table :users do |t|
      ## Database authenticatable
      t.string :email,              :null => true, :default => ""
      t.string :encrypted_password, :null => true, :default => ""

      ## Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Confirmable
      t.string   :confirmation_token
      t.datetime :confirmed_at
      t.datetime :confirmation_sent_at
      t.string   :unconfirmed_email # Only if using reconfirmable

      t.string :username
      t.integer :profile_id
      t.boolean :active

      ## Invitable
      t.string   :invitation_token, :limit => 60
      t.datetime :invitation_created_at
      t.datetime :invitation_sent_at
      t.datetime :invitation_accepted_at
      t.integer  :invitation_limit
      t.integer  :invited_by_id
      t.string   :invited_by_type
      t.integer :invitations_count, :default => 0

      t.timestamps :null => false
    end
    add_index :users, :invitation_token, :unique => true

    create_table :devise_invitations do |t|
      t.string :invitation_token
      t.datetime :invitation_created_at
      t.datetime :invitation_sent_at
      t.datetime :invitation_accepted_at
      t.datetime :superseded_at
      t.string :superseded_reason
      t.datetime :revoked_at
      t.datetime :resource_created_at
      t.json :invite_key, null: false, default: {}
      t.string :invite_key_digest, null: false
      t.integer :invitable_id
      t.string :invitable_type
      t.integer :invited_by_id
      t.string :invited_by_type
      t.timestamps
    end
    add_index :devise_invitations, :invitation_token, unique: true
    add_index :devise_invitations, [:invitable_type, :invitable_id]
    add_index :devise_invitations, [:invited_by_type, :invited_by_id]
    add_index :devise_invitations, [:invitable_type, :invite_key_digest]

    create_table :admins do |t|
      ## Database authenticatable
      t.string :email,              :null => true, :default => ""
      t.string :encrypted_password, :null => true, :default => ""

      t.integer :invitations_count, :default => 0
    end
  end
end
