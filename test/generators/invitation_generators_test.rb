# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'rails/generators'
require 'generators/devise_invitable/devise_invitable_generator'
require 'generators/devise_invitable/install_generator'
require 'generators/devise_invitable/upgrade_generator'
require 'generators/devise_invitable/upgrade_invitation_digests_generator'
require 'generators/mongoid/devise_invitable_install_generator'
require 'generators/mongoid/devise_invitable_upgrade_generator'

if DEVISE_ORM == :active_record
  require 'generators/active_record/devise_invitable_install_generator'
  require 'generators/active_record/devise_invitable_upgrade_generator'
  require 'generators/active_record/devise_invitable_digest_upgrade_generator'
end

class InvitationGeneratorsTest < ActiveSupport::TestCase
  setup do
    @destination = Dir.mktmpdir('devise-invitable-generators-')
  end

  teardown do
    FileUtils.remove_entry(@destination)
  end

  test 'model generator adds invitable to an existing Devise model' do
    write_file('app/models/user.rb', "class User\n  devise :database_authenticatable\nend\n")

    generate(DeviseInvitable::Generators::DeviseInvitableGenerator, 'User')
    generate(DeviseInvitable::Generators::DeviseInvitableGenerator, 'User')

    assert_equal "class User\n  devise :invitable, :database_authenticatable\nend\n", read_file('app/models/user.rb')
    assert_empty Dir[File.join(@destination, 'db/migrate/*')]
  end

  test 'model generator supports namespaced models' do
    write_file('app/models/admin/user.rb', "class Admin::User\n  devise :database_authenticatable\nend\n")

    generate(DeviseInvitable::Generators::DeviseInvitableGenerator, 'Admin::User')

    assert_includes read_file('app/models/admin/user.rb'), 'devise :invitable, :database_authenticatable'
  end

  test 'model generator leaves missing models alone' do
    generate(DeviseInvitable::Generators::DeviseInvitableGenerator, 'MissingUser')

    assert_empty Dir[File.join(@destination, '**/*')]
  end

  test 'install adds configuration and copies a usable locale' do
    write_file('config/initializers/devise.rb', "Devise.setup do |config|\n  # ==> Configuration for :confirmable\nend\n")

    generate(DeviseInvitable::Generators::InstallGenerator, '--orm', 'mongoid')
    generate(DeviseInvitable::Generators::InstallGenerator, '--orm', 'mongoid')

    initializer = read_file('config/initializers/devise.rb')
    assert_equal 1, initializer.scan('Configuration for :invitable').size
    assert_includes initializer, "  config.allow_legacy_invite_key_digests = false\n"
    assert_match(/Configuration for :invitable.*Configuration for :confirmable/m, initializer)
    locale = YAML.safe_load(read_file('config/locales/devise_invitable.en.yml'))
    assert locale.fetch('en').fetch('devise').fetch('invitations').fetch('send_instructions')
    assert_empty Dir[File.join(@destination, 'db/migrate/*')]
  end

  test 'install preserves existing invitation configuration on repeated runs' do
    original = "Devise.setup do |config|\n  # ==> Configuration for :invitable\n  config.invite_for = 3.days\n  # ==> Configuration for :confirmable\nend\n"
    write_file('config/initializers/devise.rb', original)

    2.times { generate(DeviseInvitable::Generators::InstallGenerator, '--orm', 'mongoid') }

    assert_equal original, read_file('config/initializers/devise.rb')
  end

  test 'install copies the locale when there is no Devise initializer' do
    generate(DeviseInvitable::Generators::InstallGenerator, '--orm', 'mongoid')

    assert_path_exists File.join(@destination, 'config/locales/devise_invitable.en.yml')
    refute_path_exists File.join(@destination, 'config/initializers/devise.rb')
  end

  test 'Mongoid upgrade hook prints the migration command for the named model' do
    output = generate(DeviseInvitable::Generators::UpgradeGenerator, 'Admin::User', '--orm', 'mongoid')

    assert_includes output, 'Run: bin/rails devise_invitable:migrate_invitations[Admin::User]'
    assert_empty Dir[File.join(@destination, '**/*')]
  end

  if DEVISE_ORM == :active_record
    test 'Active Record install hook generates the invitations table migration' do
      generate(DeviseInvitable::Generators::InstallGenerator, '--orm', 'active_record')

      migration = migration_contents('create_devise_invitations')
      assert_includes migration, "class CreateDeviseInvitations < ActiveRecord::Migration[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
      assert_includes migration, 'create_table :devise_invitations'
      assert_includes migration, 't.references :invitable, polymorphic: true'
      assert_includes migration, 't.references :invited_by, polymorphic: true'
      assert_includes migration, 'add_index :devise_invitations, :invitation_token, unique: true'
      assert_includes migration, '[:invitable_type, :invite_key_digest]'
      assert_path_exists File.join(@destination, 'config/locales/devise_invitable.en.yml')
    end

    test 'Active Record upgrade hook defaults to the email invite key' do
      generate(DeviseInvitable::Generators::UpgradeGenerator, 'User', '--orm', 'active_record')

      migration = migration_contents('upgrade_users_devise_invitations')
      assert_includes migration, "class UpgradeUsersDeviseInvitations < ActiveRecord::Migration[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
      assert_includes migration, "self.table_name = 'users'"
      assert_includes migration, 'resource.attributes.slice("email")'
      assert_includes migration, 'remove_column :users, column if column_exists?(:users, column)'
      assert_includes migration, 'ActiveRecord::IrreversibleMigration'
    end

    test 'Active Record upgrade hook passes custom invite keys to the migration' do
      generate(DeviseInvitable::Generators::UpgradeGenerator, 'User', '--orm', 'active_record', '--invite-keys', 'email', 'username')

      migration = migration_contents('upgrade_users_devise_invitations')
      assert_includes migration, 'resource.attributes.slice("email", "username")'
      assert_includes migration, "DeviseInvitable::Invitation.digest_for('User', invite_key)"
    end

    test 'digest upgrade hook generates nullable digests and terminal cleanup' do
      generate(DeviseInvitable::Generators::UpgradeInvitationDigestsGenerator, '--orm', 'active_record')

      migration = migration_contents('upgrade_devise_invitation_digests')
      assert_includes migration, "class UpgradeDeviseInvitationDigests < ActiveRecord::Migration[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
      assert_includes migration, 'change_column_null :devise_invitations, :invite_key_digest, true'
      assert_includes migration, 'SET invite_key_digest = NULL'
      %w[invitation_accepted_at superseded_at revoked_at].each do |field|
        assert_includes migration, "#{field} IS NOT NULL"
      end
      assert_includes migration, 'ActiveRecord::IrreversibleMigration'
    end
  end

  private

  def generate(generator, *arguments)
    capture_io do
      Dir.chdir(@destination) do
        generator.start(arguments, destination_root: @destination)
      end
    end.first
  end

  def write_file(path, contents)
    path = File.join(@destination, path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, contents)
  end

  def read_file(path)
    File.read(File.join(@destination, path))
  end

  def migration_contents(name)
    paths = Dir[File.join(@destination, "db/migrate/*_#{name}.rb")]
    assert_equal 1, paths.size, "Expected one #{name} migration, found #{paths.inspect}"
    File.read(paths.first)
  end
end
