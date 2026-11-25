module Devise
  module Models
    module Invitable
      module TokenLookup
        # Finds the resource identified by +original_token+.
        #
        # When +only_valid+ is +true+, returns +nil+ for a blank, invalid, or
        # expired token. Otherwise returns a resource with an error on
        # +invitation_token+ when the token cannot be accepted.
        def find_by_invitation_token(original_token, only_valid)
          if original_token.blank?
            invitable = new
            invitable.errors.add(:invitation_token, :blank)
            return invitable unless only_valid

            return
          end

          invitation, invite_key = invitation_and_key_from_token(original_token)
          invitable = invitation&.invitable || new(invite_key || {})
          invitable.assign_attributes(invite_key) if invitation && invite_key.present?
          invitable.instance_variable_set(:@current_invitation, invitation)
          if invitation.nil? || !invitable.valid_invitation?
            invitable.errors.add(:invitation_token, :invalid)
          end
          invitable unless only_valid && invitable.errors.present?
        end

        private

        def invitation_and_key_from_token(original_token)
          payload = DeviseInvitable::AcceptanceToken.decode(original_token)
          return legacy_invitation_and_key(original_token) unless payload
          return [nil, nil] unless payload[:invitable_type] == devise_invitable_base_class.name

          invitation_token = Devise.token_generator.digest(
            self,
            :invitation_token,
            payload[:raw_token]
          )
          invitation = DeviseInvitable::Invitation.to_adapter.find_first(
            id: payload[:invitation_id],
            invitable_type: devise_invitable_base_class.name,
            invitation_token: invitation_token
          )
          invitation.invitation_data = payload[:invitation_data] || {} if invitation
          invite_key = normalized_invite_keys(payload[:invite_key] || {})
          invitation = nil unless invitation &&
                                  DeviseInvitable::Invitation.valid_digest?(
                                    invitation.invite_key_digest,
                                    devise_invitable_base_class.name,
                                    invite_key,
                                    allow_legacy: allow_legacy_invite_key_digests
                                  )
          [invitation, invite_key]
        end

        def legacy_invitation_and_key(original_token)
          invitation_token = Devise.token_generator.digest(self, :invitation_token, original_token)
          invitation = DeviseInvitable::Invitation.to_adapter.find_first(
            invitable_type: devise_invitable_base_class.name,
            invitation_token: invitation_token
          )
          [invitation, invitation&.invite_key]
        end
      end
    end
  end
end
