module DeviseInvitable
  module ParameterSanitizer
    if defined?(Devise::BaseSanitizer)
      def invite
        permit self.for(:invite)
      end

      def accept_invitation
        permit self.for(:accept_invitation)
      end
    end

    def self.included(base)
      if defined?(Devise::BaseSanitizer)
        base.alias_method_chain :attributes_for, :invitable
      else
        base.alias_method_chain :initialize, :invitable
      end
    end

    private

    if defined?(Devise::BaseSanitizer)
      def permit(keys)
        default_params.permit(*Array(keys))
      end

      def attributes_for_with_invitable(kind)
        case kind
        when :invite
          resource_class.respond_to?(:invite_key_fields) ? resource_class.invite_key_fields : []
        when :accept_invitation
          [:password, :password_confirmation, :invitation_token]
        else attributes_for_without_invitable(kind)
        end
      end
    else
      def initialize_with_invitable(resource_class, resource_name, params)
        initialize_without_invitable(resource_class, resource_name, params)
        permit(:invite, keys: (resource_class.respond_to?(:invite_key_fields) ? resource_class.invite_key_fields : []) )
        permit(:accept_invitation, keys: [:password, :password_confirmation, :invitation_token] )
      end
    end
  end
end
