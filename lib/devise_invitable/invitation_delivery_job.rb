require 'active_job'

module DeviseInvitable
  # Default Active Job adapter for invitation delivery.
  #
  # The queue is read from +Devise.invitation_delivery_queue_name+. Applications
  # may configure a different job class with +Devise.invitation_delivery_job+.
  class InvitationDeliveryJob < ActiveJob::Base
    queue_as { Devise.invitation_delivery_queue_name }

    # Delivers a previously enqueued invitation immediately inside this job.
    def perform(invitation, acceptance_token = nil, options = {})
      DeviseInvitable::InvitationDelivery.deliver_now(
        invitation,
        acceptance_token: acceptance_token,
        options: options
      )
    end
  end
end
