class DeviseInvitable::RegistrationsController < Devise::RegistrationsController
  protected

  def build_resource(hash = nil)
    hash ||= resource_params || {}
    if hash[:email]
      self.resource = resource_class.where(email: hash[:email]).first
      if resource && resource.invited_to_sign_up?
        resource.attributes = hash
        resource.send_confirmation_instructions if resource.confirmation_required_for_invited?
        resource.accept_invitation
      end
    end
    self.resource ||= super
  end
end
