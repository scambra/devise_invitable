module DeviseInvitable
  module Mailer
    
    # Deliver an invitation email
    def invitation(record)
      setup_mail(record, :invitation)
    end
    
  end
end