module DeviseInvitable
  module Generators
    class UpgradeInvitationDigestsGenerator < Rails::Generators::Base
      namespace 'devise_invitable:upgrade_invitation_digests'

      desc 'Allow terminal invitation-key digests to be cleared.'

      hook_for :orm, as: :devise_invitable_digest_upgrade
    end
  end
end
