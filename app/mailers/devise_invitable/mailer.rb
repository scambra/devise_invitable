module DeviseInvitable::Mailer

  # Deliver an invitation when is requested
  def invitation(record)
    setup_mail(record, :invitation)
  end
  
end

Devise::Mailer.send :include, DeviseInvitable::Mailer