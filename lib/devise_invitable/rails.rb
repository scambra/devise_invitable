module DeviseInvitable
  class Engine < ::Rails::Engine

    ActiveSupport.on_load(:action_controller) do
      include DeviseInvitable::Controllers::Helpers
    end

    # We use to_prepare instead of after_initialize here because Devise is a Rails engine; its
    # mailer is reloaded like the rest of the user's app.  Got to make sure that our mailer methods
    # are included each time Devise.mailer is (re)loaded.
    #
    # The work is wrapped in ActiveSupport.on_load(:action_mailer) so that resolving
    # Devise.mailer (a String#constantize) doesn't force ActionMailer::Base to load
    # before app initialization completes. Without this wrapper, Rails edge's
    # guard_load_hooks support (rails/rails#56201) logs an early-load-hook warning
    # for :action_mailer (and :active_job, via MailDeliveryJob) on every boot.
    config.to_prepare do
      ActiveSupport.on_load(:action_mailer) do
        Devise.mailer.send :include, DeviseInvitable::Mailer
        unless Devise.mailer.ancestors.include?(Devise::Mailers::Helpers)
          Devise.mailer.send :include, Devise::Mailers::Helpers
        end
      end
    end
    # extend mapping with after_initialize because it's not reloaded
    config.after_initialize do
      Devise::Mapping.send :prepend, DeviseInvitable::Mapping
      Devise::ParameterSanitizer.send :prepend, DeviseInvitable::ParameterSanitizer
    end
  end
end
