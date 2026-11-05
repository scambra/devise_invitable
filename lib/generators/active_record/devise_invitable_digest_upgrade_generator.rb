require 'rails/generators/active_record'

module ActiveRecord
  module Generators
    class DeviseInvitableDigestUpgradeGenerator < ActiveRecord::Generators::Base
      source_root File.expand_path('../templates', __FILE__)
      argument :name, type: :string, default: 'devise_invitation'

      def copy_digest_upgrade_migration
        migration_template 'upgrade_devise_invitation_digests.rb',
          'db/migrate/upgrade_devise_invitation_digests.rb',
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
