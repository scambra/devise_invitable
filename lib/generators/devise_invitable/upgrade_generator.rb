module DeviseInvitable
  module Generators
    class UpgradeGenerator < Rails::Generators::NamedBase
      namespace 'devise_invitable:upgrade'

      class_option :invite_keys,
        type: :array,
        default: ['email'],
        desc: 'Columns used as invite keys in the old resource table'

      desc 'Generate a migration from resource-backed invitations to the invitations table.'

      hook_for :orm, as: :devise_invitable_upgrade
    end
  end
end
