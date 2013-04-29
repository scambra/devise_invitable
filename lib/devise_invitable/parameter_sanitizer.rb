module DeviseInvitable
  module ParameterSanitizer
    def invite
      default_params.permit(resource_class.invite_key_fields)
    end

    def accept_invitation
      default_params.permit([:password, :password_confirmation])
    end
  end
end
