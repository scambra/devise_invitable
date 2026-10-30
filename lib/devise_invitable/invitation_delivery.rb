module DeviseInvitable
  class InvitationDelivery
    def self.call(invitation, resource: nil, acceptance_token: nil, options: {})
      new(
        invitation,
        resource: resource,
        acceptance_token: acceptance_token,
        options: options
      ).deliver
    end

    def self.deliver_now(invitation, resource: nil, acceptance_token: nil, options: {})
      new(
        invitation,
        resource: resource,
        acceptance_token: acceptance_token,
        options: options,
        deliver_now: true
      ).deliver
    end

    def self.enqueue(invitation, resource: nil, acceptance_token: nil, options: {})
      delivery = new(
        invitation,
        resource: resource,
        acceptance_token: acceptance_token,
        options: options
      )
      return unless delivery.deliverable?

      DeviseInvitable.invitation_delivery_job.perform_later(
        invitation,
        delivery.acceptance_token,
        options
      )
    end

    def initialize(invitation, resource: nil, acceptance_token: nil, options: {}, deliver_now: false)
      @invitation = invitation
      @resource = resource
      @acceptance_token = acceptance_token
      @options = options
      @deliver_now = deliver_now
    end

    def deliver
      return unless deliverable?

      token = acceptance_token # Token generation may save the invitation.
      invitation.invitation_sent_at = Time.now.utc
      delivery = send_notification(token)
      invitation.clear_invite_key
      invitation.save!
      delivery
    rescue
      invitation.invitation_sent_at = nil
      raise
    end

    def deliverable?
      invitation.pending? && invitation.invitation_sent_at.nil?
    end

    def acceptance_token
      @acceptance_token ||= resource.send(:prepare_invitation_delivery)
    end

    private

      attr_reader :invitation, :options

      def send_notification(token)
        if @deliver_now
          resource.send(:send_invitation_notification_now, token, options)
        else
          resource.send(
            :send_devise_notification,
            :invitation_instructions,
            token,
            options
          )
        end
      end

      def resource
        @resource ||= begin
          resolved_resource = invitation.invitable || resource_from_invite_key
          resolved_resource.instance_variable_set(:@current_invitation, invitation)
          resolved_resource
        end
      end

      def resource_from_invite_key
        invite_key = invitation.invite_key_for_acceptance.presence || invite_key_from_token
        if invite_key.blank?
          raise DeviseInvitable::MissingInviteKeyError,
            'Cannot deliver a resource-less invitation without an acceptance token or stored invite key'
        end

        invitation.invitable_type.constantize.new(invite_key)
      end

      def invite_key_from_token
        return unless @acceptance_token

        resource_class = invitation.invitable_type.constantize
        token_invitation, invite_key = resource_class.send(
          :invitation_and_key_from_token,
          @acceptance_token
        )
        invite_key if token_invitation&.id == invitation.id
      end
  end
end
