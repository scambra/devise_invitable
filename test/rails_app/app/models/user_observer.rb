if defined?(ActiveRecord)
  class UserObserver < ActiveRecord::Observer

    def before_invitation_accepted(user)
      user.before_observer_callback_works = true
    end

    def after_invitation_accepted(user)
      user.after_observer_callback_works = true
    end

  end
end