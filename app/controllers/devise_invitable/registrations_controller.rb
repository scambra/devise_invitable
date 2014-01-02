class DeviseInvitable::RegistrationsController < Devise::RegistrationsController
  protected

  def build_resource(hash = nil)
    hash ||= resource_params || {}
    if hash[:email]
      self.resource = resource_class.where(:email => hash[:email], :encrypted_password => '').first
      if self.resource
        self.resource.attributes = hash
        self.resource.send_confirmation_instructions if self.resource.confirmation_required_for_invited?
        self.resource.accept_invitation
      end
    end
    self.resource ||= super
  end
end
