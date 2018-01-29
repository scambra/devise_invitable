module Devise
  module Models
    module Authenticatable
      BLACKLIST_FOR_SERIALIZATION.concat %i[
        invitation_token invitation_created_at invitation_sent_at
        invitation_accepted_at invitation_limit invited_by_type
        invited_by_id invitations_count
      ]
    end
  end
end
