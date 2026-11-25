# frozen_string_literal: true

module ActionDispatch::Routing
  # Adds invitation routes to Devise resource mappings.
  class Mapper
    protected

    def devise_invitation(mapping, controllers)
      resource :invitation, only: %i[new create update],
                            path: mapping.path_names[:invitation], controller: controllers[:invitations] do
        get :edit, path: mapping.path_names[:accept], as: :accept
        get :destroy, path: mapping.path_names[:remove], as: :remove
      end
    end
  end
end
