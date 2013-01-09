module DeviseInvitable
  module Mailer

    # Deliver an invitation email
    def invitation_instructions(record, opts={})
      devise_mail(record, :invitation_instructions, opts)
    end
  end
end
