class CreateDeviseInvitations < ActiveRecord::Migration<%= migration_version %>
  def change
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
      t.references :invitable, polymorphic: true
      t.references :invited_by, polymorphic: true
      t.timestamps
    end

    add_index :devise_invitations, :invitation_token, unique: true
    add_index :devise_invitations, [:invitable_type, :invite_key_digest],
      name: 'index_devise_invitations_on_type_and_invite_key'
  end
end
