# frozen_string_literal: true

module DeviseInvitable
  module Generators
    # Adds invitation support to an existing Devise model.
    class DeviseInvitableGenerator < Rails::Generators::NamedBase
      namespace 'devise_invitable'

      desc 'Add the :invitable directive to the given model.'

      def inject_devise_invitable_content
        path = File.join('app', 'models', "#{file_path}.rb")
        inject_into_file(path, 'invitable, :', after: 'devise :') if File.exist?(path)
      end
    end
  end
end
