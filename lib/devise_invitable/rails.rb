module DeviseInvitable
  class Engine < ::Rails::Engine

    ActiveSupport.on_load(:action_controller) do
      include DeviseInvitable::Controllers::Helpers
    end

    # Devise::Mailer includes Devise::Mailers::Helpers, so adding our mailer methods there reaches every
    # (re)loaded Devise.mailer without resolving it at boot. Resolving it from an on_load(:action_mailer)
    # hook re-enters the app's parent_mailer while it is still loading (#929).
    initializer "devise_invitable.mailer" do
      Devise::Mailers::Helpers.include DeviseInvitable::Mailer
    end
    # extend mapping with after_initialize because it's not reloaded
    config.after_initialize do
      Devise::Mapping.send :prepend, DeviseInvitable::Mapping
      Devise::ParameterSanitizer.send :prepend, DeviseInvitable::ParameterSanitizer
    end
  end
end
