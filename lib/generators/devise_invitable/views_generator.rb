# frozen_string_literal: true

require 'generators/devise/views_generator'

module DeviseInvitable
  module Generators
    # Copies invitation views into an application.
    class InvitationViewsGenerator < Rails::Generators::Base
      include ::Devise::Generators::ViewPathTemplates

      def copy_views
        view_directory :invitations
      end
    end

    # Selects invitation templates that use Simple Form.
    class SimpleFormForGenerator < InvitationViewsGenerator
      source_root File.expand_path('templates/simple_form_for', __dir__)
    end

    # Selects the default invitation form templates.
    class FormForGenerator < InvitationViewsGenerator
      source_root File.expand_path('../../../app/views/devise', __dir__)
    end

    # Copies invitation mail templates into an application.
    class MailerViewsGenerator < Rails::Generators::Base
      include ::Devise::Generators::ViewPathTemplates

      source_root File.expand_path('../../../app/views/devise', __dir__)
      desc 'Copies Devise mail erb views to your application.'
      hide!

      def copy_views
        view_directory :mailer
      end
    end

    # Installs invitation and mailer views for a selected scope.
    class ViewsGenerator < Rails::Generators::Base
      desc 'Copies all DeviseInvitable views to your application.'
      argument :scope, required: false, default: nil, desc: 'The scope to copy views to'

      invoke MailerViewsGenerator

      hook_for :form_builder, aliases: '-b', desc: 'Form builder to be used',
                              default: defined?(SimpleForm) ? 'simple_form_for' : 'form_for'
    end
  end
end
