module DeviseInvitable
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('../../templates', __FILE__)
      desc 'Install the invitations store, add configuration, and copy the English locale.'

      hook_for :orm, as: :devise_invitable_install

      def add_config_options_to_initializer
        devise_initializer_path = 'config/initializers/devise.rb'
        if File.exist?(devise_initializer_path)
          old_content = File.read(devise_initializer_path)

          if old_content.match(/^\s*# ==> Configuration for :invitable\n/)
            false
          else
            inject_into_file(devise_initializer_path, before: "  # ==> Configuration for :confirmable\n") do
<<-CONTENT
  # ==> Configuration for :invitable
  # The period the generated invitation token is valid.
  # After this period, the invited resource won't be able to accept the invitation.
  # When invite_for is 0 (the default), the invitation won't expire.
  # config.invite_for = 2.weeks

  # Number of invitations users can send.
  # - If invitation_limit is nil, there is no limit for invitations, users can
  # send unlimited invitations, invitation_limit column is not used.
  # - If invitation_limit is 0, users can't send invitations by default.
  # - If invitation_limit n > 0, users can send n invitations.
  # You can change invitation_limit column for some users so they can send more
  # or less invitations, even with global invitation_limit = 0
  # Default: nil
  # config.invitation_limit = 5

  # The key to be used to check existing users when sending an invitation
  # and the regexp used to test it when validate_on_invite is not set.
  # config.invite_key = { email: /\\A[^@]+@[^@]+\\z/ }
  # config.invite_key = { email: /\\A[^@]+@[^@]+\\z/, username: nil }

  # Ensure that invited record is valid.
  # The invitation won't be sent if this check fails.
  # Default: false
  # config.validate_on_invite = true

  # Resend invitation if user with invited status is invited again
  # Default: true
  # config.resend_invitation = false

  # Create a placeholder resource as soon as an invitation is sent. When false,
  # the resource is created only after the invitation is accepted.
  # Default: false
  # config.create_resource_on_invitation = true

  # Supersede other pending invitations for the same invite keys when one is
  # accepted. Disable this only for independently acceptable invitation data.
  # Default: true
  # config.supersede_other_invitations_on_accept = false

  # The column name used for counter_cache column. If this is nil,
  # the #invited_by association is declared without counter_cache.
  # Default: nil
  # config.invited_by_counter_cache = :invitations_count

  # Auto-login after the user accepts the invite. If this is false,
  # the user will need to manually log in after accepting the invite.
  # Default: true
  # config.allow_insecure_sign_in_after_accept = false

CONTENT
            end
          end
        end
      end

      def copy_locale
        copy_file '../../../config/locales/en.yml', 'config/locales/devise_invitable.en.yml'
      end

    end
  end
end
