module DeviseInvitable
  module Routes #:doc:
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

ActionController::Routing::RouteSet::Mapper.send :include, DeviseInvitable::Routes
