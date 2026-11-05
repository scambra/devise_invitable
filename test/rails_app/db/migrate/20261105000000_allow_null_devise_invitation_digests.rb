class AllowNullDeviseInvitationDigests < ActiveRecord::Migration[7.0]
  def up
    change_column_null :devise_invitations, :invite_key_digest, true

    execute <<~SQL.squish
      UPDATE devise_invitations
      SET invite_key_digest = NULL
      WHERE invitation_accepted_at IS NOT NULL
         OR superseded_at IS NOT NULL
         OR revoked_at IS NOT NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      'Cleared invitation-key digests cannot be reconstructed'
  end
end
