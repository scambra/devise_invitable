class DeviseInvitable::RegistrationsController < Devise::RegistrationsController
  protected

    def build_resource(hash = {})
      build_invited_resource(hash) if hash[:email]
      self.resource ||= super
      if self.resource.respond_to?(:registering_directly=) && resource_class.pending_invitations_for(hash).any?
        self.resource.registering_directly = true
      end
      self.resource
    end

    def build_invited_resource(hash)
      self.resource = resource_class.to_adapter.find_first(email: hash[:email])
      if self.resource && self.resource.respond_to?(:invited_to_sign_up?) && self.resource.invited_to_sign_up?
        self.resource.attributes = hash
        self.resource.send_confirmation_instructions if self.resource.confirmation_required_for_invited?
      else
        self.resource = nil
      end
    end
end
