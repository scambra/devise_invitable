require 'generators/devise/views_generator'

module DeviseInvitable
  module Generators
    class ViewsGenerator < Rails::Generators::Base
      desc 'Copies all DeviseInvitable views to your application.'

      argument :scope, :required => false, :default => nil,
                       :desc => "The scope to copy views to"

      include ::Devise::Generators::ViewPathTemplates
      source_root File.expand_path("../../../../app/views/devise", __FILE__)
      def copy_views
        view_directory :invitations
        view_directory :mailer
      end
    end
  end
end
