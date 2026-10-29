require 'active_support/key_generator'
require 'active_support/message_encryptor'
require 'active_support/core_ext/hash/indifferent_access'
require 'json'

module DeviseInvitable
  class AcceptanceToken
    CIPHER = 'aes-256-gcm'.freeze
    MAX_INVITATION_DATA_BYTES = 1_024
    PURPOSE = 'devise_invitable.invitation'.freeze
    SALT = 'devise_invitable encrypted invitation'.freeze

    class << self
      def generate(invitation:, raw_token:, invite_key:, invitation_data: nil)
        invitation_data = normalize_invitation_data(invitation_data)
        encryptor.encrypt_and_sign(
          {
            invitation_id: invitation.id.to_s,
            invitable_type: invitation.invitable_type,
            raw_token: raw_token,
            invite_key: invite_key.to_h,
            invitation_data: invitation_data,
          },
          purpose: PURPOSE
        )
      end

      def normalize_invitation_data(invitation_data)
        return {} if invitation_data.nil?

        data = invitation_data.to_h
        serialized_data = JSON.generate(data)
        if serialized_data.bytesize > MAX_INVITATION_DATA_BYTES
          raise InvitationDataTooLargeError,
            "invitation_data exceeds #{MAX_INVITATION_DATA_BYTES} serialized bytes"
        end
        data
      rescue NoMethodError, TypeError, JSON::GeneratorError
        raise ArgumentError, 'invitation_data must be a JSON-compatible hash'
      end

      def decode(token)
        payload = encryptor.decrypt_and_verify(token, purpose: PURPOSE)
        payload&.with_indifferent_access
      rescue ActiveSupport::MessageEncryptor::InvalidMessage
        nil
      end

      private

        def encryptor
          key_length = ActiveSupport::MessageEncryptor.key_len(CIPHER)
          key = Rails.application.key_generator.generate_key(SALT, key_length)
          ActiveSupport::MessageEncryptor.new(key, cipher: CIPHER, serializer: JSON)
        end
    end
  end
end
