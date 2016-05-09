module DeviseInvitable::Controllers::Helpers
  extend ActiveSupport::Concern

  included do
  end
  
  def after_invite_path_for(inviter, invitee = nil)
    after_sign_in_path_for(inviter)
  end
  
  def after_accept_path_for(resource)
    after_sign_in_path_for(resource)
  end
  
  protected
  def authenticate_inviter!
    send(:"authenticate_#{resource_name}!", :force => true)
  end
  
end

