Devise.module_eval do
  # Time interval where the invitation token is valid.
  mattr_accessor :invite_for
  @@invite_for = 0
end
Devise::ALL = (Devise::ALL + [:invitable]).freeze

module ActionController::Routing
  class RouteSet #:nodoc:
    class Mapper #:doc:
      # Adds route generation for invitable. This method is responsible to
      # generate all needed routes for devise, based on what modules you have
      # defined in your model.
      # Examples: Let's say you have an User model configured to use
      # invitable module. After creating this inside your routes:
      #
      #   map.devise_for :users
      #
      # this method is going to look inside your User model and create the
      # needed routes:
      #
      #  # Invitation routes for Invitable, if User model has :invitable configured
      #    new_user_invitation GET  /users/invitation/new(.:format)   {:controller=>"invitations", :action=>"new"}
      #   edit_user_invitation GET  /users/invitation/edit(.:format)  {:controller=>"invitations", :action=>"edit"}
      #        user_invitation PUT  /users/invitation(.:format)       {:controller=>"invitations", :action=>"update"}
      #                        POST /users/invitation(.:format)       {:controller=>"invitations", :action=>"create"}
      #
      
      protected
        def invitable(routes, mapping)
          routes.resource :invitation, :only => [:new, :create, :edit, :update], :as => mapping.path_names[:invitation]
        end
    end
  end
end

module DeviseInvitable; end

require 'devise_invitable/mailer'
require 'devise_invitable/routes'
require 'devise_invitable/schema'
