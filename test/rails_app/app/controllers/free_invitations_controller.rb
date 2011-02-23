class FreeInvitationsController < Devise::InvitationsController
  protected
  def authenticate_inviter!
  # everyone can invite
  end
end
