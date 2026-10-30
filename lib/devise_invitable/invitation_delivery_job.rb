require 'active_job'

module DeviseInvitable
  class InvitationDeliveryJob < ActiveJob::Base
    queue_as { Devise.invitation_delivery_queue_name }

    def perform(invitation, acceptance_token = nil, options = {})
      DeviseInvitable::InvitationDelivery.deliver_now(
        invitation,
        acceptance_token: acceptance_token,
        options: options
      )
    end
  end
end
