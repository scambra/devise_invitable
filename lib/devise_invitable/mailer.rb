# frozen_string_literal: true

require 'devise/version'

module DeviseInvitable
  # Adds invitation instructions to the Devise mailer.
  module Mailer
    # Deliver an invitation email
    def invitation_instructions(record, token, opts = {})
      @token = token
      devise_mail(record, :invitation_instructions, opts)
    end
  end
end
