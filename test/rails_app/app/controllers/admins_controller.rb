class AdminsController < Devise::InvitationsController
  protected
  def authenticate_inviter!
    authenticate_admin!(true)
  end
end
