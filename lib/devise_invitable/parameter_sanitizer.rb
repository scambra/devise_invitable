module DeviseInvitable
  # Integrates invitation parameters with both the current and legacy Devise
  # sanitizer APIs.
  #
  # Invite actions permit the model's configured invite keys. Acceptance permits
  # the invitation token, password, and password confirmation. Applications may
  # add further attributes through Devise's normal parameter-sanitizer hooks.
  module ParameterSanitizer
    if defined?(Devise::BaseSanitizer)
      # Returns permitted parameters for creating an invitation.
      def invite
        permit self.for(:invite)
      end

      # Returns permitted parameters for accepting an invitation.
      def accept_invitation
        permit self.for(:accept_invitation)
      end
    end

    private

      if defined?(Devise::BaseSanitizer)
        def permit(keys)
          default_params.permit(*Array(keys))
        end

        def attributes_for(kind)
          case kind
          when :invite
            resource_class.respond_to?(:invite_key_fields) ? resource_class.invite_key_fields : []
          when :accept_invitation
            [:password, :password_confirmation, :invitation_token]
          else
            super
          end
        end
      else
        # Configures invitation parameters through the legacy Devise sanitizer
        # initialization API.
        def initialize(resource_class, resource_name, params)
          super
          permit(:invite, keys: (resource_class.respond_to?(:invite_key_fields) ? resource_class.invite_key_fields : []) )
          permit(:accept_invitation, keys: [:password, :password_confirmation, :invitation_token] )
        end
      end
  end
end
