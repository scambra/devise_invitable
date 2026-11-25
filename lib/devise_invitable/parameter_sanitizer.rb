# frozen_string_literal: true

module DeviseInvitable
  # Integrates invitation parameters with Devise's parameter sanitizer.
  #
  # Invite actions permit the model's configured invite keys. Acceptance permits
  # the invitation token, password, and password confirmation. Applications may
  # add further attributes through Devise's normal parameter-sanitizer hooks.
  module ParameterSanitizer
    private

    # Configures the permitted parameters for invitation actions.
    def initialize(resource_class, resource_name, params)
      super
      invite_keys = resource_class.respond_to?(:invite_key_fields) ? resource_class.invite_key_fields : []
      permit(:invite, keys: invite_keys)
      permit(:accept_invitation, keys: %i[password password_confirmation invitation_token])
    end
  end
end
