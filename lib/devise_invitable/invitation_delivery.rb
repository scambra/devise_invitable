module DeviseInvitable
  # Coordinates invitation email delivery across two different boundaries:
  #
  # * .call enters through the resource's +send_devise_notification+ hook. This
  #   is the normal application-facing path and honors model overrides, including
  #   overrides that choose to enqueue an Action Mailer delivery.
  # * .deliver_now bypasses that hook and invokes the configured Devise mailer
  #   with +deliver_now+. It is used after an invitation job has already been
  #   dequeued, so an override cannot enqueue a second job.
  #
  # Delivery is idempotent for pending invitations: only an invitation without
  # +invitation_sent_at+ is deliverable. The service reconstructs resource-less
  # invitees when necessary and persists the sent timestamp only after success.
  class InvitationDelivery
    # Delivers +invitation+ through the resource's +send_devise_notification+
    # hook and returns that hook's result.
    #
    # This is the normal entry point for synchronous invitation delivery. It
    # deliberately honors application overrides of +send_devise_notification+;
    # consequently, an override may turn the final mail delivery into an
    # Action Mailer +deliver_later+ call.
    def self.call(invitation, resource: nil, acceptance_token: nil, options: {})
      new(
        invitation,
        resource: resource,
        acceptance_token: acceptance_token,
        options: options
      ).deliver
    end

    # Delivers +invitation+ directly through the configured Devise mailer using
    # Action Mailer's +deliver_now+, bypassing +send_devise_notification+.
    #
    # Use this after a background job has already been dequeued. Bypassing the
    # resource hook prevents a +send_devise_notification+ override that calls
    # +deliver_later+ from creating a second job. Applications normally call
    # .call or .enqueue instead; InvitationDeliveryJob calls this method.
    def self.deliver_now(invitation, resource: nil, acceptance_token: nil, options: {})
      new(
        invitation,
        resource: resource,
        acceptance_token: acceptance_token,
        options: options,
        deliver_now: true
      ).deliver
    end

    # Enqueues +invitation+ with the configured invitation delivery job.
    # Returns +nil+ when the invitation has already been sent or is not pending.
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

    # Builds a delivery for +invitation+. Supplying +resource+ or
    # +acceptance_token+ avoids reconstructing them from persisted state.
    def initialize(invitation, resource: nil, acceptance_token: nil, options: {}, deliver_now: false)
      @invitation = invitation
      @resource = resource
      @acceptance_token = acceptance_token
      @options = options
      @deliver_now = deliver_now
    end

    # Sends the invitation and returns the mail delivery result.
    #
    # On success, clears any stored invite key and persists
    # +invitation_sent_at+. On failure, resets the in-memory sent timestamp and
    # re-raises so the invitation remains retryable.
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

    # Returns whether the invitation is pending and has not been sent.
    def deliverable?
      invitation.pending? && invitation.invitation_sent_at.nil?
    end

    # Returns the supplied acceptance token or generates one from the invitee.
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
