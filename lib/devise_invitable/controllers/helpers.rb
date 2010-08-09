module DeviseInvitable
  module Controllers
    module Helpers
    protected
      # This method is used in a before_filter in the invitations controller.
      # Override it to fit your needs.
      def authenticate_inviter!
        send(:"authenticate_#{resource_name}!")
      end
    end
  end
end