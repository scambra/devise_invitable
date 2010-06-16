module ActionDispatch::Routing
  class Mapper
    protected
      def devise_invitation(mapping, controllers)
        scope mapping.full_path[1..-1], :name_prefix => mapping.name do
          resource :invitation, :only => [:new, :create, :update, :edit], :as => mapping.path_names[:invitation], :controller => controllers[:invitations]
          # get :"accept_#{mapping.name}_invitation", :controller => 'invitations', :action => 'edit' # , :name_prefix => nil, :path_prefix => "#{mapping.name}/invitation"
        end
      end
  end
end
