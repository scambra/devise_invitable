require 'rails/generators/active_record'

module ActiveRecord
  module Generators
    class DeviseInvitableUpgradeGenerator < ActiveRecord::Generators::Base
      source_root File.expand_path('../templates', __FILE__)

      class_option :invite_keys, type: :array, default: ['email']

      def copy_upgrade_migration
        migration_template 'upgrade_devise_invitations.rb',
          "db/migrate/upgrade_#{table_name}_devise_invitations.rb",
          migration_version: migration_version,
          invite_keys: options[:invite_keys]
      end

      def migration_version
        if Rails::VERSION::MAJOR >= 5
          "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
        end
      end

      def invite_keys
        options[:invite_keys]
      end
    end
  end
end
