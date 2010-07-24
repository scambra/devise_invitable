module ActionDispatch #:nodoc:
  module Routing #:nodoc:
    class Mapper #:nodoc:
    
    protected
    
      def devise_invitation(mapping, controllers)
        scope mapping.full_path[1..-1], :name_prefix => mapping.name do
          resource :invitation, :only => [:new, :create, :edit, :update], :path => mapping.path_names[:invitation],
                   :controller => controllers[:invitations] do
            get mapping.path_names[:accept].to_sym, :action => :edit
          end
        end
      end
    end
  end
end