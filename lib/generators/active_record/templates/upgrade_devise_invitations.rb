require 'digest'

class Upgrade<%= table_name.camelize %>DeviseInvitations < ActiveRecord::Migration<%= migration_version %>
  OLD_INVITATION_COLUMNS = %i[
    invitation_token invitation_created_at invitation_sent_at
    invitation_accepted_at invited_by_id invited_by_type
  ].freeze

  def up
    create_devise_invitations_table unless table_exists?(:devise_invitations)

    resource_class = Class.new(ActiveRecord::Base) do
      self.table_name = '<%= table_name %>'
      self.inheritance_column = :_type_disabled
    end
    invitation_class = Class.new(ActiveRecord::Base) do
      self.table_name = 'devise_invitations'
    end

    resource_class.where.not(invitation_created_at: nil).find_each do |resource|
      invite_key = resource.attributes.slice(<%= invite_keys.map(&:to_s).map(&:inspect).join(', ') %>)
      digest_components = invite_key.map { |key, value| [key.to_s, value.to_s] }.sort.flatten
      invitation_class.create!(
        invitation_token: resource.invitation_token,
        invitation_created_at: resource.invitation_created_at,
        invitation_sent_at: resource.invitation_sent_at,
        invitation_accepted_at: resource.invitation_accepted_at,
        resource_created_at: resource.invitation_created_at,
        invite_key: invite_key,
        invite_key_digest: Digest::SHA256.hexdigest((['<%= class_name %>'] + digest_components).join("\0")),
        invitable_type: '<%= class_name %>',
        invitable_id: resource.id,
        invited_by_type: resource.invited_by_type,
        invited_by_id: resource.invited_by_id,
        created_at: resource.invitation_created_at,
        updated_at: resource.invitation_accepted_at || resource.invitation_sent_at || resource.invitation_created_at
      )
    end

    OLD_INVITATION_COLUMNS.each do |column|
      remove_column :<%= table_name %>, column if column_exists?(:<%= table_name %>, column)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      'Multiple invitation records cannot be losslessly moved back onto <%= table_name %>'
  end

  private

    def create_devise_invitations_table
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
