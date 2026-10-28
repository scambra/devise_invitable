require 'rails/generators/active_record'

module ActiveRecord
  module Generators
    class DeviseInvitableInstallGenerator < ActiveRecord::Generators::Base
      source_root File.expand_path('../templates', __FILE__)
      argument :name, type: :string, default: 'devise_invitation'

      def copy_devise_invitations_migration
        migration_template 'create_devise_invitations.rb',
          'db/migrate/create_devise_invitations.rb',
          migration_version: migration_version
      end

      def migration_version
        if Rails::VERSION::MAJOR >= 5
          "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
        end
      end
    end
  end
end
