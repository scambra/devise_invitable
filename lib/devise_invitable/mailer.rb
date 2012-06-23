module DeviseInvitable
  module Mailer

    # Deliver an invitation email
    def invitation_instructions(record)
      devise_mail(record, :invitation_instructions)
    end
  end
end
