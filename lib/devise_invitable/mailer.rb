module DeviseInvitable
  module Mailer
    
    # Deliver an invitation email
    def invitation_instructions(record)
      setup_mail(record, :invitation_instructions)
    end
    
  end
end