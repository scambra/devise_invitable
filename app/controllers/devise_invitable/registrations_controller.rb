# frozen_string_literal: true

# Reuses pending invitees when completing direct registration.
class DeviseInvitable::RegistrationsController < Devise::RegistrationsController
  protected

  def build_resource(hash = {})
    build_invited_resource(hash) if hash[:email]
    self.resource ||= super
    if resource.respond_to?(:registering_directly=) && resource_class.pending_invitations_for(hash).any?
      resource.registering_directly = true
    end
    resource
  end

  def build_invited_resource(hash)
    self.resource = resource_class.to_adapter.find_first(email: hash[:email])
    if resource.respond_to?(:invited_to_sign_up?) && resource.invited_to_sign_up?
      resource.attributes = hash
      resource.send_confirmation_instructions if resource.confirmation_required_for_invited?
    else
      self.resource = nil
    end
  end
end
