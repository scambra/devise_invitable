module ActionDispatch::Routing
  class Mapper
    protected
      def devise_invitation(mapping, controllers)
        resource :invitation, :only => [:new, :create, :edit, :update],
                  :path => mapping.path_names[:invitation], :controller => controllers[:invitations]
      end
  end
end
