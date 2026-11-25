# frozen_string_literal: true

module Mongoid
  module Generators
    # Updates legacy invitation fields on a Mongoid model.
    class DeviseInvitableUpgradeGenerator < Rails::Generators::NamedBase
      desc 'Print the Mongoid invitation data migration command.'

      def show_migration_task
        say "Run: bin/rails devise_invitable:migrate_invitations[#{class_name}]"
      end
    end
  end
end
